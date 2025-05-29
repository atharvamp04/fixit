import 'dart:typed_data';
import 'package:mailer/mailer.dart';
import 'package:mailer/smtp_server/gmail.dart';

/// Custom MemoryAttachment class to attach binary data via the mailer package.
class MemoryAttachment extends Attachment {
  final String fileName;
  final List<int> data;
  final String mimeType;

  MemoryAttachment({required this.fileName, required this.data, this.mimeType = 'application/pdf'});

  @override
  Stream<List<int>> asStream() {
    // Return the data as a single-event stream.
    return Stream<List<int>>.value(data);
  }

  @override
  Map<String, dynamic> toMap() {
    return {
      'fileName': fileName,
      'mimeType': mimeType,
    };
  }

  @override
  String get contentType => mimeType;
}

class BillEmailService {
  // Hardcoded credentials for demonstration (replace with secure values in production).
  final String username = 'atharvamp04@gmail.com'; // Replace with your email
  final String password = 'xlhu dydw iofd tpkc'; // Replace with your App Password

  BillEmailService();

  /// Sends an invoice email with the PDF attached.
  Future<void> sendInvoiceEmail({
    required String customerEmail,
    required String filename,
    required Uint8List pdfBytes,
  }) async {
    final smtpServer = gmail(username, password);

    // Create an attachment from the PDF bytes.
    final attachment = MemoryAttachment(
      fileName: filename,
      data: pdfBytes,
      mimeType: 'application/pdf',
    );

    final message = Message()
      ..from = Address(username, 'Electrolyte Solutions')
      ..recipients.add(customerEmail)
      ..subject = 'Your Invoice: $filename'
      ..text = 'Please find your invoice attached.'
      ..html = '<p>Please find your invoice attached.</p>'
      ..attachments.add(attachment);

    try {
      final sendReport = await send(message, smtpServer);
      print('Email sent: $sendReport');
    } catch (e) {
      print('Error sending invoice email: $e');
    }
  }
}
