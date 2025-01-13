import 'package:flutter/material.dart';
import 'chat_screen.dart';
import 'history_screen.dart';
import 'account_screen.dart';

class HomePage extends StatefulWidget {
  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _selectedIndex = 0;

  Future<void> signOut() async {
    // Your sign out logic here
    // Redirect to login page after signing out
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  final List<Widget> _widgetOptions = [
    ChatScreen(),
    HistoryScreen(),
    AccountScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Home'),
        actions: [
          IconButton(
            icon: Icon(Icons.logout),
            onPressed: () {
              signOut();
              Navigator.pushReplacementNamed(context, '/');
            },
          ),
        ],
      ),
      body: _widgetOptions.elementAt(_selectedIndex),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
        items: [
          BottomNavigationBarItem(
            icon: Icon(Icons.chat, color: _selectedIndex == 0 ? Color(0xFF17CE92) : Colors.grey),
            label: 'Chat',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.history, color: _selectedIndex == 1 ? Color(0xFF17CE92) : Colors.grey),
            label: 'History',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.account_circle, color: _selectedIndex == 2 ? Color(0xFF17CE92) : Colors.grey),
            label: 'Account',
          ),
        ],
      ),
    );
  }
}
