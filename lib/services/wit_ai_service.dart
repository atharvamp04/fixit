import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

class WitAIService {
  // Replace with your secure Wit.ai Server Access Token.
  final String apiToken = "JF4FVJ6I4LCVK776BGTDRU6OV6ZW6GNO";

  // Supabase client (ensure it’s initialized in main.dart)
  final SupabaseClient supabase = Supabase.instance.client;

  /// Processes the user's message using Wit.ai.
  /// Returns a map with keys:
  /// - type: "text" or "product"
  /// - message: for text responses
  /// - products: for product responses (list)
  Future<Map<String, dynamic>> processMessage(String message) async {
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

        // Extract intent and entities.
        String intent = data['intents']?.isNotEmpty == true
            ? data['intents'][0]['name']
            : "unknown";
        Map<String, dynamic> entities = data['entities'] ?? {};

        if (intent == "product_query") {
          // First try processing via product code.
          Map<String, dynamic> result = await _processProductCode(entities);
          // If result indicates missing or malformed info, fall back to description search.
          if (result["type"] == "text" &&
              (result["message"].startsWith("Could you please provide") ||
                  result["message"].contains("empty or malformed"))) {
            result = await _processProductDescription(entities);
          }
          return result;
        }

        // Non-product intents.
        return _generateBotResponse(intent, entities);
      } else {
        return {
          "type": "text",
          "message": "Sorry, something went wrong while processing your request."
        };
      }
    } catch (e) {
      print("Error: $e");
      return {
        "type": "text",
        "message": "Error: Unable to process your request. Please check your internet connection."
      };
    }
  }

  /// Joins multiple entity values for a given key.
  String joinEntityValues(Map<String, dynamic> entities, String key) {
    if (entities.containsKey(key)) {
      var list = entities[key];
      if (list is List && list.isNotEmpty) {
        return list.map((e) => e["value"].toString()).join(" ");
      }
    }
    return "";
  }

  /// Extracts a product code from entities and queries the database.
  Future<Map<String, dynamic>> _processProductCode(Map<String, dynamic> entities) async {
    print("Entities for product code: $entities");
    if (entities.containsKey("product_code:product_code")) {
      var productEntity = entities["product_code:product_code"];
      if (productEntity is List && productEntity.isNotEmpty) {
        String productCode = productEntity[0]["value"];
        print("Extracted product code: $productCode");
        return await _checkProductAvailabilityByCode(productCode);
      }
    }
    return {"type": "text", "message": "Could you please provide the product code?"};
  }

  /// Processes a product description query by extracting detailed tokens,
  /// building a search query, and then ranking the returned products.
  Future<Map<String, dynamic>> _processProductDescription(Map<String, dynamic> entities) async {
    print("Entities for product description: $entities");

    // Extract detailed tokens.
    String material = joinEntityValues(entities, "product_material:product_material");
    String color = joinEntityValues(entities, "product_color:product_color");
    String category = joinEntityValues(entities, "product_category:product_category");
    String description = joinEntityValues(entities, "product_description:product_description");
    String prodType = joinEntityValues(entities, "Product_type:Product_type");
    String additionalComponent = joinEntityValues(entities, "additional_component:additional_component");
    String colorDescription = joinEntityValues(entities, "color_description:color_description");
    String prodComponent = joinEntityValues(entities, "product_component:product_component");
    String prodModel = joinEntityValues(entities, "product_model:product_model");
    String prodName = joinEntityValues(entities, "product_name:product_name");
    String prodSeries = joinEntityValues(entities, "product_series:product_series");
    String prodSize = joinEntityValues(entities, "product_size:product_size");

    // Combine tokens into a single search string.
    String queryPart = [material, color, category, description, prodType, additionalComponent, colorDescription, prodComponent, prodModel, prodName, prodSeries, prodSize]
        .where((element) => element.isNotEmpty)
        .join(" ")
        .trim();

    if (queryPart.isEmpty) {
      return {"type": "text", "message": "Could you please provide more details about the product?"};
    }

    print("Constructed search query: $queryPart");

    try {
      // Split the query into individual tokens.
      final tokens = queryPart.split(' ').where((token) => token.isNotEmpty).toList();

      // Build the Supabase query with an ilike filter for each token.
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
        return {"type": "text", "message": "❌ Sorry, no product found matching the description **$queryPart**."};
      }
      // Rank products using an advanced ranking algorithm.
      List<dynamic> rankedProducts = _rankProducts(response, tokens);
      return {"type": "product", "products": rankedProducts};
    } catch (e) {
      print("Supabase error: $e");
      return {"type": "text", "message": "Error fetching product details. Please try again later."};
    }
  }

  /// Ranks products based on the number of query tokens found in the "Concatenate" field.
  List<dynamic> _rankProducts(List<dynamic> products, List<String> tokens) {
    for (var product in products) {
      String concatText = (product['Concatenate'] ?? '').toString().toLowerCase();
      int score = 0;
      for (var token in tokens) {
        if (concatText.contains(token.toLowerCase())) {
          score++;
        }
      }
      product['matchScore'] = score;
    }
    products.sort((a, b) => (b['matchScore'] as int).compareTo(a['matchScore'] as int));
    print("Ranked products: ${products.map((p) => p['matchScore']).toList()}");
    return products;
  }

  /// Queries Supabase for a product with an exact product code.
  Future<Map<String, dynamic>> _checkProductAvailabilityByCode(String productCode) async {
    if (productCode.isEmpty) {
      return {"type": "text", "message": "❌ Product code is empty or malformed!"};
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
        return {"type": "text", "message": "❌ Sorry, no product found with code **$productCode**."};
      }
      return {"type": "product", "products": response};
    } catch (e) {
      print("Supabase error: $e");
      return {"type": "text", "message": "Error fetching product details. Please try again later."};
    }
  }

  /// Generates default responses for non-product queries.
  Map<String, dynamic> _generateBotResponse(String intent, Map<String, dynamic> entities) {
    switch (intent) {
      case "Greeting":
        return {"type": "text", "message": "Hello! How can I assist you today?"};
      case "Farewell":
        return {"type": "text", "message": "Goodbye! Have a great day!"};
      default:
        return {"type": "text", "message": "Sorry, I didn't understand that. Could you rephrase?"};
    }
  }
}
