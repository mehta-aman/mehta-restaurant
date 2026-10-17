import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../core/theme.dart';
import '../../models/models.dart';
import '../../providers/restaurant_provider.dart';

class BillDetailDialog extends ConsumerStatefulWidget {
  final Invoice invoice;

  const BillDetailDialog({super.key, required this.invoice});

  @override
  ConsumerState<BillDetailDialog> createState() => _BillDetailDialogState();
}

class _BillDetailDialogState extends ConsumerState<BillDetailDialog> {
  late Invoice _currentInvoice;
  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
    _currentInvoice = widget.invoice;
  }

  void _refreshFromProvider() {
    final list = ref.read(invoicesProvider);
    final match = list.where((i) => i.id == _currentInvoice.id).firstOrNull;
    if (match != null) {
      setState(() => _currentInvoice = match);
    }
  }

  Future<void> _handleRejectBill() async {
    final reasonController = TextEditingController();
    String? selectedPreset;
    final presets = [
      'Customer dispute / return',
      'Incorrect item entered',
      'Duplicate bill generated',
      'System or pricing error',
      'Cancelled by customer',
    ];

    final confirmedReason = await showDialog<String>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) {
          final isDark = Theme.of(ctx).brightness == Brightness.dark;
          return AlertDialog(
            backgroundColor: isDark ? AppColors.darkCard : Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: Row(
              children: const [
                Icon(Icons.warning_amber_rounded, color: Colors.red, size: 24),
                SizedBox(width: 8),
                Text(
                  'Reject / Void Bill',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Are you sure you want to reject Bill #${_currentInvoice.invoiceNumber}? This will mark the bill voided and reverse any associated Khata credit.',
                    style: TextStyle(
                      fontSize: 13,
                      color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 14),
                  const Text(
                    'Quick Reasons:',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: presets.map((p) {
                      final isSelected = selectedPreset == p;
                      return ChoiceChip(
                        label: Text(p, style: TextStyle(fontSize: 11, color: isSelected ? Colors.white : null)),
                        selected: isSelected,
                        selectedColor: Colors.red.shade700,
                        onSelected: (val) {
                          setModalState(() {
                            selectedPreset = val ? p : null;
                            if (val) {
                              reasonController.text = p;
                            }
                          });
                        },
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: reasonController,
                    decoration: InputDecoration(
                      labelText: 'Rejection Reason *',
                      hintText: 'e.g., Billing mishap, wrong table number...',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    maxLines: 2,
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red.shade600,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                onPressed: () {
                  final text = reasonController.text.trim();
                  if (text.isEmpty) {
                    ScaffoldMessenger.of(ctx).showSnackBar(
                      const SnackBar(content: Text('Please enter a rejection reason')),
                    );
                    return;
                  }
                  Navigator.pop(ctx, text);
                },
                child: const Text('Confirm Rejection'),
              ),
            ],
          );
        },
      ),
    );

    if (confirmedReason == null || !mounted) return;

    setState(() => _isProcessing = true);
    try {
      final res = await ref.read(invoicesProvider.notifier).voidInvoice(
            _currentInvoice.invoiceNumber,
            confirmedReason,
          );

      if (mounted) {
        setState(() {
          _currentInvoice = _currentInvoice.copyWith(
            isVoided: true,
            voidReason: confirmedReason,
          );
          _isProcessing = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(res.message),
            backgroundColor: res.success ? Colors.red.shade700 : Colors.grey.shade800,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isProcessing = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to reject bill: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _handleDeleteBill() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        return AlertDialog(
          backgroundColor: isDark ? AppColors.darkCard : Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: const [
              Icon(Icons.delete_forever_rounded, color: Colors.red, size: 26),
              SizedBox(width: 8),
              Text(
                'Delete Bill Permanently?',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          content: Text(
            'This action will permanently delete Bill #${_currentInvoice.invoiceNumber} from both the local application and cloud database.\n\nThis cannot be undone. Are you sure?',
            style: TextStyle(
              fontSize: 13,
              color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red.shade700,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Delete Bill'),
            ),
          ],
        );
      },
    );

    if (confirmed != true || !mounted) return;

    setState(() => _isProcessing = true);
    final success = await ref.read(invoicesProvider.notifier).deleteInvoice(_currentInvoice.id);

    if (mounted) {
      Navigator.pop(context, true); // Close dialog with deleted = true
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(success ? 'Bill #${_currentInvoice.invoiceNumber} permanently deleted' : 'Bill deleted locally'),
          backgroundColor: Colors.grey.shade800,
        ),
      );
    }
  }

  void _shareReceiptWhatsApp() {
    final buffer = StringBuffer();
    buffer.writeln('🧾 *MEHTA RESTAURANT*');
    buffer.writeln('Bill #: ${_currentInvoice.invoiceNumber}');
    buffer.writeln('Table: ${_currentInvoice.tableNumber}');
    buffer.writeln('Date: ${DateFormat('dd MMM yyyy, hh:mm a').format(_currentInvoice.issuedAt)}');
    if (_currentInvoice.customerName != null && _currentInvoice.customerName!.isNotEmpty) {
      buffer.writeln('Customer: ${_currentInvoice.customerName}');
    }
    buffer.writeln('---------------------------');
    for (final item in _currentInvoice.items) {
      buffer.writeln('${item.name} x${item.quantity} = ₹${(item.unitPrice * item.quantity).toStringAsFixed(0)}');
    }
    buffer.writeln('---------------------------');
    buffer.writeln('Subtotal: ₹${_currentInvoice.subtotal.toStringAsFixed(2)}');
    buffer.writeln('GST (5%): ₹${_currentInvoice.taxAmount.toStringAsFixed(2)}');
    buffer.writeln('*Grand Total: ₹${_currentInvoice.grandTotal.toStringAsFixed(2)}*');
    if (_currentInvoice.isVoided) {
      buffer.writeln('⚠️ STATUS: REJECTED / VOIDED');
      if (_currentInvoice.voidReason != null) {
        buffer.writeln('Reason: ${_currentInvoice.voidReason}');
      }
    }
    buffer.writeln('Thank you for dining with us! 🙏');

    Clipboard.setData(ClipboardData(text: buffer.toString()));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Receipt text copied to clipboard for WhatsApp!')),
    );
  }

  @override
  Widget build(BuildContext context) {
    _refreshFromProvider();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final inv = _currentInvoice;
    final dateStr = DateFormat('dd MMM yyyy, hh:mm a').format(inv.issuedAt);

    return Dialog(
      backgroundColor: isDark ? AppColors.darkCard : Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 620, maxHeight: 780),
        child: Column(
          children: [
            // Header Bar
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E1F22) : const Color(0xFFF9F9F8),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                border: Border(
                  bottom: BorderSide(
                    color: isDark ? AppColors.darkBorder : AppColors.border,
                  ),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.receipt_long_rounded, color: AppColors.primary, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              'Bill #${inv.invoiceNumber}',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                letterSpacing: -0.2,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: AppColors.primary.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                inv.tableNumber,
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.primary,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          dateStr,
                          style: TextStyle(
                            fontSize: 11.5,
                            color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  _buildStatusChip(inv),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, size: 20),
                    tooltip: 'Close',
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),

            // Main Content Area
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Void Warning Banner if Voided
                    if (inv.isVoided) ...[
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Colors.red.shade50,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.red.shade300),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(Icons.block_rounded, color: Colors.red.shade700, size: 20),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'THIS BILL HAS BEEN REJECTED / VOIDED',
                                    style: TextStyle(
                                      color: Colors.red.shade900,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12.5,
                                    ),
                                  ),
                                  const SizedBox(height: 3),
                                  Text(
                                    'Reason: ${inv.voidReason ?? 'No reason recorded'}',
                                    style: TextStyle(
                                      color: Colors.red.shade800,
                                      fontSize: 12,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    'Any ledger khata credit has been safely reversed to prevent discrepancies.',
                                    style: TextStyle(
                                      color: Colors.red.shade700,
                                      fontSize: 11,
                                      fontStyle: FontStyle.italic,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],

                    // Customer Information
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF26272B) : const Color(0xFFF7F7F5),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: isDark ? AppColors.darkBorder : AppColors.border,
                        ),
                      ),
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 18,
                            backgroundColor: AppColors.primary.withValues(alpha: 0.15),
                            child: const Icon(Icons.person_rounded, color: AppColors.primary, size: 20),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  inv.customerName?.trim().isNotEmpty == true
                                      ? inv.customerName!
                                      : 'Guest / Walk-in Customer',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 13.5,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  inv.customerPhone?.trim().isNotEmpty == true
                                      ? 'Phone: ${inv.customerPhone}'
                                      : 'No phone registered',
                                  style: TextStyle(
                                    fontSize: 11.5,
                                    color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (inv.customerPhone?.trim().isNotEmpty == true)
                            IconButton(
                              icon: const Icon(Icons.copy_rounded, size: 16),
                              tooltip: 'Copy Phone',
                              onPressed: () {
                                Clipboard.setData(ClipboardData(text: inv.customerPhone!));
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Phone number copied')),
                                );
                              },
                            ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 18),

                    // Itemized Bill Table
                    const Text(
                      'Ordered Items',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                    const SizedBox(height: 8),

                    Container(
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: isDark ? AppColors.darkBorder : AppColors.border,
                        ),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Column(
                        children: [
                          // Table Header
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                            decoration: BoxDecoration(
                              color: isDark ? const Color(0xFF2B2C30) : const Color(0xFFEFEFEF),
                              borderRadius: const BorderRadius.vertical(top: Radius.circular(9)),
                            ),
                            child: Row(
                              children: const [
                                Expanded(flex: 5, child: Text('Item', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11))),
                                Expanded(flex: 2, child: Text('Qty', textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11))),
                                Expanded(flex: 2, child: Text('Price', textAlign: TextAlign.right, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11))),
                                Expanded(flex: 2, child: Text('Total', textAlign: TextAlign.right, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11))),
                              ],
                            ),
                          ),
                          // Table Rows
                          if (inv.items.isEmpty)
                            const Padding(
                              padding: EdgeInsets.all(16),
                              child: Text('No itemized items recorded', style: TextStyle(fontSize: 12, fontStyle: FontStyle.italic)),
                            )
                          else
                            ...inv.items.asMap().entries.map((entry) {
                              final item = entry.value;
                              final isLast = entry.key == inv.items.length - 1;
                              return Container(
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                decoration: BoxDecoration(
                                  border: isLast
                                      ? null
                                      : Border(
                                          bottom: BorderSide(
                                            color: isDark ? AppColors.darkBorder : AppColors.border,
                                            width: 0.6,
                                          ),
                                        ),
                                ),
                                child: Row(
                                  children: [
                                    Expanded(
                                      flex: 5,
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            item.name,
                                            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12.5),
                                          ),
                                          if (item.notes != null && item.notes!.isNotEmpty)
                                            Text(
                                              'Note: ${item.notes}',
                                              style: TextStyle(
                                                fontSize: 10.5,
                                                fontStyle: FontStyle.italic,
                                                color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary,
                                              ),
                                            ),
                                        ],
                                      ),
                                    ),
                                    Expanded(
                                      flex: 2,
                                      child: Text(
                                        'x${item.quantity}',
                                        textAlign: TextAlign.center,
                                        style: const TextStyle(fontSize: 12),
                                      ),
                                    ),
                                    Expanded(
                                      flex: 2,
                                      child: Text(
                                        '₹${item.unitPrice.toStringAsFixed(0)}',
                                        textAlign: TextAlign.right,
                                        style: const TextStyle(fontSize: 12),
                                      ),
                                    ),
                                    Expanded(
                                      flex: 2,
                                      child: Text(
                                        '₹${(item.unitPrice * item.quantity).toStringAsFixed(0)}',
                                        textAlign: TextAlign.right,
                                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }),
                        ],
                      ),
                    ),

                    const SizedBox(height: 18),

                    // Financial Summary Deck
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF26272B) : const Color(0xFFF7F7F5),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: isDark ? AppColors.darkBorder : AppColors.border,
                        ),
                      ),
                      child: Column(
                        children: [
                          _buildSummaryRow('Subtotal', '₹${inv.subtotal.toStringAsFixed(2)}', isDark),
                          const SizedBox(height: 6),
                          _buildSummaryRow('GST / Taxes (5%)', '₹${inv.taxAmount.toStringAsFixed(2)}', isDark),
                          const Divider(height: 18),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'Grand Total',
                                style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                              ),
                              Text(
                                '₹${inv.grandTotal.toStringAsFixed(2)}',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w800,
                                  color: inv.isVoided ? Colors.red : AppColors.primary,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          // Payment Mode Breakdown
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: isDark ? AppColors.darkCard : Colors.white,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Payment Settlement',
                                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11),
                                ),
                                const SizedBox(height: 6),
                                if (inv.cashPaid > 0)
                                  _buildPaymentRow('Cash Paid', '₹${inv.cashPaid.toStringAsFixed(2)}', Colors.green),
                                if (inv.upiPaid > 0)
                                  _buildPaymentRow('UPI Paid', '₹${inv.upiPaid.toStringAsFixed(2)}', Colors.blue),
                                if (inv.creditAmount > 0)
                                  _buildPaymentRow('Khata Credit (Udhar)', '₹${inv.creditAmount.toStringAsFixed(2)}', Colors.orange),
                                if (inv.splitSummary != null) ...[
                                  const SizedBox(height: 4),
                                  Text(
                                    'Split: ${inv.splitSummary}',
                                    style: const TextStyle(fontSize: 11, fontStyle: FontStyle.italic),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Actions Bar
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E1F22) : const Color(0xFFF9F9F8),
                borderRadius: const BorderRadius.vertical(bottom: Radius.circular(16)),
                border: Border(
                  top: BorderSide(
                    color: isDark ? AppColors.darkBorder : AppColors.border,
                  ),
                ),
              ),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    // Reject / Void Button
                    if (!inv.isVoided)
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red.shade50,
                          foregroundColor: Colors.red.shade700,
                          elevation: 0,
                          side: BorderSide(color: Colors.red.shade200),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        ),
                        icon: const Icon(Icons.block_rounded, size: 16),
                        label: const Text('Reject Bill', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12)),
                        onPressed: _isProcessing ? null : _handleRejectBill,
                      ),

                    const SizedBox(width: 8),

                    // Delete Permanently Button
                    IconButton(
                      icon: const Icon(Icons.delete_outline_rounded, color: Colors.red, size: 20),
                      tooltip: 'Delete Bill Permanently',
                      onPressed: _isProcessing ? null : _handleDeleteBill,
                    ),

                    const SizedBox(width: 16),

                    // WhatsApp Share
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      ),
                      icon: const Icon(Icons.share_rounded, size: 16),
                      label: const Text('WhatsApp', style: TextStyle(fontSize: 12)),
                      onPressed: _shareReceiptWhatsApp,
                    ),

                    const SizedBox(width: 8),

                    // Print Receipt
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      ),
                      icon: const Icon(Icons.print_rounded, size: 16),
                      label: const Text('Print Receipt', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                      onPressed: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Receipt sent to primary thermal printer')),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusChip(Invoice inv) {
    if (inv.isVoided) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.red.shade100,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.cancel_rounded, size: 13, color: Colors.red.shade800),
            const SizedBox(width: 4),
            Text(
              'REJECTED',
              style: TextStyle(
                color: Colors.red.shade900,
                fontWeight: FontWeight.bold,
                fontSize: 11,
              ),
            ),
          ],
        ),
      );
    }

    if (inv.creditAmount > 0) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.amber.shade100,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          'KHATA CREDIT',
          style: TextStyle(
            color: Colors.amber.shade900,
            fontWeight: FontWeight.bold,
            fontSize: 11,
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.green.shade100,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        'PAID',
        style: TextStyle(
          color: Colors.green.shade900,
          fontWeight: FontWeight.bold,
          fontSize: 11,
        ),
      ),
    );
  }

  Widget _buildSummaryRow(String label, String value, bool isDark) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 12.5,
            color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary,
          ),
        ),
        Text(
          value,
          style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600),
        ),
      ],
    );
  }

  Widget _buildPaymentRow(String label, String value, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              ),
              const SizedBox(width: 6),
              Text(label, style: const TextStyle(fontSize: 11.5)),
            ],
          ),
          Text(value, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11.5, color: color)),
        ],
      ),
    );
  }
}
