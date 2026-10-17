import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../core/theme.dart';
import '../../models/models.dart';
import '../../providers/restaurant_provider.dart';
import '../../services/printer_service.dart';
import '../../services/whatsapp_service.dart';
import 'upi_qr_dialog.dart';

class BillingDialog extends ConsumerStatefulWidget {
  final Order order;

  const BillingDialog({super.key, required this.order});

  @override
  ConsumerState<BillingDialog> createState() => _BillingDialogState();
}

class _BillingDialogState extends ConsumerState<BillingDialog> {
  final _uuid = const Uuid();
  late TextEditingController _nameController;
  late TextEditingController _phoneController;
  late TextEditingController _cashController;
  late TextEditingController _upiController;
  late TextEditingController _creditController;

  bool _isSplitMode = false;
  int _splitCount = 2;
  late List<PayerSplit> _splits;

  void _recomputeSplits(int count) {
    _splitCount = count;
    final total = widget.order.grandTotal;
    final eachAmt = double.parse((total / count).toStringAsFixed(2));
    _splits = List.generate(count, (index) {
      final isLast = index == count - 1;
      final amt = isLast ? double.parse((total - (eachAmt * (count - 1))).toStringAsFixed(2)) : eachAmt;
      return PayerSplit(
        id: 'split_${index + 1}',
        label: 'Payer ${index + 1}',
        amount: amt,
        paymentMode: 'UPI',
        isPaid: false,
      );
    });
  }

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.order.customerName ?? '');
    _phoneController = TextEditingController(text: widget.order.customerPhone ?? '');

    // Default to full UPI
    _cashController = TextEditingController(text: '0');
    _upiController = TextEditingController(text: widget.order.grandTotal.toStringAsFixed(0));
    _creditController = TextEditingController(text: '0');
    _recomputeSplits(2);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _cashController.dispose();
    _upiController.dispose();
    _creditController.dispose();
    super.dispose();
  }

  void _calculateSplit() {
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsProvider);
    final total = widget.order.grandTotal;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final cash = double.tryParse(_cashController.text) ?? 0.0;
    final upi = double.tryParse(_upiController.text) ?? 0.0;
    final credit = double.tryParse(_creditController.text) ?? 0.0;
    final allocated = cash + upi + credit;
    final remaining = total - allocated;

    final isBalanced = (remaining.abs() < 0.01) || (cash > total && upi == 0 && credit == 0);
    final changeDue = cash > total ? cash - total : 0.0;

    final allSplitsSettled = _splits.every((s) => s.isPaid || s.paymentMode == 'Credit');
    final canComplete = _isSplitMode ? allSplitsSettled : isBalanced;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 560),
        width: MediaQuery.of(context).size.width,
        padding: const EdgeInsets.all(20),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Settlement & Bill • ${widget.order.tableNumber}',
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          'Order: ${widget.order.orderNumber}',
                          style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const Divider(height: 20),

              // Customer Details
              const Text(
                'Customer Details (Required if adding to Credit / Khata)',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
              ),
              const SizedBox(height: 8),
              LayoutBuilder(
                builder: (context, constraints) {
                  final isNarrow = constraints.maxWidth < 440;
                  if (isNarrow) {
                    return Column(
                      children: [
                        TextField(
                          controller: _nameController,
                          decoration: const InputDecoration(
                            labelText: 'Customer Name',
                            isDense: true,
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.person_outline, size: 20),
                          ),
                        ),
                        const SizedBox(height: 10),
                        TextField(
                          controller: _phoneController,
                          keyboardType: TextInputType.phone,
                          decoration: const InputDecoration(
                            labelText: 'Phone Number',
                            isDense: true,
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.phone_outlined, size: 20),
                          ),
                        ),
                      ],
                    );
                  }
                  return Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _nameController,
                          decoration: const InputDecoration(
                            labelText: 'Customer Name',
                            isDense: true,
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.person_outline, size: 20),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: _phoneController,
                          keyboardType: TextInputType.phone,
                          decoration: const InputDecoration(
                            labelText: 'Phone Number',
                            isDense: true,
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.phone_outlined, size: 20),
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 18),

              // Summary Box
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isDark
                      ? const Color(0xFF1E293B)
                      : AppColors.primaryLight.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: isDark
                        ? const Color(0xFF334155)
                        : AppColors.primary.withValues(alpha: 0.2),
                  ),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Flexible(child: Text('Items Subtotal:', overflow: TextOverflow.ellipsis)),
                        const SizedBox(width: 8),
                        Text('₹${widget.order.subtotal.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.w600)),
                      ],
                    ),
                    if (widget.order.packagingCharge > 0) ...[
                      const SizedBox(height: 4),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Flexible(child: Text('Packaging & Container:', overflow: TextOverflow.ellipsis)),
                          const SizedBox(width: 8),
                          Text('₹${widget.order.packagingCharge.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.w600, color: Color(0xFFD97706))),
                        ],
                      ),
                    ],
                    if (settings.gstEnabled && widget.order.taxAmount > 0) ...[
                      const SizedBox(height: 4),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Flexible(child: Text('GST (${settings.taxRate}%):', overflow: TextOverflow.ellipsis)),
                          const SizedBox(width: 8),
                          Text('₹${widget.order.taxAmount.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.w600)),
                        ],
                      ),
                    ],
                    const Divider(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Flexible(child: Text('Total Bill Amount:', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis)),
                        const SizedBox(width: 8),
                        Text('₹${total.toStringAsFixed(2)}', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: isDark ? const Color(0xFFFF7043) : AppColors.primary)),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),

              // Mode Switcher: Single Payer vs Multi-Payer Split
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E293B) : AppColors.borderSubtle,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: InkWell(
                        borderRadius: BorderRadius.circular(9),
                        onTap: () => setState(() => _isSplitMode = false),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                          decoration: BoxDecoration(
                            color: !_isSplitMode
                                ? (isDark ? AppColors.darkCard : Colors.white)
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(9),
                            boxShadow: !_isSplitMode
                                ? [
                                    BoxShadow(
                                      color: Colors.black.withValues(alpha: 0.08),
                                      blurRadius: 4,
                                      offset: const Offset(0, 1),
                                    )
                                  ]
                                : null,
                          ),
                          alignment: Alignment.center,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.payment,
                                size: 16,
                                color: !_isSplitMode ? AppColors.primary : AppColors.textSecondary,
                              ),
                              const SizedBox(width: 6),
                              Flexible(
                                child: Text(
                                  'Single Payer',
                                  style: TextStyle(
                                    fontWeight: !_isSplitMode ? FontWeight.bold : FontWeight.normal,
                                    color: !_isSplitMode ? (isDark ? Colors.white : AppColors.textPrimary) : AppColors.textSecondary,
                                    fontSize: 13,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    Expanded(
                      child: InkWell(
                        borderRadius: BorderRadius.circular(9),
                        onTap: () => setState(() => _isSplitMode = true),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                          decoration: BoxDecoration(
                            color: _isSplitMode
                                ? (isDark ? AppColors.darkCard : Colors.white)
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(9),
                            boxShadow: _isSplitMode
                                ? [
                                    BoxShadow(
                                      color: Colors.black.withValues(alpha: 0.08),
                                      blurRadius: 4,
                                      offset: const Offset(0, 1),
                                    )
                                  ]
                                : null,
                          ),
                          alignment: Alignment.center,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.group_outlined,
                                size: 16,
                                color: _isSplitMode ? const Color(0xFF6366F1) : AppColors.textSecondary,
                              ),
                              const SizedBox(width: 6),
                              Flexible(
                                child: Text(
                                  'Split ($_splitCount)',
                                  style: TextStyle(
                                    fontWeight: _isSplitMode ? FontWeight.bold : FontWeight.normal,
                                    color: _isSplitMode ? (isDark ? Colors.white : AppColors.textPrimary) : AppColors.textSecondary,
                                    fontSize: 13,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              if (!_isSplitMode) ...[
                // 1-Tap Quick Tender Chips & Dynamic UPI QR
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    ActionChip(
                      avatar: const Icon(Icons.qr_code, size: 16),
                      label: const Text('Full UPI'),
                      onPressed: () {
                        setState(() {
                          _cashController.text = '0';
                          _upiController.text = total.toStringAsFixed(0);
                          _creditController.text = '0';
                        });
                      },
                    ),
                    ActionChip(
                      avatar: const Icon(Icons.payments_outlined, size: 16),
                      label: const Text('Exact Cash'),
                      onPressed: () {
                        setState(() {
                          _cashController.text = total.toStringAsFixed(0);
                          _upiController.text = '0';
                          _creditController.text = '0';
                        });
                      },
                    ),
                    ActionChip(
                      avatar: const Icon(Icons.account_balance_wallet_outlined, size: 16),
                      label: const Text('Full Credit'),
                      onPressed: () {
                        setState(() {
                          _cashController.text = '0';
                          _upiController.text = '0';
                          _creditController.text = total.toStringAsFixed(0);
                        });
                      },
                    ),
                    FilledButton.tonalIcon(
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        backgroundColor: const Color(0xFF5F259F).withValues(alpha: isDark ? 0.25 : 0.12),
                        foregroundColor: isDark ? const Color(0xFFC084FC) : const Color(0xFF5F259F),
                      ),
                      icon: const Icon(Icons.qr_code_scanner, size: 18),
                      label: const Text('Show UPI QR', style: TextStyle(fontWeight: FontWeight.bold)),
                      onPressed: () {
                        final upiAmount = upi > 0 ? upi : total;
                        showDialog(
                          context: context,
                          builder: (ctx) => UpiQrDialog(
                            settings: settings,
                            amount: upiAmount,
                            tableNumber: widget.order.tableNumber,
                            orderNumber: widget.order.orderNumber,
                            onPaymentConfirmed: (confirmedAmt) {
                              setState(() {
                                _upiController.text = confirmedAmt.toStringAsFixed(0);
                                if (confirmedAmt >= total) {
                                  _cashController.text = '0';
                                  _creditController.text = '0';
                                }
                              });
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Row(
                                    children: [
                                      const Icon(Icons.check_circle, color: Colors.white),
                                      const SizedBox(width: 8),
                                      Text('UPI Payment of ₹${confirmedAmt.toStringAsFixed(0)} verified!'),
                                    ],
                                  ),
                                  backgroundColor: const Color(0xFF059669),
                                ),
                              );
                            },
                          ),
                        );
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                // Multi-tender Inputs
                LayoutBuilder(
                  builder: (context, constraints) {
                    final isNarrow = constraints.maxWidth < 440;
                    if (isNarrow) {
                      return Column(
                        children: [
                          TextField(
                            controller: _cashController,
                            keyboardType: TextInputType.number,
                            onChanged: (_) => _calculateSplit(),
                            decoration: const InputDecoration(
                              labelText: 'Cash Received (₹)',
                              isDense: true,
                              border: OutlineInputBorder(),
                              prefixIcon: Icon(Icons.payments_outlined, size: 20),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: _upiController,
                                  keyboardType: TextInputType.number,
                                  onChanged: (_) => _calculateSplit(),
                                  decoration: const InputDecoration(
                                    labelText: 'UPI (₹)',
                                    isDense: true,
                                    border: OutlineInputBorder(),
                                    prefixIcon: Icon(Icons.qr_code, size: 20),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: TextField(
                                  controller: _creditController,
                                  keyboardType: TextInputType.number,
                                  onChanged: (_) => _calculateSplit(),
                                  decoration: const InputDecoration(
                                    labelText: 'Credit (₹)',
                                    isDense: true,
                                    border: OutlineInputBorder(),
                                    prefixIcon: Icon(Icons.account_balance_wallet_outlined, size: 20),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      );
                    }
                    return Row(
                      children: [
                        // Cash
                        Expanded(
                          child: TextField(
                            controller: _cashController,
                            keyboardType: TextInputType.number,
                            onChanged: (_) => _calculateSplit(),
                            decoration: const InputDecoration(
                              labelText: 'Cash Received (₹)',
                              isDense: true,
                              border: OutlineInputBorder(),
                              prefixIcon: Icon(Icons.payments_outlined, size: 20),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        // UPI
                        Expanded(
                          child: TextField(
                            controller: _upiController,
                            keyboardType: TextInputType.number,
                            onChanged: (_) => _calculateSplit(),
                            decoration: const InputDecoration(
                              labelText: 'UPI (₹)',
                              isDense: true,
                              border: OutlineInputBorder(),
                              prefixIcon: Icon(Icons.qr_code, size: 20),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        // Credit
                        Expanded(
                          child: TextField(
                            controller: _creditController,
                            keyboardType: TextInputType.number,
                            onChanged: (_) => _calculateSplit(),
                            decoration: const InputDecoration(
                              labelText: 'Credit / Khata (₹)',
                              isDense: true,
                              border: OutlineInputBorder(),
                              prefixIcon: Icon(Icons.account_balance_wallet_outlined, size: 20),
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 10),

                // Quick Cash Denomination buttons for Cashiers
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      const Text('Cash Notes: ', style: TextStyle(fontSize: 12, color: AppColors.textSecondary, fontWeight: FontWeight.w600)),
                      _buildNoteChip(100),
                      _buildNoteChip(200),
                      _buildNoteChip(500),
                      _buildNoteChip(2000),
                    ],
                  ),
                ),
                const SizedBox(height: 12),

                // Change Return or Balance Alert
                if (changeDue > 0)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF064E3B) : Colors.green.shade50,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: isDark ? const Color(0xFF047857) : Colors.green.shade300,
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Row(
                            children: [
                              Icon(
                                Icons.change_circle_outlined,
                                color: isDark ? const Color(0xFF34D399) : Colors.green.shade800,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Return Change to Customer:',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: isDark ? const Color(0xFFD1FAE5) : Colors.green.shade900,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '₹${changeDue.toStringAsFixed(2)}',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: isDark ? const Color(0xFF34D399) : Colors.green.shade800,
                          ),
                        ),
                      ],
                    ),
                  )
                else if (!isBalanced)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      remaining > 0
                          ? '⚠️ ₹${remaining.toStringAsFixed(2)} remaining to be allocated'
                          : '⚠️ Over-allocated by ₹${(-remaining).toStringAsFixed(2)}',
                      style: const TextStyle(color: Colors.red, fontSize: 13, fontWeight: FontWeight.bold),
                    ),
                  ),
              ] else ...[
                // Multi-Payer Split Mode Controls
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Expanded(
                      child: Text(
                        'Split into equal parts:',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    TextButton.icon(
                      icon: const Icon(Icons.done_all, size: 16),
                      label: const Text('Mark All Paid', style: TextStyle(fontSize: 12)),
                      onPressed: () {
                        setState(() {
                          for (var s in _splits) {
                            s.isPaid = true;
                          }
                        });
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [2, 3, 4, 5, 6].map((n) {
                    final isSel = _splitCount == n;
                    return ChoiceChip(
                      selected: isSel,
                      label: Text('$n Payers'),
                      selectedColor: const Color(0xFF6366F1).withValues(alpha: 0.2),
                      onSelected: (val) {
                        if (val) {
                          setState(() {
                            _recomputeSplits(n);
                          });
                        }
                      },
                    );
                  }).toList(),
                ),
                const SizedBox(height: 12),

                // Summary Pill
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF6366F1).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Wrap(
                    alignment: WrapAlignment.spaceBetween,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 8,
                    runSpacing: 4,
                    children: [
                      Text(
                        'Each Payer: ₹${_splits.first.amount.toStringAsFixed(2)}',
                        style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF6366F1)),
                      ),
                      Text(
                        '${_splits.where((s) => s.isPaid).length} of $_splitCount Paid',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: allSplitsSettled ? const Color(0xFF16A34A) : Colors.orange,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),

                // Individual Payer Cards
                ..._splits.map((split) {
                  final splitIndex = _splits.indexOf(split) + 1;
                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF1E293B) : Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: split.isPaid
                            ? const Color(0xFF16A34A).withValues(alpha: 0.4)
                            : (isDark ? AppColors.darkBorder : AppColors.border),
                      ),
                    ),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 12,
                          backgroundColor: split.isPaid ? const Color(0xFF16A34A) : const Color(0xFF6366F1),
                          foregroundColor: Colors.white,
                          child: Text('$splitIndex', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${split.label} • ₹${split.amount.toStringAsFixed(2)}',
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              Wrap(
                                spacing: 4,
                                crossAxisAlignment: WrapCrossAlignment.center,
                                children: [
                                  InkWell(
                                    onTap: () => setState(() => split.paymentMode = 'UPI'),
                                    child: Text(
                                      'UPI',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: split.paymentMode == 'UPI' ? FontWeight.bold : FontWeight.normal,
                                        color: split.paymentMode == 'UPI' ? AppColors.primary : AppColors.textSecondary,
                                      ),
                                    ),
                                  ),
                                  const Text('•', style: TextStyle(color: Colors.grey, fontSize: 10)),
                                  InkWell(
                                    onTap: () => setState(() => split.paymentMode = 'Cash'),
                                    child: Text(
                                      'Cash',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: split.paymentMode == 'Cash' ? FontWeight.bold : FontWeight.normal,
                                        color: split.paymentMode == 'Cash' ? AppColors.primary : AppColors.textSecondary,
                                      ),
                                    ),
                                  ),
                                  const Text('•', style: TextStyle(color: Colors.grey, fontSize: 10)),
                                  InkWell(
                                    onTap: () => setState(() => split.paymentMode = 'Credit'),
                                    child: Text(
                                      'Credit',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: split.paymentMode == 'Credit' ? FontWeight.bold : FontWeight.normal,
                                        color: split.paymentMode == 'Credit' ? AppColors.primary : AppColors.textSecondary,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        if (split.paymentMode == 'UPI' && !split.isPaid)
                          IconButton(
                            icon: const Icon(Icons.qr_code, size: 18, color: Color(0xFF5F259F)),
                            tooltip: 'Show UPI QR',
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                            constraints: const BoxConstraints(),
                            visualDensity: VisualDensity.compact,
                            onPressed: () {
                              showDialog(
                                context: context,
                                builder: (ctx) => UpiQrDialog(
                                  settings: settings,
                                  amount: split.amount,
                                  tableNumber: '${widget.order.tableNumber} (${split.label})',
                                  orderNumber: widget.order.orderNumber,
                                  onPaymentConfirmed: (_) {
                                    setState(() {
                                      split.isPaid = true;
                                    });
                                  },
                                ),
                              );
                            },
                          ),
                        const SizedBox(width: 4),
                        FilterChip(
                          visualDensity: VisualDensity.compact,
                          padding: EdgeInsets.zero,
                          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          showCheckmark: false,
                          selected: split.isPaid,
                          label: Text(split.isPaid ? 'PAID' : 'PAY'),
                          selectedColor: const Color(0xFF16A34A).withValues(alpha: 0.2),
                          labelStyle: TextStyle(
                            color: split.isPaid ? const Color(0xFF16A34A) : Colors.orange,
                            fontWeight: FontWeight.bold,
                            fontSize: 10,
                          ),
                          onSelected: (val) {
                            setState(() {
                              split.isPaid = val;
                            });
                          },
                        ),
                      ],
                    ),
                  );
                }),
              ],

              const SizedBox(height: 24),

              // Action Buttons
              Wrap(
                alignment: WrapAlignment.end,
                spacing: 12,
                runSpacing: 10,
                children: [
                  OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Cancel'),
                  ),
                  ElevatedButton.icon(
                    icon: const Icon(Icons.receipt_long),
                    label: Text(_isSplitMode ? 'Settle & Print Split Bill' : 'Complete & Print Bill'),
                    onPressed: !canComplete
                        ? null
                        : () async {
                            final custName = _nameController.text.trim();
                            final custPhone = _phoneController.text.trim();

                            final double netCash = _isSplitMode
                                ? _splits.where((s) => s.isPaid && s.paymentMode == 'Cash').fold(0.0, (sum, s) => sum + s.amount)
                                : (cash > total ? total : cash);

                            final double netUpi = _isSplitMode
                                ? _splits.where((s) => s.isPaid && s.paymentMode == 'UPI').fold(0.0, (sum, s) => sum + s.amount)
                                : upi;

                            final double netCredit = _isSplitMode
                                ? _splits.where((s) => s.paymentMode == 'Credit').fold(0.0, (sum, s) => sum + s.amount)
                                : credit;

                            if (netCredit > 0 && (custName.isEmpty || custPhone.isEmpty)) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Customer Name & Phone are required for Credit / Khata!'),
                                  backgroundColor: Colors.red,
                                ),
                              );
                              return;
                            }

                            final invNumber = ref.read(settingsProvider.notifier).getNextInvoiceNumber();

                            final invoice = Invoice(
                              id: _uuid.v4(),
                              invoiceNumber: invNumber,
                              tableNumber: widget.order.tableNumber,
                              customerName: custName.isNotEmpty ? custName : null,
                              customerPhone: custPhone.isNotEmpty ? custPhone : null,
                              items: widget.order.items,
                              subtotal: widget.order.subtotal,
                              taxAmount: widget.order.taxAmount,
                              grandTotal: total,
                              cashPaid: netCash,
                              upiPaid: netUpi,
                              creditAmount: netCredit,
                              splits: _isSplitMode ? _splits : null,
                              splitSummary: _isSplitMode ? '$_splitCount Payers • ₹${_splits.first.amount.toStringAsFixed(0)} each' : null,
                            );

                            ref.read(invoicesProvider.notifier).addInvoice(invoice);

                            // Auto-decrement physical inventory for packaged goods & tracked items if tracking is enabled
                            if (ref.read(settingsProvider).inventoryTrackingEnabled) {
                              for (final item in widget.order.items) {
                                ref.read(menuProvider.notifier).decrementStock(item.menuItemId, item.quantity);
                              }
                            }

                            if (credit > 0) {
                              final customer = ref.read(customersProvider.notifier).getOrCreate(custName, custPhone);
                              ref.read(ledgerProvider.notifier).addEntry(
                                LedgerEntry(
                                  id: _uuid.v4(),
                                  customerId: customer.id,
                                  type: LedgerType.debit,
                                  amount: netCredit,
                                  referenceType: 'INVOICE',
                                  referenceNumber: invNumber,
                                  description: 'Dining bill credit • ${widget.order.tableNumber}',
                                ),
                              );
                            }

                            if (!widget.order.tableNumber.startsWith('Parcel')) {
                              ref.read(tablesProvider.notifier).releaseTable(widget.order.tableNumber);
                            }
                            ref.read(ordersProvider.notifier).removeOrder(widget.order.tableNumber);

                            Navigator.of(context).pop();

                            if (settings.autoPrintReceipt) {
                              await PrinterService.printReceipt(invoice: invoice, settings: settings);
                            }

                            if (context.mounted) {
                              if (_isSplitMode) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('Split Bill $invNumber printed across $_splitCount payers!'),
                                    action: SnackBarAction(
                                      label: 'Print Payer Slips',
                                      textColor: const Color(0xFFC084FC),
                                      onPressed: () {
                                        for (final s in _splits) {
                                          PrinterService.printSplitSlip(
                                            invoice: invoice,
                                            split: s,
                                            settings: settings,
                                          );
                                        }
                                      },
                                    ),
                                  ),
                                );
                              } else if (custPhone.isNotEmpty) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('Bill $invNumber printed!'),
                                    action: SnackBarAction(
                                      label: 'WhatsApp Receipt',
                                      textColor: Colors.white,
                                      onPressed: () {
                                        WhatsAppService.sendBillReceipt(
                                          phone: custPhone,
                                          customerName: custName,
                                          invoiceNumber: invNumber,
                                          totalAmount: total,
                                          paidAmount: netCash + netUpi,
                                          balanceDue: netCredit,
                                          restaurantName: settings.restaurantName,
                                        );
                                      },
                                    ),
                                  ),
                                );
                              }
                            }
                          },
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNoteChip(int amount) {
    return Builder(
      builder: (context) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        return Padding(
          padding: const EdgeInsets.only(right: 6),
          child: ActionChip(
            label: Text('+₹$amount'),
            backgroundColor: isDark ? const Color(0xFF1E293B) : AppColors.borderSubtle,
            labelStyle: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 12,
              color: isDark ? const Color(0xFFFF7043) : AppColors.primary,
            ),
            side: BorderSide(
              color: isDark ? const Color(0xFF334155) : AppColors.border,
            ),
            onPressed: () {
              final current = double.tryParse(_cashController.text) ?? 0.0;
              setState(() {
                _cashController.text = (current + amount).toStringAsFixed(0);
              });
            },
          ),
        );
      },
    );
  }
}
