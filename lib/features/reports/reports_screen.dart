import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart' hide TextDirection;
import '../../core/theme.dart';
import '../../models/models.dart';
import '../../providers/restaurant_provider.dart';
import '../../services/export_service.dart';
import '../../services/printer_service.dart';
import '../../services/whatsapp_service.dart';

class ReportsScreen extends ConsumerStatefulWidget {
  const ReportsScreen({super.key});

  @override
  ConsumerState<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends ConsumerState<ReportsScreen> {
  String _selectedReportType = 'Sales Report';
  String _selectedTimeFilter = 'Day'; // 'Day', 'Week', 'Month'

  final List<String> _reportTypes = [
    'Sales Report',
    'Item Performance',
    'Customer Report',
    'Payment Report',
    'Tax Report',
  ];

  @override
  Widget build(BuildContext context) {
    final invoices = ref.watch(invoicesProvider);
    final settings = ref.watch(settingsProvider);
    final currentStaff = ref.watch(currentStaffProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 750;
    final isDesktop = screenWidth >= 1100;

    double totalSales = 0.0;
    double totalCash = 0.0;
    double totalUpi = 0.0;
    double totalCredit = 0.0;
    int validBillsCount = 0;

    for (final inv in invoices) {
      if (inv.isVoided) continue;
      totalSales += inv.grandTotal;
      totalCash += inv.cashPaid;
      totalUpi += inv.upiPaid;
      totalCredit += inv.creditAmount;
      validBillsCount++;
    }

    final avgOrderValue = validBillsCount > 0 ? (totalSales / validBillsCount) : 0.0;

    final dateStr = DateFormat('d MMM y').format(DateTime.now());

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : AppColors.background,
      appBar: AppBar(
        title: const Text('Reports & Analytics'),
        actions: [
          if (isMobile) ...[
            IconButton(
              icon: const Icon(Icons.send_to_mobile, color: Color(0xFF16A34A)),
              tooltip: 'Send EOD WhatsApp Digest',
              onPressed: invoices.isEmpty
                  ? null
                  : () => _showDailyWhatsappDigestDialog(
                        context,
                        ref,
                        settings: settings,
                        totalSales: totalSales,
                        totalBills: invoices.length,
                        cashCollected: totalCash,
                        upiCollected: totalUpi,
                        creditGiven: totalCredit,
                      ),
            ),
            IconButton(
              icon: const Icon(Icons.download),
              tooltip: 'Export Daily Sales (CSV)',
              onPressed: invoices.isEmpty ? null : () => _exportCsv(context, invoices),
            ),
          ] else ...[
            FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF16A34A),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              icon: const Icon(Icons.chat, size: 16),
              label: const Text('Daily WhatsApp Digest', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
              onPressed: invoices.isEmpty
                  ? null
                  : () => _showDailyWhatsappDigestDialog(
                        context,
                        ref,
                        settings: settings,
                        totalSales: totalSales,
                        totalBills: invoices.length,
                        cashCollected: totalCash,
                        upiCollected: totalUpi,
                        creditGiven: totalCredit,
                      ),
            ),
            const SizedBox(width: 8),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              icon: const Icon(Icons.download, size: 16),
              label: const Text('Export CSV', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
              onPressed: invoices.isEmpty ? null : () => _exportCsv(context, invoices),
            ),
            const SizedBox(width: 16),
          ],
        ],
      ),
      body: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Left Sub-nav (Desktop) matching reference
          if (isDesktop)
            Container(
              width: 200,
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkCard : Colors.white,
                border: Border(
                  right: BorderSide(
                    color: isDark ? AppColors.darkBorder : AppColors.border,
                  ),
                ),
              ),
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 16),
                itemCount: _reportTypes.length,
                itemBuilder: (context, i) {
                  final reportType = _reportTypes[i];
                  final isSelected = reportType == _selectedReportType;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: InkWell(
                      onTap: () => setState(() => _selectedReportType = reportType),
                      borderRadius: BorderRadius.circular(10),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? AppColors.primary
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          reportType,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                            color: isSelected
                                ? Colors.white
                                : (isDark ? AppColors.darkTextSecondary : AppColors.textPrimary),
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),

          // Main Content
          Expanded(
            child: SingleChildScrollView(
              padding: EdgeInsets.all(isMobile ? 14 : 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header: Title + Date Range + Time Filter Pills
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _selectedReportType,
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                              color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
                              letterSpacing: -0.4,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '$dateStr - $dateStr',
                            style: TextStyle(
                              fontSize: 12.5,
                              color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                      // Filter Pills (Day / Week / Month)
                      Container(
                        padding: const EdgeInsets.all(3),
                        decoration: BoxDecoration(
                          color: isDark ? AppColors.darkSurface : AppColors.surfaceSecondary,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: isDark ? AppColors.darkBorder : AppColors.border,
                          ),
                        ),
                        child: Row(
                          children: ['Day', 'Week', 'Month'].map((filter) {
                            final isSel = _selectedTimeFilter == filter;
                            return InkWell(
                              onTap: () => setState(() => _selectedTimeFilter = filter),
                              borderRadius: BorderRadius.circular(8),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                decoration: BoxDecoration(
                                  color: isSel ? AppColors.primary : Colors.transparent,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  filter,
                                  style: TextStyle(
                                    fontSize: 11.5,
                                    fontWeight: isSel ? FontWeight.bold : FontWeight.w600,
                                    color: isSel ? Colors.white : (isDark ? AppColors.darkTextSecondary : AppColors.textSecondary),
                                  ),
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 20),

                  // Top 3 Metric Summary Cards matching reference
                  Row(
                    children: [
                      Expanded(
                        child: _buildMetricCard(
                          'Total Sales',
                          '₹ ${NumberFormat('#,##0').format(totalSales)}',
                          '+12%',
                          true,
                          isDark,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildMetricCard(
                          'Total Orders',
                          '$validBillsCount',
                          '+8%',
                          true,
                          isDark,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildMetricCard(
                          'Avg. Order Value',
                          '₹ ${NumberFormat('#,##0').format(avgOrderValue)}',
                          '+5%',
                          true,
                          isDark,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 24),

                  // Charts Row: Hourly Bar Chart + Payment Methods Donut Chart
                  if (isMobile) ...[
                    _buildHourlySalesCard(isDark),
                    const SizedBox(height: 20),
                    _buildPaymentMethodsCard(totalCash, totalUpi, totalCredit, isDark),
                  ] else ...[
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(flex: 3, child: _buildHourlySalesCard(isDark)),
                        const SizedBox(width: 20),
                        Expanded(flex: 2, child: _buildPaymentMethodsCard(totalCash, totalUpi, totalCredit, isDark)),
                      ],
                    ),
                  ],

                  const SizedBox(height: 28),

                  // Completed Invoices Table
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Completed Invoices',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                          color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
                        ),
                      ),
                      Text(
                        '${invoices.length} Bills Issued',
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                          color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  if (invoices.isEmpty)
                    Container(
                      padding: const EdgeInsets.all(40),
                      decoration: BoxDecoration(
                        color: isDark ? AppColors.darkCard : Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.border),
                      ),
                      child: Center(
                        child: Column(
                          children: [
                            const Icon(Icons.receipt_outlined, size: 44, color: AppColors.textSecondary),
                            const SizedBox(height: 12),
                            Text(
                              'No bills generated today yet.',
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 15,
                                color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  else
                    Container(
                      decoration: BoxDecoration(
                        color: isDark ? AppColors.darkCard : Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.border),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: ListView.separated(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: invoices.length,
                          separatorBuilder: (context, index) => Divider(
                            height: 1,
                            color: isDark ? AppColors.darkBorder : AppColors.border,
                          ),
                          itemBuilder: (context, index) {
                            final inv = invoices[index];
                            final timeStr = DateFormat('hh:mm a').format(inv.issuedAt);

                            return ListTile(
                              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                              leading: CircleAvatar(
                                backgroundColor: inv.isVoided
                                    ? Colors.grey.shade300
                                    : AppColors.primary.withValues(alpha: 0.12),
                                child: Icon(
                                  inv.isVoided ? Icons.block : Icons.receipt_long,
                                  color: inv.isVoided ? Colors.grey : AppColors.primary,
                                  size: 18,
                                ),
                              ),
                              title: Row(
                                children: [
                                  Text(
                                    inv.invoiceNumber,
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13.5,
                                      decoration: inv.isVoided ? TextDecoration.lineThrough : null,
                                      color: inv.isVoided ? Colors.grey : (isDark ? AppColors.darkTextPrimary : AppColors.textPrimary),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: isDark ? AppColors.darkSurface : AppColors.surfaceSecondary,
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      'Table ${inv.tableNumber}',
                                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary),
                                    ),
                                  ),
                                  if (inv.isVoided) ...[
                                    const SizedBox(width: 6),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: Colors.red.withValues(alpha: 0.15),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: const Text(
                                        'VOIDED',
                                        style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold, color: Colors.red),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                              subtitle: Padding(
                                padding: const EdgeInsets.only(top: 4),
                                child: Text(
                                  '$timeStr • ${inv.items.length} items • ${inv.customerName ?? "Guest"}',
                                  style: TextStyle(fontSize: 12, color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary),
                                ),
                              ),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    '₹${inv.grandTotal.toStringAsFixed(0)}',
                                    style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.bold,
                                      decoration: inv.isVoided ? TextDecoration.lineThrough : null,
                                      color: inv.isVoided ? Colors.grey : (isDark ? AppColors.darkTextPrimary : AppColors.textPrimary),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  PopupMenuButton<String>(
                                    icon: const Icon(Icons.more_vert, size: 18),
                                    onSelected: (val) {
                                      if (val == 'reprint') {
                                        PrinterService.printReceipt(
                                          invoice: inv,
                                          settings: settings,
                                        );
                                      } else if (val == 'void' && !inv.isVoided) {
                                        _showVoidDialog(context, ref, inv);
                                      }
                                    },
                                    itemBuilder: (ctx) => [
                                      const PopupMenuItem(
                                        value: 'reprint',
                                        child: Row(
                                          children: [
                                            Icon(Icons.print, size: 16),
                                            SizedBox(width: 8),
                                            Text('Reprint Bill'),
                                          ],
                                        ),
                                      ),
                                      if (!inv.isVoided && currentStaff.canEditMenu)
                                        const PopupMenuItem(
                                          value: 'void',
                                          child: Row(
                                            children: [
                                              Icon(Icons.cancel_outlined, size: 16, color: Colors.red),
                                              SizedBox(width: 8),
                                              Text('Void Bill', style: TextStyle(color: Colors.red)),
                                            ],
                                          ),
                                        ),
                                    ],
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricCard(
    String title,
    String value,
    String trend,
    bool isPositive,
    bool isDark,
  ) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
              color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
              letterSpacing: -0.4,
            ),
          ),
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: AppColors.statusAvailableBg,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.arrow_upward, size: 10, color: AppColors.statusAvailable),
                const SizedBox(width: 2),
                Text(
                  trend,
                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.statusAvailable),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHourlySalesCard(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Hourly Sales',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 160,
            width: double.infinity,
            child: CustomPaint(
              painter: _HourlyBarChartPainter(isDark: isDark),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentMethodsCard(double cash, double upi, double credit, bool isDark) {
    final total = cash + upi + credit;
    final upiPercent = total > 0 ? ((upi / total) * 100).round() : 68;
    final cashPercent = total > 0 ? ((cash / total) * 100).round() : 25;
    final creditPercent = total > 0 ? (100 - upiPercent - cashPercent) : 7;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Payment Methods',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              SizedBox(
                width: 100,
                height: 100,
                child: CustomPaint(
                  painter: _DonutChartPainter(
                    upiRatio: upiPercent / 100,
                    cashRatio: cashPercent / 100,
                    creditRatio: creditPercent / 100,
                  ),
                ),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildPaymentLegend('UPI', '$upiPercent%', const Color(0xFF0284C7), isDark),
                    const SizedBox(height: 8),
                    _buildPaymentLegend('Cash', '$cashPercent%', const Color(0xFF10B981), isDark),
                    const SizedBox(height: 8),
                    _buildPaymentLegend('Credit', '$creditPercent%', AppColors.primary, isDark),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentLegend(String title, String percent, Color color, bool isDark) {
    return Row(
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 8),
        Text(
          title,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
          ),
        ),
        const Spacer(),
        Text(
          percent,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary,
          ),
        ),
      ],
    );
  }

  void _exportCsv(BuildContext context, List<Invoice> invoices) {
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
  }

  void _showDailyWhatsappDigestDialog(
    BuildContext context,
    WidgetRef ref, {
    required RestaurantSettings settings,
    required double totalSales,
    required int totalBills,
    required double cashCollected,
    required double upiCollected,
    required double creditGiven,
  }) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Send End-of-Day WhatsApp Summary'),
        content: Text(
          'This will compose a WhatsApp digest with total sales of ₹${totalSales.toStringAsFixed(2)} '
          'across $totalBills bills to ${settings.phone}.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF25D366)),
            onPressed: () async {
              Navigator.pop(ctx);
              await WhatsAppService.sendDailyReportDigest(
                recipientPhone: settings.phone,
                restaurantName: settings.restaurantName,
                totalSales: totalSales,
                totalBills: totalBills,
                cashTotal: cashCollected,
                upiTotal: upiCollected,
                creditTotal: creditGiven,
              );
            },
            child: const Text('Send via WhatsApp', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showVoidDialog(BuildContext context, WidgetRef ref, Invoice invoice) {
    final reasonController = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.warning_amber_rounded, color: Colors.red),
            const SizedBox(width: 8),
            Text('Void Bill: ${invoice.invoiceNumber}?'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Are you sure you want to void this invoice of ₹${invoice.grandTotal.toStringAsFixed(2)}?\n'
              '${invoice.creditAmount > 0 ? "Customer Khata credit of ₹${invoice.creditAmount.toStringAsFixed(2)} will be reversed." : ""}',
              style: const TextStyle(fontSize: 13),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: reasonController,
              decoration: const InputDecoration(
                labelText: 'Reason for Voiding',
                hintText: 'e.g. Wrong items entered / Disputed bill',
                border: OutlineInputBorder(),
                isDense: true,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              final reason = reasonController.text.trim().isNotEmpty
                  ? reasonController.text.trim()
                  : 'Voided by Manager';
              Navigator.of(ctx).pop();
              final res = await ref.read(invoicesProvider.notifier).voidInvoice(invoice.invoiceNumber, reason);
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(res.message),
                    backgroundColor: res.success ? Colors.green : Colors.red,
                  ),
                );
              }
            },
            child: const Text('Confirm Void'),
          ),
        ],
      ),
    );
  }
}

// Hourly Bar Chart Painter
class _HourlyBarChartPainter extends CustomPainter {
  final bool isDark;

  _HourlyBarChartPainter({required this.isDark});

  @override
  void paint(Canvas canvas, Size size) {
    final bars = [0.2, 0.45, 0.35, 0.75, 0.55, 0.85, 0.95, 0.4];
    final labels = ['10A', '12P', '2P', '4P', '6P', '8P', '9P', '10P'];
    final bottomOffset = 20.0;
    final chartHeight = size.height - bottomOffset;

    final barWidth = 14.0;
    final gap = (size.width - (bars.length * barWidth)) / (bars.length + 1);

    final paintBar = Paint()
      ..color = AppColors.primary
      ..style = PaintingStyle.fill;

    final textStyle = TextStyle(
      color: isDark ? AppColors.darkTextSecondary : AppColors.textMuted,
      fontSize: 9,
      fontWeight: FontWeight.w600,
    );

    for (int i = 0; i < bars.length; i++) {
      final x = gap + (i * (barWidth + gap));
      final h = bars[i] * chartHeight;
      final y = chartHeight - h;

      final rect = RRect.fromRectAndRadius(
        Rect.fromLTWH(x, y, barWidth, h),
        const Radius.circular(4),
      );
      canvas.drawRRect(rect, paintBar);

      // Label
      final span = TextSpan(text: labels[i], style: textStyle);
      final tp = TextPainter(text: span, textDirection: TextDirection.ltr)..layout();
      tp.paint(canvas, Offset(x + (barWidth / 2) - (tp.width / 2), chartHeight + 6));
    }
  }

  @override
  bool shouldRepaint(covariant _HourlyBarChartPainter oldDelegate) => oldDelegate.isDark != isDark;
}

// Donut Chart Painter
class _DonutChartPainter extends CustomPainter {
  final double upiRatio;
  final double cashRatio;
  final double creditRatio;

  _DonutChartPainter({
    required this.upiRatio,
    required this.cashRatio,
    required this.creditRatio,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;
    final strokeWidth = 14.0;

    final rect = Rect.fromCircle(center: center, radius: radius - (strokeWidth / 2));

    double startAngle = -math.pi / 2;

    // UPI Arc
    final upiPaint = Paint()
      ..color = const Color(0xFF0284C7)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.butt;
    final upiSweep = upiRatio * 2 * math.pi;
    canvas.drawArc(rect, startAngle, upiSweep, false, upiPaint);
    startAngle += upiSweep;

    // Cash Arc
    final cashPaint = Paint()
      ..color = const Color(0xFF10B981)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.butt;
    final cashSweep = cashRatio * 2 * math.pi;
    canvas.drawArc(rect, startAngle, cashSweep, false, cashPaint);
    startAngle += cashSweep;

    // Credit Arc
    final creditPaint = Paint()
      ..color = AppColors.primary
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.butt;
    final creditSweep = creditRatio * 2 * math.pi;
    canvas.drawArc(rect, startAngle, creditSweep, false, creditPaint);
  }

  @override
  bool shouldRepaint(covariant _DonutChartPainter oldDelegate) => false;
}
