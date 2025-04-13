import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'chat_screen.dart';
import 'history_screen.dart';
import 'profile_screen.dart';
import 'manager_notifications_screen.dart';
import 'user_notifications_screen.dart';
import 'bill_screen.dart'; // Import BillScreen
import '../services/auth_service.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _selectedIndex = 0;
  final AuthService _authService = AuthService(Supabase.instance.client);
  String _sessionId = DateTime.now().millisecondsSinceEpoch.toString();
  String? userRole;

  @override
  Future<void> signOut() async {
    try {
      await _authService.signOut();
      if (mounted) {
        Navigator.pushReplacementNamed(context, '/login');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error signing out: $e')),
        );
      }
    }
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  void initState() {
    super.initState();
    _getUserRole();
  }

  // Method to fetch user role from the database
  Future<void> _getUserRole() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user != null) {
      final response = await Supabase.instance.client
          .from('profiles') // Assuming 'users' table holds user data
          .select('role')
          .eq('id', user.id)
          .single();

      if (response != null && response['role'] != null) {
        setState(() {
          userRole = response['role'];
        });

        // Debugging: Log the fetched role
        print('Fetched role: $userRole');
      } else {
        print('❌ Role not found or empty');
      }
    }
  }

  List<Widget> get _widgetOptions {
    // Check the role and load the appropriate screen
    return [
      ChatScreen(sessionId: _sessionId),
      HistoryScreen(),
      BillScreen(),
      const ProfileScreen(),
      // Show appropriate screen based on the user role
      userRole == 'manager' // Check for exact match
          ? ManagerNotificationsScreen()
          : UserNotificationsScreen(),
    ];
  }

  List<BottomNavigationBarItem> get _bottomNavItems {
    return const [
      BottomNavigationBarItem(
        icon: Icon(Icons.chat),
        label: 'Chat',
      ),
      BottomNavigationBarItem(
        icon: Icon(Icons.history),
        label: 'History',
      ),
      BottomNavigationBarItem(
        icon: Icon(Icons.receipt),
        label: 'Bill',
      ),
      BottomNavigationBarItem(
        icon: Icon(Icons.account_circle),
        label: 'Profile',
      ),
      BottomNavigationBarItem(
        icon: Icon(Icons.notifications),
        label: 'Alerts',
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        if (_selectedIndex > 0) {
          setState(() {
            _selectedIndex = 0;
          });
          return false;
        }
        return true;
      },
      child: Scaffold(
        body: SafeArea(
          child: userRole == null
              ? Center(child: CircularProgressIndicator()) // Show loading until the role is fetched
              : _widgetOptions[_selectedIndex],
        ),
        bottomNavigationBar: BottomNavigationBar(
          type: BottomNavigationBarType.fixed,
          currentIndex: _selectedIndex,
          onTap: _onItemTapped,
          selectedItemColor: const Color(0xFFEFE516),
          unselectedItemColor: Colors.grey,
          showUnselectedLabels: true,
          items: _bottomNavItems,
        ),
      ),
    );
  }
}
