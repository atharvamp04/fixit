import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:convert';
import '../services/mail_service.dart';
import 'package:uuid/uuid.dart';

class ProductGrid extends StatelessWidget {
  final List<dynamic> products;

  const ProductGrid({Key? key, required this.products}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        double maxWidth = constraints.maxWidth;
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: products.map((product) {
              return ProductCard(
                product: product,
                maxWidth: maxWidth,
              );
            }).toList(),
          ),
        );
      },
    );
  }
}

class ProductCard extends StatefulWidget {
  final dynamic product;
  final double maxWidth;

  const ProductCard({Key? key, required this.product, required this.maxWidth})
      : super(key: key);

  @override
  _ProductCardState createState() => _ProductCardState();
}

class _ProductCardState extends State<ProductCard> {
  bool isExpanded = false;
  final MailService mailService = MailService();
  final SupabaseClient supabase = Supabase.instance.client;
  final Uuid uuid = Uuid(); // ✅ Define Uuid instance

  Future<String?> _fetchManagerId(String userEmail) async {
    final response = await supabase
        .from('profiles')  // Fetch from profile instead of notifications
        .select('id')
        .eq('email', userEmail) // Assuming manager is identified by email
        .maybeSingle();

    return response?['id'];
  }

  Future<void> _sendNotificationToManager() async {
    final product = widget.product;
    String productName = product['Product Description'] ?? 'N/A';
    int stock = product['Quantity On Hand'] ?? 0;
    String managerEmail = "2022.atharva.phadtare@ves.ac.in"; // Get the manager's email

    String? managerId = await _fetchManagerId(managerEmail);
    if (managerId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Error: Manager ID not found in profile!")),
      );
      return;
    }

    final notificationPayload = {
      "title": "Stock Alert: $productName",
      "message": "Stock is low: Only $stock units left!",
      "managerId": managerId,
    };

    try {
      // Send notification via HTTP API
      final notificationResponse = await http.post(
        Uri.parse('https://your-api.com/send-notification'),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode(notificationPayload),
      );

      // Send email
      await mailService.sendStockRequestEmail(
        managerEmail: managerEmail,
        productName: productName,
        stock: stock,
      );

      // Insert notification in Supabase
      await supabase.from('notifications').insert({
        'id': const Uuid().v4(),
        'message': "Stock Alert: $productName - Only $stock left!",
        'created_at': DateTime.now().toIso8601String(),
        'manager_id': managerId, // Ensure this ID exists in profile
        'is_read': false,
      });

      if (notificationResponse.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Notification & Email sent to Manager")),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Notification Sent!")),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error: $e")),
      );
    }
  }


  @override
  Widget build(BuildContext context) {
    final product = widget.product;
    String productName = product['Product Description'] ?? 'N/A';
    String location = product['Location Name'] ?? 'N/A';
    int stock = product['Quantity On Hand'] ?? 0;
    int price = product['Product Price'] ?? 0;
    String productCode = product['Product Code'] ?? 'N/A';
    String details = product['Concatenate'] ?? '';

    double totalPadding = 16.0;
    double closedWidth = (widget.maxWidth - totalPadding - 8) / 2;
    double expandedWidth = widget.maxWidth - totalPadding;
    double cardWidth = isExpanded ? expandedWidth : closedWidth;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
      width: cardWidth,
      child: Card(
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                productName,
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                maxLines: 4,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(Icons.location_on, size: 16, color: Colors.grey),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      location,
                      style: const TextStyle(fontSize: 14, color: Colors.grey),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text("Price: ₹$price", style: const TextStyle(fontSize: 14, color: Colors.black87)),
              const SizedBox(height: 4),
              Text("Stock: $stock units", style: const TextStyle(fontSize: 14, color: Colors.black54)),
              const SizedBox(height: 8),
              Center(
                child: TextButton(
                  onPressed: () => setState(() => isExpanded = !isExpanded),
                  style: TextButton.styleFrom(
                    backgroundColor: const Color(0xFFEFE516),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  child: Text(isExpanded ? "Hide Details" : "View Details", style: const TextStyle(fontSize: 14, color: Colors.white)),
                ),
              ),
              if (isExpanded) ...[
                const SizedBox(height: 8),
                const Divider(),
                const SizedBox(height: 8),
                Text("Product Code: $productCode", style: const TextStyle(fontSize: 14, color: Colors.black87)),
                const SizedBox(height: 4),
                Text("Details: $details", style: const TextStyle(fontSize: 12, color: Colors.black54), maxLines: 3, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 8),
                Center(
                  child: ElevatedButton(
                    onPressed: _sendNotificationToManager,
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.red, padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
                    child: const Text("Request", style: TextStyle(fontSize: 14, color: Colors.white)),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
