import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

class WitAIService {
  final String apiToken = "JF4FVJ6I4LCVK776BGTDRU6OV6ZW6GNO"; // Replace with your Wit.ai token

  // Using the global SupabaseClient initialized in main.dart
  final SupabaseClient supabase = Supabase.instance.client; // Access the global Supabase client

  /// Processes the user's message using Wit.ai
  Future<String> processMessage(String message) async {
    final String url = "https://api.wit.ai/message?v=20230124&q=${Uri.encodeComponent(message)}";

    try {
      final response = await http.get(
        Uri.parse(url),
        headers: {
          "Authorization": "Bearer $apiToken",
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        print("Wit.ai Response: $data");

        String intent = data['intents']?.isNotEmpty == true
            ? data['intents'][0]['name']
            : "unknown";

        Map<String, dynamic> entities = data['entities'] ?? {};

        // Check if the intent is related to product availability and process accordingly
        if (intent == "product_query") {
          return await _processProductAvailability(entities);
        }

        // Default response for unrecognized intents
        return await _generateBotResponse(intent, entities);
      } else {
        return "Sorry, something went wrong while processing your request.";
      }
    } catch (e) {
      print("Error: $e");
      return "Error: Unable to process your request. Please check your internet connection.";
    }
  }

  /// Processes product availability based on Wit.ai entities
  Future<String> _processProductAvailability(Map<String, dynamic> entities) async {
    print("Entities received: $entities"); // Debugging entities

    // Check for the key "product_code:product_code" since we're now using Product Code.
    if (entities.containsKey("product_code:product_code")) {
      var productEntity = entities["product_code:product_code"];
      print("Found key 'product_code:product_code'");

      // Check if productEntity is a List and not empty
      if (productEntity is List && productEntity.isNotEmpty) {
        String productCode = productEntity[0]["value"];
        print("Extracted product code: $productCode"); // This should now print the product code
        return await _checkProductAvailability(productCode); // Query Supabase with the extracted value
      } else {
        print("productEntity is not a List or is empty.");
      }
    } else {
      print("No 'product_code:product_code' key found in entities.");
    }

    return "Could you please provide the product code?";
  }

  /// Generates a bot response based on detected intent
  Future<String> _generateBotResponse(String intent, Map<String, dynamic> entities) async {
    switch (intent) {
      case "Greeting":
        return "Hello! How can I assist you today?";
      case "Farewell":
        return "Goodbye! Have a great day!";
      case "order_pizza":
        return "Yeah Sure!!!";
      default:
        return "Sorry, I didn't understand that. Could you rephrase?";
    }
  }

  /// Checks the product availability from Supabase database based on Product Code
  /// Fetches and displays all products from the database
  /// Checks the product availability from Supabase database based on Product Code
  Future<String> _checkProductAvailability(String productCode) async {
    try {
      print("🔍 Searching for product with Product Code: $productCode");

      if (productCode.isEmpty) {
        return "Product code is empty or malformed!";
      }

      // Fetch all matching products
      final List<dynamic> response = await supabase
          .from('products')
          .select('*')  // Fetch all columns
          .eq('Product Code', productCode); // Exact match for product code

      print("📊 Supabase response: $response");

      // If no products were found
      if (response.isEmpty) {
        return "Sorry, no product found with code $productCode.";
      }

      // Build response for multiple products
      List<String> productDetails = response.map((product) {
        String productName = product['Product Description'];
        int stock = product['Quantity On Hand'] ?? 0;
        int price = product['Product Price'] ?? 0;

        return "📦 **$productName** - ₹$price, Stock: $stock units";
      }).toList();

      return productDetails.join("\n");
    } catch (e) {
      print("❌ Supabase error: $e");
      return "Error fetching product details. Please try again later.";
    }
  }


}
