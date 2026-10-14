import 'package:intl/intl.dart';
import '../models/models.dart';

class ExportService {
  static String _convertToCsv(List<List<dynamic>> rows) {
    final buffer = StringBuffer();
    for (final row in rows) {
      final line = row.map((cell) {
        final str = cell?.toString() ?? '';
        if (str.contains(',') || str.contains('"') || str.contains('\n')) {
          return '"${str.replaceAll('"', '""')}"';
        }
        return str;
      }).join(',');
      buffer.writeln(line);
    }
    return buffer.toString();
  }

  static String generateCustomerLedgerCsv({
    required Customer customer,
    required List<LedgerEntry> entries,
  }) {
    final List<List<dynamic>> rows = [];
    
    // Header Info
    rows.add(['MEHTA RESTAURANT - CUSTOMER ACCOUNT STATEMENT']);
    rows.add(['Customer Name', customer.name]);
    rows.add(['Customer Phone', customer.phone]);
    rows.add(['Statement Date', DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now())]);
    rows.add([]);

    // Table Header
    rows.add(['Date', 'Reference Type', 'Reference No.', 'Description', 'Debit (₹)', 'Credit (₹)', 'Running Balance (₹)']);

    double runningBalance = 0.0;
    final dateFormat = DateFormat('dd/MM/yyyy');

    for (final entry in entries) {
      if (entry.type == LedgerType.debit) {
        runningBalance += entry.amount;
        rows.add([
          dateFormat.format(entry.date),
          entry.referenceType,
          entry.referenceNumber,
          entry.description,
          entry.amount.toStringAsFixed(2),
          '0.00',
          runningBalance.toStringAsFixed(2),
        ]);
      } else {
        runningBalance -= entry.amount;
        rows.add([
          dateFormat.format(entry.date),
          entry.referenceType,
          entry.referenceNumber,
          entry.description,
          '0.00',
          entry.amount.toStringAsFixed(2),
          runningBalance.toStringAsFixed(2),
        ]);
      }
    }

    rows.add([]);
    rows.add(['', '', '', 'NET OUTSTANDING BALANCE', '', '', runningBalance.toStringAsFixed(2)]);

    return _convertToCsv(rows);
  }

  static String generateDailySalesCsv({
    required List<Invoice> invoices,
    required DateTime date,
  }) {
    final List<List<dynamic>> rows = [];
    final dateFormat = DateFormat('dd/MM/yyyy');
    final timeFormat = DateFormat('HH:mm');

    rows.add(['MEHTA RESTAURANT - DAILY SALES REPORT']);
    rows.add(['Date', dateFormat.format(date)]);
    rows.add([]);

    rows.add(['Invoice No', 'Time', 'Table', 'Customer', 'Subtotal (₹)', 'Tax (₹)', 'Total (₹)', 'Cash (₹)', 'UPI (₹)', 'Credit (₹)']);

    double totalSales = 0.0;
    double totalCash = 0.0;
    double totalUpi = 0.0;
    double totalCredit = 0.0;

    for (final inv in invoices) {
      totalSales += inv.grandTotal;
      totalCash += inv.cashPaid;
      totalUpi += inv.upiPaid;
      totalCredit += inv.creditAmount;

      rows.add([
        inv.invoiceNumber,
        timeFormat.format(inv.issuedAt),
        inv.tableNumber,
        inv.customerName ?? 'Walk-in',
        inv.subtotal.toStringAsFixed(2),
        inv.taxAmount.toStringAsFixed(2),
        inv.grandTotal.toStringAsFixed(2),
        inv.cashPaid.toStringAsFixed(2),
        inv.upiPaid.toStringAsFixed(2),
        inv.creditAmount.toStringAsFixed(2),
      ]);
    }

    rows.add([]);
    rows.add([
      'TOTALS',
      '',
      '',
      '${invoices.length} Bills',
      '',
      '',
      totalSales.toStringAsFixed(2),
      totalCash.toStringAsFixed(2),
      totalUpi.toStringAsFixed(2),
      totalCredit.toStringAsFixed(2),
    ]);

    return _convertToCsv(rows);
  }
}
