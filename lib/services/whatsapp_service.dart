import 'package:url_launcher/url_launcher.dart';

class WhatsAppService {
  static Future<bool> sendPendingBalanceReminder({
    required String phone,
    required String customerName,
    required double pendingBalance,
    required String restaurantName,
  }) async {
    // Sanitize phone number
    String cleanPhone = phone.replaceAll(RegExp(r'\D'), '');
    if (!cleanPhone.startsWith('91') && cleanPhone.length == 10) {
      cleanPhone = '91$cleanPhone';
    }

    final message = '''
Namaste $customerName,

Greetings from *$restaurantName*.

This is a gentle reminder regarding your pending dining account balance of *₹${pendingBalance.toStringAsFixed(2)}*.

You may clear this via UPI or Cash at the counter.
If you have any queries or need your detailed account statement, please let us know.

Thank you for your patronage!
*$restaurantName*
'''.trim();

    final encodedMessage = Uri.encodeComponent(message);
    final url = Uri.parse('https://wa.me/$cleanPhone?text=$encodedMessage');

    if (await canLaunchUrl(url)) {
      return await launchUrl(url, mode: LaunchMode.externalApplication);
    } else {
      return false;
    }
  }

  static Future<bool> sendBillReceipt({
    required String phone,
    required String customerName,
    required String invoiceNumber,
    required double totalAmount,
    required double paidAmount,
    required double balanceDue,
    required String restaurantName,
  }) async {
    String cleanPhone = phone.replaceAll(RegExp(r'\D'), '');
    if (!cleanPhone.startsWith('91') && cleanPhone.length == 10) {
      cleanPhone = '91$cleanPhone';
    }

    final message = '''
Receipt from *$restaurantName*
Invoice No: *$invoiceNumber*
Customer: $customerName

Total Bill: ₹${totalAmount.toStringAsFixed(2)}
Amount Paid: ₹${paidAmount.toStringAsFixed(2)}
${balanceDue > 0 ? "Pending Balance: ₹${balanceDue.toStringAsFixed(2)}\n" : ""}
Thank you for dining with us!
'''.trim();

    final encodedMessage = Uri.encodeComponent(message);
    final url = Uri.parse('https://wa.me/$cleanPhone?text=$encodedMessage');

    if (await canLaunchUrl(url)) {
      return await launchUrl(url, mode: LaunchMode.externalApplication);
    } else {
      return false;
    }
  }
}
