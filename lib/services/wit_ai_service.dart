import 'dart:convert';
import 'package:http/http.dart' as http;

class WitAIService {
  final String apiToken = "JF4FVJ6I4LCVK776BGTDRU6OV6ZW6GNO"; // Replace with your actual Wit.ai token

  Future<String> processMessage(String message) async {
    final String url = "https://api.wit.ai/message?v=20230124&q=${Uri.encodeComponent(message)}";

    try {
      // Send the GET request to Wit.ai API
      final response = await http.get(
        Uri.parse(url),
        headers: {
          "Authorization": "Bearer $apiToken",  // Your Wit.ai token
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        // Log the raw response for debugging purposes
        print("Wit.ai Response: $data");

        // Extract the intent and entities from the response
        String intent = data['intents']?.isNotEmpty == true
            ? data['intents'][0]['name']
            : "unknown";  // Default value if no intent is found

        Map<String, dynamic> entities = data['entities'] ?? {};

        // Generate response based on the detected intent
        return _generateBotResponse(intent, entities);
      } else {
        return "Sorry, something went wrong. Please try again!";
      }
    } catch (e) {
      return "Error: Unable to process your request. Please check your internet connection.";
    }
  }

  // Generate the appropriate bot response based on the intent
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
