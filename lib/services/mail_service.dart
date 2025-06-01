import 'package:mailer/mailer.dart';
import 'package:mailer/smtp_server.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class MailService {
  final SupabaseClient supabase = Supabase.instance.client;

  // ⚠️ Do not hardcode credentials in production
  final String username = 'atharvamp04@gmail.com';
  final String password = 'xlhu dydw iofd tpkc'; // App password

  Future<void> sendStockRequestEmail({
    required String managerEmail,
    required String productName,
    required int stock,
    required int quantity,
  }) async {
    try {
      final user = supabase.auth.currentUser;
      if (user == null) {
        print('❌ Error: No authenticated user found');
        return;
      }

      final String userId = user.id;
      final profileResponse = await supabase
          .from('profiles')
          .select('full_name')
          .eq('id', userId)
          .single();

      if (profileResponse == null) {
        print('❌ Error: User profile not found');
        return;
      }

      String senderName = profileResponse['full_name'] ?? 'User';

      final smtpServer = gmail(username, password);
      final message = Message()
        ..from = Address(username, 'fixit Stock Manager')
        ..recipients.add(managerEmail)
        ..subject = '🔔 Stock Request: $productName Needed'
        ..text = '''
Dear Manager,

The stock for "$productName" is currently low. Only $stock units are left.

I would like to request $quantity additional unit(s) of this product.

Please restock it as soon as possible.

Best regards,
$senderName
'''.trim()
        ..html = '''
<h3>📢 Stock Request: <span style="color:#ff6600;">$productName</span></h3>
<p><b>Current Stock:</b> $stock units remaining</p>
<p><b>Requested Quantity:</b> $quantity unit(s)</p>
<p>Dear Manager,</p>
<p>I need <b>$quantity</b> more unit(s) of <b>$productName</b>. Please arrange the stock at the earliest.</p>
<p>Best Regards,</p>
<p><b>$senderName</b></p>
''';

      final sendReport = await send(message, smtpServer);
      print('✅ Email sent successfully: ${sendReport.toString()}');

      final managerProfile = await supabase
          .from('profiles')
          .select('id')
          .eq('email', managerEmail)
          .single();

      if (managerProfile == null) {
        print('❌ Error: Manager profile not found for $managerEmail');
        return;
      }

      final String managerId = managerProfile['id'];

      // Insert notification with requested quantity as separate field
      await supabase.from('notifications').insert({
        'manager_id': managerId,
        'message': 'Stock Request for "$productName"',
        'requested_by': userId,
        'requested_quantity': quantity,  // Here!
        'is_read': false,
      });

      print('✅ Notification inserted into Supabase');
    } catch (e) {
      print('❌ Error in sendStockRequestEmail: $e');
    }
  }

}
