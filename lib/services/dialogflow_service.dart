import 'package:dialogflow_flutter/dialogflowFlutter.dart';
import 'package:dialogflow_flutter/googleAuth.dart';

class DialogflowService {
  Future<String> getResponse(String query) async {
    try {
      // Initialize AuthGoogle with the credentials JSON
      final authGoogle = await AuthGoogle(fileJson: "assets/newagent-9aew-094a12e96d99.json").build();

      // Create the DialogFlow instance with the language set to "en"
      final dialogflow = DialogFlow(authGoogle: authGoogle, language: "en");

      // Send the query and get the response
      final AIResponse response = await dialogflow.detectIntent(query);

      // Log the response message for debugging purposes
      print('Dialogflow response message: ${response?.getMessage()}');

      // Check if the response is null or empty and return a fallback message
      if (response == null || response.getMessage() == null) {
        print('Dialogflow response is null or empty');
        return 'Sorry, I didn\'t understand that. Can you try again?';
      }

      // Return the message from the respohellonse
      return response.getMessage() ?? 'No response from bot';
    } catch (e) {
      // Log the error and return a generic error message
      print('Error in DialogflowService: $e');
      return 'There was an error processing your request. Please try again later.';
    }
  }
}
