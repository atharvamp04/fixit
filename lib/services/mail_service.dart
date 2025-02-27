import 'package:mailer/mailer.dart';
import 'package:mailer/smtp_server.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class MailService {
  final SupabaseClient supabase = Supabase.instance.client;

  // Hardcoded email credentials (⚠️ Not recommended for production)
  final String username = 'atharvamp04@gmail.com'; // Replace with your email
  final String password = 'qyim tslj tqjy clyr'; // Replace with your App Password

  Future<void> sendStockRequestEmail({
    required String managerEmail,
    required String productName,
    required int stock,
  }) async {
    try {
      // Fetch the currently authenticated user
      final user = supabase.auth.currentUser;

      if (user == null) {
        print('❌ Error: No authenticated user found');
        return;
      }

      final String userId = user.id; // Get the authenticated user's UUID
      print('🔍 Debug: Authenticated User UUID -> $userId');

      // Validate UUID format
      if (userId.isEmpty || userId.length != 36) {
        print('❌ Error: Invalid UUID format for userId');
        return;
      }

      // Fetch full name from Supabase profiles table
      final response = await supabase
          .from('profiles')
          .select('full_name')
          .eq('id', userId)
          .single();

      if (response == null) {
        print('❌ Error: User profile not found');
        return;
      }

      String senderName = response['full_name'] ?? 'User';

      final smtpServer = gmail(username, password);

      final message = Message()
        ..from = Address(username, 'FixIT Stock Manager')
        ..recipients.add(managerEmail)
        ..subject = '🔔 Stock Request: $productName Needed'
        ..text = '''
Dear Manager,

The stock for "$productName" is currently low. Only $stock units are left.

I would like to request 1 additional unit of this product.

Please restock it as soon as possible.

Best regards,
$senderName
'''.trim()
        ..html = '''
<h3>📢 Stock Request: <span style="color:#ff6600;">$productName</span></h3>
<p><b>Current Stock:</b> $stock units remaining</p>
<p><b>Requested Quantity:</b> 1 unit</p>
<p>Dear Manager,</p>
<p>I need <b>1</b> more unit of <b>$productName</b>. Please arrange the stock at the earliest.</p>
<p>Best Regards,</p>
<p><b>$senderName</b></p>
''';

      final sendReport = await send(message, smtpServer);
      print('✅ Email sent successfully: ${sendReport.toString()}');
    } catch (e) {
      print('❌ Error sending email: $e');
    }
  }
}
