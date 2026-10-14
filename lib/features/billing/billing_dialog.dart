import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../core/theme.dart';
import '../../models/models.dart';
import '../../providers/restaurant_provider.dart';
import '../../services/printer_service.dart';
import '../../services/whatsapp_service.dart';

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

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.order.customerName ?? '');
    _phoneController = TextEditingController(text: widget.order.customerPhone ?? '');

    // Default to full UPI
    _cashController = TextEditingController(text: '0');
    _upiController = TextEditingController(text: widget.order.grandTotal.toStringAsFixed(0));
    _creditController = TextEditingController(text: '0');
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

    final cash = double.tryParse(_cashController.text) ?? 0.0;
    final upi = double.tryParse(_upiController.text) ?? 0.0;
    final credit = double.tryParse(_creditController.text) ?? 0.0;
    final allocated = cash + upi + credit;
    final remaining = total - allocated;

    final isBalanced = (remaining.abs() < 0.01) || (cash > total && upi == 0 && credit == 0);
    final changeDue = cash > total ? cash - total : 0.0;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        width: 560,
        padding: const EdgeInsets.all(26),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Settlement & Bill • ${widget.order.tableNumber}',
                        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                      ),
                      Text(
                        'Order: ${widget.order.orderNumber}',
                        style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
                      ),
                    ],
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const Divider(height: 24),

              // Customer Details
              const Text(
                'Customer Details (Required if adding to Credit / Khata)',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
              ),
              const SizedBox(height: 8),
              Row(
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
              ),
              const SizedBox(height: 18),

              // Summary Box
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.primaryLight.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Items Subtotal:'),
                        Text('₹${widget.order.subtotal.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.w600)),
                      ],
                    ),
                    if (settings.gstEnabled && widget.order.taxAmount > 0) ...[
                      const SizedBox(height: 4),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('GST (${settings.taxRate}%):'),
                          Text('₹${widget.order.taxAmount.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.w600)),
                        ],
                      ),
                    ],
                    const Divider(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Total Bill Amount:', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                        Text('₹${total.toStringAsFixed(2)}', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppColors.primary)),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),

              // 1-Tap Quick Tender Chips
              Row(
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
                  const SizedBox(width: 8),
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
                  const SizedBox(width: 8),
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
                ],
              ),
              const SizedBox(height: 14),

              // Multi-tender Inputs
              Row(
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
                    color: Colors.green.shade50,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.green.shade300),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.change_circle_outlined, color: Colors.green.shade800),
                          const SizedBox(width: 8),
                          Text(
                            'Return Change to Customer:',
                            style: TextStyle(fontWeight: FontWeight.bold, color: Colors.green.shade900),
                          ),
                        ],
                      ),
                      Text(
                        '₹${changeDue.toStringAsFixed(2)}',
                        style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.green.shade800),
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

              const SizedBox(height: 24),

              // Action Buttons
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton.icon(
                    icon: const Icon(Icons.receipt_long),
                    label: const Text('Complete & Print Bill'),
                    onPressed: !isBalanced
                        ? null
                        : () async {
                            final custName = _nameController.text.trim();
                            final custPhone = _phoneController.text.trim();

                            if (credit > 0 && (custName.isEmpty || custPhone.isEmpty)) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Customer Name & Phone are required for Credit / Khata!'),
                                  backgroundColor: Colors.red,
                                ),
                              );
                              return;
                            }

                            final invNumber = ref.read(settingsProvider.notifier).getNextInvoiceNumber();
                            final netCash = cash > total ? total : cash;

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
                              upiPaid: upi,
                              creditAmount: credit,
                            );

                            ref.read(invoicesProvider.notifier).addInvoice(invoice);

                            if (credit > 0) {
                              final customer = ref.read(customersProvider.notifier).getOrCreate(custName, custPhone);
                              ref.read(ledgerProvider.notifier).addEntry(
                                LedgerEntry(
                                  id: _uuid.v4(),
                                  customerId: customer.id,
                                  type: LedgerType.debit,
                                  amount: credit,
                                  referenceType: 'INVOICE',
                                  referenceNumber: invNumber,
                                  description: 'Dining bill credit • ${widget.order.tableNumber}',
                                ),
                              );
                            }

                            ref.read(tablesProvider.notifier).releaseTable(widget.order.tableNumber);
                            ref.read(ordersProvider.notifier).removeOrder(widget.order.tableNumber);

                            Navigator.of(context).pop();

                            await PrinterService.printReceipt(invoice: invoice, settings: settings);

                            if (custPhone.isNotEmpty && context.mounted) {
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
                                        paidAmount: netCash + upi,
                                        balanceDue: credit,
                                        restaurantName: settings.restaurantName,
                                      );
                                    },
                                  ),
                                ),
                              );
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
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: ActionChip(
        label: Text('+₹$amount'),
        backgroundColor: AppColors.background,
        onPressed: () {
          final current = double.tryParse(_cashController.text) ?? 0.0;
          setState(() {
            _cashController.text = (current + amount).toStringAsFixed(0);
          });
        },
      ),
    );
  }
}
