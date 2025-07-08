import 'dart:io';
import 'package:csv/csv.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';

import '../widgets/common_layout.dart';

class DownloadDataScreen extends StatefulWidget {
  const DownloadDataScreen({super.key});

  @override
  State<DownloadDataScreen> createState() => _DownloadDataScreenState();
}

class _DownloadDataScreenState extends State<DownloadDataScreen> {
  final GlobalKey<ScaffoldState> scaffoldKey = GlobalKey<ScaffoldState>();
  final List<String> tables = ['orders', 'payment_metadata', 'profiles'];
  String? selectedTable;

  Future<void> _downloadCsv(String tableName) async {
    try {
      final supabase = Supabase.instance.client;
      final data = await supabase.from(tableName).select();

      if (data.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No data found to export')),
        );
        return;
      }

      final headers = data.first.keys.toList();
      final rows = data.map((row) => headers.map((h) => row[h]).toList()).toList();
      final csvData = const ListToCsvConverter().convert([headers, ...rows]);

      if (!await Permission.storage.request().isGranted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Storage permission not granted')),
        );
        return;
      }

      Directory downloadsDir;
      if (Platform.isAndroid) {
        downloadsDir = Directory('/storage/emulated/0/Download');
      } else {
        downloadsDir = await getApplicationDocumentsDirectory();
      }

      final filePath = '${downloadsDir.path}/$tableName.csv';
      final file = File(filePath);
      await file.writeAsString(csvData);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('✅ File saved to: $filePath')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('❌ Error: $e')),
      );
    }
  }

  void _onNavTapped(int index) {
    switch (index) {
      case 0:
        Navigator.pushReplacementNamed(context, '/chat');
        break;
      case 1:
        Navigator.pushReplacementNamed(context, '/history');
        break;
      case 2:
        Navigator.pushReplacementNamed(context, '/bill');
        break;
      case 3:
        Navigator.pushReplacementNamed(context, '/profile');
        break;
      case 4:
        Navigator.pushReplacementNamed(context, '/alerts');
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return CommonLayout(
      title: "Download Data",
      scaffoldKey: scaffoldKey,
      selectedIndex: 0, // 👈 Use a valid index (e.g. 0)
      onItemTapped: _onNavTapped,
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            DropdownButtonFormField<String>(
              value: selectedTable,
              decoration: const InputDecoration(
                labelText: 'Select Table',
                border: OutlineInputBorder(),
              ),
              items: tables.map((table) {
                return DropdownMenuItem(
                  value: table,
                  child: Text(table),
                );
              }).toList(),
              onChanged: (value) {
                setState(() {
                  selectedTable = value;
                });
              },
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: selectedTable == null
                  ? null
                  : () => _downloadCsv(selectedTable!),
              icon: const Icon(Icons.file_download),
              label: const Text("Download CSV"),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
