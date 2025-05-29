import 'package:flutter/material.dart';

class BillSummaryBottomSheet extends StatelessWidget {
  final double subtotal;
  final double serviceCharge; // <-- You forgot to declare this earlier
  final List<Map<String, dynamic>> selectedProducts;
  final VoidCallback onConfirmDownload;
  final ValueChanged<bool> onConsentChanged;

  const BillSummaryBottomSheet({
    Key? key,
    required this.subtotal,
    required this.serviceCharge, // <-- Now it's added correctly
    required this.selectedProducts,
    required this.onConfirmDownload,
    required this.onConsentChanged,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    bool isChecked = false;
    double grandTotal = subtotal + serviceCharge;

    return StatefulBuilder(
      builder: (context, setState) => Padding(
        padding: MediaQuery.of(context).viewInsets.add(const EdgeInsets.all(20)),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text("Invoice Summary", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),

            // Product list
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: selectedProducts.length,
              itemBuilder: (context, index) {
                final product = selectedProducts[index];
                final name = product['product_name'] ?? 'Unnamed';
                final quantity = product['quantity'] ?? 1;
                final price = product['customer_price'] ?? '0';

                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(child: Text("$name (x$quantity)")),
                      Text("₹$price"),
                    ],
                  ),
                );
              },
            ),

            const Divider(),
            buildSummaryRow("Subtotal", subtotal),
            buildSummaryRow("Service Charge", serviceCharge),
            const Divider(),
            buildSummaryRow("Grand Total", grandTotal, isBold: true),

            const SizedBox(height: 16),
            Row(
              children: [
                Checkbox(
                  value: isChecked,
                  onChanged: (value) {
                    setState(() => isChecked = value ?? false);
                    onConsentChanged(isChecked);
                  },
                ),
                const Expanded(child: Text("Technician has confirmed the item list.")),
              ],
            ),
            const SizedBox(height: 8),
            ElevatedButton(
              onPressed: isChecked
                  ? () {
                Navigator.pop(context);
                onConfirmDownload();
              }
                  : null,
              child: const Text("Generate Invoice"),
            ),
          ],
        ),
      ),
    );
  }

  Widget buildSummaryRow(String title, double value, {bool isBold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(title, style: isBold ? const TextStyle(fontWeight: FontWeight.bold) : null),
          Text("₹${value.toStringAsFixed(2)}", style: isBold ? const TextStyle(fontWeight: FontWeight.bold) : null),
        ],
      ),
    );
  }
}
