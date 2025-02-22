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

  String _sessionId = DateTime.now().millisecondsSinceEpoch.toString();

  List<Widget> get _widgetOptions => [
    ChatScreen(sessionId: _sessionId),
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
        body: _widgetOptions[_selectedIndex],
        bottomNavigationBar: BottomNavigationBar(
          currentIndex: _selectedIndex,
          onTap: _onItemTapped,
          selectedItemColor: Color(0xFFEFE516), // Color for selected item
          unselectedItemColor: Colors.grey, // Grey for unselected items
          showUnselectedLabels: true,
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
