import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

class InvoiceHistoryPage extends StatefulWidget {
  @override
  _InvoiceHistoryPageState createState() => _InvoiceHistoryPageState();
}

class _InvoiceHistoryPageState extends State<InvoiceHistoryPage> {
  final SupabaseClient supabase = Supabase.instance.client;
  List<dynamic> orders = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    fetchUserOrders();
  }

  Future<void> fetchUserOrders() async {
    final userId = supabase.auth.currentUser?.id;

    if (userId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('User not logged in')),
      );
      return;
    }

    try {
      final response = await supabase
          .from('orders')
          .select('tech_name, customer_email, invoice_copy')
          .eq('user_id', userId);

      setState(() {
        orders = response;
        isLoading = false;
      });
    } catch (e) {
      setState(() {
        isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading invoices: $e')),
      );
    }
  }

  Future<void> _openPdf(String url) async {
    try {
      final Uri uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not open PDF')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error launching PDF: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Invoice History'),
        backgroundColor: Colors.yellow[600],
      ),
      body: isLoading
          ? Center(child: CircularProgressIndicator())
          : orders.isEmpty
          ? Center(child: Text('No invoices found.'))
          : ListView.builder(
        itemCount: orders.length,
        itemBuilder: (context, index) {
          final order = orders[index];
          final String name = order['tech_name'] ?? 'Unnamed';
          final String email = order['customer_email'] ?? '';
          final String pdfUrl = order['invoice_copy'] ?? '';

          return Card(
            margin: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            child: ListTile(
              leading: Icon(Icons.person, color: Colors.blue),
              title: Text(name),
              subtitle: email.isNotEmpty ? Text(email) : null,
              trailing: IconButton(
                icon: Icon(Icons.picture_as_pdf, color: Colors.red),
                onPressed: pdfUrl.isNotEmpty
                    ? () => _openPdf(pdfUrl)
                    : null,
                tooltip:
                pdfUrl.isNotEmpty ? 'Open PDF' : 'No PDF URL',
              ),
            ),
          );
        },
      ),
    );
  }
}
