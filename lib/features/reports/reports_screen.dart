import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../core/theme.dart';
import '../../providers/restaurant_provider.dart';
import '../../services/export_service.dart';
import '../../services/printer_service.dart';

class ReportsScreen extends ConsumerWidget {
  const ReportsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final invoices = ref.watch(invoicesProvider);
    final settings = ref.watch(settingsProvider);

    double totalSales = 0.0;
    double totalCash = 0.0;
    double totalUpi = 0.0;
    double totalCredit = 0.0;

    for (final inv in invoices) {
      totalSales += inv.grandTotal;
      totalCash += inv.cashPaid;
      totalUpi += inv.upiPaid;
      totalCredit += inv.creditAmount;
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Sales & Business Reports'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: ElevatedButton.icon(
              icon: const Icon(Icons.download, size: 18),
              label: const Text('Export Daily Sales (CSV)'),
              onPressed: invoices.isEmpty
                  ? null
                  : () {
                      final csvData = ExportService.generateDailySalesCsv(
                        invoices: invoices,
                        date: DateTime.now(),
                      );
                      showDialog(
                        context: context,
                        builder: (_) => AlertDialog(
                          title: const Text('Daily Sales Export (CSV / Excel)'),
                          content: SizedBox(
                            width: 600,
                            child: SingleChildScrollView(
                              child: SelectableText(csvData),
                            ),
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.of(context).pop(),
                              child: const Text('Close'),
                            ),
                          ],
                        ),
                      );
                    },
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Metrics Row
            Row(
              children: [
                _buildMetricCard('Today\'s Total Sales', '₹${totalSales.toStringAsFixed(2)}', Icons.point_of_sale, AppColors.primary),
                const SizedBox(width: 16),
                _buildMetricCard('UPI Collected', '₹${totalUpi.toStringAsFixed(2)}', Icons.qr_code, Colors.indigo),
                const SizedBox(width: 16),
                _buildMetricCard('Cash Collected', '₹${totalCash.toStringAsFixed(2)}', Icons.payments, Colors.teal),
                const SizedBox(width: 16),
                _buildMetricCard('New Credit Added', '₹${totalCredit.toStringAsFixed(2)}', Icons.pending_actions, Colors.red.shade700),
              ],
            ),
            const SizedBox(height: 24),

            // Invoices Table
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Completed Invoices',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                Text(
                  '${invoices.length} Bills Issued',
                  style: const TextStyle(color: AppColors.textSecondary, fontWeight: FontWeight.w600),
                ),
              ],
            ),
            const SizedBox(height: 12),

            if (invoices.isEmpty)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(40),
                  child: Center(
                    child: Column(
                      children: const [
                        Icon(Icons.receipt_outlined, size: 48, color: AppColors.textSecondary),
                        SizedBox(height: 12),
                        Text(
                          'No bills generated today yet.',
                          style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'When bills are paid from the Table POS, they will show up here.',
                          style: TextStyle(color: AppColors.textSecondary),
                        ),
                      ],
                    ),
                  ),
                ),
              )
            else
              Card(
                child: ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: invoices.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final inv = invoices[index];
                    final timeFormat = DateFormat('hh:mm a');

                    return ListTile(
                      leading: CircleAvatar(
                        backgroundColor: AppColors.primaryLight,
                        child: Text(
                          inv.tableNumber,
                          style: const TextStyle(
                            color: AppColors.primary,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ),
                      title: Row(
                        children: [
                          Text(inv.invoiceNumber, style: const TextStyle(fontWeight: FontWeight.bold)),
                          const SizedBox(width: 12),
                          if (inv.customerName != null)
                            Text('Customer: ${inv.customerName}', style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
                        ],
                      ),
                      subtitle: Text(
                        'Time: ${timeFormat.format(inv.issuedAt)}  •  ${inv.items.length} items  •  Cash: ₹${inv.cashPaid.toStringAsFixed(0)} | UPI: ₹${inv.upiPaid.toStringAsFixed(0)} ${inv.creditAmount > 0 ? "| Credit: ₹${inv.creditAmount.toStringAsFixed(0)}" : ""}',
                        style: const TextStyle(fontSize: 12),
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '₹${inv.grandTotal.toStringAsFixed(2)}',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                          ),
                          const SizedBox(width: 12),
                          IconButton(
                            icon: const Icon(Icons.print_outlined, size: 20),
                            tooltip: 'Reprint Thermal Receipt',
                            onPressed: () {
                              PrinterService.printReceipt(invoice: inv, settings: settings);
                            },
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildMetricCard(String title, String value, IconData icon, Color color) {
    return Expanded(
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(title, style: const TextStyle(color: AppColors.textSecondary, fontSize: 13, fontWeight: FontWeight.w500)),
                  Icon(icon, color: color, size: 22),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                value,
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: color),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
