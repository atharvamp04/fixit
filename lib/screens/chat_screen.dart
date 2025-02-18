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
  final ScrollController _scrollController = ScrollController(); // Added scroll controller

  @override
  void initState() {
    super.initState();
    _loadChatHistory();
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  // Utility method to scroll to the bottom of the chat.
  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  // Load chat history for the current session from SharedPreferences.
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
        // Scroll to bottom after chat history is loaded.
        WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
      } catch (e) {
        print("Error loading chat history: $e");
      }
    }
  }

  // Save the current chat history to SharedPreferences for this session.
  void _saveChatHistory() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String chatHistory = jsonEncode(messages);
    await prefs.setString(widget.sessionId, chatHistory); // Save session-specific chat
  }

  // Send a message: adds the user message, processes it via Wit AI, then shows the response.
  void _sendMessage() async {
    if (_controller.text.trim().isEmpty) return;

    String userMessage = _controller.text.trim();
    _controller.clear();

    setState(() {
      messages.add({"sender": "user", "text": userMessage});
      isLoading = true;
    });
    // Scroll to the bottom after adding the user message.
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());

    try {
      final response = await _witAIService.processMessage(userMessage);
      setState(() {
        messages.add({"sender": "bot", "text": response});
      });
      // Scroll to the bottom after receiving the bot's reply.
      WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
    } catch (error) {
      setState(() {
        messages.add({"sender": "bot", "text": "Sorry, I couldn't process that."});
      });
      WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
    } finally {
      setState(() {
        isLoading = false;
      });
      _saveChatHistory(); // Save chat history after processing the message
    }
  }

  // Start a new chat session.
  // Using Navigator.push adds the new ChatScreen on top of the current one,
  // ensuring that the new chat screen gets its own Scaffold (with an AppBar and a back button).
  void _startNewChat() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String newSessionId = DateTime.now().millisecondsSinceEpoch.toString();

    // Store the previous session's chat history.
    await prefs.setString(widget.sessionId, jsonEncode(messages));

    // Navigate to a new chat session.
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => ChatScreen(sessionId: newSessionId)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Each ChatScreen has its own Scaffold with an AppBar.
      appBar: AppBar(
        backgroundColor: const Color(0xFFF8F13F),
        title: const Text(
          "FixIT",
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
        centerTitle: true,
        // The new chat button is provided in the AppBar's actions.
        actions: [
          IconButton(
            icon: const Icon(Icons.add_comment, color: Colors.white),
            onPressed: _startNewChat,
          ),
        ],
      ),
      body: Column(
        children: [
          // Chat messages list.
          Expanded(
            child: ListView.builder(
              controller: _scrollController, // Attach scroll controller here.
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
          // Loading indicator while processing a message.
          if (isLoading)
            const Padding(
              padding: EdgeInsets.all(8.0),
              child: CircularProgressIndicator(
                color: Color(0xFFEFE516),
              ),
            ),
          // Input field and send button.
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
                        borderSide: const BorderSide(color: Color(0xFFEFE516), width: 2),
                      ),
                    ),
                    onSubmitted: (value) => _sendMessage(),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.send, color: Color(0xFFEFE516)),
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
    final backgroundColor = isUser ? const Color(0xFFEFE516) : Colors.grey[200];
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
