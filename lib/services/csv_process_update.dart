import 'package:csv/csv.dart';

List<Map<String, dynamic>> processCSV(String csvContent) {
  List<List<dynamic>> rows = const CsvToListConverter().convert(csvContent, eol: '\n');
  List<String> headers = rows.first.map((e) => e.toString()).toList();
  int descIndex = headers.indexOf("Product Description");
  int codeIndex = headers.indexOf("Product Code");

  // Add new 'Concatenate' column
  headers.add("Concatenate");

  List<Map<String, dynamic>> data = [];

  for (int i = 1; i < rows.length; i++) {
    List<dynamic> row = rows[i];
    String description = row[descIndex].toString().replaceAll("_", " ");
    String code = row[codeIndex].toString();
    row[descIndex] = description;

    // Add Concatenate value
    row.add("$code $description");

    // Map headers to row
    Map<String, dynamic> rowMap = {};
    for (int j = 0; j < headers.length; j++) {
      rowMap[headers[j]] = row[j];
    }
    data.add(rowMap);
  }

  return data;
}
