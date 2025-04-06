import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';

class ManagerNotificationsScreen extends StatefulWidget {
  @override
  _ManagerNotificationsScreenState createState() =>
      _ManagerNotificationsScreenState();
}

class _ManagerNotificationsScreenState
    extends State<ManagerNotificationsScreen> {
  List<Map<String, dynamic>> _notifications = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadNotifications();
  }

  Future<void> _loadNotifications() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) {
      print('❌ No authenticated user');
      setState(() {
        _isLoading = false;
      });
      return;
    }

    final managerId = user.id; // UUID of the manager
    final notifications = await fetchManagerNotifications(managerId);

    if (!mounted) return;

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
      _notifications
          .removeWhere((notification) => notification['id'] == notificationId);
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
            Icon(Icons.notifications_off,
                size: 60, color: Colors.grey),
            SizedBox(height: 10),
            Text('No new notifications',
                style: TextStyle(fontSize: 18, color: Colors.grey)),
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
            direction: DismissDirection.endToStart,
            background: Container(
              alignment: Alignment.centerRight,
              padding: EdgeInsets.symmetric(horizontal: 20),
              color: Colors.green,
              child:
              Icon(Icons.check, color: Colors.white, size: 30),
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
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      notification['message'],
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    SizedBox(height: 5),
                    Text(formattedDate, style: TextStyle(color: Colors.grey[600])),
                    if (notification['requested_by']?['full_name'] != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 4.0),
                        child: Text(
                          'Requested by: ${notification['requested_by']['full_name']}',
                          style: TextStyle(
                              color: Colors.grey[700], fontStyle: FontStyle.italic),
                        ),
                      ),
                    SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        ElevatedButton(
                          onPressed: () {
                            // Accept button pressed (no functionality yet)
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                          ),
                          child: Text('Accept'),
                        ),
                        SizedBox(width: 10),
                        ElevatedButton(
                          onPressed: () {
                            // Reject button pressed (no functionality yet)
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red,
                          ),
                          child: Text('Reject'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

          );
        },
      ),
    );
  }
}

Future<List<Map<String, dynamic>>> fetchManagerNotifications(
    String managerId) async {
  final supabase = Supabase.instance.client;

  final result = await supabase
      .from('notifications')
      .select('id, message, created_at, requested_by(full_name)')
      .eq('manager_id', managerId)
      .eq('is_read', false) // Optional: only unread notifications
      .order('created_at', ascending: false); // Optional: latest first

  if (result is List) {
    return result.cast<Map<String, dynamic>>();
  } else {
    print('❌ Failed to fetch notifications');
    return [];
  }
}
