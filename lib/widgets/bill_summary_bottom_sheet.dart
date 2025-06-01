import 'package:flutter/material.dart';
import '../screens/payment_confirmation_screen.dart';


class BillSummaryBottomSheet extends StatelessWidget {
  final double subtotal;
  final double serviceCharge;
  final List<Map<String, dynamic>> selectedProducts;
  final VoidCallback onConfirmDownload;
  final ValueChanged<bool> onConsentChanged;

  const BillSummaryBottomSheet({
    Key? key,
    required this.subtotal,
    required this.serviceCharge,
    required this.selectedProducts,
    required this.onConfirmDownload,
    required this.onConsentChanged,
  }) : super(key: key);

  final Color primaryColor = const Color(0xFFF8F13F); // App primary color

  @override
  Widget build(BuildContext context) {
    bool isChecked = false;
    double grandTotal = (subtotal + serviceCharge).roundToDouble();

    return StatefulBuilder(
      builder: (context, setState) => DraggableScrollableSheet(
        initialChildSize: 0.8,
        minChildSize: 0.4,
        maxChildSize: 0.95,
        expand: false,
        builder: (_, controller) => Container(
          padding: const EdgeInsets.all(20),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            boxShadow: [
              BoxShadow(
                color: Colors.black12,
                blurRadius: 10,
                offset: Offset(0, -2),
              ),
            ],
          ),
          child: SingleChildScrollView(
            controller: controller,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Center(
                  child: Text(
                    "Invoice Summary",
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
                  ),
                ),
                const SizedBox(height: 16),

                // Product List
                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: selectedProducts.length,
                  itemBuilder: (context, index) {
                    final product = selectedProducts[index];
                    final name = product['product_description'] ?? 'Unnamed';
                    final quantity = product['quantity'] ?? 1;
                    final price = product['customer_price'] ?? '0';

                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4.0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              "$name (x$quantity)",
                              style: const TextStyle(fontSize: 16),
                            ),
                          ),
                          Text("₹$price", style: const TextStyle(fontWeight: FontWeight.w600)),
                        ],
                      ),
                    );
                  },
                ),

                const Divider(height: 30),

                buildSummaryRow("Subtotal", subtotal),
                buildSummaryRow("Service Charge", serviceCharge),
                const Divider(),
                buildSummaryRow("Grand Total", grandTotal, isBold: true, highlight: true),

                const SizedBox(height: 16),

                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Checkbox(
                      value: isChecked,
                      activeColor: primaryColor,
                      onChanged: (value) {
                        setState(() => isChecked = value ?? false);
                        onConsentChanged(isChecked);
                      },
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        "Technician has confirmed the item list.",
                        style: TextStyle(color: Colors.grey[800], fontSize: 15),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: isChecked
                        ? () {
                      Navigator.pop(context); // Close bottom sheet
                      onConfirmDownload(); // Optional callback
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => PaymentConfirmationScreen()),
                      );
                    }
                        : null,

                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryColor,
                      disabledBackgroundColor: Colors.grey[400],
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      "Generate Invoice",
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.black),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget buildSummaryRow(String title, double value, {bool isBold = false, bool highlight = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            title,
            style: TextStyle(
              fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
              fontSize: highlight ? 17 : 15,
            ),
          ),
          Text(
            "₹${value.toStringAsFixed(2)}",
            style: TextStyle(
              fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
              fontSize: highlight ? 17 : 15,
              color: highlight ? Colors.green[700] : Colors.black,
            ),
          ),
        ],
      ),
    );
  }
}