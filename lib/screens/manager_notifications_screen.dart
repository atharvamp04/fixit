import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:fixit/services/slip_service.dart';

class ManagerNotificationsScreen extends StatefulWidget {
  @override
  _ManagerNotificationsScreenState createState() =>
      _ManagerNotificationsScreenState();
}

class _ManagerNotificationsScreenState
    extends State<ManagerNotificationsScreen> {
  List<Map<String, dynamic>> _notifications = [];
  bool _isLoading = true;
  List<Map<String, dynamic>> _requesterAlerts = [];  // Store requester alerts

  @override
  void initState() {
    super.initState();
    _loadNotifications();
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
    final requesterAlerts = await fetchRequesterAlerts(managerId);  // Fetch alerts for the manager

    if (!mounted) return;

    setState(() {
      _notifications = notifications;
      _requesterAlerts = requesterAlerts;  // Set requester alerts
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
                    'FixIt Courier Confirmation Slip',
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
                pw.Text('Details:', style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
                pw.SizedBox(height: 10),
                _buildRow('Product Name:', productName),
                _buildRow('Requested By:', requestedBy),
                _buildRow('Courier Status:', '✅ Product has been successfully couriered.'),
                _buildRow('Confirmation Date:', formattedDate),
                pw.Spacer(),
                pw.Align(
                  alignment: pw.Alignment.bottomRight,
                  child: pw.Text(
                    'Thank you for using FixIt.',
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
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('My Notifications',style: TextStyle(color: Colors.white, fontSize: 30, fontWeight: FontWeight.w800),),
        backgroundColor: const Color(0xFFF8F13F),),
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

          final createdAtRaw = notification['created_at'];
          final formattedDate = createdAtRaw != null
              ? DateFormat('MMM d, yyyy • hh:mm a')
              .format(DateTime.tryParse(createdAtRaw.toString()) ??
              DateTime.now())
              : 'Unknown Date';

          final productName =
              notification['message'] ?? 'No product name';

          final profiles = notification['profiles'];
          final requestedBy = profiles != null &&
              profiles['full_name'] != null
              ? profiles['full_name']
              : 'Unknown';
          final requesterEmail = profiles != null &&
              profiles['email'] != null
              ? profiles['email']
              : 'Unknown Email';

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
              margin:
              EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              elevation: 3,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(productName,
                        style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold)),
                    SizedBox(height: 5),
                    if (requestedBy.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 4.0),
                        child: Text(
                          'Requested by: $requestedBy',
                          style: TextStyle(
                              color: Colors.grey[700],
                              fontStyle: FontStyle.italic),
                        ),
                      ),
                    SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        ElevatedButton(
                          onPressed: () async {
                            final notification = _notifications[index];
                            final requesterEmail = notification['profiles']?['email'] ?? 'Unknown Email';
                            final requestedBy = (notification['profiles']?['full_name'] ?? 'Unknown').trim();
                            final productName = notification['message'] ?? 'No product name';
                            final requesterId = notification['requested_by'];

                            // Send email
                            final mailService = MailService();
                            final pdf = await _generatePdf(productName, requestedBy);
                            final pdfBytes = await pdf.save();

                            await mailService.sendCourierConfirmationSlip(
                              recipientEmail: requesterEmail,
                              recipientName: requestedBy,
                              productName: productName,
                              pdfBytes: pdfBytes,
                            );

                            // Send in-app notification to requester
                            await sendNotificationToRequester(
                              recipientId: requesterId,
                              message: '✅ Your request for "$productName" has been accepted and couriered.',
                            );

                            // Mark as read for manager
                            _markAsRead(notification['id']);
                          },
                          style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                          child: Text('Accept'),
                        ),

                        SizedBox(width: 10),

                        ElevatedButton(
                          onPressed: () async {
                            final notification = _notifications[index];
                            final requesterEmail = notification['profiles']?['email'] ?? 'Unknown Email';
                            final requestedBy = (notification['profiles']?['full_name'] ?? 'Unknown').trim();
                            final productName = notification['message'] ?? 'No product name';
                            final requesterId = notification['requested_by'];

                            // Send rejection email
                            final mailService = MailService();
                            await mailService.sendRejectionMail(
                              recipientEmail: requesterEmail,
                              recipientName: requestedBy,
                              productName: productName,
                            );

                            // Send in-app rejection notification
                            await sendNotificationToRequester(
                              recipientId: requesterId,
                              message: '❌ Your request for "$productName" has been rejected by the manager.',
                            );

                            // Mark as read
                            _markAsRead(notification['id']);
                          },
                          style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
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
      .select(
      'id, message, created_at, requested_by, profiles:requested_by(full_name, email)')
      .eq('manager_id', managerId)
      .eq('is_read', false)
      .order('created_at', ascending: false);

  if (result is List) {
    return result.cast<Map<String, dynamic>>();
  } else {
    print('❌ Failed to fetch notifications');
    return [];
  }
}

Future<void> sendNotificationToRequester({
  required String recipientId,
  required String message,
}) async {
  if (recipientId.isEmpty) {
    print('⚠️ recipientId is empty. Skipping insertion.');
    return;
  }

  try {
    final response = await Supabase.instance.client.from('notifications').insert({
      'requested_by': recipientId,
      'message': message,
      'type': 'status-update',
    });

    print('📩 In-app notification sent to $recipientId: $response');
  } catch (error) {
    print('❌ Error sending notification: $error');
  }
}


Future<List<Map<String, dynamic>>> fetchRequesterAlerts(String requesterId) async {
  final supabase = Supabase.instance.client;

  final result = await supabase
      .from('notifications')
      .select('id, message, created_at')
      .eq('requested_by', requesterId)
      .eq('type', 'status-update') // ✅ filter only status-update notifications
      .order('created_at', ascending: false);

  if (result is List) {
    return result.cast<Map<String, dynamic>>();
  } else {
    print('❌ Failed to fetch requester alerts');
    return [];
  }
}
