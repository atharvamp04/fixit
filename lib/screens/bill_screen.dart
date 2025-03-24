import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';
import 'package:printing/printing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class BillScreen extends StatefulWidget {
  @override
  _BillScreenState createState() => _BillScreenState();
}

class _BillScreenState extends State<BillScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController ticketNumberController = TextEditingController();
  final TextEditingController userNameController = TextEditingController();
  final TextEditingController serialNumberController = TextEditingController();
  final TextEditingController serviceChargeController = TextEditingController(text: "0");

  String? selectedProductCode;
  List<Map<String, dynamic>> productList = [];
  List<Map<String, dynamic>> selectedProducts = [];

  @override
  void initState() {
    super.initState();
    fetchProducts();
  }

  Future<void> fetchProducts() async {
    final response = await Supabase.instance.client
        .from('atomberg')
        .select('product_name, product_code, product_description, customer_price')
        .eq('active', true);

    setState(() {
      productList = response.map((product) {
        return {
          'product_name': product['product_name'],
          'product_code': product['product_code'],
          'product_description': product['product_description'] ?? 'No description available',
          'customer_price': product['customer_price'].toString(),
        };
      }).toList();
    });
  }

  void addProductToList(Map<String, dynamic> product) {
    setState(() {
      selectedProducts.add(product);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Bill Form")),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                buildTextField("Ticket Number", Icons.confirmation_number, ticketNumberController),
                buildTextField("User Name", Icons.person, userNameController),
                buildDropdownField(),
                buildSelectedProductsList(),
                buildTextField("Serial Number", Icons.tag, serialNumberController),
                SizedBox(height: 20),
                buildGenerateInvoiceButton(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget buildDropdownField() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("Select Item"),
          DropdownButtonFormField<String>(
            value: selectedProductCode,
            isExpanded: true,
            decoration: InputDecoration(border: OutlineInputBorder()),
            items: productList.map((product) {
              return DropdownMenuItem<String>(
                value: product['product_code'],
                child: Text("${product['product_name']} (${product['product_code']}) - ${product['product_description']}"),
              );
            }).toList(),
            onChanged: (value) {
              setState(() {
                selectedProductCode = value;
                var selectedProduct = productList.firstWhere((product) => product['product_code'] == value);
                addProductToList(selectedProduct);
              });
            },
          ),
        ],
      ),
    );
  }

  Widget buildSelectedProductsList() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text("Selected Products", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        SizedBox(height: 8),
        ListView.builder(
          shrinkWrap: true,
          physics: NeverScrollableScrollPhysics(),
          itemCount: selectedProducts.length,
          itemBuilder: (context, index) {
            var product = selectedProducts[index];
            return ListTile(
              title: Text("${product['product_name']} (${product['product_code']})"),
              subtitle: Text("${product['product_description']}"),
              trailing: Text("₹${product['customer_price']}"),
              leading: IconButton(
                icon: Icon(Icons.delete, color: Colors.red),
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

  Widget buildGenerateInvoiceButton() {
    return Center(
      child: ElevatedButton(
        onPressed: generateInvoice,
        child: Text("Generate Invoice"),
      ),
    );
  }

  Widget buildTextField(
      String label,
      IconData icon,
      TextEditingController controller, {
        bool isNumber = false,
      }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: TextFormField(
        controller: controller,
        keyboardType: isNumber ? TextInputType.number : TextInputType.text,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon),
          border: OutlineInputBorder(),
        ),
        validator: (value) => value == null || value.isEmpty ? "Enter $label" : null,
      ),
    );
  }

  Future<void> generateInvoice() async {
    final pdf = pw.Document();

    try {
      // Load Logos
      final ByteData atombergLogo = await rootBundle.load('assets/atomberg_logo.png');
      final ByteData electrolyteLogo = await rootBundle.load('assets/electrolyte_logo.jpeg');
      final Uint8List atombergLogoData = atombergLogo.buffer.asUint8List();
      final Uint8List electrolyteLogoData = electrolyteLogo.buffer.asUint8List();

      // Load QR Code & Stamp
      final ByteData qrCode = await rootBundle.load('assets/qr_code.png');
      final ByteData stampImage = await rootBundle.load('assets/stamp.png');
      final Uint8List qrCodeData = qrCode.buffer.asUint8List();
      final Uint8List stampImageData = stampImage.buffer.asUint8List();

      // Calculate Grand Total
      double grandTotal = selectedProducts.fold(0.0, (sum, product) {
        String cleanedPrice = product['customer_price'].replaceAll(RegExp(r'[^0-9.]'), '');
        double price = double.tryParse(cleanedPrice) ?? 0.0;
        return sum + price;
      });

      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          build: (pw.Context context) {
            return pw.Container(
              padding: pw.EdgeInsets.all(10), // Space inside the border
              decoration: pw.BoxDecoration(
                border: pw.Border.all(width: 1), // Full-page border
              ),
              child: pw.Stack(
                children: [
                  // **Watermark at the center**
                  pw.Positioned.fill(
                    child: pw.Center(
                      child: pw.Opacity(
                        opacity: 0.15, // Adjust transparency level
                        child: pw.Image(pw.MemoryImage(electrolyteLogoData), height: 300), // Adjust size
                      ),
                    ),
                  ),

                  // **Main Invoice Content**
                  pw.Column(
                    children: [
                      // **LOGOS & HEADER**
                      pw.Row(
                        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                        children: [
                          pw.Image(pw.MemoryImage(electrolyteLogoData), height: 40), // Reduced size
                          pw.Column(
                            crossAxisAlignment: pw.CrossAxisAlignment.center,
                            children: [
                              pw.Text("Electrolyte Solutions",
                                  style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)), // Slightly smaller
                              pw.Text("Authorised Service Partner of Atomberg Technologies Pvt. Ltd.",
                                  style: pw.TextStyle(fontSize: 9)),
                              pw.Text("Shop No. 5, XYZ Complex, Navi Mumbai, Maharashtra - 400705",
                                  style: pw.TextStyle(fontSize: 9)), // Added address
                            ],
                          ),
                          pw.Image(pw.MemoryImage(atombergLogoData), height: 50),
                        ],
                      ),

                      pw.SizedBox(height: 8),
                      pw.Divider(),

                      // **Invoice Details**
                      pw.Container(
                        padding: pw.EdgeInsets.all(8),
                        decoration: pw.BoxDecoration(border: pw.Border.all()),
                        child: pw.Row(
                          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                          children: [
                            pw.Column(
                              crossAxisAlignment: pw.CrossAxisAlignment.start,
                              children: [
                                pw.Text("BILL TO: ${userNameController.text}"),
                                pw.Text("TICKET: ${ticketNumberController.text}"),
                                pw.Text("INVOICE NO: ES/25-26/${serialNumberController.text}"),
                                pw.Text("BILL DATE: ${DateTime.now().toString().split(' ')[0]}"),
                              ],
                            ),
                            pw.Text("FOR: Atomberg Products Service"),
                          ],
                        ),
                      ),

                      pw.SizedBox(height: 10),

                      // **TABLE**
                      pw.Table.fromTextArray(
                        headers: ["DESCRIPTION", "QUANTITY", "RATE (incl. tax)", "AMOUNT"],
                        data: selectedProducts.map((product) {
                          String cleanedPrice = product['customer_price'].replaceAll(RegExp(r'[^0-9.]'), '');
                          double price = double.tryParse(cleanedPrice) ?? 0.0;
                          return [
                            product['product_description'],
                            "1",
                            "Rs.${price.toStringAsFixed(2)}",
                            "Rs.${price.toStringAsFixed(2)}",
                          ];
                        }).toList(),
                        border: pw.TableBorder.all(),
                        cellAlignment: pw.Alignment.center,
                        headerStyle: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold),
                        cellStyle: pw.TextStyle(fontSize: 9), // Smaller font size
                        columnWidths: {
                          0: pw.FixedColumnWidth(200), // Fixed width for "DESCRIPTION" column
                          1: pw.FlexColumnWidth(),
                          2: pw.FlexColumnWidth(),
                          3: pw.FlexColumnWidth(),
                        },
                      ),

                      pw.SizedBox(height: 20),
                      pw.Divider(),

                      // **Grand Total**
                      pw.Align(
                        alignment: pw.Alignment.centerRight,
                        child: pw.Text("GRAND TOTAL: Rs.${grandTotal.toStringAsFixed(2)}",
                            style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
                      ),

                      pw.SizedBox(height: 20),
                      pw.Divider(),

                      // **Bank Details, QR Code, Separator & Stamp**
                      pw.Row(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          // Bank Details (Left Side)
                          pw.Expanded(
                            child: pw.Column(
                              crossAxisAlignment: pw.CrossAxisAlignment.start,
                              children: [
                                pw.Text("Bank Details", style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
                                pw.Text("Name: M/s Electrolyte Solutions"),
                                pw.Text("Bank Name: Axis Bank Ltd."),
                                pw.Text("Account No.: 921000031635999"),
                                pw.Text("IFSC Code: UTIB0001622"),
                                pw.Text("Branch: Mulund East"),
                              ],
                            ),
                          ),

                          pw.SizedBox(width: 10),

                          // Vertical Separator Line
                          pw.Container(
                            height: 100, // Adjust height as needed
                            width: 1, // Thin vertical line
                            color: PdfColors.black,
                          ),

                          // QR Code in Center with "Scan to Pay"
                          pw.Expanded(
                            child: pw.Column(
                              mainAxisAlignment: pw.MainAxisAlignment.center,
                              children: [
                                pw.Image(pw.MemoryImage(qrCodeData), height: 80),
                                pw.SizedBox(height: 5),
                                pw.Text("Scan to Pay", style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
                              ],
                            ),
                          ),

                          pw.SizedBox(width: 10),

                          // Vertical Separator Line
                          pw.Container(
                            height: 100, // Adjust height as needed
                            width: 1, // Thin vertical line
                            color: PdfColors.black,
                          ),

                          pw.SizedBox(width: 10),

                          // Stamp with Labels (Right Side)
                          pw.Expanded(
                            child: pw.Column(
                              mainAxisAlignment: pw.MainAxisAlignment.center,
                              children: [
                                pw.Text("Electrolyte Solutions", style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
                                pw.Image(pw.MemoryImage(stampImageData), height: 80),
                                pw.SizedBox(height: 5),
                                pw.Text("Authorized Signatory\nFor Electrolyte Solutions",
                                    textAlign: pw.TextAlign.center,
                                    style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
                              ],
                            ),
                          ),
                        ],
                      ),

                      pw.SizedBox(height: 10),

                      // **Additional Notes**
                      pw.Text("Make all cheque or bank transfers payable to: M/s Electrolyte Solutions.",
                          style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
                      pw.SizedBox(height: 5),
                      pw.Text("Note: Spare/Products are warranted for a period of 1 year from the date of handing over to the customer.",
                          style: pw.TextStyle(fontSize: 9)),
                      pw.SizedBox(height: 5),
                      pw.Text("This is a computer-generated invoice. No signature required.",
                          style: pw.TextStyle(fontSize: 9)),
                      pw.SizedBox(height: 5),
                      pw.Text("Subjected to Navi Mumbai Jurisdiction.",
                          style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
                    ],
                  ),
                ],
              ),
            );
          },
        ),
      );


      // Save PDF
      final output = await getTemporaryDirectory();
      final file = File("${output.path}/invoice.pdf");
      await file.writeAsBytes(await pdf.save());

      // Open PDF
      await Printing.layoutPdf(onLayout: (PdfPageFormat format) async => pdf.save());

    } catch (e) {
      print("Error generating invoice: $e");
    }
  }

}
