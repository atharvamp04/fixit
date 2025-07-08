import 'package:flutter/material.dart';
import '../widgets/drawer_appbar.dart';
import '../widgets/drawer_top_appbar.dart'; // If used elsewhere

class CommonLayout extends StatelessWidget {
  final Widget body;
  final String title;
  final GlobalKey<ScaffoldState> scaffoldKey;
  final int selectedIndex;
  final void Function(int) onItemTapped;

  const CommonLayout({
    super.key,
    required this.body,
    required this.title,
    required this.scaffoldKey,
    required this.selectedIndex,
    required this.onItemTapped,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: scaffoldKey,
      appBar: DrawerAppBar(
        scaffoldKey: scaffoldKey,
        title: Text(
          title,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      drawer: const AppDrawer(), // Make sure this file exists at widgets/app_drawer.dart
      body: body,
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: selectedIndex,
        onTap: onItemTapped,
        selectedItemColor: Colors.yellow[700],
        unselectedItemColor: Colors.grey,
        type: BottomNavigationBarType.fixed,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.chat), label: 'Chat'),
          BottomNavigationBarItem(icon: Icon(Icons.history), label: 'History'),
          BottomNavigationBarItem(icon: Icon(Icons.receipt), label: 'Bills'),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profile'),
          BottomNavigationBarItem(icon: Icon(Icons.notifications), label: 'Alerts'),
        ],
      ),
    );
  }
}
