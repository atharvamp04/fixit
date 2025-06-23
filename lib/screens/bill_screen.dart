import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:printing/printing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'pdf_generator.dart';
import 'package:Invexa/services/bill_email_service.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../widgets/bill_summary_bottom_sheet.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'dart:async';
import 'invoice_history_page.dart';



import 'package:easy_localization/easy_localization.dart';

class BillScreen extends StatefulWidget {
  @override
  _BillScreenState createState() => _BillScreenState();
}

class _BillScreenState extends State<BillScreen> with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;
  final _formKey = GlobalKey<FormState>();

  // Invoice Number will be auto-generated and not editable.
  final TextEditingController invoiceNumberController = TextEditingController();
  final TextEditingController userNameController = TextEditingController();
  final TextEditingController serialNumberController = TextEditingController();
  final TextEditingController serviceChargeController = TextEditingController(text: "0");
  final TextEditingController customerEmailController = TextEditingController();
  final TextEditingController preparedByController = TextEditingController();
  final TextEditingController caseIdController      = TextEditingController();

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
    _loadFormFromLocalStorage();

    userNameController.addListener(_saveFormToLocalStorage);
    serialNumberController.addListener(_saveFormToLocalStorage);
    serviceChargeController.addListener(_saveFormToLocalStorage);
    customerEmailController.addListener(_saveFormToLocalStorage);
    preparedByController.addListener(_saveFormToLocalStorage);
    caseIdController.addListener(_saveFormToLocalStorage);
  }

  @override
  void dispose() {
    userNameController.removeListener(_saveFormToLocalStorage);
    serialNumberController.removeListener(_saveFormToLocalStorage);
    serviceChargeController.removeListener(_saveFormToLocalStorage);
    customerEmailController.removeListener(_saveFormToLocalStorage);
    preparedByController.removeListener(_saveFormToLocalStorage);
    caseIdController.removeListener(_saveFormToLocalStorage);

    userNameController.dispose();
    serialNumberController.dispose();
    serviceChargeController.dispose();
    customerEmailController.dispose();
    preparedByController.dispose();
    caseIdController.dispose();

    super.dispose();
  }




  // Future<void> _populateInvoiceNumber() async {
  //   final dynamic result = await supabase.rpc('generate_invoice_number');
  //   String base;
  //   if (result is String) {
  //     base = result;
  //   } else if (result is Map<String, dynamic> && result.containsKey('data')) {
  //     base = result['data'] as String;
  //   } else {
  //     base = "ES/25-26/001";
  //   }
  //   setState(() {
  //     _baseInvoice = base;
  //     _rebuildInvoice();
  //   });
  // }

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
    List<Map<String, dynamic>> allProducts = [];
    int batchSize = 1000;
    int start = 0;

    while (true) {
      final response = await supabase
          .from('atomberg')
          .select('product_name, product_code, product_description, customer_price')
          .eq('active', true)
          .range(start, start + batchSize - 1);

      // Check if response is a valid List
      if (response == null || response is! List || response.isEmpty) {
        break;
      }

      // Map the batch into desired structure
      final batch = response.map<Map<String, dynamic>>((product) {
        return {
          'product_name': product['product_name'],
          'product_code': product['product_code'],
          'product_description': product['product_description'] ?? 'No description available',
          'customer_price': product['customer_price'].toString(),
          'quantity': 1,
        };
      }).toList();

      allProducts.addAll(batch);

      // Stop if batch returned fewer than requested — end of data
      if (batch.length < batchSize) break;

      start += batchSize;
    }

    setState(() {
      productList = allProducts;
    });
  }


  void onBrandChanged(String? brand) {
    setState(() {
      selectedBrand = brand;
    });
    _saveFormToLocalStorage();
  }
  void addProductToList(Map<String, dynamic> product) {
    setState(() {
      int index = selectedProducts.indexWhere((p) => p['product_code'] == product['product_code']);
      if (index != -1) {
        selectedProducts[index]['quantity'] = (selectedProducts[index]['quantity'] ?? 1) + 1;
      } else {
        selectedProducts.add(Map<String, dynamic>.from(product));
      }
    });
    _saveFormToLocalStorage();
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
      final String filePath = 'ES/25-26/$filename'; // ✅ Define proper folder path

      await supabase.storage
          .from('invoices') // ✅ Only 1 "invoices" — this is the bucket name
          .uploadBinary(filePath, pdfBytes, fileOptions: const FileOptions(upsert: true));

      final String publicUrl = supabase.storage
          .from('invoices')
          .getPublicUrl(filePath); // ✅ Use same filePath here

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

    // Fetch fresh invoice number from RPC to avoid duplicates.
    String freshBaseInvoice = await getNextInvoiceNumber();
    setState(() {
      _baseInvoice = freshBaseInvoice;
      _rebuildInvoice();  // This updates invoiceNumberController.text
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
      preparedBy: preparedByController.text,
      caseId:    caseIdController.text,
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

    final user = Supabase.instance.client.auth.currentUser;

    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("User not logged in.")),
      );
      return;
    }

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
      'prepared_by':    preparedByController.text,
      'case_id':        caseIdController.text,
      'user_id': user.id,
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

  final String _formCacheKey = 'bill_form_cache';

// Make this async since you're using await inside
  Future<void> _saveFormToLocalStorage() async {
    final formData = {
      'userName': userNameController.text,
      'serialNumber': serialNumberController.text,
      'serviceCharge': serviceChargeController.text,
      'customerEmail': customerEmailController.text,
      'selectedBrand': selectedBrand,
      'selectedProducts': selectedProducts,
      'preparedBy'     : preparedByController.text,
      'caseId'         : caseIdController.text,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    };

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_formCacheKey, jsonEncode(formData));
  }

// Also make this async
  Future<void> _loadFormFromLocalStorage() async {
    final prefs = await SharedPreferences.getInstance();
    String? cachedData = prefs.getString(_formCacheKey);

    if (cachedData == null) return;

    final Map<String, dynamic> formData = jsonDecode(cachedData);
    final int savedTime = formData['timestamp'] ?? 0;
    final int now = DateTime.now().millisecondsSinceEpoch;

    // If older than 10 minutes, ignore
    if (now - savedTime > 10 * 60 * 1000) {
      await prefs.remove(_formCacheKey);
      return;
    }

    // Load values into controllers and variables
    userNameController.text = formData['userName'] ?? '';
    serialNumberController.text = formData['serialNumber'] ?? '';
    serviceChargeController.text = formData['serviceCharge'] ?? '0';
    customerEmailController.text = formData['customerEmail'] ?? '';
    selectedBrand = formData['selectedBrand'];
    selectedProducts = List<Map<String, dynamic>>.from(formData['selectedProducts'] ?? []);
    preparedByController.text    = formData['preparedBy'] ?? '';
    caseIdController.text        = formData['caseId'] ?? '';
  }


  Future<void> clearAllData() async {
    setState(() {
      userNameController.clear();
      serialNumberController.clear();
      serviceChargeController.text = "0";
      customerEmailController.clear();

      selectedBrand = null;
      selectedProductCode = null;
      selectedProducts.clear();

      technicianConsent = false;
      generatedPdfBytes = null;

      invoiceNumberController.clear();
      _baseInvoice = "";
      _warrantyType = "OW";
    });

    // Clear from local storage as well
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
  }


  /// Allows the technician to share/download the generated PDF.
  void handleSharePdf() async {
    if (generatedPdfBytes != null && generatedPdfBytes!.isNotEmpty) {
      bool? shareConfirmed;

      // Start a timer to clear data automatically after 10 seconds
      Timer clearTimer = Timer(Duration(seconds: 10), () async {
        await clearAllData();
      });

      shareConfirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text('Share PDF?'),
          content: Text('Do you want to share the generated PDF?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text('No'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: Text('Yes'),
            ),
          ],
        ),
      );

      // If user responded before timer runs
      if (clearTimer.isActive) {
        clearTimer.cancel(); // Cancel the timer to avoid double clear
        if (shareConfirmed == true) {
          try {
            String invoice = invoiceNumberController.text.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_');
            String email = customerEmailController.text.replaceAll(RegExp(r'[^a-zA-Z0-9@.]'), '_');
            String filename = "${invoice}_$email.pdf";

            await Printing.sharePdf(
              bytes: generatedPdfBytes!,
              filename: filename,
            );
          } catch (e) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('error_sharing_pdf'.tr(args: [e.toString()])),
              ),
            );
          }
        }

        await clearAllData();
      }

    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('generate_invoice_first'.tr())),
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
        suffixIcon: Icon(icon, color: Colors.yellow[600]),
        focusedBorder: const UnderlineInputBorder(
          borderSide: BorderSide(color: Color(0xFFEFE516)),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.yellow[600],
        title: Text(
          'bill_form.title'.tr(),
          style: const TextStyle(fontSize: 30, fontWeight: FontWeight.w800, color: Colors.white),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.history),
            color: Colors.white,
            tooltip: 'Invoice History',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => InvoiceHistoryPage()),
              );
            },
          ),
          IconButton(
            icon: Icon(
              Icons.share,
              color: generatedPdfBytes == null || generatedPdfBytes!.isEmpty
                  ? Colors.grey.shade400
                  : Colors.white,
            ),
            onPressed: (generatedPdfBytes == null || generatedPdfBytes!.isEmpty)
                ? null
                : handleSharePdf,
            tooltip: (generatedPdfBytes == null || generatedPdfBytes!.isEmpty)
                ? 'generate_invoice_first'.tr()
                : 'share_invoice'.tr(),
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
                  // ── NEW FIELDS BEGIN ──
                  _buildStyledField(
                    'bill_form.prepared_by'.tr(),    // You’ll need to add these keys to your .json translation files
                    Icons.person_outline,
                    preparedByController,
                  ),
                  const SizedBox(height: 16),

                  _buildStyledField(
                    'bill_form.case_id'.tr(),
                    Icons.confirmation_number_outlined,
                    caseIdController,
                  ),
// ── NEW FIELDS END ──

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
                          : () async {
                        // Calculate subtotal
                        double subTotal = selectedProducts.fold(0.0, (sum, product) {
                          final String cleanedPrice = product['customer_price']
                              .toString()
                              .replaceAll(RegExp(r'[^0-9.]'), '');
                          final double price = double.tryParse(cleanedPrice) ?? 0.0;
                          final int quantity = int.tryParse(product['quantity'].toString()) ?? 1;
                          return sum + (price * quantity);
                        });

                        // Show the summary bottom sheet
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

                        // Wait for invoice generation to finish (if handleGenerateInvoice is async)
                        // If you want to wait for handleGenerateInvoice here,
                        // you may need to refactor showBillSummaryBottomSheet to return Future.

                        // After generating invoice, clear all data
                        // If you want to clear immediately after showing summary, uncomment below:
                        // await clearAllData();
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.yellow[600],
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