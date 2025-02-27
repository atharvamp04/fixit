import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'chat_screen.dart';
import 'history_screen.dart';
import 'profile_screen.dart';
import 'manager_notifications_screen.dart'; // Import ManagerNotificationsScreen
import '../services/auth_service.dart'; // AuthService import

class HomePage extends StatefulWidget {
  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _selectedIndex = 0;
  final AuthService _authService = AuthService(Supabase.instance.client);
  String _sessionId = DateTime.now().millisecondsSinceEpoch.toString();
  bool isManager = false; // Flag to check if user is a manager

  @override
  void initState() {
    super.initState();
    _checkUserRole();
  }

  Future<void> _checkUserRole() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user != null && user.id != null) {
      final response = await Supabase.instance.client
          .from('profiles') // Adjust table name based on your database
          .select('role')
          .eq('id', user.id!) // Ensure user.id is not null
          .single();

      if (response != null && response['role'] == 'manager') {
        setState(() {
          isManager = true;
        });
      }
    }
  }

  Future<void> signOut() async {
    try {
      await _authService.signOut();
      Navigator.pushReplacementNamed(context, '/login');
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error signing out: $e')),
      );
    }
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  List<Widget> get _widgetOptions => [
    ChatScreen(sessionId: _sessionId),
    HistoryScreen(),
    ProfileScreen(),
  ];

  final List<String> _appBarTitles = ['Chat', 'History', 'Profile'];

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        if (_selectedIndex > 0) {
          setState(() {
            _selectedIndex = 0; // Navigate back to Chat screen
          });
          return false;
        }
        return true;
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(_appBarTitles[_selectedIndex]),
          actions: [
            if (isManager) // Show only if user is a manager
              IconButton(
                icon: const Icon(Icons.notifications),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => ManagerNotificationsScreen(),
                    ),
                  );
                },
              ),
          ],
        ),
        body: _widgetOptions[_selectedIndex],
        bottomNavigationBar: BottomNavigationBar(
          currentIndex: _selectedIndex,
          onTap: _onItemTapped,
          selectedItemColor: Color(0xFFEFE516),
          unselectedItemColor: Colors.grey,
          showUnselectedLabels: true,
          items: const [
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
