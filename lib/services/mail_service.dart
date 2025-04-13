import 'package:mailer/mailer.dart';
import 'package:mailer/smtp_server.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class MailService {
  final SupabaseClient supabase = Supabase.instance.client;

  // ⚠️ Do not hardcode credentials in production
  final String username = 'atharvamp04@gmail.com';
  final String password = 'qyim tslj tqjy clyr'; // App password

  Future<void> sendStockRequestEmail({
    required String managerEmail,
    required String productName,
    required int stock,
  }) async {
    try {
      // Step 1: Get authenticated user
      final user = supabase.auth.currentUser;
      if (user == null) {
        print('❌ Error: No authenticated user found');
        return;
      }

      final String userId = user.id;
      print('🔍 Debug: Authenticated User UUID -> $userId');

      // Step 2: Fetch full name from 'profiles' table
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

      // Step 3: Prepare and send email
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

      // Step 4: Get manager's UUID from profiles using email
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

      // Step 5: Insert notification
      await supabase.from('notifications').insert({
        'manager_id': managerId,
        'message': '$productName.',
        'requested_by': userId,
        'is_read': false,
      });

      print('✅ Notification inserted into Supabase');
    } catch (e) {
      print('❌ Error in sendStockRequestEmail: $e');
    }
  }
}
