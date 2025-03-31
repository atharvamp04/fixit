import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:printing/printing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'pdf_generator.dart';
import 'package:fixit/services/bill_email_service.dart';

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

  @override
  void initState() {
    super.initState();
    fetchProducts();
    _populateInvoiceNumber();
  }

  Future<void> _populateInvoiceNumber() async {
    String invoice = await getNextInvoiceNumber();
    setState(() {
      invoiceNumberController.text = invoice;
    });
  }

  Future<void> fetchProducts() async {
    final response = await supabase
        .from('atomberg')
        .select('product_name, product_code, product_description, customer_price')
        .eq('active', true);
    if (response != null && response is List) {
      setState(() {
        productList = response.map<Map<String, dynamic>>((product) {
          return {
            'product_name': product['product_name'],
            'product_code': product['product_code'],
            'product_description': product['product_description'] ?? 'No description available',
            'customer_price': product['customer_price'].toString(),
          };
        }).toList();
      });
    } else {
      print("Error fetching products.");
    }
  }

  void addProductToList(Map<String, dynamic> product) {
    setState(() {
      selectedProducts.add(product);
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
      return "INV-0001";
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

    double subTotal = selectedProducts.fold(0.0, (sum, product) {
      String cleanedPrice = product['customer_price'].replaceAll(RegExp(r'[^0-9.]'), '');
      double price = double.tryParse(cleanedPrice) ?? 0.0;
      return sum + price;
    });
    double finalTotal = subTotal + serviceCharge;

    final dynamic orderResponse = await supabase.from('orders').insert({
      'invoice_no': invoiceNumber,
      'brand': selectedBrand,
      'product_code': selectedProducts.map((p) => p['product_code']).join(', '),
      'description': selectedProducts.map((p) => p['product_description']).join(', '),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Bill Form"),
        actions: [
          IconButton(
            icon: const Icon(Icons.share),
            onPressed: handleSharePdf,
          )
        ],
      ),
      body: Stack(
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildTextField("Invoice Number", Icons.confirmation_number, invoiceNumberController, readOnly: true, enabled: false),
                  const SizedBox(height: 12),
                  _buildTextField("User Name", Icons.person, userNameController),
                  const SizedBox(height: 12),
                  _buildTextField("Customer Email", Icons.email, customerEmailController, keyboardType: TextInputType.emailAddress),
                  const SizedBox(height: 12),
                  _buildBrandDropdown(),
                  const SizedBox(height: 12),
                  _buildDropdownField(),
                  const SizedBox(height: 12),
                  _buildSelectedProductsList(),
                  const SizedBox(height: 12),
                  _buildTextField("Serial Number", Icons.tag, serialNumberController),
                  const SizedBox(height: 12),
                  _buildTextField("Service Charge", Icons.attach_money, serviceChargeController, keyboardType: TextInputType.number),
                  const SizedBox(height: 12),
                  CheckboxListTile(
                    title: const Text("I confirm that the invoice details are correct."),
                    value: technicianConsent,
                    onChanged: (bool? value) {
                      setState(() {
                        technicianConsent = value ?? false;
                      });
                    },
                    controlAffinity: ListTileControlAffinity.leading,
                  ),
                  const SizedBox(height: 20),
                  Center(
                    child: ElevatedButton(
                      onPressed: isLoading ? null : handleGenerateInvoice,
                      child: isLoading
                          ? const CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      )
                          : const Text("Generate Invoice"),
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (isLoading)
            Container(
              color: Colors.black.withOpacity(0.5),
              child: const Center(
                child: CircularProgressIndicator(),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildBrandDropdown() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text("Select Brand"),
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
          validator: (value) => value == null ? "Please select a brand" : null,
        ),
      ],
    );
  }

  Widget _buildDropdownField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text("Select Product"),
        DropdownButtonFormField<String>(
          value: selectedProductCode,
          isExpanded: true,
          decoration: const InputDecoration(border: OutlineInputBorder()),
          items: productList.map((product) {
            return DropdownMenuItem<String>(
              value: product['product_code'],
              child: Text(
                  "${product['product_name']} (${product['product_code']}) - ${product['product_description']}"
              ),
            );
          }).toList(),
          onChanged: (value) {
            setState(() {
              selectedProductCode = value;
              var selectedProduct = productList.firstWhere((product) => product['product_code'] == value);
              addProductToList(selectedProduct);
            });
          },
          validator: (value) => value == null ? "Please select a product" : null,
        ),
      ],
    );
  }

  Widget _buildSelectedProductsList() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text("Selected Products", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: selectedProducts.length,
          itemBuilder: (context, index) {
            var product = selectedProducts[index];
            return ListTile(
              title: Text("${product['product_name']} (${product['product_code']})"),
              subtitle: Text("${product['product_description']}"),
              trailing: Text("₹${product['customer_price']}"),
              leading: IconButton(
                icon: const Icon(Icons.delete, color: Colors.red),
                onPressed: () {
                  setState(() {
                    selectedProducts.removeAt(index);
                  });
                },
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildTextField(String label, IconData icon, TextEditingController controller,
      {TextInputType keyboardType = TextInputType.text, bool readOnly = false, bool enabled = true}) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      readOnly: readOnly,
      enabled: enabled,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
        border: const OutlineInputBorder(),
      ),
      validator: (value) => value == null || value.isEmpty ? "Enter $label" : null,
    );
  }
}
