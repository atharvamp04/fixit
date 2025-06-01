import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../services/wit_ai_service.dart';
import '../widgets/product_grid.dart';
import '../widgets/animated_chat_bubble.dart';

class ChatScreen extends StatefulWidget {
  final String sessionId;

  const ChatScreen({super.key, required this.sessionId});

  @override
  _ChatScreenState createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  final ScrollController _scrollController = ScrollController();
  final WitAIService _witAIService = WitAIService();

  List<Map<String, dynamic>> messages = [];
  bool isLoading = false;
  int hintIndex = 0;
  Timer? _hintTimer;
  String lastUpdateText = "";

  @override
  void initState() {
    super.initState();
    _loadChatHistory();
    _startHintAnimation();
    _fetchLastUpdate();

    _focusNode.addListener(() {
      setState(() {});
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    _scrollController.dispose();
    _hintTimer?.cancel();
    super.dispose();
  }

  /// Hint message animation
  List<String> _getHintMessages() {
    return [
      "ask_about_products".tr(),
      "check_stock".tr(),
      "get_product_details".tr(),
      "find_best_options".tr(),
      "type_message".tr(),
    ];
  }

  void _startHintAnimation() {
    _hintTimer = Timer.periodic(const Duration(seconds: 3), (timer) {
      if (!_focusNode.hasFocus && mounted) {
        setState(() {
          hintIndex = (hintIndex + 1) % _getHintMessages().length;
        });
      }
    });
  }

  /// Fetch last update time from Supabase
  Future<void> _fetchLastUpdate() async {
    final supabase = Supabase.instance.client;

    try {
      final response = await supabase
          .from('updates')
          .select('updated_at')
          .eq('updated_table', 'products')
          .order('updated_at', ascending: false)
          .limit(1)
          .single();

      if (response != null) {
        DateTime updatedAt = DateTime.parse(response['updated_at']);
        setState(() {
          lastUpdateText = _formatTimeAgo(updatedAt);
        });
      } else {
        setState(() {
          lastUpdateText = "No updates found";
        });
      }
    } catch (e) {
      setState(() {
        lastUpdateText = "Failed to fetch update time";
      });
    }
  }

  String _formatTimeAgo(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inSeconds < 60) {
      return 'Inventory Updated just now';
    } else if (difference.inMinutes < 60) {
      return 'Inventory Updated ${difference.inMinutes} minute${difference.inMinutes == 1 ? '' : 's'} ago';
    } else if (difference.inHours < 24) {
      return 'Inventory Updated ${difference.inHours} hour${difference.inHours == 1 ? '' : 's'} ago';
    } else if (difference.inDays == 1) {
      return 'Inventory Updated yesterday';
    } else {
      return 'Inventory Updated ${difference.inDays} days ago';
    }
  }

  /// Load chat history
  void _loadChatHistory() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? chatHistory = prefs.getString(widget.sessionId);
    if (chatHistory != null && chatHistory.isNotEmpty) {
      try {
        List<dynamic> jsonData = jsonDecode(chatHistory);
        setState(() {
          messages = List<Map<String, dynamic>>.from(jsonData);
        });
        _scrollToBottom();
      } catch (e) {
        print("Error loading chat history: $e");
      }
    }
  }

  /// Save chat history
  void _saveChatHistory() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString(widget.sessionId, jsonEncode(messages));
  }

  /// Scroll to bottom
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

  /// Send message to chatbot
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
          "data": response["type"] == "text"
              ? response["message"]
              : response["products"]
        });
      });
    } catch (error) {
      setState(() {
        messages.add({
          "sender": "bot",
          "type": "text",
          "data": "Sorry, I couldn't process that."
        });
      });
    } finally {
      setState(() => isLoading = false);
      _scrollToBottom();
      _saveChatHistory();
    }
  }

  /// Start a new chat session
  void _startNewChat() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString(widget.sessionId, jsonEncode(messages));
    final newSessionId = DateTime.now().millisecondsSinceEpoch.toString();

    if (Navigator.of(context).canPop()) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => ChatScreen(sessionId: newSessionId),
        ),
      );
    } else {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ChatScreen(sessionId: newSessionId),
        ),
      );
    }
  }

  /// Build UI
  @override
  Widget build(BuildContext context) {
    final hintMessages = _getHintMessages();

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.yellow[600],
        title: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(
              "chat".tr(),
              style: const TextStyle(
                fontSize: 30,
                fontWeight: FontWeight.w800,
                color: Colors.white,
              ),
            ),
            const SizedBox(width: 10),
            if (lastUpdateText.isNotEmpty)
              Text(
                  lastUpdateText,
                style: const TextStyle(
                  fontSize: 12, // Slightly bigger
                  color: Colors.white,
                  fontWeight: FontWeight.w500,
                ),
              ),
          ],
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
                final msg = messages[index];
                if (msg["type"] == "text") {
                  return AnimatedChatBubble(
                    text: msg["data"] ?? "No content",
                    isUser: msg["sender"] == "user",
                  );
                } else if (msg["type"] == "product" && msg["data"] != null) {
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
                  child: TextField(
                    controller: _controller,
                    focusNode: _focusNode,
                    style: const TextStyle(fontSize: 16),
                    decoration: InputDecoration(
                      hintText:
                      _focusNode.hasFocus ? "" : hintMessages[hintIndex],
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 12),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(30),
                        borderSide:
                        const BorderSide(color: Colors.grey, width: 1),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(30),
                        borderSide: const BorderSide(
                            color: Color(0xFFEFE516), width: 2),
                      ),
                    ),
                    onSubmitted: (_) => _sendMessage(),
                  ),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: _sendMessage,
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: Color(0xFFF8F13F),
                    ),
                    child: const Icon(Icons.send, color: Colors.white),
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
