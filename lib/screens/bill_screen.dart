import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:printing/printing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'pdf_generator.dart';
import 'package:fixit/services/bill_email_service.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../widgets/bill_summary_bottom_sheet.dart';

import 'package:easy_localization/easy_localization.dart';

class BillScreen extends StatefulWidget {
  @override
  _BillScreenState createState() => _BillScreenState();
}

class _BillScreenState extends State<BillScreen> {
  final _formKey = GlobalKey<FormState>();

  // Invoice Number will be auto-generated and not editable.
  final TextEditingController invoiceNumberController = TextEditingController();
  final TextEditingController userNameController = TextEditingController();
  final TextEditingController serialNumberController = TextEditingController();
  final TextEditingController serviceChargeController = TextEditingController(text: "0");
  final TextEditingController customerEmailController = TextEditingController();

  String? selectedProductCode;
  List<Map<String, dynamic>> productList = [];
  List<Map<String, dynamic>> selectedProducts = [];

  // Brand dropdown selection.
  String? selectedBrand;
  final List<String> brandList = ["Atomberg", "Symphony", "Usha"];

  // Technician consent checkbox.
  bool technicianConsent = false;

  final SupabaseClient supabase = Supabase.instance.client;

  // Cache generated PDF bytes for sharing/downloading.
  Uint8List? generatedPdfBytes;

  // Loading flag to show a loader when invoice generation is in progress.
  bool isLoading = false;

  // Instance of our email service.
  final BillEmailService emailService = BillEmailService();

  /// Holds the raw sequence from RPC, e.g. "ES/25-26/001"
  String _baseInvoice = "";

  /// Warranty type prefix: “OW” or “IN”
  String _warrantyType = "OW";

  @override
  void initState() {
    super.initState();
    fetchProducts();
    _populateInvoiceNumber();
  }

  Future<void> _populateInvoiceNumber() async {
    final dynamic result = await supabase.rpc('generate_invoice_number');
    String base;
    if (result is String) {
      base = result;
    } else if (result is Map<String, dynamic> && result.containsKey('data')) {
      base = result['data'] as String;
    } else {
      base = "ES/25-26/001";
    }
    setState(() {
      _baseInvoice = base;
      _rebuildInvoice();
    });
  }

  /// Combine base + prefix → full invoice
  void _rebuildInvoice() {
    final parts = _baseInvoice.split('/');
    if (parts.length == 3) {
      invoiceNumberController.text = "${parts[0]}/${parts[1]}/$_warrantyType${parts[2]}";
    } else {
      invoiceNumberController.text = _baseInvoice;
    }
  }


  Future<void> fetchProducts() async {
    final response = await supabase
        .from('atomberg')
        .select('product_name, product_code, product_description, customer_price')
        .eq('active', true);
    if (response != null && response is List) {
      setState(() {
        productList = response.map<Map<String, dynamic>>((product) {
          // Set a default quantity of 1 if not already specified.
          return {
            'product_name': product['product_name'],
            'product_code': product['product_code'],
            'product_description': product['product_description'] ?? 'No description available',
            'customer_price': product['customer_price'].toString(),
            'quantity': 1,
          };
        }).toList();
      });
    } else {
      print("Error fetching products.");
    }
  }

  void addProductToList(Map<String, dynamic> product) {
    setState(() {
      // If the product is already added, you might want to increase its quantity.
      final existing = selectedProducts.firstWhere(
            (p) => p['product_code'] == product['product_code'],
        orElse: () => {},
      );
      if (existing.isNotEmpty) {
        existing['quantity'] = (existing['quantity'] ?? 1) + 1;
      } else {
        selectedProducts.add(Map<String, dynamic>.from(product));
      }
    });
  }

  /// Get the next unique invoice number via an RPC call.
  Future<String> getNextInvoiceNumber() async {
    final dynamic result = await supabase.rpc('generate_invoice_number');
    if (result is String) {
      return result;
    } else if (result is Map<String, dynamic> && result.containsKey('data')) {
      return result['data'] as String;
    } else {
      print("RPC returned unexpected data: $result");
      return "ES/25-26/00";
    }
  }

  /// Upload PDF bytes to Supabase Storage (bucket: 'invoices') and return its public URL.
  Future<String?> uploadInvoicePdf(Uint8List pdfBytes, String filename) async {
    try {
      final String filePath = await supabase.storage
          .from('invoices')
          .uploadBinary(filename, pdfBytes, fileOptions: const FileOptions(upsert: true));
      final String publicUrl = supabase.storage.from('invoices').getPublicUrl(filePath);
      return publicUrl;
    } catch (e) {
      print("Error uploading PDF: $e");
      return null;
    }
  }

  /// Handles invoice generation, order insertion, PDF upload, emailing, and sharing.
  Future<void> handleGenerateInvoice() async {
    if (!_formKey.currentState!.validate() || selectedProducts.isEmpty || selectedBrand == null) {
      return;
    }
    if (!technicianConsent) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Technician consent is required.")),
      );
      return;
    }

    setState(() {
      isLoading = true;
    });

    String invoiceNumber = invoiceNumberController.text;
    double serviceCharge = double.tryParse(serviceChargeController.text) ?? 0.0;

    // Generate the PDF.
    Uint8List pdfBytes = await generatePdf(
      invoiceNumber: invoiceNumber,
      userName: userNameController.text,
      serialNumber: serialNumberController.text,
      customerEmail: customerEmailController.text,
      brand: selectedBrand!,
      serviceCharge: serviceCharge,
      selectedProducts: selectedProducts,
    );
    setState(() {
      generatedPdfBytes = pdfBytes;
    });

    String filename = "${invoiceNumber}_${customerEmailController.text}.pdf";

    // Upload the PDF.
    String? pdfUrl = await uploadInvoicePdf(pdfBytes, filename);
    if (pdfUrl == null) {
      setState(() {
        isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Error uploading invoice PDF")),
      );
      return;
    }

    // Calculate subtotal using quantity * price.
    double subTotal = selectedProducts.fold(0.0, (sum, product) {
      final String cleanedPrice = product['customer_price'].toString().replaceAll(RegExp(r'[^0-9.]'), '');
      final double price = double.tryParse(cleanedPrice) ?? 0.0;
      final int quantity = int.tryParse(product['quantity'].toString()) ?? 1;
      return sum + (price * quantity);
    });
    double finalTotal = subTotal + serviceCharge;

    final dynamic orderResponse = await supabase.from('orders').insert({
      'invoice_no': invoiceNumber,
      'brand': selectedBrand,
      'product_code': selectedProducts.map((p) => "${p['product_code']} (x${p['quantity']})").join(', '),
      'description': selectedProducts.map((p) => "${p['product_description']} (x${p['quantity']})").join(', '),
      'tech_name': userNameController.text,
      'amount': subTotal,
      'service_charge': serviceCharge,
      'final_amount': finalTotal,
      'invoice_copy': pdfUrl,
      'customer_email': customerEmailController.text,
    });

    // Send the invoice email with PDF attached.
    await emailService.sendInvoiceEmail(
      customerEmail: customerEmailController.text,
      filename: filename,
      pdfBytes: pdfBytes,
    );

    setState(() {
      isLoading = false;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Invoice generated, order updated, and email sent.")),
    );
  }

  /// Allows the technician to share/download the generated PDF.
  void handleSharePdf() {
    if (generatedPdfBytes != null) {
      try {
        Printing.sharePdf(
          bytes: generatedPdfBytes!,
          filename: "${invoiceNumberController.text}_${customerEmailController.text}.pdf",
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error sharing PDF: $e")),
        );
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please generate an invoice first.")),
      );
    }
  }

  void showBillSummaryBottomSheet(
      BuildContext context,
      double subTotal,
      List<Map<String, dynamic>> productList,
      TextEditingController serviceChargeController,
      VoidCallback onConfirmDownload,
      ValueChanged<bool> onConsentChanged,
      ) {
    double parsedServiceCharge = double.tryParse(serviceChargeController.text) ?? 0.0;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => BillSummaryBottomSheet(
        subtotal: subTotal,
        serviceCharge: parsedServiceCharge, // from TextField
        selectedProducts: productList,
        onConsentChanged: onConsentChanged,
        onConfirmDownload: onConfirmDownload,
      ),
    );
  }

  Widget _buildStyledField(
      String label,
      IconData icon,
      TextEditingController controller, {
        bool readOnly = false,
        bool enabled = true,
        TextInputType keyboardType = TextInputType.text,
      }) {
    return TextFormField(
      controller: controller,
      readOnly: readOnly,
      enabled: enabled,
      keyboardType: keyboardType,
      decoration: InputDecoration(
        labelText: label,
        hintText: 'Enter $label',
        suffixIcon: Icon(icon, color: const Color(0xFFEFE516)),
        focusedBorder: const UnderlineInputBorder(
          borderSide: BorderSide(color: Color(0xFFEFE516)),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFFEFE516),
        title: Text(
          'bill_form.title'.tr(),
          style: const TextStyle(fontSize: 30, fontWeight: FontWeight.w800, color: Colors.white),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.share, color: Colors.white),
            onPressed: handleSharePdf,
          )
        ],
      ),
      body: Stack(
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 10),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 10),
                  Text(
                    'bill_form.fill_details'.tr(), // Use translation key
                    style: const TextStyle(fontSize: 16),
                  ),
                  const SizedBox(height: 10),
                  _buildStyledField(
                    'bill_form.invoice_number'.tr(), // Use translation key
                    Icons.confirmation_number,
                    invoiceNumberController,
                    readOnly: true,
                    enabled: false,
                  ),
                  SizedBox(height: 16),
                  // — Warranty Type —
                  Text("bill_form.warranty_type".tr()),
                  DropdownButtonFormField<String>(
                    value: _warrantyType,
                    items: const [
                      DropdownMenuItem(value: 'OW', child: Text('Out of Warranty (OW)')),
                      DropdownMenuItem(value: 'IW', child: Text('In Warranty (IW)')),
                    ],
                    onChanged: (val) {
                      if (val != null) {
                        setState(() {
                          _warrantyType = val;
                          _rebuildInvoice();
                        });
                      }
                    },
                  ),

                  const SizedBox(height: 16),
                  _buildStyledField(
                    'bill_form.user_name'.tr(), // Use translation key
                    Icons.person,
                    userNameController,
                  ),
                  const SizedBox(height: 16),
                  _buildStyledField(
                    'bill_form.customer_email'.tr(), // Use translation key
                    Icons.email,
                    customerEmailController,
                    keyboardType: TextInputType.emailAddress,
                  ),
                  const SizedBox(height: 16),
                  _buildBrandDropdown(),
                  const SizedBox(height: 16),
                  _buildProductSearchField(context),
                  const SizedBox(height: 16),
                  _buildSelectedProductsList(),
                  const SizedBox(height: 16),
                  _buildStyledField(
                    'bill_form.serial_number'.tr(), // Use translation key
                    Icons.tag,
                    serialNumberController,
                  ),
                  const SizedBox(height: 16),
                  _buildStyledField(
                    'bill_form.service_charge'.tr(), // Use translation key
                    Icons.attach_money,
                    serviceChargeController,
                    keyboardType: TextInputType.number,
                  ),
                  const SizedBox(height: 30),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: isLoading
                          ? null
                          : () {
                        double subTotal = selectedProducts.fold(0.0, (sum, product) {
                          final String cleanedPrice = product['customer_price']
                              .toString()
                              .replaceAll(RegExp(r'[^0-9.]'), '');
                          final double price = double.tryParse(cleanedPrice) ?? 0.0;
                          final int quantity = int.tryParse(product['quantity'].toString()) ?? 1;
                          return sum + (price * quantity);
                        });

                        showBillSummaryBottomSheet(
                          context,
                          subTotal,
                          selectedProducts,
                          serviceChargeController,
                          handleGenerateInvoice,
                              (bool value) {
                            setState(() {
                              technicianConsent = value;
                            });
                          },
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFEFE516),
                        padding: const EdgeInsets.symmetric(vertical: 15),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30.0),
                        ),
                        elevation: 5,
                        shadowColor: Colors.black.withOpacity(0.3),
                      ),
                      child: isLoading
                          ? const CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      )
                          : Text(
                        'bill_form.view_summary'.tr(), // Use translation key
                        style: const TextStyle(color: Colors.white, fontSize: 16),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (isLoading)
            Container(
              color: Colors.black.withOpacity(0.5),
              child: const Center(child: CircularProgressIndicator()),
            ),
        ],
      ),
    );
  }

  Widget _buildBrandDropdown() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text("bill_form.select_brand".tr()), // Use translation key
        DropdownButtonFormField<String>(
          value: selectedBrand,
          isExpanded: true,
          decoration: const InputDecoration(border: OutlineInputBorder()),
          items: brandList.map((brand) {
            return DropdownMenuItem<String>(
              value: brand,
              child: Text(brand),
            );
          }).toList(),
          onChanged: (value) {
            setState(() {
              selectedBrand = value;
            });
          },
          validator: (value) => value == null ? "bill_form.select_brand_error".tr() : null, // Use translation key
        ),
      ],
    );
  }

  Widget _buildProductSearchField(BuildContext context) {
    TextEditingController _searchController = TextEditingController();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text("bill_form.search_product".tr()), // Use translation key
        Autocomplete<Map<String, dynamic>>(
          displayStringForOption: (product) =>
          "${product['product_description']} (${product['product_code']})",
          optionsBuilder: (TextEditingValue textEditingValue) {
            if (textEditingValue.text.isEmpty) {
              return const Iterable<Map<String, dynamic>>.empty();
            }
            return productList.where((product) =>
            product['product_description']
                .toLowerCase()
                .contains(textEditingValue.text.toLowerCase()) ||
                product['product_code']
                    .toLowerCase()
                    .contains(textEditingValue.text.toLowerCase()));
          },
          onSelected: (Map<String, dynamic> selectedProduct) {
            _searchController.clear(); // clear field after selection
            addProductToList(selectedProduct);
          },
          fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) {
            _searchController = controller;
            return TextFormField(
              controller: controller,
              focusNode: focusNode,
              decoration: InputDecoration(
                border: const OutlineInputBorder(),
                hintText: "bill_form.search_product_hint".tr(), // Use translation key
                prefixIcon: const Icon(Icons.search),
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildSelectedProductsList() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "bill_form.selected_products".tr(),
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: selectedProducts.length,
          itemBuilder: (context, index) {
            var product = selectedProducts[index];
            return Card(
              margin: const EdgeInsets.symmetric(vertical: 6),
              child: ListTile(
                title: Text("${product['product_description']} (${product['product_code']})"),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("₹${product['customer_price']}"),
                    Row(
                      children: [
                        const Text("Qty: "),
                        IconButton(
                          icon: const Icon(Icons.remove),
                          onPressed: () {
                            setState(() {
                              product['quantity'] = ((product['quantity'] ?? 1) > 1)
                                  ? (product['quantity'] ?? 1) - 1
                                  : 1;
                            });
                          },
                        ),
                        Text((product['quantity'] ?? 1).toString()),
                        IconButton(
                          icon: const Icon(Icons.add),
                          onPressed: () {
                            setState(() {
                              product['quantity'] = (product['quantity'] ?? 1) + 1;
                            });
                          },
                        ),
                      ],
                    )
                  ],
                ),
                trailing: IconButton(
                  icon: const Icon(Icons.delete),
                  onPressed: () {
                    setState(() {
                      selectedProducts.removeAt(index);
                    });
                  },
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}
