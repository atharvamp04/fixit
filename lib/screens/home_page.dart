import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'chat_screen.dart';
import 'history_screen.dart';
import 'profile_screen.dart';
import 'manager_notifications_screen.dart';
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
  bool isManager = false;

  @override
  void initState() {
    super.initState();
    _checkUserRole();
  }

  Future<void> _checkUserRole() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user != null && user.id.isNotEmpty) {
      final response = await Supabase.instance.client
          .from('profiles')
          .select('role')
          .eq('id', user.id)
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

  List<Widget> get _widgetOptions {
    final basePages = [
      ChatScreen(sessionId: _sessionId),
      HistoryScreen(),
      BillScreen(),
      const ProfileScreen(),
    ];
    if (isManager) {
      basePages.add(ManagerNotificationsScreen());
    }
    return basePages;
  }

  List<BottomNavigationBarItem> get _bottomNavItems {
    final baseItems = const [
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
    ];
    if (isManager) {
      return [
        ...baseItems,
        const BottomNavigationBarItem(
          icon: Icon(Icons.notifications),
          label: 'Alerts',
        ),
      ];
    }
    return baseItems;
  }

  List<String> get _appBarTitles {
    final titles = ['Chat', 'History', 'Bill', 'Profile'];
    if (isManager) {
      titles.add('Notifications');
    }
    return titles;
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
        // Removed AppBar completely
        body: SafeArea(
          child: _widgetOptions[_selectedIndex],
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
