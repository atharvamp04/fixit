import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

class WitAIService {
  // Replace with your secure Wit.ai Server Access Token.
  final String apiToken = "JF4FVJ6I4LCVK776BGTDRU6OV6ZW6GNO";

  // Supabase client (ensure it’s initialized in main.dart)
  final SupabaseClient supabase = Supabase.instance.client;

  /// Processes the user's message using Wit.ai.
  Future<String> processMessage(String message) async {
    final String url =
        "https://api.wit.ai/message?v=20230124&q=${Uri.encodeComponent(message)}";

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

        // Extract the intent.
        String intent = data['intents']?.isNotEmpty == true
            ? data['intents'][0]['name']
            : "unknown";
        // Extract entities.
        Map<String, dynamic> entities = data['entities'] ?? {};

        if (intent == "product_query") {
          // First try processing via product code.
          String result = await _processProductCode(entities);
          // If no valid product code is detected, fall back to description search.
          if (result.startsWith("Could you please provide") ||
              result.contains("empty or malformed")) {
            result = await _processProductDescription(entities);
          }
          return result;
        }

        // Handle non-product intents.
        return _generateBotResponse(intent, entities);
      } else {
        return "Sorry, something went wrong while processing your request.";
      }
    } catch (e) {
      print("Error: $e");
      return "Error: Unable to process your request. Please check your internet connection.";
    }
  }

  /// Helper function to join multiple entity values.
  String joinEntityValues(Map<String, dynamic> entities, String key) {
    if (entities.containsKey(key)) {
      var list = entities[key];
      if (list is List && list.isNotEmpty) {
        // Join all found values separated by a space.
        return list.map((e) => e["value"].toString()).join(" ");
      }
    }
    return "";
  }

  /// Tries to extract a product code and searches the database.
  Future<String> _processProductCode(Map<String, dynamic> entities) async {
    print("Entities for product code: $entities");
    if (entities.containsKey("product_code:product_code")) {
      var productEntity = entities["product_code:product_code"];
      if (productEntity is List && productEntity.isNotEmpty) {
        String productCode = productEntity[0]["value"];
        print("Extracted product code: $productCode");
        return await _checkProductAvailabilityByCode(productCode);
      }
    }
    return "Could you please provide the product code?";
  }

  /// Processes a query based on product description details.
  Future<String> _processProductDescription(Map<String, dynamic> entities) async {
    print("Entities for product description: $entities");

    // Extract detailed tokens, joining multiple values if available.
    String material =
    joinEntityValues(entities, "product_material:product_material");
    String color = joinEntityValues(entities, "product_color:product_color");
    String category =
    joinEntityValues(entities, "product_category:product_category");
    String description =
    joinEntityValues(entities, "product_description:product_description");

    // Combine the tokens into one search query.
    String queryPart = [material, color, category, description]
        .where((element) => element.isNotEmpty)
        .join(" ")
        .trim();

    if (queryPart.isEmpty) {
      return "Could you please provide more details about the product?";
    }

    print("Constructed search query: $queryPart");

    try {
      // Split the combined query into tokens.
      final tokens =
      queryPart.split(' ').where((token) => token.isNotEmpty).toList();

      // Build the query by applying an ilike filter for each token.
      var queryBuilder = supabase
          .from('products')
          .select('*')
          .gt('Quantity On Hand', 0);

      for (var token in tokens) {
        queryBuilder = queryBuilder.ilike('Concatenate', '%$token%');
      }
      final List<dynamic> response = await queryBuilder;

      print("Supabase response (description search): $response");

      if (response.isEmpty) {
        return "❌ Sorry, no product found matching the description **$queryPart**.";
      }
      return _formatProductResponse(response);
    } catch (e) {
      print("Supabase error: $e");
      return "Error fetching product details. Please try again later.";
    }
  }

  /// Queries Supabase using an exact product code.
  Future<String> _checkProductAvailabilityByCode(String productCode) async {
    if (productCode.isEmpty) {
      return "❌ Product code is empty or malformed!";
    }
    try {
      print("🔍 Searching for product with code: $productCode");

      final List<dynamic> response = await supabase
          .from('products')
          .select('*')
          .eq('Product Code', productCode)
          .gt('Quantity On Hand', 0);

      print("Supabase response (code search): $response");

      if (response.isEmpty) {
        return "❌ Sorry, no product found with code **$productCode**.";
      }
      return _formatProductResponse(response);
    } catch (e) {
      print("Supabase error: $e");
      return "Error fetching product details. Please try again later.";
    }
  }

  /// Formats the product data into a human-readable response.
  String _formatProductResponse(List<dynamic> products) {
    if (products.length == 1) {
      var product = products[0];
      String location = product['Location Name'] ?? 'N/A';
      String productName = product['Product Description'] ?? 'N/A';
      int stock = product['Quantity On Hand'] ?? 0;
      int price = product['Product Price'] ?? 0;

      return "📍 **Location:** $location\n"
          "📦 **$productName**\n"
          "💰 **Price:** ₹$price\n"
          "📊 **Stock:** $stock units";
    } else {
      // For multiple products, use a structured bullet list.
      StringBuffer responseBuffer = StringBuffer();
      responseBuffer.writeln("📦 **Available Products:**\n");
      for (var product in products) {
        String location = product['Location Name'] ?? 'N/A';
        String productName = product['Product Description'] ?? 'N/A';
        int stock = product['Quantity On Hand'] ?? 0;
        int price = product['Product Price'] ?? 0;
        responseBuffer.writeln(
            "- **$productName**\n  Location: $location\n  Price: ₹$price\n  Stock: $stock units\n");
      }
      return responseBuffer.toString();
    }
  }

  /// Generates default responses for non-product queries.
  String _generateBotResponse(String intent, Map<String, dynamic> entities) {
    switch (intent) {
      case "Greeting":
        return "Hello! How can I assist you today?";
      case "Farewell":
        return "Goodbye! Have a great day!";
      default:
        return "Sorry, I didn't understand that. Could you rephrase?";
    }
  }
}
