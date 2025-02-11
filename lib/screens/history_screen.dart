import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'chat_screen.dart';

class HistoryScreen extends StatefulWidget {
  @override
  _HistoryScreenState createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  List<Map<String, String>> sessions = [];

  @override
  void initState() {
    super.initState();
    _loadSessions();
  }

  Future<void> _loadSessions() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    List<Map<String, String>> loadedSessions = [];

    for (String sessionId in prefs.getKeys()) {
      String? chatHistoryJson = prefs.getString(sessionId);

      if (chatHistoryJson != null && chatHistoryJson.isNotEmpty) {
        try {
          List<dynamic> messages = jsonDecode(chatHistoryJson);

          // Ensure messages is a list and has at least one entry
          if (messages.isNotEmpty && messages is List) {
            // Find the first user message
            var firstUserMessage = messages.firstWhere(
                  (msg) => msg is Map<String, dynamic> && msg["sender"] == "user",
              orElse: () => {"text": "No user messages"},
            );

            String firstQuery = firstUserMessage["text"] ?? "No user messages";

            loadedSessions.add({
              "sessionId": sessionId,
              "firstQuery": firstQuery,
            });
          }
        } catch (e) {
          print("Error parsing session $sessionId: $e");
        }
      }
    }

    setState(() {
      sessions = loadedSessions;
    });
  }

  void _createNewSession() async {
    String sessionId = DateTime.now().millisecondsSinceEpoch.toString();
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => ChatScreen(sessionId: sessionId)),
    ).then((_) => _loadSessions());
  }

  void _openSession(String sessionId) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => ChatScreen(sessionId: sessionId)),
    );
  }

  Future<void> _clearAllSessions() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    for (var session in sessions) {
      await prefs.remove(session["sessionId"]!);
    }

    setState(() {
      sessions.clear();
    });

    print("All sessions cleared");
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Color(0xFF17CE92),
        title: Text("Chat History", style: TextStyle(color: Colors.white)),
        centerTitle: true,
        actions: [
          IconButton(
            icon: Icon(Icons.delete, color: Colors.white),
            onPressed: _clearAllSessions,
          ),
        ],
      ),
      body: sessions.isEmpty
          ? Center(child: Text("No chat history available"))
          : ListView.builder(
        padding: EdgeInsets.all(16),
        itemCount: sessions.length,
        itemBuilder: (context, index) {
          return Card(
            elevation: 4, // Adds a shadow effect
            margin: EdgeInsets.symmetric(vertical: 8),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: ListTile(
              contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              leading: CircleAvatar(
                backgroundColor: Color(0xFF17CE92),
                child: Icon(Icons.chat, color: Colors.white),
              ),
              title: Text(
                "Chat ${index + 1}",
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              subtitle: Text(
                sessions[index]["firstQuery"] ?? "No messages",
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              trailing: Icon(Icons.arrow_forward_ios, color: Colors.grey),
              onTap: () => _openSession(sessions[index]["sessionId"]!),
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: Color(0xFF17CE92),
        onPressed: _createNewSession,
        child: Icon(Icons.add, color: Colors.white),
      ),
    );
  }

}
