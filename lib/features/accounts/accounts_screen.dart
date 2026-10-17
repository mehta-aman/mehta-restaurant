import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
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
  String _txFilter = 'ALL'; // 'ALL', 'BILLS', 'PAYMENTS'
  final Set<String> _selectedEntryIds = {}; // For simultaneous batch operations
  bool _mobileShowDetail = false; // For mobile master-detail navigation

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

    // Default select first customer if none selected or if selected customer was deleted
    if ((_selectedCustomerId == null || !customers.any((c) => c.id == _selectedCustomerId)) &&
        filteredCustomers.isNotEmpty) {
      _selectedCustomerId = filteredCustomers.first.id;
      _selectedEntryIds.clear();
    } else if (customers.isEmpty) {
      _selectedCustomerId = null;
      _selectedEntryIds.clear();
    }

    final Customer? selectedCustomer = () {
      for (final c in customers) {
        if (c.id == _selectedCustomerId) return c;
      }
      return null;
    }();

    final selectedEntries = selectedCustomer != null
        ? ref.read(ledgerProvider.notifier).getCustomerEntries(selectedCustomer.id)
        : <LedgerEntry>[];

    final totalOutstanding = customers.fold(0.0, (sum, c) {
      final bal = ref.read(ledgerProvider.notifier).getCustomerBalance(c.id);
      return sum + (bal > 0 ? bal : 0);
    });

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 750;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          isMobile && _mobileShowDetail && selectedCustomer != null
              ? '${selectedCustomer.name}\'s Khata'
              : 'Credit Ledger (Khata)',
          style: const TextStyle(fontSize: 16),
        ),
        leading: isMobile && _mobileShowDetail
            ? IconButton(
                icon: const Icon(Icons.arrow_back),
                tooltip: 'Back to Accounts',
                onPressed: () => setState(() => _mobileShowDetail = false),
              )
            : null,
        actions: [
          if (isMobile) ...[
            IconButton(
              icon: const Icon(Icons.person_add_alt_1, size: 20),
              tooltip: 'New Customer',
              onPressed: () => _showAddCustomerDialog(context),
            ),
            IconButton(
              icon: const Icon(Icons.post_add, size: 22, color: Color(0xFFDC2626)),
              tooltip: 'Add Bill',
              onPressed: () => _showAddBillDialog(context, selectedCustomer),
            ),
          ] else ...[
            FilledButton.tonalIcon(
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                visualDensity: VisualDensity.compact,
              ),
              icon: const Icon(Icons.person_add_alt_1, size: 16),
              label: const Text('New Customer', style: TextStyle(fontSize: 12)),
              onPressed: () => _showAddCustomerDialog(context),
            ),
            const SizedBox(width: 8),
            FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: isDark ? const Color(0xFFDC2626) : const Color(0xFFB91C1C),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                visualDensity: VisualDensity.compact,
              ),
              icon: const Icon(Icons.post_add, size: 16),
              label: const Text('+ Add Bill', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
              onPressed: () => _showAddBillDialog(context, selectedCustomer),
            ),
            const SizedBox(width: 8),
          ],

          IconButton(
            icon: Icon(
              isDark ? Icons.light_mode : Icons.dark_mode,
            ),
            tooltip: 'Switch Theme',
            onPressed: () => ref.read(themeModeProvider.notifier).toggleTheme(),
          ),
          if (!isMobile)
            Center(
              child: Container(
                margin: const EdgeInsets.only(right: 16),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF4C0519) : Colors.red.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: isDark ? const Color(0xFF881337) : Colors.red.shade200),
                ),
                child: Text(
                  'Pending: ₹${totalOutstanding.toStringAsFixed(0)}',
                  style: TextStyle(
                    color: isDark ? const Color(0xFFFDA4AF) : Colors.red.shade800,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
              ),
            ),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isMobile = constraints.maxWidth < 750;

          final customersListWidget = Container(
            width: isMobile ? double.infinity : 360,
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              border: isMobile ? null : Border(right: BorderSide(color: Theme.of(context).dividerColor)),
            ),
            child: Column(
              children: [
                if (isMobile)
                  Container(
                    margin: const EdgeInsets.fromLTRB(14, 10, 14, 4),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF4C0519) : Colors.red.shade50,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: isDark ? const Color(0xFF881337) : Colors.red.shade200),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            'Total Pending Credit Across Store:',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: isDark ? const Color(0xFFFDA4AF) : Colors.red.shade800,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '₹${totalOutstanding.toStringAsFixed(0)}',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: isDark ? const Color(0xFFFDA4AF) : Colors.red.shade900,
                          ),
                        ),
                      ],
                    ),
                  ),
                // Top Header Row with Add Customer button
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 14, 12, 6),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          'Accounts (${filteredCustomers.length})',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          visualDensity: VisualDensity.compact,
                        ),
                        icon: const Icon(Icons.person_add_alt_1, size: 15),
                        label: const Text('Add Account', style: TextStyle(fontSize: 12)),
                        onPressed: () => _showAddCustomerDialog(context),
                      ),
                    ],
                  ),
                ),

                // Search box
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  child: TextField(
                    controller: _searchController,
                    onChanged: (val) => setState(() => _search = val),
                    decoration: InputDecoration(
                      hintText: 'Search customer by name or phone...',
                      prefixIcon: const Icon(Icons.search, size: 20),
                      suffixIcon: _search.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear, size: 16),
                              onPressed: () {
                                _searchController.clear();
                                setState(() => _search = '');
                              },
                            )
                          : null,
                      isDense: true,
                      filled: true,
                      fillColor: isDark ? const Color(0xFF1E293B) : AppColors.borderSubtle,
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
                  child: filteredCustomers.isEmpty
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.all(24),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.person_off_outlined, size: 40, color: AppColors.textSecondary),
                                const SizedBox(height: 12),
                                Text(
                                  _search.isNotEmpty ? 'No customers match "$_search"' : 'No customers in credit ledger',
                                  style: const TextStyle(fontWeight: FontWeight.bold),
                                  textAlign: TextAlign.center,
                                ),
                                const SizedBox(height: 8),
                                ElevatedButton.icon(
                                  icon: const Icon(Icons.person_add_alt_1, size: 16),
                                  label: const Text('Add First Customer'),
                                  onPressed: () => _showAddCustomerDialog(context),
                                ),
                              ],
                            ),
                          ),
                        )
                      : ListView.separated(
                          itemCount: filteredCustomers.length,
                          separatorBuilder: (_, _) => const Divider(height: 1),
                          itemBuilder: (context, index) {
                            final customer = filteredCustomers[index];
                            final balance = ref.read(ledgerProvider.notifier).getCustomerBalance(customer.id);
                            final isSelected = customer.id == _selectedCustomerId;

                            return Material(
                              color: Colors.transparent,
                              child: ListTile(
                                selected: isSelected,
                                selectedTileColor: isDark
                                    ? AppColors.primary.withValues(alpha: 0.18)
                                    : AppColors.primaryLight.withValues(alpha: 0.6),
                                leading: CircleAvatar(
                                  backgroundColor: isDark ? const Color(0xFF334155) : AppColors.primaryLight,
                                  child: Text(
                                    customer.name.isNotEmpty ? customer.name[0].toUpperCase() : 'C',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: isDark ? const Color(0xFFFF7043) : AppColors.primary,
                                    ),
                                  ),
                                ),
                                title: Text(
                                  customer.name,
                                  style: TextStyle(
                                    fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                                    fontSize: 14,
                                  ),
                                ),
                                subtitle: Text(
                                  customer.phone,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary,
                                  ),
                                ),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      crossAxisAlignment: CrossAxisAlignment.end,
                                      children: [
                                        Text(
                                          '₹${balance.toStringAsFixed(0)}',
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 14,
                                            color: balance > 0
                                                ? (isDark ? const Color(0xFFF87171) : Colors.red.shade700)
                                                : (isDark ? const Color(0xFF34D399) : AppColors.statusAvailable),
                                          ),
                                        ),
                                        Container(
                                          margin: const EdgeInsets.only(top: 2),
                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                                          decoration: BoxDecoration(
                                            color: balance > 0
                                                ? (isDark ? const Color(0xFF4C0519) : Colors.red.shade50)
                                                : (isDark ? const Color(0xFF064E3B) : Colors.green.shade50),
                                            borderRadius: BorderRadius.circular(4),
                                          ),
                                          child: Text(
                                            balance > 0 ? 'Pending' : 'Settled',
                                            style: TextStyle(
                                              fontSize: 10,
                                              fontWeight: FontWeight.w600,
                                              color: balance > 0
                                                  ? (isDark ? const Color(0xFFF87171) : Colors.red.shade700)
                                                  : (isDark ? const Color(0xFF34D399) : AppColors.statusAvailable),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(width: 4),
                                    PopupMenuButton<String>(
                                      icon: const Icon(Icons.more_vert, size: 18),
                                      tooltip: 'Customer Options',
                                      onSelected: (val) {
                                        if (val == 'edit') {
                                          _showEditCustomerDialog(context, customer);
                                        } else if (val == 'delete') {
                                          _showDeleteCustomerDialog(context, customer);
                                        }
                                      },
                                      itemBuilder: (_) => [
                                        const PopupMenuItem(
                                          value: 'edit',
                                          child: Row(
                                            children: [
                                              Icon(Icons.edit_outlined, size: 16),
                                              SizedBox(width: 8),
                                              Text('Edit Profile'),
                                            ],
                                          ),
                                        ),
                                        const PopupMenuItem(
                                          value: 'delete',
                                          child: Row(
                                            children: [
                                              Icon(Icons.delete_outline, size: 16, color: Colors.red),
                                              SizedBox(width: 8),
                                              Text('Delete Account', style: TextStyle(color: Colors.red)),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                                onTap: () {
                                  setState(() {
                                    _selectedCustomerId = customer.id;
                                    _selectedEntryIds.clear();
                                    _mobileShowDetail = true;
                                  });
                                },
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
          );

          if (isMobile) {
            if (_mobileShowDetail && selectedCustomer != null) {
              return _buildCustomerLedgerView(
                context,
                ref,
                selectedCustomer,
                selectedEntries,
                settings,
                isMobile: true,
              );
            }
            return customersListWidget;
          }

          return Row(
            children: [
              customersListWidget,
              // Right Panel: Selected Customer Ledger Transactions & Simultaneous Batch Management
              Expanded(
                child: selectedCustomer == null
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.account_balance_wallet_outlined, size: 54, color: AppColors.textSecondary),
                            const SizedBox(height: 12),
                            const Text(
                              'Select or create a customer to view and manage their credit ledger',
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 12),
                            ElevatedButton.icon(
                              icon: const Icon(Icons.person_add_alt_1),
                              label: const Text('Add New Customer Account'),
                              onPressed: () => _showAddCustomerDialog(context),
                            ),
                          ],
                        ),
                      )
                    : _buildCustomerLedgerView(
                        context,
                        ref,
                        selectedCustomer,
                        selectedEntries,
                        settings,
                        isMobile: false,
                      ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildCustomerLedgerView(
    BuildContext context,
    WidgetRef ref,
    Customer customer,
    List<LedgerEntry> selectedEntries,
    RestaurantSettings settings, {
    bool isMobile = false,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final balance = ref.read(ledgerProvider.notifier).getCustomerBalance(customer.id);

    // Filter transactions
    final filteredEntries = selectedEntries.where((entry) {
      if (_txFilter == 'BILLS') return entry.type == LedgerType.debit;
      if (_txFilter == 'PAYMENTS') return entry.type == LedgerType.credit;
      return true;
    }).toList();

    final billsCount = selectedEntries.where((e) => e.type == LedgerType.debit).length;
    final paymentsCount = selectedEntries.where((e) => e.type == LedgerType.credit).length;
    final totalBilled = selectedEntries.where((e) => e.type == LedgerType.debit).fold(0.0, (sum, e) => sum + e.amount);
    final totalPaid = selectedEntries.where((e) => e.type == LedgerType.credit).fold(0.0, (sum, e) => sum + e.amount);

    // Selected entries objects
    final activeSelectedEntries = filteredEntries.where((e) => _selectedEntryIds.contains(e.id)).toList();
    final selectedTotalAmount = activeSelectedEntries.fold(0.0, (sum, e) => sum + e.amount);

    return Padding(
      padding: EdgeInsets.all(isMobile ? 12 : 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (isMobile)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: InkWell(
                onTap: () => setState(() => _mobileShowDetail = false),
                borderRadius: BorderRadius.circular(8),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: const [
                      Icon(Icons.arrow_back_ios, size: 14, color: AppColors.primary),
                      SizedBox(width: 4),
                      Flexible(
                        child: Text(
                          'All Customer Accounts',
                          style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold, fontSize: 13),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

          // Customer Profile Header Card
          Card(
            child: LayoutBuilder(
              builder: (context, cardConstraints) {
                final isNarrow = isMobile || cardConstraints.maxWidth < 620;
                return Padding(
                  padding: EdgeInsets.all(isNarrow ? 12 : 16),
                  child: isNarrow
                      ? Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            CircleAvatar(
                              radius: 22,
                              backgroundColor: isDark ? const Color(0xFF334155) : AppColors.primaryLight,
                              child: Text(
                                customer.name.isNotEmpty ? customer.name[0].toUpperCase() : 'C',
                                style: TextStyle(
                                  color: isDark ? const Color(0xFFFF7043) : AppColors.primary,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 18,
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    customer.name,
                                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                                  ),
                                  Text(
                                    customer.phone,
                                    style: TextStyle(
                                      color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.edit_outlined, size: 18),
                              tooltip: 'Edit Customer Details',
                              onPressed: () => _showEditCustomerDialog(context, customer),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete_outline, size: 18, color: Colors.red),
                              tooltip: 'Delete Customer Account',
                              onPressed: () => _showDeleteCustomerDialog(context, customer),
                            ),
                          ],
                        ),
                        const Divider(height: 16),
                        Wrap(
                          alignment: WrapAlignment.spaceBetween,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          spacing: 8,
                          runSpacing: 4,
                          children: [
                            Text(
                              'Billed: ₹${totalBilled.toStringAsFixed(0)} • Paid: ₹${totalPaid.toStringAsFixed(0)}',
                              style: TextStyle(
                                fontSize: 11,
                                color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary,
                              ),
                            ),
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Text('Pending: ', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                                Text(
                                  '₹${balance.toStringAsFixed(2)}',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: balance > 0
                                        ? (isDark ? const Color(0xFFF87171) : Colors.red.shade700)
                                        : (isDark ? const Color(0xFF34D399) : AppColors.statusAvailable),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ],
                    )
                  : Row(
                      children: [
                        CircleAvatar(
                          radius: 28,
                          backgroundColor: isDark ? const Color(0xFF334155) : AppColors.primaryLight,
                          child: Text(
                            customer.name.isNotEmpty ? customer.name[0].toUpperCase() : 'C',
                            style: TextStyle(
                              color: isDark ? const Color(0xFFFF7043) : AppColors.primary,
                              fontWeight: FontWeight.bold,
                              fontSize: 22,
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Row(
                                      children: [
                                        Flexible(
                                          child: Text(
                                            customer.name,
                                            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                        if (customer.notes != null && customer.notes!.isNotEmpty) ...[
                                          const SizedBox(width: 8),
                                          Flexible(
                                            child: Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                              decoration: BoxDecoration(
                                                color: AppColors.primary.withValues(alpha: 0.12),
                                                borderRadius: BorderRadius.circular(6),
                                              ),
                                              child: Text(
                                                customer.notes!,
                                                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.primary),
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.edit_outlined, size: 20),
                                    tooltip: 'Edit Customer Details',
                                    onPressed: () => _showEditCustomerDialog(context, customer),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.delete_outline, size: 20, color: Colors.red),
                                    tooltip: 'Delete Customer Account',
                                    onPressed: () => _showDeleteCustomerDialog(context, customer),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Wrap(
                                spacing: 12,
                                runSpacing: 4,
                                crossAxisAlignment: WrapCrossAlignment.center,
                                children: [
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(Icons.phone_outlined, size: 14, color: AppColors.textSecondary),
                                      const SizedBox(width: 4),
                                      Text(
                                        customer.phone,
                                        style: TextStyle(
                                          color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary,
                                          fontSize: 13,
                                        ),
                                      ),
                                    ],
                                  ),
                                  Text(
                                    'Total Billed: ₹${totalBilled.toStringAsFixed(0)}  •  Paid: ₹${totalPaid.toStringAsFixed(0)}',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 16),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              'Outstanding Balance',
                              style: TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w600,
                                color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '₹${balance.toStringAsFixed(2)}',
                              style: TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.w800,
                                color: balance > 0
                                    ? (isDark ? const Color(0xFFF87171) : Colors.red.shade700)
                                    : (isDark ? const Color(0xFF34D399) : AppColors.statusAvailable),
                              ),
                            ),
                            const SizedBox(height: 6),
                            ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF25D366),
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                visualDensity: VisualDensity.compact,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              ),
                              icon: const Icon(Icons.chat, size: 13),
                              label: const Text('Send Reminder', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                              onPressed: () async {
                                final currentBal = ref.read(ledgerProvider.notifier).getCustomerBalance(customer.id);
                                if (currentBal <= 0) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('Customer balance is already fully settled!')),
                                  );
                                  return;
                                }
                                await WhatsAppService.sendPendingBalanceReminder(
                                  phone: customer.phone,
                                  customerName: customer.name,
                                  pendingBalance: currentBal,
                                  restaurantName: settings.restaurantName,
                                );
                              },
                            ),
                          ],
                        ),
                      ],
                    ),
                );
              },
            ),
          ),
          const SizedBox(height: 14),

          // Action Bar: Add Pending Bill, Record Payment, WhatsApp reminder, Export CSV
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                // 1. ADD PENDING BILL (Primary Red Action)
                FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: isDark ? const Color(0xFFDC2626) : const Color(0xFFB91C1C),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  ),
                  icon: const Icon(Icons.post_add, size: 18),
                  label: const Text('Add Pending Bill / Debit', style: TextStyle(fontWeight: FontWeight.bold)),
                  onPressed: () {
                    _showAddBillDialog(context, customer);
                  },
                ),
                const SizedBox(width: 8),

                // 2. RECORD PAYMENT / SETTLEMENT
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  ),
                  icon: const Icon(Icons.payments_outlined, size: 18),
                  label: const Text('Record Payment / Settlement'),
                  onPressed: () {
                    _showPaymentCollectionDialog(context, customer);
                  },
                ),
                const SizedBox(width: 8),

                // 3. WHATSAPP REMINDER
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF25D366), // WhatsApp Green
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  ),
                  icon: const Icon(Icons.chat, size: 18),
                  label: const Text('WhatsApp Balance Reminder'),
                  onPressed: () async {
                    final currentBal = ref.read(ledgerProvider.notifier).getCustomerBalance(customer.id);
                    if (currentBal <= 0) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Customer balance is already fully settled!')),
                      );
                      return;
                    }
                    await WhatsAppService.sendPendingBalanceReminder(
                      phone: customer.phone,
                      customerName: customer.name,
                      pendingBalance: currentBal,
                      restaurantName: settings.restaurantName,
                    );
                  },
                ),
                const SizedBox(width: 8),

                // 4. EXPORT TO CSV
                IconButton.outlined(
                  icon: const Icon(Icons.file_download_outlined),
                  tooltip: 'Export Statement to CSV / Excel',
                  onPressed: () {
                    final csvData = ExportService.generateCustomerLedgerCsv(
                      customer: customer,
                      entries: selectedEntries,
                    );
                    showDialog(
                      context: context,
                      builder: (_) => AlertDialog(
                        insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
                        title: Text('Ledger Statement for ${customer.name}'),
                        content: Container(
                          constraints: const BoxConstraints(maxWidth: 500),
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
          ),
          const SizedBox(height: 14),

          // Simultaneous Batch Management Bar (Shows when 1 or more items selected)
          if (_selectedEntryIds.isNotEmpty)
            LayoutBuilder(
              builder: (context, constraints) {
                final isCompact = constraints.maxWidth < 620;
                if (isCompact) {
                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF1E293B) : Colors.indigo.shade50,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: isDark ? AppColors.darkBorder : Colors.indigo.shade200),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.check_circle, size: 18, color: isDark ? Colors.indigo.shade300 : Colors.indigo),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                '${_selectedEntryIds.length} selected (₹${selectedTotalAmount.toStringAsFixed(2)})',
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.close, size: 18),
                              tooltip: 'Clear Selection',
                              visualDensity: VisualDensity.compact,
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                              onPressed: () => setState(() => _selectedEntryIds.clear()),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            FilledButton.tonalIcon(
                              style: FilledButton.styleFrom(
                                backgroundColor: const Color(0xFF16A34A).withValues(alpha: 0.15),
                                foregroundColor: const Color(0xFF16A34A),
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                visualDensity: VisualDensity.compact,
                              ),
                              icon: const Icon(Icons.done_all, size: 15),
                              label: const Text('Settle Selected', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                              onPressed: () => _showBatchSettleDialog(context, customer, activeSelectedEntries),
                            ),
                            FilledButton.icon(
                              style: FilledButton.styleFrom(
                                backgroundColor: Colors.red.shade700,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                visualDensity: VisualDensity.compact,
                              ),
                              icon: const Icon(Icons.delete_sweep, size: 15),
                              label: Text('Delete (${_selectedEntryIds.length})', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                              onPressed: () => _showBatchDeleteDialog(context, activeSelectedEntries),
                            ),
                          ],
                        ),
                      ],
                    ),
                  );
                }
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1E293B) : Colors.indigo.shade50,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: isDark ? AppColors.darkBorder : Colors.indigo.shade200),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.check_circle, size: 20, color: isDark ? Colors.indigo.shade300 : Colors.indigo),
                      const SizedBox(width: 8),
                      Text(
                        '${_selectedEntryIds.length} bills/entries selected',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        'Total: ₹${selectedTotalAmount.toStringAsFixed(2)}',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                          color: isDark ? Colors.indigo.shade200 : Colors.indigo.shade900,
                        ),
                      ),
                      const Spacer(),
                      FilledButton.tonalIcon(
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFF16A34A).withValues(alpha: 0.15),
                          foregroundColor: const Color(0xFF16A34A),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          visualDensity: VisualDensity.compact,
                        ),
                        icon: const Icon(Icons.done_all, size: 16),
                        label: const Text('Settle Selected', style: TextStyle(fontWeight: FontWeight.bold)),
                        onPressed: () => _showBatchSettleDialog(context, customer, activeSelectedEntries),
                      ),
                      const SizedBox(width: 8),
                      FilledButton.icon(
                        style: FilledButton.styleFrom(
                          backgroundColor: Colors.red.shade700,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          visualDensity: VisualDensity.compact,
                        ),
                        icon: const Icon(Icons.delete_sweep, size: 16),
                        label: Text('Delete (${_selectedEntryIds.length}) Simultaneously', style: const TextStyle(fontWeight: FontWeight.bold)),
                        onPressed: () => _showBatchDeleteDialog(context, activeSelectedEntries),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        icon: const Icon(Icons.close, size: 18),
                        tooltip: 'Clear Selection',
                        onPressed: () => setState(() => _selectedEntryIds.clear()),
                      ),
                    ],
                  ),
                );
              },
            ),

          // Transaction History Header & Filter Chips
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 8,
            runSpacing: 6,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Checkbox(
                    value: filteredEntries.isNotEmpty && _selectedEntryIds.length == filteredEntries.length,
                    tristate: _selectedEntryIds.isNotEmpty && _selectedEntryIds.length < filteredEntries.length,
                    onChanged: (val) {
                      setState(() {
                        if (val == true) {
                          _selectedEntryIds.addAll(filteredEntries.map((e) => e.id));
                        } else {
                          _selectedEntryIds.clear();
                        }
                      });
                    },
                  ),
                  Flexible(
                    child: Text(
                      isMobile ? 'Ledger History' : 'Transaction Ledger History',
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: [
                  ChoiceChip(
                    label: Text('All (${selectedEntries.length})', style: const TextStyle(fontSize: 12)),
                    selected: _txFilter == 'ALL',
                    onSelected: (val) => setState(() => _txFilter = 'ALL'),
                  ),
                  ChoiceChip(
                    label: Text('Bills ($billsCount)', style: const TextStyle(fontSize: 12)),
                    selected: _txFilter == 'BILLS',
                    onSelected: (val) => setState(() => _txFilter = 'BILLS'),
                  ),
                  ChoiceChip(
                    label: Text('Payments ($paymentsCount)', style: const TextStyle(fontSize: 12)),
                    selected: _txFilter == 'PAYMENTS',
                    onSelected: (val) => setState(() => _txFilter = 'PAYMENTS'),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Ledger Table / List
          Expanded(
            child: filteredEntries.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            _txFilter == 'BILLS' ? Icons.receipt_long_outlined : Icons.account_balance_wallet_outlined,
                            size: 40,
                            color: AppColors.textSecondary,
                          ),
                          const SizedBox(height: 10),
                          Text(
                            _txFilter == 'BILLS'
                                ? 'No pending bills recorded for ${customer.name}.'
                                : (_txFilter == 'PAYMENTS' ? 'No payment settlements recorded yet.' : 'No transactions recorded for this customer.'),
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 8),
                          FilledButton.icon(
                            style: FilledButton.styleFrom(
                              backgroundColor: isDark ? const Color(0xFFDC2626) : const Color(0xFFB91C1C),
                              foregroundColor: Colors.white,
                            ),
                            icon: const Icon(Icons.post_add, size: 16),
                            label: const Text('Add First Pending Bill'),
                            onPressed: () => _showAddBillDialog(context, customer),
                          ),
                        ],
                      ),
                    ),
                  )
                : Card(
                    child: ListView.separated(
                      itemCount: filteredEntries.length,
                      separatorBuilder: (_, _) => const Divider(height: 1),
                      itemBuilder: (context, idx) {
                        final entry = filteredEntries[idx];
                        final isDebit = entry.type == LedgerType.debit;
                        final dateFormat = DateFormat('dd MMM yyyy, hh:mm a');
                        final isChecked = _selectedEntryIds.contains(entry.id);

                        return Material(
                          color: isChecked
                              ? (isDark
                                  ? Colors.indigo.withValues(alpha: 0.22)
                                  : Colors.indigo.shade50)
                              : Colors.transparent,
                          child: ListTile(
                            contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            leading: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Checkbox(
                                  value: isChecked,
                                  onChanged: (val) {
                                    setState(() {
                                      if (val == true) {
                                        _selectedEntryIds.add(entry.id);
                                      } else {
                                        _selectedEntryIds.remove(entry.id);
                                      }
                                    });
                                  },
                                ),
                                CircleAvatar(
                                  radius: 16,
                                  backgroundColor: isDebit
                                      ? (isDark ? const Color(0xFF4C0519) : Colors.red.shade50)
                                      : (isDark ? const Color(0xFF064E3B) : Colors.green.shade50),
                                  child: Icon(
                                    isDebit ? Icons.arrow_upward : Icons.arrow_downward,
                                    color: isDebit
                                        ? (isDark ? const Color(0xFFF87171) : Colors.red)
                                        : (isDark ? const Color(0xFF34D399) : Colors.green),
                                    size: 16,
                                  ),
                                ),
                              ],
                            ),
                            title: Text(
                              entry.description,
                              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            subtitle: Text(
                              '${entry.referenceType}: ${entry.referenceNumber}  •  ${dateFormat.format(entry.date)}',
                              style: TextStyle(
                                fontSize: 11.5,
                                color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Text(
                                      '${isDebit ? "+ ₹" : "- ₹"}${entry.amount.toStringAsFixed(2)}',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 13,
                                        color: isDebit
                                            ? (isDark ? const Color(0xFFF87171) : Colors.red.shade700)
                                            : (isDark ? const Color(0xFF34D399) : AppColors.statusAvailable),
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                                      decoration: BoxDecoration(
                                        color: isDebit
                                            ? (isDark ? const Color(0xFF4C0519) : Colors.red.shade50)
                                            : (isDark ? const Color(0xFF064E3B) : Colors.green.shade50),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(
                                        isDebit ? 'PENDING' : 'SETTLED',
                                        style: TextStyle(
                                          fontSize: 9,
                                          fontWeight: FontWeight.bold,
                                          color: isDebit
                                              ? (isDark ? const Color(0xFFF87171) : Colors.red.shade800)
                                              : (isDark ? const Color(0xFF34D399) : AppColors.statusAvailable),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(width: 4),
                                PopupMenuButton<String>(
                                  icon: const Icon(Icons.more_vert, size: 18),
                                  tooltip: 'Bill Actions',
                                  onSelected: (action) {
                                    if (action == 'edit') {
                                      _showEditBillDialog(context, entry);
                                    } else if (action == 'delete') {
                                      _showDeleteSingleBillDialog(context, entry);
                                    }
                                  },
                                  itemBuilder: (_) => [
                                    const PopupMenuItem(
                                      value: 'edit',
                                      child: Row(
                                        children: [
                                          Icon(Icons.edit_outlined, size: 16),
                                          SizedBox(width: 8),
                                          Text('Edit Bill / Entry'),
                                        ],
                                      ),
                                    ),
                                    const PopupMenuItem(
                                      value: 'delete',
                                      child: Row(
                                        children: [
                                          Icon(Icons.delete_outline, size: 16, color: Colors.red),
                                          SizedBox(width: 8),
                                          Text('Delete Bill', style: TextStyle(color: Colors.red)),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  // --- DIALOG 1: ADD NEW CUSTOMER TO KHATA ---
  void _showAddCustomerDialog(BuildContext context) {
    final nameController = TextEditingController();
    final phoneController = TextEditingController();
    final notesController = TextEditingController();
    final openingBalController = TextEditingController();
    final billRefController = TextEditingController(text: 'OPENING-BAL');
    bool hasOpeningBalance = false;

    showDialog(
      context: context,
      builder: (dialogCtx) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        return StatefulBuilder(
          builder: (context, setModalState) {
            return AlertDialog(
              insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
              title: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.person_add_alt_1, color: AppColors.primary, size: 22),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text('Add New Customer (Khata)', overflow: TextOverflow.ellipsis),
                  ),
                ],
              ),
              content: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 480),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Create a customer ledger account to track credit orders, pending bills, and settlements.',
                        style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: nameController,
                        autofocus: true,
                        decoration: const InputDecoration(
                          labelText: 'Customer Full Name *',
                          hintText: 'e.g. Ramesh Verma, Sharma Ji',
                          prefixIcon: Icon(Icons.person_outline, size: 20),
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                      ),
                      const SizedBox(height: 14),
                      TextField(
                        controller: phoneController,
                        keyboardType: TextInputType.phone,
                        decoration: const InputDecoration(
                          labelText: 'Mobile Phone Number *',
                          hintText: 'e.g. 9829012345',
                          prefixIcon: Icon(Icons.phone_outlined, size: 20),
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                      ),
                      const SizedBox(height: 14),
                      TextField(
                        controller: notesController,
                        decoration: const InputDecoration(
                          labelText: 'Notes / Category (Optional)',
                          hintText: 'e.g. Regular VIP guest, Nearby shop, Office account',
                          prefixIcon: Icon(Icons.notes, size: 20),
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                      ),
                      const SizedBox(height: 16),
                      const Divider(height: 1),
                      const SizedBox(height: 8),

                      // Toggle for Opening / Previous Pending Bill
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text(
                          'Add Existing Pending Bill / Opening Balance',
                          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                        ),
                        subtitle: const Text(
                          'Enable if this customer already has old unpaid bills',
                          style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                        ),
                        value: hasOpeningBalance,
                        onChanged: (val) {
                          setModalState(() => hasOpeningBalance = val);
                        },
                      ),

                      if (hasOpeningBalance) ...[
                        const SizedBox(height: 10),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFF1E293B) : Colors.amber.shade50,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: isDark ? AppColors.darkBorder : Colors.amber.shade200),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              TextField(
                                controller: openingBalController,
                                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                decoration: const InputDecoration(
                                  labelText: 'Pending Bill Amount (₹) *',
                                  prefixIcon: Icon(Icons.currency_rupee, size: 18),
                                  border: OutlineInputBorder(),
                                  isDense: true,
                                ),
                              ),
                              const SizedBox(height: 10),
                              TextField(
                                controller: billRefController,
                                decoration: const InputDecoration(
                                  labelText: 'Bill / Slip Reference #',
                                  hintText: 'e.g. SLIP-101 or OPENING-BAL',
                                  prefixIcon: Icon(Icons.receipt_outlined, size: 18),
                                  border: OutlineInputBorder(),
                                  isDense: true,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogCtx).pop(),
                  child: const Text('Cancel'),
                ),
                ElevatedButton.icon(
                  icon: const Icon(Icons.check, size: 18),
                  label: const Text('Create Customer Account'),
                  onPressed: () {
                    final name = nameController.text.trim();
                    final phone = phoneController.text.trim();

                    if (name.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Please enter a customer name!')),
                      );
                      return;
                    }
                    if (phone.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Please enter a phone number!')),
                      );
                      return;
                    }

                    final newCust = ref.read(customersProvider.notifier).addCustomer(
                          name: name,
                          phone: phone,
                          notes: notesController.text.trim().isNotEmpty ? notesController.text.trim() : null,
                        );

                    if (hasOpeningBalance) {
                      final openingAmt = double.tryParse(openingBalController.text.trim()) ?? 0.0;
                      if (openingAmt > 0) {
                        final billRef = billRefController.text.trim().isNotEmpty ? billRefController.text.trim() : 'OPENING-BAL';
                        ref.read(ledgerProvider.notifier).addPendingBill(
                              customerId: newCust.id,
                              amount: openingAmt,
                              referenceNumber: billRef,
                              description: 'Opening Pending Balance / Previous Bill',
                              referenceType: 'OPENING_BALANCE',
                            );
                      }
                    }

                    Navigator.of(dialogCtx).pop();
                    setState(() {
                      _selectedCustomerId = newCust.id;
                      _search = '';
                      _searchController.clear();
                      _selectedEntryIds.clear();
                    });

                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('✅ Customer account created for ${newCust.name}!'),
                        backgroundColor: AppColors.statusAvailable,
                      ),
                    );
                  },
                ),
              ],
            );
          },
        );
      },
    );
  }

  // --- DIALOG 2: EDIT CUSTOMER DETAILS ---
  void _showEditCustomerDialog(BuildContext context, Customer customer) {
    final nameController = TextEditingController(text: customer.name);
    final phoneController = TextEditingController(text: customer.phone);
    final notesController = TextEditingController(text: customer.notes ?? '');

    showDialog(
      context: context,
      builder: (dialogCtx) {
        return AlertDialog(
          insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.edit, color: AppColors.primary, size: 20),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text('Edit Customer Profile', overflow: TextOverflow.ellipsis),
              ),
            ],
          ),
          content: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 450),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: nameController,
                    decoration: const InputDecoration(
                      labelText: 'Customer Name *',
                      prefixIcon: Icon(Icons.person_outline, size: 20),
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: phoneController,
                    decoration: const InputDecoration(
                      labelText: 'Phone Number *',
                      prefixIcon: Icon(Icons.phone_outlined, size: 20),
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: notesController,
                    decoration: const InputDecoration(
                      labelText: 'Notes / Category',
                      prefixIcon: Icon(Icons.notes, size: 20),
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogCtx).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                final name = nameController.text.trim();
                final phone = phoneController.text.trim();
                if (name.isEmpty || phone.isEmpty) return;

                ref.read(customersProvider.notifier).updateCustomer(
                      id: customer.id,
                      name: name,
                      phone: phone,
                      notes: notesController.text.trim(),
                    );

                Navigator.of(dialogCtx).pop();
                setState(() {});
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('✅ Customer profile updated!'), backgroundColor: AppColors.statusAvailable),
                );
              },
              child: const Text('Save Changes'),
            ),
          ],
        );
      },
    );
  }

  // --- DIALOG 3: DELETE CUSTOMER ACCOUNT ---
  void _showDeleteCustomerDialog(BuildContext context, Customer customer) {
    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        title: Row(
          children: const [
            Icon(Icons.warning_amber_rounded, color: Colors.red),
            SizedBox(width: 8),
            Expanded(
              child: Text('Delete Customer Account?', overflow: TextOverflow.ellipsis),
            ),
          ],
        ),
        content: Text(
          'Are you sure you want to delete ${customer.name} (${customer.phone})?\n\nThis will also remove all their transaction history and ledger records. This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogCtx).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            onPressed: () {
              ref.read(ledgerProvider.notifier).deleteEntriesForCustomer(customer.id);
              ref.read(customersProvider.notifier).deleteCustomer(customer.id);
              Navigator.of(dialogCtx).pop();
              setState(() {
                _selectedCustomerId = null;
                _selectedEntryIds.clear();
              });
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('🗑️ Customer account for ${customer.name} deleted.')),
              );
            },
            child: const Text('Delete Account'),
          ),
        ],
      ),
    );
  }

  // --- DIALOG 4: ADD PENDING BILL / DEBIT TO CUSTOMER ---
  void _showAddBillDialog(BuildContext context, [Customer? initialCustomer]) {
    final customers = ref.read(customersProvider);
    if (customers.isEmpty) {
      showDialog(
        context: context,
        builder: (dialogCtx) => AlertDialog(
          title: const Text('No Customer Accounts Found'),
          content: const Text(
            'To add a bill to the credit ledger, you must have at least one registered customer account.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogCtx).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton.icon(
              icon: const Icon(Icons.person_add_alt_1),
              label: const Text('Create Customer Account'),
              onPressed: () {
                Navigator.of(dialogCtx).pop();
                _showAddCustomerDialog(context);
              },
            ),
          ],
        ),
      );
      return;
    }

    Customer targetCustomer = initialCustomer ??
        (customers.where((c) => c.id == _selectedCustomerId).firstOrNull ?? customers.first);

    final amountController = TextEditingController();
    final billRefController = TextEditingController(
      text: 'BILL-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}',
    );
    final descController = TextEditingController();
    DateTime billDate = DateTime.now();
    String category = 'Dine-in Order';

    final categories = [
      'Dine-in Order',
      'Takeaway / Parcel',
      'Packaged Goods (Bikaji)',
      'Party / Catering',
      'Old Pending Bill',
    ];

    showDialog(
      context: context,
      builder: (dialogCtx) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        return StatefulBuilder(
          builder: (modalCtx, setModalState) {
            final dateFormat = DateFormat('dd MMM yyyy');
            return AlertDialog(
              insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
              actionsOverflowButtonSpacing: 8,
              title: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.red.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.post_add, color: Colors.red, size: 22),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text('Add Pending Bill (Debit Entry)', overflow: TextOverflow.ellipsis),
                  ),
                ],
              ),
              content: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 480),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Customer selector dropdown & live status
                      DropdownButtonFormField<String>(
                        initialValue: targetCustomer.id,
                        isExpanded: true,
                        decoration: const InputDecoration(
                          labelText: 'Select Customer Account *',
                          prefixIcon: Icon(Icons.person_outline, size: 20),
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                        items: customers.map((c) {
                          return DropdownMenuItem<String>(
                            value: c.id,
                            child: Text(
                              '${c.name} (${c.phone})',
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5),
                            ),
                          );
                        }).toList(),
                        onChanged: (val) {
                          if (val != null) {
                            setModalState(() {
                              targetCustomer = customers.firstWhere((c) => c.id == val);
                            });
                          }
                        },
                      ),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF1E293B) : AppColors.borderSubtle,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.border),
                        ),
                        child: Wrap(
                          alignment: WrapAlignment.spaceBetween,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          spacing: 8,
                          runSpacing: 4,
                          children: [
                            Text(
                              'Current Dues: ₹${ref.read(ledgerProvider.notifier).getCustomerBalance(targetCustomer.id).toStringAsFixed(0)}',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary,
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.red.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: const Text(
                                '+ Increases dues',
                                style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.red),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),

                      // Bill Amount
                      TextField(
                        controller: amountController,
                        autofocus: true,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                        decoration: const InputDecoration(
                          labelText: 'Bill Amount (₹) *',
                          prefixIcon: Icon(Icons.currency_rupee, size: 22),
                          hintText: '0.00',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 14),

                      // Bill Ref & Date
                      TextField(
                        controller: billRefController,
                        decoration: const InputDecoration(
                          labelText: 'Bill / Invoice Number *',
                          prefixIcon: Icon(Icons.receipt_long_outlined, size: 18),
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                      ),
                      const SizedBox(height: 12),
                      InkWell(
                        onTap: () async {
                          final picked = await showDatePicker(
                            context: modalCtx,
                            initialDate: billDate,
                            firstDate: DateTime(2020),
                            lastDate: DateTime.now().add(const Duration(days: 1)),
                          );
                          if (picked != null) {
                            setModalState(() => billDate = picked);
                          }
                        },
                        borderRadius: BorderRadius.circular(4),
                        child: InputDecorator(
                          decoration: const InputDecoration(
                            labelText: 'Bill Date',
                            prefixIcon: Icon(Icons.calendar_today, size: 18),
                            border: OutlineInputBorder(),
                            isDense: true,
                          ),
                          child: Text(dateFormat.format(billDate)),
                        ),
                      ),
                      const SizedBox(height: 14),

                      // Bill Category chips
                      const Text('Bill Category / Particulars', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 8,
                        runSpacing: 6,
                        children: categories.map((cat) {
                          final isSelected = category == cat;
                          return ChoiceChip(
                            label: Text(cat, style: const TextStyle(fontSize: 12)),
                            selected: isSelected,
                            onSelected: (val) {
                              if (val) {
                                setModalState(() {
                                  category = cat;
                                  if (descController.text.isEmpty || categories.contains(descController.text)) {
                                    descController.text = cat;
                                  }
                                });
                              }
                            },
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 12),

                      // Description / Particulars
                      TextField(
                        controller: descController,
                        decoration: const InputDecoration(
                          labelText: 'Description / Item Details',
                          hintText: 'e.g. Table T03 Dinner (4 Persons), or 2x Bikaji Namkeen packets',
                          prefixIcon: Icon(Icons.description_outlined, size: 18),
                          border: OutlineInputBorder(),
                          isDense: true,
                          helperText: 'Saved in customer transaction ledger',
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogCtx).pop(),
                  child: const Text('Cancel'),
                ),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red.shade700,
                    foregroundColor: Colors.white,
                  ),
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Add Bill to Khata'),
                  onPressed: () {
                    final amt = double.tryParse(amountController.text.trim()) ?? 0.0;
                    if (amt <= 0) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Please enter a valid bill amount greater than ₹0!')),
                      );
                      return;
                    }

                    final billRef = billRefController.text.trim().isNotEmpty
                        ? billRefController.text.trim()
                        : 'BILL-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}';

                    final description = descController.text.trim().isNotEmpty
                        ? descController.text.trim()
                        : category;

                    ref.read(ledgerProvider.notifier).addPendingBill(
                          customerId: targetCustomer.id,
                          amount: amt,
                          referenceNumber: billRef,
                          description: description,
                          date: billDate,
                          referenceType: 'INVOICE',
                        );

                    final messenger = ScaffoldMessenger.of(context);
                    Navigator.of(dialogCtx).pop();
                    setState(() {
                      _selectedCustomerId = targetCustomer.id;
                      if (MediaQuery.of(context).size.width < 768) {
                        _mobileShowDetail = true;
                      }
                    });

                    messenger.showSnackBar(
                      SnackBar(
                        content: Text('✅ Pending bill of ₹${amt.toStringAsFixed(2)} added for ${targetCustomer.name}!'),
                        backgroundColor: AppColors.statusAvailable,
                      ),
                    );
                  },
                ),
              ],
            );
          },
        );
      },
    );
  }

  // --- DIALOG 5: EDIT SINGLE BILL / TRANSACTION ---
  void _showEditBillDialog(BuildContext context, LedgerEntry entry) {
    final amountController = TextEditingController(text: entry.amount.toStringAsFixed(2));
    final refController = TextEditingController(text: entry.referenceNumber);
    final descController = TextEditingController(text: entry.description);
    DateTime billDate = entry.date;
    final isDebit = entry.type == LedgerType.debit;

    showDialog(
      context: context,
      builder: (dialogCtx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final dateFormat = DateFormat('dd MMM yyyy, hh:mm a');
            return AlertDialog(
              insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
              title: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: (isDebit ? Colors.red : Colors.green).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(Icons.edit, color: isDebit ? Colors.red : Colors.green, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text('Edit ${isDebit ? "Pending Bill" : "Payment"} Entry', overflow: TextOverflow.ellipsis),
                  ),
                ],
              ),
              content: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 480),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextField(
                        controller: amountController,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        decoration: const InputDecoration(
                          labelText: 'Amount (₹) *',
                          prefixIcon: Icon(Icons.currency_rupee, size: 20),
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: refController,
                        decoration: const InputDecoration(
                          labelText: 'Reference Number / Bill #',
                          prefixIcon: Icon(Icons.receipt_long, size: 18),
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: descController,
                        decoration: const InputDecoration(
                          labelText: 'Description / Particulars',
                          prefixIcon: Icon(Icons.description, size: 18),
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                      ),
                      const SizedBox(height: 12),
                      InkWell(
                        onTap: () async {
                          final picked = await showDatePicker(
                            context: context,
                            initialDate: billDate,
                            firstDate: DateTime(2020),
                            lastDate: DateTime.now().add(const Duration(days: 1)),
                          );
                          if (picked != null) {
                            setModalState(() => billDate = picked);
                          }
                        },
                        child: InputDecorator(
                          decoration: const InputDecoration(
                            labelText: 'Transaction Date',
                            prefixIcon: Icon(Icons.calendar_today, size: 18),
                            border: OutlineInputBorder(),
                            isDense: true,
                          ),
                          child: Text(dateFormat.format(billDate)),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogCtx).pop(),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () {
                    final amt = double.tryParse(amountController.text.trim()) ?? 0.0;
                    if (amt <= 0) return;

                    ref.read(ledgerProvider.notifier).updateEntry(
                          entryId: entry.id,
                          amount: amt,
                          referenceNumber: refController.text.trim(),
                          description: descController.text.trim(),
                          date: billDate,
                        );

                    Navigator.of(dialogCtx).pop();
                    setState(() {});
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('✅ Transaction entry updated!'), backgroundColor: AppColors.statusAvailable),
                    );
                  },
                  child: const Text('Save Changes'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // --- DIALOG 6: DELETE SINGLE BILL ---
  void _showDeleteSingleBillDialog(BuildContext context, LedgerEntry entry) {
    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        title: Row(
          children: const [
            Icon(Icons.delete_outline, color: Colors.red),
            SizedBox(width: 8),
            Expanded(
              child: Text('Delete Bill Entry?', overflow: TextOverflow.ellipsis),
            ),
          ],
        ),
        content: Text(
          'Are you sure you want to delete ${entry.referenceType} (${entry.referenceNumber}) for ₹${entry.amount.toStringAsFixed(2)}?\n\nCustomer balance will be recalculated immediately.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogCtx).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            onPressed: () {
              ref.read(ledgerProvider.notifier).deleteEntry(entry.id);
              _selectedEntryIds.remove(entry.id);
              Navigator.of(dialogCtx).pop();
              setState(() {});
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('🗑️ Entry deleted and balance recalculated.')),
              );
            },
            child: const Text('Delete Entry'),
          ),
        ],
      ),
    );
  }

  // --- DIALOG 7: BATCH DELETE MULTIPLE BILLS SIMULTANEOUSLY ---
  void _showBatchDeleteDialog(BuildContext context, List<LedgerEntry> entriesToDelete) {
    final total = entriesToDelete.fold(0.0, (sum, e) => sum + e.amount);
    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        title: Row(
          children: const [
            Icon(Icons.delete_sweep, color: Colors.red),
            SizedBox(width: 8),
            Expanded(
              child: Text('Delete Selected Bills Simultaneously?', overflow: TextOverflow.ellipsis),
            ),
          ],
        ),
        content: Text(
          'You are about to delete ${entriesToDelete.length} selected bills/entries totaling ₹${total.toStringAsFixed(2)}.\n\nAll selected entries will be permanently removed and the customer pending balance will be updated simultaneously.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogCtx).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            onPressed: () {
              final ids = entriesToDelete.map((e) => e.id).toList();
              ref.read(ledgerProvider.notifier).deleteEntries(ids);
              _selectedEntryIds.clear();
              Navigator.of(dialogCtx).pop();
              setState(() {});
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('🗑️ ${ids.length} entries deleted simultaneously!'),
                  backgroundColor: AppColors.statusAvailable,
                ),
              );
            },
            child: Text('Delete ${entriesToDelete.length} Entries'),
          ),
        ],
      ),
    );
  }

  // --- DIALOG 8: BATCH SETTLE SELECTED BILLS ---
  void _showBatchSettleDialog(BuildContext context, Customer customer, List<LedgerEntry> selectedBills) {
    final totalToSettle = selectedBills.fold(0.0, (sum, e) => sum + e.amount);
    final amountController = TextEditingController(text: totalToSettle.toStringAsFixed(2));
    final refController = TextEditingController(text: 'SETTLE-${selectedBills.length}-BILLS');
    String method = 'UPI';

    showDialog(
      context: context,
      builder: (dialogCtx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return AlertDialog(
              insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
              title: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF16A34A).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.done_all, color: Color(0xFF16A34A), size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text('Settle ${selectedBills.length} Selected Bills', overflow: TextOverflow.ellipsis),
                  ),
                ],
              ),
              content: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 480),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.green.shade50,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.green.shade200),
                        ),
                        child: Wrap(
                          alignment: WrapAlignment.spaceBetween,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          spacing: 8,
                          runSpacing: 4,
                          children: [
                            Text('Sum of ${selectedBills.length} Selected Bills:', style: const TextStyle(fontWeight: FontWeight.w600, color: Colors.black87)),
                            Text(
                              '₹${totalToSettle.toStringAsFixed(2)}',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF16A34A)),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),
                      TextField(
                        controller: amountController,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        decoration: const InputDecoration(
                          labelText: 'Settlement Amount (₹) *',
                          prefixIcon: Icon(Icons.currency_rupee, size: 20),
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        initialValue: method,
                        decoration: const InputDecoration(
                          labelText: 'Payment Mode',
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                        items: const [
                          DropdownMenuItem(value: 'UPI', child: Text('UPI (GPay, PhonePe, Paytm)')),
                          DropdownMenuItem(value: 'Cash', child: Text('Cash at Counter')),
                          DropdownMenuItem(value: 'Bank Transfer', child: Text('Bank Transfer / NEFT')),
                          DropdownMenuItem(value: 'Cheque', child: Text('Cheque')),
                        ],
                        onChanged: (val) {
                          if (val != null) setModalState(() => method = val);
                        },
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: refController,
                        decoration: const InputDecoration(
                          labelText: 'Settlement Reference / Note',
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogCtx).pop(),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF16A34A), foregroundColor: Colors.white),
                  onPressed: () {
                    final amt = double.tryParse(amountController.text.trim()) ?? 0.0;
                    if (amt <= 0) return;

                    ref.read(ledgerProvider.notifier).recordPayment(
                          customerId: customer.id,
                          amount: amt,
                          paymentMode: method,
                          referenceNumber: refController.text.trim(),
                          note: 'Batch settlement for ${selectedBills.length} bills',
                        );

                    _selectedEntryIds.clear();
                    Navigator.of(dialogCtx).pop();
                    setState(() {});
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('✅ Batch settlement of ₹${amt.toStringAsFixed(2)} recorded!'),
                        backgroundColor: AppColors.statusAvailable,
                      ),
                    );
                  },
                  child: const Text('Confirm Batch Settlement'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // --- DIALOG 9: RECORD PAYMENT / SETTLEMENT ---
  void _showPaymentCollectionDialog(BuildContext context, Customer customer) {
    final amountController = TextEditingController();
    final refController = TextEditingController();
    final currentBal = ref.read(ledgerProvider.notifier).getCustomerBalance(customer.id);
    String method = 'UPI';

    showDialog(
      context: context,
      builder: (dialogCtx) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        return StatefulBuilder(
          builder: (context, setModalState) {
            return AlertDialog(
              insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
              actionsOverflowButtonSpacing: 8,
              title: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF16A34A).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.payments_outlined, color: Color(0xFF16A34A), size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text('Record Payment from ${customer.name}', overflow: TextOverflow.ellipsis),
                  ),
                ],
              ),
              content: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 480),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Balance status
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF1E293B) : AppColors.borderSubtle,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.border),
                        ),
                        child: Wrap(
                          alignment: WrapAlignment.spaceBetween,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          spacing: 8,
                          runSpacing: 4,
                          children: [
                            const Text('Current Pending Balance:', style: TextStyle(fontWeight: FontWeight.w600)),
                            Text(
                              '₹${currentBal.toStringAsFixed(2)}',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                                color: currentBal > 0 ? Colors.red.shade700 : AppColors.statusAvailable,
                              ),
                            ),
                          ],
                        ),
                      ),
                    const SizedBox(height: 14),

                    // Quick fill full balance button
                    if (currentBal > 0)
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton.icon(
                          icon: const Icon(Icons.done_all, size: 16),
                          label: Text('Full Settlement (₹${currentBal.toStringAsFixed(2)})'),
                          onPressed: () {
                            setModalState(() {
                              amountController.text = currentBal.toStringAsFixed(2);
                            });
                          },
                        ),
                      ),

                    TextField(
                      controller: amountController,
                      autofocus: true,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      decoration: const InputDecoration(
                        labelText: 'Amount Received (₹) *',
                        prefixIcon: Icon(Icons.currency_rupee, size: 20),
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                    ),
                    const SizedBox(height: 12),

                    DropdownButtonFormField<String>(
                      initialValue: method,
                      decoration: const InputDecoration(
                        labelText: 'Payment Mode',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                      items: const [
                        DropdownMenuItem(value: 'UPI', child: Text('UPI (GPay, PhonePe, Paytm)')),
                        DropdownMenuItem(value: 'Cash', child: Text('Cash at Counter')),
                        DropdownMenuItem(value: 'Bank Transfer', child: Text('Bank Transfer / NEFT / IMPS')),
                        DropdownMenuItem(value: 'Cheque', child: Text('Cheque')),
                      ],
                      onChanged: (val) {
                        if (val != null) setModalState(() => method = val);
                      },
                    ),
                    const SizedBox(height: 12),

                    TextField(
                      controller: refController,
                      decoration: const InputDecoration(
                        labelText: 'Reference Number / UTR / Note (Optional)',
                        hintText: 'e.g. UTR-902144, GPay Txn ID, or Cash counter receipt',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogCtx).pop(),
                  child: const Text('Cancel'),
                ),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF16A34A),
                    foregroundColor: Colors.white,
                  ),
                  icon: const Icon(Icons.check, size: 18),
                  label: const Text('Save Settlement'),
                  onPressed: () {
                    final amt = double.tryParse(amountController.text.trim()) ?? 0.0;
                    if (amt <= 0) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Please enter an amount greater than ₹0!')),
                      );
                      return;
                    }

                    ref.read(ledgerProvider.notifier).recordPayment(
                          customerId: customer.id,
                          amount: amt,
                          paymentMode: method,
                          referenceNumber: refController.text.trim(),
                        );

                    final messenger = ScaffoldMessenger.of(context);
                    Navigator.of(dialogCtx).pop();
                    setState(() {});

                    messenger.showSnackBar(
                      SnackBar(
                        content: Text('✅ Payment settlement of ₹${amt.toStringAsFixed(2)} recorded!'),
                        backgroundColor: AppColors.statusAvailable,
                      ),
                    );
                  },
                ),
              ],
            );
          },
        );
      },
    );
  }
}
