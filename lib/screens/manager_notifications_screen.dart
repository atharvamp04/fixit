import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:Invexa/services/slip_service.dart';
import 'csv_upload_page.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:realtime_client/realtime_client.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:firebase_messaging/firebase_messaging.dart';



class ManagerNotificationsScreen extends StatefulWidget {
  @override
  _ManagerNotificationsScreenState createState() =>
      _ManagerNotificationsScreenState();
}

class _ManagerNotificationsScreenState
    extends State<ManagerNotificationsScreen> {
  List<Map<String, dynamic>> _notifications = [];
  bool _isLoading = true;
  List<Map<String, dynamic>> _requesterAlerts = []; // Store requester alerts

  late RealtimeChannel _notificationChannel;


  @override
  void initState() {
    super.initState();
    _loadNotifications();
    _subscribeToRealtimeNotifications();
    _requestNotificationPermission();
    _initFCM();

  }

  void _initFCM() async {
    // Request permission
    NotificationSettings settings = await FirebaseMessaging.instance.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    if (settings.authorizationStatus == AuthorizationStatus.authorized) {
      print('🔐 Notification permission granted.');

      // 🔑 Get FCM token
      String? token = await FirebaseMessaging.instance.getToken();
      print('📱 Device FCM Token: $token');

      // Optional: Save to Supabase or your backend
      // await Supabase.instance.client
      //     .from('device_tokens')
      //     .insert({'user_id': userId, 'token': token});
    } else {
      print('❌ Notification permission denied.');
    }
  }

  bool isAccepting = false;
  bool isRejecting = false;


  Future<void> _requestNotificationPermission() async {
    final status = await Permission.notification.request();
    debugPrint("🔔 Notification permission: $status");
  }



  String extractProductName(String message) {
    final regex = RegExp(r"Stock low for (.+?)\. Requested");
    final match = regex.firstMatch(message);

    if (match != null && match.groupCount > 0) {
      return match.group(1) ?? '';
    } else {
      return 'Unknown Product';
    }
  }

  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();


  Future<void> _loadNotifications() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) {
      print('❌ No authenticated user');
      setState(() {
        _isLoading = false;
      });
      return;
    }

    final managerId = user.id;
    final notifications = await fetchManagerNotifications(managerId);

    // Fetch requester alerts
    final requesterAlerts = await fetchRequesterAlerts(managerId); // Fetch alerts for the manager

    if (!mounted) return;

    setState(() {
      _notifications = notifications;
      _requesterAlerts = requesterAlerts; // Set requester alerts
      _isLoading = false;
    });
  }

  void _subscribeToRealtimeNotifications() {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;

    final managerId = user.id;

    _notificationChannel = Supabase.instance.client
        .channel('public:notifications')
        .onPostgresChanges(
      event: PostgresChangeEvent.insert,
      schema: 'public',
      table: 'notifications',
      filter: PostgresChangeFilter(
        column: 'manager_id',
        value: 'eq.$managerId',
        type: PostgresChangeFilterType.eq, // 👈 required in latest SDK
      ),
      callback: (payload) {
        print('📥 New notification: ${payload.newRecord}');

        final message = payload.newRecord['message'] ?? 'You have a new request!';

        _showLocalNotification(message); // 🔔 play sound & show
        _loadNotifications(); // Optional: refresh screen
      },
    )
        .subscribe();
  }


  Future<void> _showLocalNotification(String message) async {
    const androidDetails = AndroidNotificationDetails(
      'manager_channel_id',
      'Manager Notifications',
      channelDescription: 'Channel for manager real-time notifications',
      importance: Importance.max,
      priority: Priority.high,
      playSound: true,
    );

    const details = NotificationDetails(android: androidDetails);

    await flutterLocalNotificationsPlugin.show(
      0,
      'New Request',
      message,
      details,
    );
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

  Future<pw.Document> _generatePdf(String productName, String requestedBy) async {
    final pdf = pw.Document();

    final now = DateTime.now();
    final formattedDate = DateFormat('yMMMd • hh:mm a').format(now);

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context context) {
          return pw.Container(
            padding: const pw.EdgeInsets.all(24),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Center(
                  child: pw.Text(
                    'Invexa Courier Confirmation Slip',
                    style: pw.TextStyle(
                      fontSize: 24,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.blue800,
                    ),
                  ),
                ),
                pw.SizedBox(height: 10),
                pw.Divider(thickness: 1.5, color: PdfColors.grey600),
                pw.SizedBox(height: 20),
                pw.Text('Details:',
                    style: pw.TextStyle(
                        fontSize: 18, fontWeight: pw.FontWeight.bold)),
                pw.SizedBox(height: 10),
                _buildRow('Product Name:', productName),
                _buildRow('Requested By:', requestedBy),
                _buildRow('Courier Status:', '✅ Product has been successfully couriered.'),
                _buildRow('Confirmation Date:', formattedDate),
                pw.Spacer(),
                pw.Align(
                  alignment: pw.Alignment.bottomRight,
                  child: pw.Text(
                    'Thank you for using Invexa.',
                    style: pw.TextStyle(
                      fontStyle: pw.FontStyle.italic,
                      fontSize: 12,
                      color: PdfColors.grey600,
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );

    return pdf;
  }

  pw.Widget _buildRow(String label, String value) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 4),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Container(
            width: 130,
            child: pw.Text(
              label,
              style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
            ),
          ),
          pw.Expanded(
            child: pw.Text(value),
          ),
        ],
      ),
    );
  }

  @override
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'My Notifications',
          style: TextStyle(
            color: Colors.white,
            fontSize: 30,
            fontWeight: FontWeight.w800,
          ),
        ),
        backgroundColor: Colors.yellow[600],
        actions: [
          IconButton(
            icon: Icon(Icons.upload_file, color: Colors.white),
            tooltip: 'Upload CSV',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => CsvUploadPage()),
              );
            },
          ),
        ],
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : Column(
        children: [
          Expanded(
            child: _notifications.isEmpty
                ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min, // 👈 important fix
                mainAxisAlignment: MainAxisAlignment.center,
                children: const [
                  Icon(Icons.notifications_off, size: 60, color: Colors.grey),
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
                final createdAtRaw = notification['created_at'];
                final formattedDate = createdAtRaw != null
                    ? DateFormat('MMM d, yyyy • hh:mm a').format(
                    DateTime.tryParse(createdAtRaw.toString()) ?? DateTime.now())
                    : 'Unknown Date';

                final productName = notification['message'] ?? 'No product name';
                final profiles = notification['profiles'];
                final requestedBy = profiles != null && profiles['full_name'] != null
                    ? profiles['full_name']
                    : 'Unknown';
                final requesterEmail = profiles != null && profiles['email'] != null
                    ? profiles['email']
                    : 'Unknown Email';
                final requestedQty =
                    notification['requested_quantity']?.toString() ?? 'N/A';

                if (requestedBy == 'Unknown') return SizedBox.shrink();

                return Dismissible(
                  key: Key(notification['id']),
                  direction: DismissDirection.endToStart,
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
                    elevation: 4,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(productName,
                              style: const TextStyle(
                                  fontSize: 18, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 8),
                          Text("Requested by: $requestedBy",
                              style: TextStyle(fontSize: 14, color: Colors.grey[700])),
                          const SizedBox(height: 4),
                          Text("Requested Qty: $requestedQty",
                              style: TextStyle(fontSize: 14, color: Colors.grey[700])),
                          const SizedBox(height: 16),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              ElevatedButton.icon(
                                onPressed: isAccepting
                                    ? null
                                    : () async {
                                  setState(() => isAccepting = true);

                                  try {
                                    final requesterId = notification['requested_by'];
                                    final mailService = MailService();
                                    final pdf = await _generatePdf(productName, requestedBy);
                                    final pdfBytes = await pdf.save();

                                    await mailService.sendCourierConfirmationSlip(
                                      recipientEmail: requesterEmail,
                                      recipientName: requestedBy,
                                      productName: productName,
                                      pdfBytes: pdfBytes,
                                    );
                                    await sendFcmNotificationToRequester(
                                      recipientId: requesterId,
                                      message: '✅ Your request for "$productName" has been accepted.',
                                    );
                                    await insertInAppNotificationToRequester(
                                      recipientId: requesterId,
                                      message: '✅ Your request for "$productName" has been accepted.',
                                    );

                                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                                      content: Text(
                                          'Request accepted and confirmation slip sent to $requestedBy.'),
                                      backgroundColor: Colors.green,
                                    ));

                                    _markAsRead(notification['id']);
                                  } finally {
                                    setState(() => isAccepting = false);
                                  }
                                },
                                icon: isAccepting
                                    ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    valueColor: AlwaysStoppedAnimation<Color>(Colors.black),
                                    strokeWidth: 2,
                                  ),
                                )
                                    : const Icon(Icons.check_circle, color: Colors.white),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.yellow[600],
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                ),
                                label: Text(
                                  isAccepting ? "Accepting..." : "Accept",
                                  style: const TextStyle(color: Colors.black),
                                ),
                              ),
                              const SizedBox(width: 12),
                              ElevatedButton.icon(
                                onPressed: isRejecting
                                    ? null
                                    : () async {
                                  setState(() => isRejecting = true);

                                  try {
                                    final requesterId = notification['requested_by'];
                                    final mailService = MailService();
                                    await mailService.sendRejectionMail(
                                      recipientEmail: requesterEmail,
                                      recipientName: requestedBy,
                                      productName: productName,
                                    );

                                    await sendFcmNotificationToRequester(
                                      recipientId: requesterId,
                                      message: '❌ Your request for "$productName" has been rejected.',
                                    );

                                    await insertInAppNotificationToRequester(
                                      recipientId: requesterId,
                                      message: '❌ Your request for "$productName" has been rejected.',
                                    );

                                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                                      content:
                                      Text('Request rejected and email sent to $requestedBy.'),
                                      backgroundColor: Colors.red,
                                    ));

                                    _markAsRead(notification['id']);
                                  } finally {
                                    setState(() => isRejecting = false);
                                  }
                                },
                                icon: isRejecting
                                    ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                    strokeWidth: 2,
                                  ),
                                )
                                    : const Icon(Icons.cancel, color: Colors.white),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.red,
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                ),
                                label: Text(
                                  isRejecting ? "Rejecting..." : "Reject",
                                  style: const TextStyle(color: Colors.white),
                                ),
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
          ),
        ],
      ),
    );
  }

}

Future<void> sendFcmNotificationToRequester({
  required String recipientId,
  required String message,
}) async {
  if (recipientId.isEmpty) {
    print('⚠️ recipientId is empty. Skipping FCM.');
    return;
  }

  try {
    final response = await Supabase.instance.client.functions.invoke(
      'send-fcm',
      body: {
        'manager_id': recipientId, // used as ID param in Edge Function
        'message': message,
      },
    );

    if (response.data != null) {
      print('✅ FCM notification sent to requester');
    } else {
      print('❌ FCM send error: $response');
    }
  } catch (e) {
    print('❌ Exception sending FCM: $e');
  }
}


Future<List<Map<String, dynamic>>> fetchManagerNotifications(String managerId) async {
  final result = await Supabase.instance.client
      .from('notifications')
      .select('id, message, created_at, requested_by, requested_quantity, profiles:requested_by(full_name, email)')
      .eq('manager_id', managerId)
      .eq('is_read', false)
      .order('created_at', ascending: false);

  if (result is List) {
    return result.cast<Map<String, dynamic>>();
  } else {
    print('❌ Failed to fetch manager notifications');
    return [];
  }
}


Future<void> insertInAppNotificationToRequester({
  required String recipientId,
  required String message,
}) async {
  if (recipientId.isEmpty) {
    print('⚠️ recipientId is empty. Skipping DB insert.');
    return;
  }

  try {
    final response = await Supabase.instance.client.from('notifications').insert({
      'requested_by': recipientId,
      'message': message,
      'type': 'status-update',
      'is_read': false,
      'created_at': DateTime.now().toIso8601String(),
    });

    print('📩 In-app notification stored: $response');
  } catch (error) {
    print('❌ Error inserting in-app notification: $error');
  }
}


Future<List<Map<String, dynamic>>> fetchRequesterAlerts(String requesterId) async {
  final result = await Supabase.instance.client
      .from('notifications')
      .select('id, message, created_at, is_read')
      .eq('requested_by', requesterId)
      .order('created_at', ascending: false);

  if (result is List) {
    return result.cast<Map<String, dynamic>>();
  } else {
    print('❌ Failed to fetch requester alerts');
    return [];
  }
}
