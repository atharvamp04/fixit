import 'dart:async';
import 'package:flutter/material.dart';
import 'chat_bubble.dart'; // Import ChatBubble

class AnimatedChatBubble extends StatefulWidget {
  final String text;
  final bool isUser;

  const AnimatedChatBubble({super.key, required this.text, required this.isUser});

  @override
  _AnimatedChatBubbleState createState() => _AnimatedChatBubbleState();
}

class _AnimatedChatBubbleState extends State<AnimatedChatBubble> {
  String _displayText = "";
  int _index = 0;

  @override
  void initState() {
    super.initState();
    _startTypingEffect();
  }

  void _startTypingEffect() {
    Timer.periodic(const Duration(milliseconds: 50), (timer) {
      if (_index < widget.text.length) {
        setState(() {
          _displayText += widget.text[_index];
          _index++;
        });
      } else {
        timer.cancel();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return ChatBubble(text: _displayText, isUser: widget.isUser);
  }
}
