import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart'; // 👈 Add this import
import 'package:supabase_flutter/supabase_flutter.dart';
import 'chat_screen.dart';
import 'history_screen.dart';
import 'profile_screen.dart';
import 'manager_notifications_screen.dart';
import 'user_notifications_screen.dart';
import 'bill_screen.dart';
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
          SnackBar(content: Text('error_signing_out'.tr(args: [e.toString()]))),
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

  Future<void> _getUserRole() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user != null) {
      final response = await Supabase.instance.client
          .from('profiles')
          .select('role')
          .eq('id', user.id)
          .single();

      if (response != null && response['role'] != null) {
        setState(() {
          userRole = response['role'];
        });
        print('Fetched role: $userRole');
      } else {
        print('❌ Role not found or empty');
      }
    }
  }

  List<Widget> get _widgetOptions {
    return [
      ChatScreen(sessionId: _sessionId),
      HistoryScreen(),
      BillScreen(),
      const ProfileScreen(),
      userRole == 'manager'
          ? ManagerNotificationsScreen()
          : UserNotificationsScreen(),
    ];
  }

  List<BottomNavigationBarItem> get _bottomNavItems {
    return [
      BottomNavigationBarItem(
        icon: const Icon(Icons.chat),
        label: 'chat'.tr(),
      ),
      BottomNavigationBarItem(
        icon: const Icon(Icons.history),
        label: 'history'.tr(),
      ),
      BottomNavigationBarItem(
        icon: const Icon(Icons.receipt),
        label: 'bill'.tr(),
      ),
      BottomNavigationBarItem(
        icon: const Icon(Icons.account_circle),
        label: 'profile'.tr(),
      ),
      BottomNavigationBarItem(
        icon: const Icon(Icons.notifications),
        label: 'alerts'.tr(),
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
              ? const Center(child: CircularProgressIndicator())
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
