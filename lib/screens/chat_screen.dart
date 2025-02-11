import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../services/wit_ai_service.dart';

class ChatScreen extends StatefulWidget {
  final String sessionId; // Unique session ID for each chat

  const ChatScreen({super.key, required this.sessionId});

  @override
  _ChatScreenState createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _controller = TextEditingController();
  final WitAIService _witAIService = WitAIService();
  List<Map<String, String>> messages = [];
  bool isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadChatHistory();
  }

  void _loadChatHistory() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? chatHistory = prefs.getString(widget.sessionId); // Load specific session

    if (chatHistory != null && chatHistory.isNotEmpty) {
      try {
        List<dynamic> jsonData = jsonDecode(chatHistory);
        setState(() {
          messages = jsonData.map<Map<String, String>>((msg) {
            return {
              "sender": msg["sender"].toString(),
              "text": msg["text"].toString()
            };
          }).toList();
        });
      } catch (e) {
        print("Error loading chat history: $e");
      }
    }
  }

  void _saveChatHistory() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String chatHistory = jsonEncode(messages);
    await prefs.setString(widget.sessionId, chatHistory); // Save session-specific chat
  }

  void _sendMessage() async {
    if (_controller.text.trim().isEmpty) return;

    String userMessage = _controller.text.trim();
    _controller.clear();

    setState(() {
      messages.add({"sender": "user", "text": userMessage});
      isLoading = true;
    });

    try {
      final response = await _witAIService.processMessage(userMessage);
      setState(() {
        messages.add({"sender": "bot", "text": response});
      });
    } catch (error) {
      setState(() {
        messages.add({"sender": "bot", "text": "Sorry, I couldn't process that."});
      });
    } finally {
      setState(() {
        isLoading = false;
      });

      _saveChatHistory(); // Save chat history after message
    }
  }

  void _startNewChat() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String newSessionId = DateTime.now().millisecondsSinceEpoch.toString();

    // Store the previous session in history
    await prefs.setString(widget.sessionId, jsonEncode(messages));

    // Navigate to a new chat session
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => ChatScreen(sessionId: newSessionId)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF17CE92),
        title: const Text(
          "FixIT",
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.add_comment, color: Colors.white),
            onPressed: _startNewChat, // New chat button
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              itemCount: messages.length,
              itemBuilder: (context, index) {
                return ChatBubble(
                  text: messages[index]["text"] ?? "No content",
                  isUser: messages[index]["sender"] == "user",
                );
              },
            ),
          ),
          if (isLoading)
            const Padding(
              padding: EdgeInsets.all(8.0),
              child: CircularProgressIndicator(
                color: Color(0xFF17CE92),
              ),
            ),
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    style: const TextStyle(fontSize: 16),
                    decoration: InputDecoration(
                      hintText: "Type your message...",
                      hintStyle: const TextStyle(color: Colors.grey),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(25),
                        borderSide: const BorderSide(color: Colors.grey, width: 1),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(25),
                        borderSide: const BorderSide(color: Color(0xFF17CE92), width: 2),
                      ),
                    ),
                    onSubmitted: (value) => _sendMessage(),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.send, color: Color(0xFF17CE92)),
                  onPressed: _sendMessage,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class ChatBubble extends StatelessWidget {
  final String text;
  final bool isUser;

  const ChatBubble({super.key, required this.text, required this.isUser});

  @override
  Widget build(BuildContext context) {
    final backgroundColor = isUser ? const Color(0xFF17CE92) : Colors.grey[200];
    final textColor = isUser ? Colors.white : Colors.black87;

    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 6),
        padding: const EdgeInsets.all(14),
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: isUser ? const Radius.circular(16) : const Radius.circular(0),
            bottomRight: isUser ? const Radius.circular(0) : const Radius.circular(16),
          ),
          boxShadow: const [
            BoxShadow(
              color: Colors.black12,
              blurRadius: 6,
              offset: Offset(2, 2),
            ),
          ],
        ),
        child: Text(
          text,
          style: TextStyle(fontSize: 15, color: textColor),
        ),
      ),
    );
  }
}
