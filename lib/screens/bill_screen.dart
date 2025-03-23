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

    // Load invoice template as background image
    final ByteData data = await rootBundle.load("assets/invoice_template.jpg");
    final Uint8List bytes = data.buffer.asUint8List();
    final pdfImage = pw.MemoryImage(bytes);

    pdf.addPage(
      pw.Page(
        build: (pw.Context context) {
          return pw.Stack(
            children: [
              pw.Image(pdfImage, fit: pw.BoxFit.cover), // Template as background

              // Overlay dynamic text in appropriate positions
              pw.Positioned(left: 50, top: 100, child: pw.Text("Invoice No: ${ticketNumberController.text}", style: pw.TextStyle(fontSize: 14))),
              pw.Positioned(left: 50, top: 130, child: pw.Text("Customer Name: ${userNameController.text}", style: pw.TextStyle(fontSize: 14))),
              pw.Positioned(left: 50, top: 160, child: pw.Text("Serial Number: ${serialNumberController.text}", style: pw.TextStyle(fontSize: 14))),

              // Product Table
              pw.Positioned(
                left: 50,
                top: 220,
                child: pw.Table.fromTextArray(
                  headers: ["Product Name", "Code", "Description", "Price"],
                  data: selectedProducts.map((product) => [
                    product['product_name'],
                    product['product_code'],
                    product['product_description'],
                    "₹${product['customer_price']}",
                  ]).toList(),
                  border: pw.TableBorder.all(),
                  cellAlignment: pw.Alignment.centerLeft,
                ),
              ),
            ],
          );
        },
      ),
    );

    final output = await getExternalStorageDirectory();
    final file = File("${output!.path}/invoice.pdf");
    await file.writeAsBytes(await pdf.save());

    await Printing.layoutPdf(
      onLayout: (format) async => pdf.save(),
    );
  }
}
