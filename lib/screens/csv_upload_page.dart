import 'package:flutter/material.dart';
import 'dart:io';
import 'dart:convert';
import 'package:file_picker/file_picker.dart';
import 'package:csv/csv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class CsvUploadPage extends StatefulWidget {
  @override
  _CsvUploadPageState createState() => _CsvUploadPageState();
}

class _CsvUploadPageState extends State<CsvUploadPage> {
  bool _isUploadingStock = false;
  bool _isUploadingPrice = false;

  String? _stockFileName;
  String? _priceFileName;

  Future<String?> pickCSVFile() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['csv'],
    );

    if (result == null) return null;

    final path = result.files.single.path;
    if (path == null) return null;

    setState(() {
      if (_isUploadingStock) {
        _stockFileName = result.files.single.name;
      } else if (_isUploadingPrice) {
        _priceFileName = result.files.single.name;
      }
    });

    final file = File(path);
    try {
      final bytes = await file.readAsBytes();
      String content;
      try {
        content = utf8.decode(bytes, allowMalformed: true);
      } catch (_) {
        content = latin1.decode(bytes);
      }
      return content;
    } catch (e) {
      debugPrint('Error reading file: $e');
      return null;
    }
  }

  List<Map<String, dynamic>> processCSV(String csvContent) {
    final csvTable = CsvToListConverter(
      eol: '\n',
      shouldParseNumbers: false,
    ).convert(csvContent);

    if (csvTable.isEmpty) return [];

    final headers = csvTable.first.map((e) => e.toString().trim()).toList();
    final data = <Map<String, dynamic>>[];

    for (var i = 1; i < csvTable.length; i++) {
      final rowValues = csvTable[i];
      if (rowValues.length != headers.length) continue;

      final row = <String, dynamic>{};
      for (var j = 0; j < headers.length; j++) {
        row[headers[j]] = rowValues[j].toString().trim();
      }

      final descKey = "Product Description";
      if (row.containsKey(descKey)) {
        row[descKey] = row[descKey]?.replaceAll('_', ' ') ?? '';
      }

      final dateKey = "Last Modified Date";
      if (row.containsKey(dateKey)) {
        row[dateKey] = convertDate(row[dateKey] ?? '');
      }

      row['Concatenate'] = '${row["Product Code"] ?? ''} ${row[descKey] ?? ''}';

      data.add(row);
    }

    return data;
  }

  String convertDate(String dateStr) {
    final parts = dateStr.split('/');
    if (parts.length != 3) return dateStr;
    final day = parts[0].padLeft(2, '0');
    final month = parts[1].padLeft(2, '0');
    final year = parts[2];
    return '$year-$month-$day';
  }

  List<Map<String, dynamic>> processPriceCSV(String csvContent) {
    // Use Djikstra’s “CsvToListConverter” with explicit CRLF support and textDelimiter = '"'.
    // That way, fields like "2,499" (with a comma) are kept together.
    final converter = CsvToListConverter(
      eol: '\r\n',
      fieldDelimiter: ',',
      textDelimiter: '"',
      shouldParseNumbers: false,
    );

    final csvTable = converter.convert(csvContent);

    if (csvTable.isEmpty) return [];

    // Treat the first row as headers (trim whitespace).
    final headers = csvTable.first.map((e) => e.toString().trim()).toList();

    final data = <Map<String, dynamic>>[];
    // Starting from row #1 (i = 1), because row #0 is the header row.
    for (var i = 1; i < csvTable.length; i++) {
      final rowValues = csvTable[i];

      // If the entire row is empty/blank, skip it.
      final allBlank = rowValues.every((cell) {
        final s = cell.toString().trim();
        return s.isEmpty;
      });
      if (allBlank) continue;

      // If the number of columns does not match the header count, skip it.
      if (rowValues.length != headers.length) continue;

      final row = <String, dynamic>{};
      for (var j = 0; j < headers.length; j++) {
        final rawKey = headers[j];
        final rawVal = rowValues[j].toString().trim();

        switch (rawKey) {
          case "Active (Product)":
          // Some CSVs encode boolean as "TRUE"/"FALSE" (case-insensitive) or "1"/"0".
            final lower = rawVal.toLowerCase();
            row['active'] = (lower == 'true' || lower == '1');
            break;

          case "Product Name":
            row['product_name'] = rawVal;
            break;

          case "Product Code":
            row['product_code'] = rawVal;
            break;

          case "Product Description":
            row['product_description'] = rawVal;
            break;

          case "Customer Price":
            row['customer_price'] = rawVal;
            break;

          case "ASP Price":
            row['asp_price'] = rawVal;
            break;

          default:
          // We ignore any other columns.
            break;
        }
      }

      // If “Active (Product)” was missing or unparsable, default it to false:
      if (!row.containsKey('active')) {
        row['active'] = false;
      }

      data.add(row);
    }

    // For debugging, you can print how many rows were parsed:
    // print("processPriceCSV → parsed ${data.length} valid row(s).");

    return data;
  }



  Future<void> uploadToSupabase(String tableName, List<Map<String, dynamic>> data) async {
    final supabase = Supabase.instance.client;

    try {
      debugPrint('Deleting all rows in $tableName...');
      await supabase.from(tableName).delete().gt('id', 0);

      // Reset the ID sequence for the specified table
      if (tableName == 'products') {
        final response = await supabase.rpc('reset_products_table');
        if (response == null) {
          print("✅ Products table reset successfully.");
        } else {
          print("❌ Error resetting products table: $response");
        }
      } else if (tableName == 'atomberg') {
        final response = await supabase.rpc('reset_atomberg_table');
        if (response == null) {
          print("✅ Atomberg table reset successfully.");
        } else {
          print("❌ Error resetting atomberg table: $response");
        }
      } else {
        print("⚠️ Unknown table name: $tableName. Skipping reset.");
      }

      debugPrint('Inserting ${data.length} rows into $tableName...');
      await supabase.from(tableName).insert(data);
      debugPrint('Upload successful to $tableName!');

      // Log the update event in updates_log table
      final user = supabase.auth.currentUser;
      if (user != null) {
        await supabase.from('updates').insert({
          'user_id': user.id,
          'email': user.email ?? '',
          'updated_table': tableName,
          // 'updated_at' timestamp assumed to be set by DB default (e.g., now())
        });
        print("📋 Upload event logged for user ${user.email} on table $tableName");
      } else {
        print("⚠️ No logged-in user found to log upload event.");
      }
    } catch (e) {
      debugPrint('Upload failed for $tableName: $e');
      throw e;
    }
  }




  Future<void> _pickAndUploadStockCSV() async {
    setState(() {
      _isUploadingStock = true;
      _stockFileName = null;
    });

    try {
      final csvString = await pickCSVFile();
      if (csvString == null) throw 'No file selected';

      final parsedData = processCSV(csvString);
      await uploadToSupabase('products', parsedData);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Products Data uploaded successfully")),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Upload failed: $e")),
      );
    } finally {
      setState(() {
        _isUploadingStock = false;
      });
    }
  }

  Future<void> _pickAndUploadPriceCSV() async {
    setState(() {
      _isUploadingPrice = true;
      _priceFileName = null;
    });

    try {
      final csvString = await pickCSVFile();
      if (csvString == null) throw 'No file selected';

      final parsedData = processPriceCSV(csvString);

      // Debug print to double-check row count:
      debugPrint("Uploading ${parsedData.length} rows to 'atomberg'…");

      await uploadToSupabase('atomberg', parsedData);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Atomberg Price Data uploaded successfully")),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Upload failed: $e")),
      );
    } finally {
      setState(() {
        _isUploadingPrice = false;
      });
    }
  }


  @override
  Widget build(BuildContext context) {
    final darkTextColor = Colors.grey[900];
    final cardBgColor = Colors.white;
    final borderColor = Colors.grey.shade300;

    final headerStyle = TextStyle(
      fontSize: 22,
      fontWeight: FontWeight.bold,
      color: darkTextColor,
    );

    final fileNameStyle = TextStyle(
      fontSize: 14,
      color: Colors.grey[700],
      fontStyle: FontStyle.italic,
    );

    Widget buildUploadCard({
      required String title,
      required bool isUploading,
      required String? fileName,
      required VoidCallback onPressed,
    }) {
      return Card(
        color: cardBgColor,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: borderColor, width: 1),
        ),
        elevation: 2,
        margin: EdgeInsets.only(bottom: 30),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: headerStyle),
              SizedBox(height: 16),
              if (fileName != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Row(
                    children: [
                      Icon(Icons.insert_drive_file, color: Colors.grey[600]),
                      SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          fileName,
                          style: fileNameStyle,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      IconButton(
                        icon: Icon(Icons.clear, color: Colors.grey[600]),
                        tooltip: 'Clear selection',
                        onPressed: () {
                          setState(() {
                            if (title.toLowerCase().contains("stock")) {
                              _stockFileName = null;
                            } else {
                              _priceFileName = null;
                            }
                          });
                        },
                      ),
                    ],
                  ),
                ),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: isUploading ? null : onPressed,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.yellow[600],
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    elevation: 3,
                  ),
                  child: isUploading
                      ? SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2.5,
                    ),
                  )
                      : Text(
                    'Select & Upload CSV',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        backgroundColor: Colors.white,
        iconTheme: IconThemeData(color: Colors.grey[900]),
        elevation: 1,
        centerTitle: true,
        title: Text(
          'Upload CSV Files',
          style: TextStyle(
            color: Colors.grey[900],
            fontWeight: FontWeight.bold,
            fontSize: 22,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 30),
        child: Column(
          children: [
            buildUploadCard(
              title: 'Atomberg Stock Data CSV',
              isUploading: _isUploadingStock,
              fileName: _stockFileName,
              onPressed: _pickAndUploadStockCSV,
            ),
            buildUploadCard(
              title: 'Atomberg Price CSV',
              isUploading: _isUploadingPrice,
              fileName: _priceFileName,
              onPressed: _pickAndUploadPriceCSV,
            ),
          ],
        ),
      ),
    );
  }
}