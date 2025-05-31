import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'package:easy_localization/easy_localization.dart'; // Add Easy Localization import

class UserNotificationsScreen extends StatefulWidget {
  @override
  _UserNotificationsScreenState createState() =>
      _UserNotificationsScreenState();
}

class _UserNotificationsScreenState extends State<UserNotificationsScreen> {
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

    final requesterId = user.id;
    final notifications = await fetchRequesterAlerts(requesterId);

    if (!mounted) return;

    setState(() {
      _notifications = notifications;
      _isLoading = false;
    });
  }

  Future<List<Map<String, dynamic>>> fetchRequesterAlerts(String requesterId) async {
    final supabase = Supabase.instance.client;

    final result = await supabase
        .from('notifications')
        .select('id, message, created_at')
        .eq('requested_by', requesterId) // Filter notifications for the logged-in user
        .eq('type', 'status-update') // Filter only "status-update" type notifications
        .order('created_at', ascending: false); // Order by the most recent notification

    if (result is List) {
      return result.cast<Map<String, dynamic>>(); // Cast the result to List<Map<String, dynamic>>
    } else {
      print('❌ Failed to fetch requester alerts');
      return [];
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          tr('my_notifications'), // Use localized text here
          style: TextStyle(
            color: Colors.white,
            fontSize: 30,
            fontWeight: FontWeight.w800,
          ),
        ),
        backgroundColor: Colors.yellow[600],
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : _notifications.isEmpty
          ? Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.notifications_off, size: 60, color: Colors.grey),
            SizedBox(height: 10),
            Text(
              tr('no_notifications'), // Use localized text here
              style: TextStyle(fontSize: 18, color: Colors.grey),
            ),
          ],
        ),
      )
          : ListView.builder(
        itemCount: _notifications.length,
        itemBuilder: (context, index) {
          final notification = _notifications[index];

          final createdAtRaw = notification['created_at'];
          final message = notification['message'] ?? 'No message';

          return Card(
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
                  Text(message, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  SizedBox(height: 5),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
