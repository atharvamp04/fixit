import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'dart:async';
import 'package:flutter_animate/flutter_animate.dart';
import '../services/wit_ai_service.dart';
import '../widgets/product_grid.dart';
import '../widgets/animated_chat_bubble.dart'; // Animated chat bubbles

class ChatScreen extends StatefulWidget {
  final String sessionId;

  const ChatScreen({super.key, required this.sessionId});

  @override
  _ChatScreenState createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _controller = TextEditingController();
  final WitAIService _witAIService = WitAIService();
  List<Map<String, dynamic>> messages = [];
  bool isLoading = false;
  final ScrollController _scrollController = ScrollController();

  final List<String> hintMessages = [
    "Ask me about products...",
    "Check stock availability...",
    "Get product details...",
    "Find the best options...",
    "Type your message..."
  ];
  int hintIndex = 0;
  Timer? _hintTimer;
  bool _isTextFieldActive = false;

  @override
  void initState() {
    super.initState();
    _loadChatHistory();
    _startHintAnimation();
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    _hintTimer?.cancel();
    super.dispose();
  }

  void _startHintAnimation() {
    _hintTimer = Timer.periodic(const Duration(seconds: 3), (timer) {
      if (!_isTextFieldActive && mounted) {
        setState(() {
          hintIndex = (hintIndex + 1) % hintMessages.length;
        });
      }
    });
  }

  void _stopHintAnimation() {
    _hintTimer?.cancel();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _loadChatHistory() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? chatHistory = prefs.getString(widget.sessionId);
    if (chatHistory != null && chatHistory.isNotEmpty) {
      try {
        List<dynamic> jsonData = jsonDecode(chatHistory);
        setState(() {
          messages = jsonData.map<Map<String, dynamic>>((msg) {
            return {
              "sender": msg["sender"],
              "type": msg["type"],
              "data": msg["data"],
            };
          }).toList();
        });
        _scrollToBottom();
      } catch (e) {
        print("Error loading chat history: $e");
      }
    }
  }

  void _saveChatHistory() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String chatHistory = jsonEncode(messages);
    await prefs.setString(widget.sessionId, chatHistory);
  }

  void _sendMessage() async {
    if (_controller.text.trim().isEmpty) return;

    String userMessage = _controller.text.trim();
    _controller.clear();

    setState(() {
      messages.add({"sender": "user", "type": "text", "data": userMessage});
      isLoading = true;
    });

    _scrollToBottom();

    try {
      final response = await _witAIService.processMessage(userMessage);
      setState(() {
        messages.add({
          "sender": "bot",
          "type": response["type"],
          "data": response["type"] == "text" ? response["message"] : response["products"]
        });
      });
      _scrollToBottom();
    } catch (error) {
      setState(() {
        messages.add({"sender": "bot", "type": "text", "data": "Sorry, I couldn't process that."});
      });
      _scrollToBottom();
    } finally {
      setState(() {
        isLoading = false;
      });
      _saveChatHistory();
    }
  }

  void _startNewChat() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String newSessionId = DateTime.now().millisecondsSinceEpoch.toString();
    await prefs.setString(widget.sessionId, jsonEncode(messages));

    if (context.mounted) {
      Navigator.pop(context, newSessionId);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFFF8F13F),
        title: const Text(
          "Chats",
          style: TextStyle(fontSize: 30, fontWeight: FontWeight.w800, color: Colors.white),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_comment, color: Colors.white),
            onPressed: _startNewChat,
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              itemCount: messages.length,
              itemBuilder: (context, index) {
                var msg = messages[index];
                if (msg["type"] == "text") {
                  return AnimatedChatBubble(
                    text: msg["data"] ?? "No content",
                    isUser: msg["sender"] == "user",
                  );
                } else if (msg["type"] == "product") {
                  return ProductGrid(products: msg["data"]);
                } else {
                  return const SizedBox();
                }
              },
            ),
          ),
          if (isLoading)
            const Padding(
              padding: EdgeInsets.all(8.0),
              child: CircularProgressIndicator(color: Color(0xFFEFE516)),
            ),
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: Row(
              children: [
                Expanded(
                  child: Stack(
                    children: [
                      TextField(
                        controller: _controller,
                        style: const TextStyle(fontSize: 16),
                        decoration: InputDecoration(
                          hintText: "", // Hint handled separately
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
                        onChanged: (value) {
                          setState(() {
                            _isTextFieldActive = value.isNotEmpty;
                          });
                          if (_isTextFieldActive) {
                            _stopHintAnimation();
                          } else {
                            _startHintAnimation();
                          }
                        },
                        onTap: () {
                          setState(() {
                            _isTextFieldActive = true;
                          });
                          _stopHintAnimation();
                        },
                        onEditingComplete: () {
                          setState(() {
                            _isTextFieldActive = false;
                          });
                          _startHintAnimation();
                        },
                      ),
                      Positioned(
                        left: 20,
                        top: 15,
                        child: AnimatedSwitcher(
                          duration: const Duration(milliseconds: 500),
                          transitionBuilder: (widget, animation) => FadeTransition(
                            opacity: animation,
                            child: SlideTransition(
                              position: Tween<Offset>(
                                begin: const Offset(0.5, 0),
                                end: Offset.zero,
                              ).animate(animation),
                              child: widget,
                            ),
                          ),
                          child: !_isTextFieldActive
                              ? Text(
                            hintMessages[hintIndex],
                            key: ValueKey(hintMessages[hintIndex]),
                            style: const TextStyle(fontSize: 14, color: Colors.grey),
                          )
                              : const SizedBox(),
                        ),
                      ),
                    ],
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
