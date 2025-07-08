import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../screens/download_data.dart';
import '../screens/documents_page.dart';

class AppDrawer extends StatefulWidget {
  const AppDrawer({super.key});

  @override
  State<AppDrawer> createState() => _AppDrawerState();
}

class _AppDrawerState extends State<AppDrawer> {
  String? userRole;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    fetchUserRole();
  }

  Future<void> fetchUserRole() async {
    final supabase = Supabase.instance.client;
    final user = supabase.auth.currentUser;

    if (user != null) {
      final response = await supabase
          .from('profiles')
          .select('role')
          .eq('id', user.id)
          .single();

      if (mounted) {
        setState(() {
          userRole = response['role'] as String?;
          _isLoading = false;
        });
      }
    } else {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
        padding: EdgeInsets.zero,
        children: [
          const DrawerHeader(
            decoration: BoxDecoration(color: Color(0xFFFFEB3B)),
            child: Text(
              'Menu',
              style: TextStyle(fontSize: 24, color: Colors.black),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.home),
            title: const Text('Home'),
            onTap: () {
              Navigator.pop(context);
              Navigator.pushNamed(context, '/home');
            },
          ),
          if (userRole == 'admin') // ✅ Show only for admin
            ListTile(
              leading: const Icon(Icons.download),
              title: const Text('Download Data'),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const DownloadDataScreen()),
                );
              },
            ),
          ListTile(
            leading: const Icon(Icons.folder),
            title: const Text('Documents'),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const DocumentsPage()),
              );
            },
          ),
        ],
      ),
    );
  }
}
