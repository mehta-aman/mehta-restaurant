import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

class WhatsAppService {
  static Future<bool> sendDailyEodDigest({
    required String ownerPhone,
    required String restaurantName,
    required DateTime date,
    required double totalSales,
    required int totalBills,
    required double cashCollected,
    required double upiCollected,
    required double creditGiven,
    required double khataRecoveries,
    required List<String> topSellingItems,
  }) async {
    String cleanPhone = ownerPhone.replaceAll(RegExp(r'\D'), '');
    if (!cleanPhone.startsWith('91') && cleanPhone.length == 10) {
      cleanPhone = '91$cleanPhone';
    }

    final message = formatDailyEodMessage(
      restaurantName: restaurantName,
      date: date,
      totalSales: totalSales,
      totalBills: totalBills,
      cashCollected: cashCollected,
      upiCollected: upiCollected,
      creditGiven: creditGiven,
      khataRecoveries: khataRecoveries,
      topSellingItems: topSellingItems,
    );

    final encodedMessage = Uri.encodeComponent(message);
    final url = Uri.parse('https://wa.me/$cleanPhone?text=$encodedMessage');

    if (await canLaunchUrl(url)) {
      return await launchUrl(url, mode: LaunchMode.externalApplication);
    } else {
      return false;
    }
  }

  static Future<bool> sendDailyReportDigest({
    required String recipientPhone,
    required String restaurantName,
    required double totalSales,
    required int totalBills,
    required double cashTotal,
    required double upiTotal,
    required double creditTotal,
  }) async {
    return sendDailyEodDigest(
      ownerPhone: recipientPhone,
      restaurantName: restaurantName,
      date: DateTime.now(),
      totalSales: totalSales,
      totalBills: totalBills,
      cashCollected: cashTotal,
      upiCollected: upiTotal,
      creditGiven: creditTotal,
      khataRecoveries: 0.0,
      topSellingItems: const [],
    );
  }

  static String formatDailyEodMessage({
    required String restaurantName,
    required DateTime date,
    required double totalSales,
    required int totalBills,
    required double cashCollected,
    required double upiCollected,
    required double creditGiven,
    required double khataRecoveries,
    required List<String> topSellingItems,
  }) {
    final dateStr = DateFormat('dd MMM yyyy').format(date);
    final timeStr = DateFormat('hh:mm a').format(DateTime.now());

    final topItemsText = topSellingItems.isEmpty
        ? '• None recorded'
        : topSellingItems.take(5).map((i) => '• $i').join('\n');

    return '''
📊 *DAILY CLOSING REPORT • $restaurantName*
📅 Date: *$dateStr* ($timeStr)
━━━━━━━━━━━━━━━━━━━━
💰 *TOTAL REVENUE: ₹${totalSales.toStringAsFixed(2)}*
🧾 Total Invoices: *$totalBills bills*

💵 *Collections Breakdown:*
• Cash at Counter: *₹${cashCollected.toStringAsFixed(2)}*
• UPI Payments: *₹${upiCollected.toStringAsFixed(2)}*
• Added to Credit (Khata): *₹${creditGiven.toStringAsFixed(2)}*
${khataRecoveries > 0 ? "• Khata Recoveries Received: *₹${khataRecoveries.toStringAsFixed(2)}*\n" : ""}
💼 *Net Cash in Hand / Drawer:* *₹${(cashCollected + khataRecoveries).toStringAsFixed(2)}*

🔥 *Top Moving Items Today:*
$topItemsText

━━━━━━━━━━━━━━━━━━━━
_Report generated automatically by Mehta Restaurant Management System_
'''.trim();
  }

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
