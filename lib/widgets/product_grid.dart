import 'package:flutter/material.dart';

class ProductGrid extends StatelessWidget {
  final List<dynamic> products;

  const ProductGrid({Key? key, required this.products}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Use LayoutBuilder to determine available width.
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
  final double maxWidth; // The available width from the parent

  const ProductCard({Key? key, required this.product, required this.maxWidth})
      : super(key: key);

  @override
  _ProductCardState createState() => _ProductCardState();
}

class _ProductCardState extends State<ProductCard> {
  bool isExpanded = false;

  @override
  Widget build(BuildContext context) {
    final product = widget.product;
    String productName = product['Product Description'] ?? 'N/A';
    String location = product['Location Name'] ?? 'N/A';
    int stock = product['Quantity On Hand'] ?? 0;
    int price = product['Product Price'] ?? 0;
    String productCode = product['Product Code'] ?? 'N/A';
    String details = product['Concatenate'] ?? '';

    // When closed, we want two cards per row. Assume Wrap's horizontal padding is 8 on each side.
    // So total horizontal padding = 16.
    double totalPadding = 16.0;
    double closedWidth = (widget.maxWidth - totalPadding - 8) / 2;
    // When expanded, the card takes the full available width (minus total horizontal padding).
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
              // Product Name
              Text(
                productName,
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 8),
              // Location Row
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
              // Price and Stock Info
              Text(
                "Price: ₹$price",
                style: const TextStyle(fontSize: 14, color: Colors.black87),
              ),
              const SizedBox(height: 4),
              Text(
                "Stock: $stock units",
                style: const TextStyle(fontSize: 14, color: Colors.black54),
              ),
              // Expanded Details: visible only when expanded.
              if (isExpanded) ...[
                const SizedBox(height: 8),
                const Divider(),
                const SizedBox(height: 8),
                Text(
                  "Product Code: $productCode",
                  style: const TextStyle(fontSize: 14, color: Colors.black87),
                ),
                const SizedBox(height: 4),
                Text(
                  "Details: $details",
                  style: const TextStyle(fontSize: 12, color: Colors.black54),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
              const SizedBox(height: 8),
              // Centered "View Details" / "Hide Details" button.
              Center(
                child: TextButton(
                  onPressed: () {
                    setState(() {
                      isExpanded = !isExpanded;
                    });
                  },
                  style: TextButton.styleFrom(
                    backgroundColor: Colors.blue,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: Text(
                    isExpanded ? "Hide Details" : "View Details",
                    style: const TextStyle(fontSize: 14, color: Colors.white),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
