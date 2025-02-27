import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';

class ManagerNotificationsScreen extends StatefulWidget {
  @override
  _ManagerNotificationsScreenState createState() => _ManagerNotificationsScreenState();
}

class _ManagerNotificationsScreenState extends State<ManagerNotificationsScreen> {
  List<Map<String, dynamic>> _notifications = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadNotifications();
  }

  Future<void> _loadNotifications() async {
    final notifications = await fetchManagerNotifications();
    setState(() {
      _notifications = notifications;
      _isLoading = false;
    });
  }

  Future<void> _markAsRead(String notificationId) async {
    await Supabase.instance.client
        .from('notifications')
        .update({'is_read': true})
        .eq('id', notificationId);

    setState(() {
      _notifications.removeWhere((notification) => notification['id'] == notificationId);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Notifications')),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : _notifications.isEmpty
          ? Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.notifications_off, size: 60, color: Colors.grey),
            SizedBox(height: 10),
            Text('No new notifications', style: TextStyle(fontSize: 18, color: Colors.grey)),
          ],
        ),
      )
          : ListView.builder(
        itemCount: _notifications.length,
        itemBuilder: (context, index) {
          final notification = _notifications[index];
          final formattedDate = DateFormat('MMM d, yyyy • hh:mm a')
              .format(DateTime.parse(notification['created_at']));

          return Dismissible(
            key: Key(notification['id']),
            direction: DismissDirection.endToStart, // Swipe left to dismiss
            background: Container(
              alignment: Alignment.centerRight,
              padding: EdgeInsets.symmetric(horizontal: 20),
              color: Colors.green,
              child: Icon(Icons.check, color: Colors.white, size: 30),
            ),
            onDismissed: (direction) {
              _markAsRead(notification['id']);
            },
            child: Card(
              margin: EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              elevation: 3,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              child: ListTile(
                contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                title: Text(notification['message'], style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                subtitle: Text(formattedDate, style: TextStyle(color: Colors.grey[600])),
                leading: Icon(Icons.notifications, color: Color(0xFFEFE516)),
                trailing: IconButton(
                  icon: Icon(Icons.check, color: Colors.green),
                  onPressed: () => _markAsRead(notification['id']),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

Future<List<Map<String, dynamic>>> fetchManagerNotifications() async {
  final user = Supabase.instance.client.auth.currentUser;
  if (user == null) return [];

  final response = await Supabase.instance.client
      .from('notifications')
      .select('*')
      .eq('manager_id', user.id)
      .eq('is_read', false)
      .order('created_at', ascending: false);

  return response;
}
