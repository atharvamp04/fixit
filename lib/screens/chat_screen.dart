import 'package:flutter/material.dart';

class ChatScreen extends StatefulWidget {
  @override
  _ChatScreenState createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  bool _isChatStarted = false; // To track if chat is started
  TextEditingController _controller = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // If chat is not started, show the welcome message
          if (!_isChatStarted)
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'Welcome to ',
                    style: TextStyle(
                      fontSize: 48,
                      fontWeight: FontWeight.bold,
                      color: Colors.black,
                    ),
                  ),
                  Text(
                    'FixIt 🔧',
                    style: TextStyle(
                      fontSize: 54,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF17CE92), // Color for "FixIt"
                    ),
                  ),
                  SizedBox(height: 10),
                  Text(
                    'Start chatting with FixIt',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.black,
                    ),
                  ),
                  SizedBox(height: 20),
                  // Full-width Start Chat button
                  SizedBox(
                    width: double.infinity, // Makes the button take full width
                    child: ElevatedButton(
                      onPressed: () {
                        setState(() {
                          _isChatStarted = true; // Enable chat after button press
                        });
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Color(0xFF17CE92),
                        padding: EdgeInsets.symmetric(vertical: 15), // Vertical padding only
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30.0),
                        ),
                      ),
                      child: Text(
                        'START CHAT',
                        style: TextStyle(color: Colors.white, fontSize: 16),
                      ),
                    ),
                  ),
                ],
              ),
            ),

          // If chat started, show the chat input field and send button at the bottom
          if (_isChatStarted)
            Positioned(
              bottom: 20,
              left: 20,
              right: 20,
              child: Row(
                children: [
                  // TextField for chat input with background color and rounded corners
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.grey[200], // Background color for the text field
                        borderRadius: BorderRadius.circular(25.0), // Slight border radius
                      ),
                      child: TextField(
                        controller: _controller,
                        decoration: InputDecoration(
                          hintText: 'How can I help?',
                          border: InputBorder.none, // Remove default border
                          contentPadding: EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                        ),
                      ),
                    ),
                  ),
                  SizedBox(width: 10),
                  // Send button with background color and white icon
                  CircleAvatar(
                    radius: 25,
                    backgroundColor: Color(0xFF17CE92),
                    child: IconButton(
                      icon: Icon(Icons.send, color: Colors.white),
                      onPressed: () {
                        // Handle send message logic here
                        if (_controller.text.isNotEmpty) {
                          // You can add the functionality to send the message
                          print('Sent: ${_controller.text}');
                          _controller.clear(); // Clear the input field after sending
                        }
                      },
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
