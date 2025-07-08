// documents_page.dart
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../widgets/common_layout.dart';

class DocumentsPage extends StatefulWidget {
  const DocumentsPage({super.key});

  @override
  State<DocumentsPage> createState() => _DocumentsPageState();
}

class _DocumentsPageState extends State<DocumentsPage> {
  List<Map<String, dynamic>> documents = [];
  bool isLoading = true;
  final GlobalKey<ScaffoldState> scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  void initState() {
    super.initState();
    fetchDocuments();
  }

  Future<void> fetchDocuments() async {
    try {
      final data = await Supabase.instance.client
          .from('documents')
          .select('title, url')
          .order('uploaded_at', ascending: false);

      setState(() {
        documents = data.cast<Map<String, dynamic>>();
        isLoading = false;
      });
    } catch (e) {
      print('❌ Error: $e');
      setState(() => isLoading = false);
    }
  }

  Future<void> openPdf(String url) async {
    final uri = Uri.parse(url);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text("Failed to open PDF")));
    }
  }

  @override
  Widget build(BuildContext context) {
    return CommonLayout(
      scaffoldKey: scaffoldKey,
      title: 'Documents',
      body: ListView.builder(
        itemCount: documents.length,
        itemBuilder: (context, index) {
          final doc = documents[index];
          return ListTile(
            leading: const Icon(Icons.picture_as_pdf, color: Colors.red),
            title: Text(doc['title']),
            onTap: () => openPdf(doc['url']),
          );
        },
      ),
      selectedIndex: 4, // for Alerts tab or whichever index
      onItemTapped: (int index) {
        // Handle tab change or navigation here
      },
    );

  }
}
