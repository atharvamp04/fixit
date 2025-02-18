import 'package:flutter/material.dart';
import 'dart:convert';

class ProductGridWidget extends StatelessWidget {
  final String jsonData; // JSON encoded list of products

  const ProductGridWidget({Key? key, required this.jsonData}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    List<dynamic> products = jsonDecode(jsonData);

    return GridView.builder(
      shrinkWrap: true, // Makes the GridView take only the space it needs
      physics: NeverScrollableScrollPhysics(), // Let outer scroll view handle scrolling
      itemCount: products.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2, // 2 cards per row
        mainAxisSpacing: 8,
        crossAxisSpacing: 8,
        childAspectRatio: 3 / 2,
      ),
      itemBuilder: (context, index) {
        final product = products[index];
        final productName = product['Product Description'] ?? 'N/A';
        final price = product['Product Price'] ?? 0;
        final stock = product['Quantity On Hand'] ?? 0;

        return Card(
          elevation: 4,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: Padding(
            padding: const EdgeInsets.all(12.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  productName,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const Spacer(),
                Text(
                  "Price: ₹$price",
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.green[700],
                  ),
                ),
                Text(
                  "Stock: $stock",
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[700],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
