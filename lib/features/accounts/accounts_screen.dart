import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import '../../core/theme.dart';
import '../../models/models.dart';
import '../../providers/restaurant_provider.dart';
import '../../services/export_service.dart';
import '../../services/whatsapp_service.dart';

class AccountsScreen extends ConsumerStatefulWidget {
  const AccountsScreen({super.key});

  @override
  ConsumerState<AccountsScreen> createState() => _AccountsScreenState();
}

class _AccountsScreenState extends ConsumerState<AccountsScreen> {
  String? _selectedCustomerId;
  final TextEditingController _searchController = TextEditingController();
  String _search = '';
  final _uuid = const Uuid();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final customers = ref.watch(customersProvider);
    final settings = ref.watch(settingsProvider);

    final filteredCustomers = customers.where((c) {
      return c.name.toLowerCase().contains(_search.toLowerCase()) ||
          c.phone.contains(_search);
    }).toList();

    // Default select first customer if none selected
    if (_selectedCustomerId == null && filteredCustomers.isNotEmpty) {
      _selectedCustomerId = filteredCustomers.first.id;
    }

    final selectedCustomer = customers.cast<Customer?>().firstWhere(
      (c) => c?.id == _selectedCustomerId,
      orElse: () => null,
    );

    final selectedEntries = selectedCustomer != null
        ? ref.read(ledgerProvider.notifier).getCustomerEntries(selectedCustomer.id)
        : <LedgerEntry>[];

    final totalOutstanding = customers.fold(0.0, (sum, c) {
      final bal = ref.read(ledgerProvider.notifier).getCustomerBalance(c.id);
      return sum + (bal > 0 ? bal : 0);
    });

    return Scaffold(
      appBar: AppBar(
        title: const Text('Customer Credit Ledger (Khata)'),
        actions: [
          Center(
            child: Container(
              margin: const EdgeInsets.only(right: 16),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.red.shade200),
              ),
              child: Text(
                'Total Pending Credit: ₹${totalOutstanding.toStringAsFixed(2)}',
                style: TextStyle(
                  color: Colors.red.shade800,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ),
          ),
        ],
      ),
      body: Row(
        children: [
          // Left Sidebar: Customers List
          Container(
            width: 360,
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(right: BorderSide(color: AppColors.border)),
            ),
            child: Column(
              children: [
                // Search box
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: TextField(
                    controller: _searchController,
                    onChanged: (val) => setState(() => _search = val),
                    decoration: InputDecoration(
                      hintText: 'Search customer by name or phone...',
                      prefixIcon: const Icon(Icons.search, size: 20),
                      isDense: true,
                      filled: true,
                      fillColor: AppColors.background,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ),
                const Divider(height: 1),

                // Customer Tiles
                Expanded(
                  child: ListView.separated(
                    itemCount: filteredCustomers.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final customer = filteredCustomers[index];
                      final balance = ref.read(ledgerProvider.notifier).getCustomerBalance(customer.id);
                      final isSelected = customer.id == _selectedCustomerId;

                      return ListTile(
                        selected: isSelected,
                        selectedTileColor: AppColors.primaryLight.withOpacity(0.5),
                        title: Text(
                          customer.name,
                          style: TextStyle(
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                            fontSize: 14,
                          ),
                        ),
                        subtitle: Text(
                          customer.phone,
                          style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                        ),
                        trailing: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              '₹${balance.toStringAsFixed(0)}',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                                color: balance > 0 ? Colors.red.shade700 : AppColors.statusAvailable,
                              ),
                            ),
                            Text(
                              balance > 0 ? 'Pending' : 'Settled',
                              style: TextStyle(
                                fontSize: 10,
                                color: balance > 0 ? Colors.red.shade700 : AppColors.statusAvailable,
                              ),
                            ),
                          ],
                        ),
                        onTap: () {
                          setState(() {
                            _selectedCustomerId = customer.id;
                          });
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),

          // Right Panel: Selected Customer Ledger Transactions
          Expanded(
            child: selectedCustomer == null
                ? const Center(child: Text('Select a customer to view ledger.'))
                : Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Customer Profile Card
                        Card(
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Row(
                              children: [
                                CircleAvatar(
                                  radius: 26,
                                  backgroundColor: AppColors.primaryLight,
                                  child: Text(
                                    selectedCustomer.name.isNotEmpty ? selectedCustomer.name[0] : 'C',
                                    style: const TextStyle(
                                      color: AppColors.primary,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 20,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        selectedCustomer.name,
                                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                                      ),
                                      Text(
                                        'Phone: ${selectedCustomer.phone}  •  ${selectedCustomer.notes ?? 'No special notes'}',
                                        style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
                                      ),
                                    ],
                                  ),
                                ),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    const Text('Derived Balance', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                                    Text(
                                      '₹${ref.read(ledgerProvider.notifier).getCustomerBalance(selectedCustomer.id).toStringAsFixed(2)}',
                                      style: TextStyle(
                                        fontSize: 22,
                                        fontWeight: FontWeight.bold,
                                        color: ref.read(ledgerProvider.notifier).getCustomerBalance(selectedCustomer.id) > 0
                                            ? Colors.red.shade700
                                            : AppColors.statusAvailable,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Action Bar: WhatsApp reminder & Settle Payment & CSV
                        Row(
                          children: [
                            ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF25D366), // WhatsApp Green
                              ),
                              icon: const Icon(Icons.chat, size: 18),
                              label: const Text('Send WhatsApp Reminder'),
                              onPressed: () async {
                                final bal = ref.read(ledgerProvider.notifier).getCustomerBalance(selectedCustomer.id);
                                if (bal <= 0) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('Customer balance is already settled!')),
                                  );
                                  return;
                                }
                                await WhatsAppService.sendPendingBalanceReminder(
                                  phone: selectedCustomer.phone,
                                  customerName: selectedCustomer.name,
                                  pendingBalance: bal,
                                  restaurantName: settings.restaurantName,
                                );
                              },
                            ),
                            const SizedBox(width: 12),
                            OutlinedButton.icon(
                              icon: const Icon(Icons.add_card, size: 18),
                              label: const Text('Record Payment / Settlement'),
                              onPressed: () {
                                _showPaymentCollectionDialog(context, selectedCustomer);
                              },
                            ),
                            const Spacer(),
                            IconButton.outlined(
                              icon: const Icon(Icons.file_download_outlined),
                              tooltip: 'Export Statement to CSV / Excel',
                              onPressed: () {
                                final csvData = ExportService.generateCustomerLedgerCsv(
                                  customer: selectedCustomer,
                                  entries: selectedEntries,
                                );
                                showDialog(
                                  context: context,
                                  builder: (_) => AlertDialog(
                                    title: Text('Export for ${selectedCustomer.name}'),
                                    content: SizedBox(
                                      width: 500,
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
                          ],
                        ),
                        const SizedBox(height: 16),

                        // Ledger Table
                        const Text(
                          'Transaction History (Immutable Double-Entry Ledger)',
                          style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),

                        Expanded(
                          child: selectedEntries.isEmpty
                              ? const Center(child: Text('No transactions recorded for this customer.'))
                              : Card(
                                  child: ListView.separated(
                                    itemCount: selectedEntries.length,
                                    separatorBuilder: (_, __) => const Divider(height: 1),
                                    itemBuilder: (context, idx) {
                                      final entry = selectedEntries[idx];
                                      final isDebit = entry.type == LedgerType.debit;
                                      final dateFormat = DateFormat('dd MMM yyyy, hh:mm a');

                                      return ListTile(
                                        leading: CircleAvatar(
                                          backgroundColor: isDebit ? Colors.red.shade50 : Colors.green.shade50,
                                          child: Icon(
                                            isDebit ? Icons.arrow_upward : Icons.arrow_downward,
                                            color: isDebit ? Colors.red : Colors.green,
                                            size: 18,
                                          ),
                                        ),
                                        title: Text(
                                          entry.description,
                                          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                                        ),
                                        subtitle: Text(
                                          '${entry.referenceType}: ${entry.referenceNumber}  •  ${dateFormat.format(entry.date)}',
                                          style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                                        ),
                                        trailing: Text(
                                          '${isDebit ? "+ ₹" : "- ₹"}${entry.amount.toStringAsFixed(2)}',
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 15,
                                            color: isDebit ? Colors.red.shade700 : AppColors.statusAvailable,
                                          ),
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

  void _showPaymentCollectionDialog(BuildContext context, Customer customer) {
    final amountController = TextEditingController();
    final refController = TextEditingController();
    String method = 'UPI';

    showDialog(
      context: context,
      builder: (_) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return AlertDialog(
              title: Text('Record Payment from ${customer.name}'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: amountController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Amount Received (₹)',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: method,
                    decoration: const InputDecoration(
                      labelText: 'Payment Mode',
                      border: OutlineInputBorder(),
                    ),
                    items: const [
                      DropdownMenuItem(value: 'UPI', child: Text('UPI (GPay, PhonePe, Paytm)')),
                      DropdownMenuItem(value: 'Cash', child: Text('Cash')),
                      DropdownMenuItem(value: 'Bank Transfer', child: Text('Bank Transfer / NEFT')),
                    ],
                    onChanged: (val) {
                      if (val != null) setModalState(() => method = val);
                    },
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: refController,
                    decoration: const InputDecoration(
                      labelText: 'Reference Number / UTR / Note',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () {
                    final amt = double.tryParse(amountController.text) ?? 0.0;
                    if (amt <= 0) return;

                    ref.read(ledgerProvider.notifier).addEntry(
                          LedgerEntry(
                            id: _uuid.v4(),
                            customerId: customer.id,
                            type: LedgerType.credit, // reduces outstanding debt
                            amount: amt,
                            referenceType: 'PAYMENT',
                            referenceNumber: refController.text.trim().isNotEmpty ? refController.text.trim() : 'REC-${DateTime.now().millisecondsSinceEpoch.toString().substring(8)}',
                            description: '$method Payment Received',
                          ),
                        );

                    Navigator.of(context).pop();
                    setState(() {});
                  },
                  child: const Text('Save Settlement'),
                ),
              ],
            );
          },
        );
      },
    );
  }
}
