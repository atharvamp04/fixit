import 'dart:typed_data';
import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

/// Generates the invoice PDF and returns the PDF bytes.
/// The PDF includes fields such as invoice number, brand, and customer email.
Future<Uint8List> generatePdf({
  required String invoiceNumber,
  required String userName,
  required String serialNumber,
  required String customerEmail,
  required String brand,
  required double serviceCharge,
  required List<Map<String, dynamic>> selectedProducts,
}) async {
  // Load a custom font (e.g., Roboto-Regular) that supports Unicode.
  final fontData = await rootBundle.load("assets/fonts/Roboto-Regular.ttf");
  final ttf = pw.Font.ttf(fontData);

  final pdf = pw.Document(
    theme: pw.ThemeData.withFont(
      base: ttf,
      bold: ttf,
      italic: ttf,
      boldItalic: ttf,
    ),
  );

  try {
    // Load assets.
    final ByteData atombergLogo = await rootBundle.load('assets/atomberg_logo.png');
    final ByteData electrolyteLogo = await rootBundle.load('assets/electrolyte_logo.jpeg');
    final Uint8List atombergLogoData = atombergLogo.buffer.asUint8List();
    final Uint8List electrolyteLogoData = electrolyteLogo.buffer.asUint8List();

    // Load QR Code & Stamp.
    final ByteData qrCode = await rootBundle.load('assets/qr_code.png');
    final ByteData stampImage = await rootBundle.load('assets/stamp.png');
    final Uint8List qrCodeData = qrCode.buffer.asUint8List();
    final Uint8List stampImageData = stampImage.buffer.asUint8List();

    // Calculate totals.
    double subTotal = selectedProducts.fold(0.0, (sum, product) {
      String cleanedPrice = product['customer_price'].replaceAll(RegExp(r'[^0-9.]'), '');
      double price = double.tryParse(cleanedPrice) ?? 0.0;
      return sum + price;
    });
    double finalTotal = subTotal + serviceCharge;

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context context) {
          return pw.Container(
            padding: pw.EdgeInsets.all(10),
            decoration: pw.BoxDecoration(
              border: pw.Border.all(width: 1),
            ),
            child: pw.Stack(
              children: [
                // Watermark.
                pw.Positioned.fill(
                  child: pw.Center(
                    child: pw.Opacity(
                      opacity: 0.15,
                      child: pw.Image(
                        pw.MemoryImage(electrolyteLogoData),
                        height: 300,
                      ),
                    ),
                  ),
                ),
                // Main content.
                pw.Column(
                  children: [
                    // Header: Logos & Company Info.
                    pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: [
                        pw.Image(pw.MemoryImage(electrolyteLogoData), height: 40),
                        pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.center,
                          children: [
                            pw.Text("Electrolyte Solutions",
                                style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
                            pw.Text("Authorised Service Partner of Atomberg Technologies Pvt. Ltd.",
                                style: pw.TextStyle(fontSize: 9)),
                            pw.Text("Shop No. 5, XYZ Complex, Navi Mumbai, Maharashtra - 400705",
                                style: pw.TextStyle(fontSize: 9)),
                          ],
                        ),
                        pw.Image(pw.MemoryImage(atombergLogoData), height: 50),
                      ],
                    ),
                    pw.SizedBox(height: 8),
                    pw.Divider(),
                    // Invoice Details.
                    pw.Container(
                      padding: pw.EdgeInsets.all(8),
                      decoration: pw.BoxDecoration(border: pw.Border.all()),
                      child: pw.Row(
                        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                        children: [
                          pw.Column(
                            crossAxisAlignment: pw.CrossAxisAlignment.start,
                            children: [
                              pw.Text("BILL TO: $userName"),
                              pw.Text("Email: $customerEmail"),
                              pw.Text("INVOICE NO: $invoiceNumber"),
                              pw.Text("BRAND: $brand"),
                              pw.Text("SERIAL: $serialNumber"),
                              pw.Text("BILL DATE: ${DateTime.now().toString().split(' ')[0]}"),
                            ],
                          ),
                          pw.Text("FOR: Atomberg Products Service"),
                        ],
                      ),
                    ),
                    pw.SizedBox(height: 10),
                    // Table of Products.
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
                      cellStyle: pw.TextStyle(fontSize: 9),
                      columnWidths: {
                        0: pw.FixedColumnWidth(200),
                        1: pw.FlexColumnWidth(),
                        2: pw.FlexColumnWidth(),
                        3: pw.FlexColumnWidth(),
                      },
                    ),
                    pw.SizedBox(height: 20),
                    pw.Divider(),
                    // Totals.
                    pw.Align(
                      alignment: pw.Alignment.centerRight,
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.end,
                        children: [
                          pw.Text("SUBTOTAL: Rs.${subTotal.toStringAsFixed(2)}", style: pw.TextStyle(fontSize: 12)),
                          pw.Text("SERVICE CHARGE: Rs.${serviceCharge.toStringAsFixed(2)}", style: pw.TextStyle(fontSize: 12)),
                          pw.Text("GRAND TOTAL: Rs.${finalTotal.toStringAsFixed(2)}",
                              style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
                        ],
                      ),
                    ),
                    pw.SizedBox(height: 20),
                    pw.Divider(),
                    // Bank Details, QR Code, and Stamp.
                    pw.Row(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
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
                        pw.Container(
                          height: 100,
                          width: 1,
                          color: PdfColors.black,
                        ),
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
                        pw.Container(
                          height: 100,
                          width: 1,
                          color: PdfColors.black,
                        ),
                        pw.SizedBox(width: 10),
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
                    // Additional Notes.
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
    return pdf.save();
  } catch (e) {
    print("Error generating invoice: $e");
    return Uint8List(0);
  }
}
