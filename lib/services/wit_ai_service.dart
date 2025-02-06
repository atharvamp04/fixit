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
        if (intent == "product_availability") {
          return await _processProductAvailability(entities);
        }

        // Default response for unrecognized intents
        return await _generateBotResponse(intent, entities);
      } else {
        return "Sorry, something went wrong while processing your request.";
      }
    } catch (e) {
      return "Error: Unable to process your request. Please check your internet connection.";
    }
  }

  /// Processes product availability based on Wit.ai entities
  Future<String> _processProductAvailability(Map<String, dynamic> entities) async {
    print("Entities received: $entities"); // Debugging entities

    // Check for the key "product_name:product_name" since that's what the log shows.
    if (entities.containsKey("product_name:product_name")) {
      var productEntity = entities["product_name:product_name"];
      print("Found key 'product_name:product_name'");

      // Check if productEntity is a List and not empty
      if (productEntity is List && productEntity.isNotEmpty) {
        String productName = productEntity[0]["value"];
        print("Extracted product name: $productName"); // This should now print "Motor Controller"
        return await _checkProductAvailability(productName); // Query Supabase with the extracted value
      } else {
        print("productEntity is not a List or is empty.");
      }
    } else {
      print("No 'product_name:product_name' key found in entities.");
    }

    return "Could you please specify the product name?";
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

  /// Checks the product availability from Supabase database
  Future<String> _checkProductAvailability(String productName) async {
    try {
      print("🔍 Searching for product: $productName");

      // Print the product name here to ensure it's not empty or malformed
      if (productName.isEmpty) {
        return "Product name is empty or malformed!";
      }

      final response = await supabase
          .from('products-A')
          .select('*')  // Fetch all columns
          .ilike('product_name', '%$productName%') // Use the productName variable
          .limit(1)
          .maybeSingle();




      print("📊 Supabase response: $response");  // Check what response we get from Supabase

      if (response != null && response.isNotEmpty) {
        int stock = response['stock'];
        int price = response['price'];

        if (stock > 0) {
          return "Yes, $productName is available! 🏷️ Price: ₹$price. 📦 Stock: $stock units.";
        } else {
          return "Sorry, $productName is currently out of stock.";
        }
      } else {
        return "Sorry, we couldn't find any information about $productName.";
      }
    } catch (e) {
      print("❌ Supabase error: $e");
      return "Error fetching product details. Please try again later.";
    }
  }


}

