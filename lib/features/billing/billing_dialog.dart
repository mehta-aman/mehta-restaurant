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

    final isBalanced = (remaining.abs() < 0.01);

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: 520,
        padding: const EdgeInsets.all(24),
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
                        'Settlement & Bill - ${widget.order.tableNumber}',
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
                'Customer Information (Required for Credit Ledger)',
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
              const SizedBox(height: 20),

              // Summary Box
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.primaryLight.withOpacity(0.4),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.primary.withOpacity(0.2)),
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
                        Text('₹${total.toStringAsFixed(2)}', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.primary)),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Multi-tender Split Payment Inputs
              const Text(
                'Payment Tender Breakdown (Split Accepted)',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
              ),
              const SizedBox(height: 10),

              Row(
                children: [
                  // Cash
                  Expanded(
                    child: TextField(
                      controller: _cashController,
                      keyboardType: TextInputType.number,
                      onChanged: (_) => _calculateSplit(),
                      decoration: const InputDecoration(
                        labelText: 'Cash (₹)',
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
              const SizedBox(height: 8),

              // Balance Validation Indicator
              if (!isBalanced)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    remaining > 0
                      ? '⚠️ ₹${remaining.toStringAsFixed(2)} remaining to be allocated'
                      : '⚠️ Over-allocated by ₹${(-remaining).toStringAsFixed(2)}',
                    style: const TextStyle(color: Colors.red, fontSize: 12, fontWeight: FontWeight.w600),
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
                                  content: Text('Customer Name & Phone are required to record a Credit / Khata entry!'),
                                  backgroundColor: Colors.red,
                                ),
                              );
                              return;
                            }

                            // 1. Generate Invoice Number
                            final invNumber = ref.read(settingsProvider.notifier).getNextInvoiceNumber();

                            // 2. Create Invoice Record
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
                              cashPaid: cash,
                              upiPaid: upi,
                              creditAmount: credit,
                            );

                            ref.read(invoicesProvider.notifier).addInvoice(invoice);

                            // 3. If credit allocated, append to immutable Customer Ledger
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
                                  description: 'Dining bill credit - ${widget.order.tableNumber}',
                                ),
                              );
                            }

                            // 4. Release Table and Clear Order
                            ref.read(tablesProvider.notifier).releaseTable(widget.order.tableNumber);
                            ref.read(ordersProvider.notifier).removeOrder(widget.order.tableNumber);

                            Navigator.of(context).pop();

                            // 5. Open Thermal Print Preview
                            await PrinterService.printReceipt(invoice: invoice, settings: settings);

                            // 6. Optional: WhatsApp bill share
                            if (custPhone.isNotEmpty && context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Bill $invNumber generated successfully!'),
                                  action: SnackBarAction(
                                    label: 'WhatsApp Receipt',
                                    textColor: Colors.white,
                                    onPressed: () {
                                      WhatsAppService.sendBillReceipt(
                                        phone: custPhone,
                                        customerName: custName,
                                        invoiceNumber: invNumber,
                                        totalAmount: total,
                                        paidAmount: cash + upi,
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
}
