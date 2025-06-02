import 'package:mailer/mailer.dart';
import 'package:mailer/smtp_server.dart';
import 'dart:typed_data';

class MailService {
  // Method to send the courier confirmation slip (accept)
  Future<void> sendCourierConfirmationSlip({
    required String recipientEmail,
    required String recipientName,
    required String productName,
    required Uint8List pdfBytes,
  }) async {
    final smtpServer = gmail(
      'electrolytesolninvoice@gmail.com',
      'levz csbw hyfw rudl', // Use Gmail App Password
    );

    final message = Message()
      ..from = Address('electrolytesolninvoice@gmail.com', 'fixit Courier')
      ..recipients.add(recipientEmail)
      ..subject = 'Courier Confirmation Slip for $productName'
      ..text = 'Hi $recipientName,\n\nYour product "$productName" has been couriered.'
      ..attachments = [
        StreamAttachment(
          Stream.fromIterable([pdfBytes]),
          'application/pdf',
          fileName: 'confirmation_slip.pdf',
        ),
      ];

    try {
      final sendReport = await send(message, smtpServer);
      print('✅ Email sent: $sendReport');
    } catch (e) {
      print('❌ Email sending failed: $e');
    }
  }

  // Method to send the rejection email (plain text)
  Future<void> sendRejectionMail({
    required String recipientEmail,
    required String recipientName,
    required String productName,
  }) async {
    final smtpServer = gmail(
      'electrolytesolninvoice@gmail.com',
      'levz csbw hyfw rudl', // Use Gmail App Password
    );

    final subject = 'Product Courier Request Rejected';
    final body = '''
Dear $recipientName,

We regret to inform you that your product "$productName" courier request has been rejected. Please contact the manager for further assistance.

Thank you for your understanding.

Best regards,
The fixit Team
    ''';

    final message = Message()
      ..from = Address('electrolytesolninvoice@gmail.com', 'fixit Courier')
      ..recipients.add(recipientEmail)
      ..subject = subject
      ..text = body;

    try {
      final sendReport = await send(message, smtpServer);
      print('✅ Rejection email sent: $sendReport');
    } catch (e) {
      print('❌ Email sending failed: $e');
    }
  }
}