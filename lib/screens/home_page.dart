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

  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();


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
          key: _scaffoldKey,
        drawer: Drawer(
          child: ListView(
            padding: EdgeInsets.zero,
            children: [
              const DrawerHeader(
                decoration: BoxDecoration(
                  color: Colors.yellow,
                ),
                child: Text(
                  'Navigation',
                  style: TextStyle(color: Colors.black, fontSize: 24),
                ),
              ),
              ListTile(
                leading: const Icon(Icons.chat),
                title: Text('chat'.tr()),
                onTap: () {
                  setState(() => _selectedIndex = 0);
                  Navigator.pop(context);
                },
              ),
              ListTile(
                leading: const Icon(Icons.history),
                title: Text('history'.tr()),
                onTap: () {
                  setState(() => _selectedIndex = 1);
                  Navigator.pop(context);
                },
              ),
              ListTile(
                leading: const Icon(Icons.receipt),
                title: Text('bill'.tr()),
                onTap: () {
                  setState(() => _selectedIndex = 2);
                  Navigator.pop(context);
                },
              ),
              ListTile(
                leading: const Icon(Icons.account_circle),
                title: Text('profile'.tr()),
                onTap: () {
                  setState(() => _selectedIndex = 3);
                  Navigator.pop(context);
                },
              ),
              ListTile(
                leading: const Icon(Icons.notifications),
                title: Text('alerts'.tr()),
                onTap: () {
                  setState(() => _selectedIndex = 4);
                  Navigator.pop(context);
                },
              ),
              const Divider(),
              ListTile(
                leading: const Icon(Icons.logout),
                title: const Text('Logout'),
                onTap: signOut,
              ),
            ],
          ),
        ),
        body: SafeArea(
          child: userRole == null
              ? const Center(child: CircularProgressIndicator())
              : _widgetOptions[_selectedIndex],
        ),
        bottomNavigationBar: BottomNavigationBar(
          type: BottomNavigationBarType.fixed,
          currentIndex: _selectedIndex,
          onTap: _onItemTapped,
          selectedItemColor: Colors.yellow[600],
          unselectedItemColor: Colors.grey,
          showUnselectedLabels: true,
          items: _bottomNavItems,
        ),
      ),
    );
  }

}
