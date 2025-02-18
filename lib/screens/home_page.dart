import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'chat_screen.dart';
import 'history_screen.dart';
import 'profile_screen.dart';
import '../services/auth_service.dart'; // Assuming AuthService is imported from your services directory

class HomePage extends StatefulWidget {
  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _selectedIndex = 0;

  // AuthService instance
  final AuthService _authService = AuthService(Supabase.instance.client);

  Future<void> signOut() async {
    try {
      await _authService.signOut();
      Navigator.pushReplacementNamed(context, '/login');
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error signing out: $e')));
    }
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  // List of screens
  final List<Widget> _widgetOptions = [
    ChatScreen(sessionId: ''),
    HistoryScreen(),
    ProfileScreen(),
  ];

  // List of titles for the AppBar
  final List<String> _appBarTitles = [
    'Chat',
    'History',
    'Profile',
  ];

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        if (_selectedIndex > 0) {
          setState(() {
            _selectedIndex = 0; // Navigate back to Chat screen
          });
          return false; // Prevent app from closing
        }
        return true; // Allow default behavior (exit app)
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(_appBarTitles[_selectedIndex]), // Dynamic title
          leading: _selectedIndex == 0
              ? null // Hide back button on Chat screen
              : IconButton(
            icon: Icon(Icons.arrow_back),
            onPressed: () {
              setState(() {
                _selectedIndex = 0; // Navigate back to Chat
              });
            },
          ),
          actions: [
            IconButton(
              icon: Icon(Icons.logout),
              onPressed: signOut,
            ),
          ],
        ),
        body: _widgetOptions[_selectedIndex],
        bottomNavigationBar: BottomNavigationBar(
          currentIndex: _selectedIndex,
          onTap: _onItemTapped,
          items: [
            BottomNavigationBarItem(
              icon: Icon(Icons.chat),
              label: 'Chat',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.history),
              label: 'History',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.account_circle),
              label: 'Profile',
            ),
          ],
        ),
      ),
    );
  }
}
