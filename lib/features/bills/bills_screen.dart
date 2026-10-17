import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../core/theme.dart';
import '../../models/models.dart';
import '../../providers/restaurant_provider.dart';
import 'bill_detail_dialog.dart';

class BillsScreen extends ConsumerStatefulWidget {
  const BillsScreen({super.key});

  @override
  ConsumerState<BillsScreen> createState() => _BillsScreenState();
}

class _BillsScreenState extends ConsumerState<BillsScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String _dateFilter = 'All'; // 'All', 'Today', 'Week', 'Month'
  String _statusFilter = 'All'; // 'All', 'Paid', 'Credit', 'Voided'
  final Set<String> _selectedInvoiceIds = {};
  bool _isSyncing = false;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      setState(() => _searchQuery = _searchController.text.trim().toLowerCase());
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _syncWithCloud() async {
    setState(() => _isSyncing = true);
    try {
      await ref.read(invoicesProvider.notifier).syncWithCloud();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Bills synced with Supabase cloud successfully')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error syncing bills: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSyncing = false);
      }
    }
  }

  Future<void> _handleSingleDelete(Invoice inv) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        return AlertDialog(
          backgroundColor: isDark ? AppColors.darkCard : Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: const [
              Icon(Icons.delete_forever_rounded, color: Colors.red, size: 24),
              SizedBox(width: 8),
              Text('Delete Bill?', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            ],
          ),
          content: Text(
            'Are you sure you want to delete Bill #${inv.invoiceNumber} (${inv.tableNumber})?\nThis will remove it permanently from database records.',
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
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );

    if (confirmed == true && mounted) {
      await ref.read(invoicesProvider.notifier).deleteInvoice(inv.id);
      setState(() => _selectedInvoiceIds.remove(inv.id));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Bill #${inv.invoiceNumber} deleted')),
        );
      }
    }
  }

  Future<void> _handleBulkDelete() async {
    if (_selectedInvoiceIds.isEmpty) return;

    final count = _selectedInvoiceIds.length;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        return AlertDialog(
          backgroundColor: isDark ? AppColors.darkCard : Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: const [
              Icon(Icons.delete_sweep_rounded, color: Colors.red, size: 26),
              SizedBox(width: 8),
              Text('Delete Selected Bills?', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            ],
          ),
          content: Text(
            'Are you sure you want to permanently delete $count selected bills together?\n\nThis will purge them from both local storage and the Supabase cloud database. This operation cannot be undone.',
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
              child: Text('Delete $count Bills'),
            ),
          ],
        );
      },
    );

    if (confirmed == true && mounted) {
      final idsToDelete = _selectedInvoiceIds.toList();
      await ref.read(invoicesProvider.notifier).bulkDeleteInvoices(idsToDelete);
      setState(() => _selectedInvoiceIds.clear());
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$count bills deleted successfully')),
        );
      }
    }
  }

  Future<void> _handlePurgeAll() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        return AlertDialog(
          backgroundColor: isDark ? AppColors.darkCard : Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: const [
              Icon(Icons.warning_rounded, color: Colors.red, size: 26),
              SizedBox(width: 8),
              Text('Purge All Bills History?', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            ],
          ),
          content: Text(
            'DANGER: This will delete ALL generated bills in history from local storage and the database.\n\nOnly proceed if you want a complete reset of billing history.',
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
                backgroundColor: Colors.red.shade900,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Purge Everything'),
            ),
          ],
        );
      },
    );

    if (confirmed == true && mounted) {
      await ref.read(invoicesProvider.notifier).clearAllInvoices();
      setState(() => _selectedInvoiceIds.clear());
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('All bill history has been purged')),
        );
      }
    }
  }

  Future<void> _quickRejectBill(Invoice inv) async {
    final reasonController = TextEditingController(text: 'Billing mishap / incorrect order');
    final confirmed = await showDialog<String>(
      context: context,
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        return AlertDialog(
          backgroundColor: isDark ? AppColors.darkCard : Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: const [
              Icon(Icons.block_rounded, color: Colors.red, size: 24),
              SizedBox(width: 8),
              Text('Reject Bill', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Reject Bill #${inv.invoiceNumber} for Table ${inv.tableNumber}?',
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: reasonController,
                decoration: InputDecoration(
                  labelText: 'Rejection Reason',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red.shade700,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              onPressed: () => Navigator.pop(ctx, reasonController.text.trim()),
              child: const Text('Confirm Reject'),
            ),
          ],
        );
      },
    );

    if (confirmed != null && confirmed.isNotEmpty && mounted) {
      final res = await ref.read(invoicesProvider.notifier).voidInvoice(inv.invoiceNumber, confirmed);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(res.message)),
        );
      }
    }
  }

  void _openBillDetails(Invoice inv) {
    showDialog(
      context: context,
      builder: (_) => BillDetailDialog(invoice: inv),
    );
  }

  List<Invoice> _filterInvoices(List<Invoice> allInvoices) {
    final now = DateTime.now();

    return allInvoices.where((inv) {
      // Search filter
      if (_searchQuery.isNotEmpty) {
        final matchNum = inv.invoiceNumber.toLowerCase().contains(_searchQuery);
        final matchTable = inv.tableNumber.toLowerCase().contains(_searchQuery);
        final matchCust = inv.customerName?.toLowerCase().contains(_searchQuery) ?? false;
        final matchPhone = inv.customerPhone?.toLowerCase().contains(_searchQuery) ?? false;
        if (!matchNum && !matchTable && !matchCust && !matchPhone) return false;
      }

      // Date filter
      if (_dateFilter == 'Today') {
        if (inv.issuedAt.year != now.year ||
            inv.issuedAt.month != now.month ||
            inv.issuedAt.day != now.day) {
          return false;
        }
      } else if (_dateFilter == 'Week') {
        final diff = now.difference(inv.issuedAt).inDays;
        if (diff > 7) return false;
      } else if (_dateFilter == 'Month') {
        if (inv.issuedAt.year != now.year || inv.issuedAt.month != now.month) {
          return false;
        }
      }

      // Status filter
      if (_statusFilter == 'Voided') {
        if (!inv.isVoided) return false;
      } else if (_statusFilter == 'Credit') {
        if (inv.creditAmount <= 0 || inv.isVoided) return false;
      } else if (_statusFilter == 'Paid') {
        if (inv.isVoided || inv.creditAmount > 0) return false;
      }

      return true;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final allInvoices = ref.watch(invoicesProvider);
    final filteredInvoices = _filterInvoices(allInvoices);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = screenWidth >= 960;

    // Metrics
    final totalCount = allInvoices.length;
    final totalRevenue = allInvoices
        .where((i) => !i.isVoided)
        .fold(0.0, (sum, i) => sum + i.grandTotal);
    final paidCount = allInvoices.where((i) => !i.isVoided && i.creditAmount <= 0).length;
    final creditCount = allInvoices.where((i) => !i.isVoided && i.creditAmount > 0).length;
    final voidedCount = allInvoices.where((i) => i.isVoided).length;

    final allSelected = filteredInvoices.isNotEmpty &&
        filteredInvoices.every((i) => _selectedInvoiceIds.contains(i.id));

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : AppColors.background,
      body: Column(
        children: [
          // Top Header Deck
          Container(
            padding: EdgeInsets.symmetric(
              horizontal: isDesktop ? 28 : 16,
              vertical: 20,
            ),
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkCard : Colors.white,
              border: Border(
                bottom: BorderSide(
                  color: isDark ? AppColors.darkBorder : AppColors.border,
                ),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Title & Top Actions
                Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.receipt_long_rounded, color: AppColors.primary, size: 22),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Bills & Invoices Management',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.3,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Live Database Sync • CRUD Operations • Safe Reversals',
                            style: TextStyle(
                              fontSize: 12,
                              color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Action Buttons
                    // Bulk Delete Button (Active when selected)
                    if (_selectedInvoiceIds.isNotEmpty) ...[
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red.shade700,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        ),
                        icon: const Icon(Icons.delete_sweep_rounded, size: 18),
                        label: Text('Delete Selected (${_selectedInvoiceIds.length})'),
                        onPressed: _handleBulkDelete,
                      ),
                      const SizedBox(width: 8),
                    ],

                    // Sync Cloud Button
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      ),
                      icon: _isSyncing
                          ? const SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.sync_rounded, size: 18),
                      label: const Text('Cloud Sync'),
                      onPressed: _isSyncing ? null : _syncWithCloud,
                    ),

                    const SizedBox(width: 8),

                    // Purge All History Menu
                    PopupMenuButton<String>(
                      icon: const Icon(Icons.more_vert_rounded),
                      tooltip: 'More actions',
                      onSelected: (val) {
                        if (val == 'purge') _handlePurgeAll();
                      },
                      itemBuilder: (ctx) => [
                        const PopupMenuItem(
                          value: 'purge',
                          child: Row(
                            children: [
                              Icon(Icons.delete_forever_rounded, color: Colors.red, size: 18),
                              SizedBox(width: 8),
                              Text('Purge All History', style: TextStyle(color: Colors.red, fontSize: 13)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),

                const SizedBox(height: 18),

                // Metrics Deck
                LayoutBuilder(
                  builder: (context, constraints) {
                    final isNarrow = constraints.maxWidth < 700;
                    if (isNarrow) {
                      return SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            _buildStatCard('Total Bills', '$totalCount', Icons.receipt_rounded, const Color(0xFF6366F1), isDark),
                            const SizedBox(width: 10),
                            _buildStatCard('Revenue', '₹${totalRevenue.toStringAsFixed(0)}', Icons.currency_rupee_rounded, AppColors.primary, isDark),
                            const SizedBox(width: 10),
                            _buildStatCard('Fully Paid', '$paidCount', Icons.check_circle_rounded, const Color(0xFF10B981), isDark),
                            const SizedBox(width: 10),
                            _buildStatCard('Khata Credit', '$creditCount', Icons.account_balance_wallet_rounded, const Color(0xFFF59E0B), isDark),
                            const SizedBox(width: 10),
                            _buildStatCard('Voided / Rejected', '$voidedCount', Icons.block_rounded, const Color(0xFFEF4444), isDark),
                          ],
                        ),
                      );
                    }
                    return Row(
                      children: [
                        Expanded(child: _buildStatCard('Total Bills', '$totalCount', Icons.receipt_rounded, const Color(0xFF6366F1), isDark)),
                        const SizedBox(width: 12),
                        Expanded(child: _buildStatCard('Revenue', '₹${totalRevenue.toStringAsFixed(0)}', Icons.currency_rupee_rounded, AppColors.primary, isDark)),
                        const SizedBox(width: 12),
                        Expanded(child: _buildStatCard('Fully Paid', '$paidCount', Icons.check_circle_rounded, const Color(0xFF10B981), isDark)),
                        const SizedBox(width: 12),
                        Expanded(child: _buildStatCard('Khata Credit', '$creditCount', Icons.account_balance_wallet_rounded, const Color(0xFFF59E0B), isDark)),
                        const SizedBox(width: 12),
                        Expanded(child: _buildStatCard('Voided / Rejected', '$voidedCount', Icons.block_rounded, const Color(0xFFEF4444), isDark)),
                      ],
                    );
                  },
                ),
              ],
            ),
          ),

          // Filters & Search Bar Deck
          Container(
            padding: EdgeInsets.symmetric(
              horizontal: isDesktop ? 28 : 16,
              vertical: 12,
            ),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1A1B1E) : const Color(0xFFF1F2F0),
              border: Border(
                bottom: BorderSide(
                  color: isDark ? AppColors.darkBorder : AppColors.border,
                ),
              ),
            ),
            child: Row(
              children: [
                // Select All Checkbox
                if (filteredInvoices.isNotEmpty) ...[
                  Checkbox(
                    value: allSelected,
                    tristate: _selectedInvoiceIds.isNotEmpty && !allSelected,
                    onChanged: (val) {
                      setState(() {
                        if (val == true) {
                          _selectedInvoiceIds.addAll(filteredInvoices.map((i) => i.id));
                        } else {
                          _selectedInvoiceIds.clear();
                        }
                      });
                    },
                  ),
                  const SizedBox(width: 4),
                ],

                // Search field
                Expanded(
                  child: Container(
                    height: 38,
                    decoration: BoxDecoration(
                      color: isDark ? AppColors.darkCard : Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: isDark ? AppColors.darkBorder : AppColors.border,
                      ),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    child: Row(
                      children: [
                        Icon(
                          Icons.search_rounded,
                          size: 18,
                          color: isDark ? AppColors.darkTextSecondary : AppColors.textMuted,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextField(
                            controller: _searchController,
                            style: const TextStyle(fontSize: 12.5),
                            decoration: const InputDecoration(
                              hintText: 'Search by Bill #, customer name, phone, table...',
                              hintStyle: TextStyle(fontSize: 12),
                              border: InputBorder.none,
                              isDense: true,
                              contentPadding: EdgeInsets.zero,
                            ),
                          ),
                        ),
                        if (_searchQuery.isNotEmpty)
                          GestureDetector(
                            onTap: () => _searchController.clear(),
                            child: const Icon(Icons.close_rounded, size: 16),
                          ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(width: 12),

                // Date Filter Pills
                _buildFilterChip('All Time', 'All', _dateFilter, (v) => setState(() => _dateFilter = v)),
                const SizedBox(width: 6),
                _buildFilterChip('Today', 'Today', _dateFilter, (v) => setState(() => _dateFilter = v)),
                const SizedBox(width: 6),
                _buildFilterChip('This Week', 'Week', _dateFilter, (v) => setState(() => _dateFilter = v)),
                const SizedBox(width: 12),

                // Status Filter Pills
                _buildStatusFilterChip('All', 'All', _statusFilter, (v) => setState(() => _statusFilter = v)),
                const SizedBox(width: 6),
                _buildStatusFilterChip('Paid', 'Paid', _statusFilter, (v) => setState(() => _statusFilter = v)),
                const SizedBox(width: 6),
                _buildStatusFilterChip('Khata', 'Credit', _statusFilter, (v) => setState(() => _statusFilter = v)),
                const SizedBox(width: 6),
                _buildStatusFilterChip('Voided', 'Voided', _statusFilter, (v) => setState(() => _statusFilter = v)),
              ],
            ),
          ),

          // Main Invoices List / Table
          Expanded(
            child: filteredInvoices.isEmpty
                ? _buildEmptyState(isDark)
                : isDesktop
                    ? _buildDesktopDataTable(filteredInvoices, isDark)
                    : _buildMobileCardsList(filteredInvoices, isDark),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF26272B) : const Color(0xFFF7F7F5),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isDark ? AppColors.darkBorder : AppColors.border,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w600,
                    color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 1),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.2,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, String value, String current, Function(String) onSelect) {
    final isSelected = current == value;
    return InkWell(
      onTap: () => onSelect(value),
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: isSelected ? AppColors.primary : const Color(0xFFD0D0CE),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11.5,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
            color: isSelected ? Colors.white : null,
          ),
        ),
      ),
    );
  }

  Widget _buildStatusFilterChip(String label, String value, String current, Function(String) onSelect) {
    final isSelected = current == value;
    return InkWell(
      onTap: () => onSelect(value),
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF202124) : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: isSelected ? const Color(0xFF202124) : const Color(0xFFD0D0CE),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11.5,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
            color: isSelected ? Colors.white : null,
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState(bool isDark) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF26272B) : const Color(0xFFEAEAEA),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.receipt_long_outlined,
              size: 48,
              color: isDark ? AppColors.darkTextSecondary : AppColors.textMuted,
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'No Generated Bills Found',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 6),
          Text(
            _searchQuery.isNotEmpty
                ? 'No bills match the search criteria "$_searchQuery".'
                : 'Bills generated at table checkout will automatically appear here dynamically.',
            style: TextStyle(
              fontSize: 12.5,
              color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDesktopDataTable(List<Invoice> invoices, bool isDark) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Container(
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkCard : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isDark ? AppColors.darkBorder : AppColors.border,
          ),
        ),
        child: Column(
          children: [
            // Header Row
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF26272B) : const Color(0xFFF7F7F5),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(11)),
                border: Border(
                  bottom: BorderSide(
                    color: isDark ? AppColors.darkBorder : AppColors.border,
                  ),
                ),
              ),
              child: Row(
                children: const [
                  SizedBox(width: 40, child: Text('#', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11.5))),
                  Expanded(flex: 3, child: Text('BILL #', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11.5))),
                  Expanded(flex: 3, child: Text('DATE & TIME', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11.5))),
                  Expanded(flex: 2, child: Text('TABLE', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11.5))),
                  Expanded(flex: 4, child: Text('CUSTOMER', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11.5))),
                  Expanded(flex: 4, child: Text('ITEMS', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11.5))),
                  Expanded(flex: 3, child: Text('AMOUNT', textAlign: TextAlign.right, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11.5))),
                  Expanded(flex: 3, child: Text('STATUS', textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11.5))),
                  Expanded(flex: 4, child: Text('ACTIONS', textAlign: TextAlign.right, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11.5))),
                ],
              ),
            ),

            // Rows
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: invoices.length,
              separatorBuilder: (context, index) => Divider(
                height: 1,
                color: isDark ? AppColors.darkBorder : AppColors.border,
              ),
              itemBuilder: (context, index) {
                final inv = invoices[index];
                final isSelected = _selectedInvoiceIds.contains(inv.id);
                final dateFormatted = DateFormat('dd MMM, hh:mm a').format(inv.issuedAt);
                final itemsSummary = inv.items.isEmpty
                    ? 'General Order'
                    : '${inv.items.length} items • ${inv.items.map((i) => i.name).take(2).join(', ')}${inv.items.length > 2 ? '...' : ''}';

                return InkWell(
                  onTap: () => _openBillDetails(inv),
                  child: Container(
                    color: isSelected
                        ? AppColors.primary.withValues(alpha: 0.08)
                        : (inv.isVoided ? Colors.red.withValues(alpha: 0.03) : null),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    child: Row(
                      children: [
                        // Checkbox
                        SizedBox(
                          width: 40,
                          child: Checkbox(
                            value: isSelected,
                            onChanged: (val) {
                              setState(() {
                                if (val == true) {
                                  _selectedInvoiceIds.add(inv.id);
                                } else {
                                  _selectedInvoiceIds.remove(inv.id);
                                }
                              });
                            },
                          ),
                        ),

                        // Bill #
                        Expanded(
                          flex: 3,
                          child: Row(
                            children: [
                              Text(
                                inv.invoiceNumber,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                  color: AppColors.primary,
                                ),
                              ),
                            ],
                          ),
                        ),

                        // Date & Time
                        Expanded(
                          flex: 3,
                          child: Text(
                            dateFormatted,
                            style: TextStyle(
                              fontSize: 12,
                              color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary,
                            ),
                          ),
                        ),

                        // Table Badge
                        Expanded(
                          flex: 2,
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: AppColors.primary.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                inv.tableNumber,
                                style: const TextStyle(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.primary,
                                ),
                              ),
                            ),
                          ),
                        ),

                        // Customer
                        Expanded(
                          flex: 4,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                inv.customerName?.trim().isNotEmpty == true ? inv.customerName! : 'Guest Walk-in',
                                style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              if (inv.customerPhone?.trim().isNotEmpty == true)
                                Text(
                                  inv.customerPhone!,
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: isDark ? AppColors.darkTextSecondary : AppColors.textMuted,
                                  ),
                                ),
                            ],
                          ),
                        ),

                        // Items
                        Expanded(
                          flex: 4,
                          child: Text(
                            itemsSummary,
                            style: TextStyle(
                              fontSize: 11.5,
                              color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),

                        // Amount
                        Expanded(
                          flex: 3,
                          child: Text(
                            '₹${inv.grandTotal.toStringAsFixed(2)}',
                            textAlign: TextAlign.right,
                            style: TextStyle(
                              fontSize: 13.5,
                              fontWeight: FontWeight.bold,
                              color: inv.isVoided ? Colors.red : null,
                              decoration: inv.isVoided ? TextDecoration.lineThrough : null,
                            ),
                          ),
                        ),

                        // Status Badge
                        Expanded(
                          flex: 3,
                          child: Center(child: _buildTableStatusChip(inv)),
                        ),

                        // Row Actions
                        Expanded(
                          flex: 4,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              // View Details
                              IconButton(
                                icon: const Icon(Icons.visibility_outlined, size: 18),
                                tooltip: 'View Bill Details',
                                onPressed: () => _openBillDetails(inv),
                              ),

                              // Quick Reject / Void (if not voided)
                              if (!inv.isVoided)
                                IconButton(
                                  icon: const Icon(Icons.block_rounded, color: Colors.orange, size: 18),
                                  tooltip: 'Reject / Void Bill',
                                  onPressed: () => _quickRejectBill(inv),
                                ),

                              // Delete Bill (Separately)
                              IconButton(
                                icon: const Icon(Icons.delete_outline_rounded, color: Colors.red, size: 18),
                                tooltip: 'Delete Bill',
                                onPressed: () => _handleSingleDelete(inv),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMobileCardsList(List<Invoice> invoices, bool isDark) {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: invoices.length,
      itemBuilder: (context, index) {
        final inv = invoices[index];
        final isSelected = _selectedInvoiceIds.contains(inv.id);
        final dateFormatted = DateFormat('dd MMM, hh:mm a').format(inv.issuedAt);

        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          elevation: 0,
          color: isSelected
              ? AppColors.primary.withValues(alpha: 0.08)
              : (isDark ? AppColors.darkCard : Colors.white),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(
              color: isSelected
                  ? AppColors.primary
                  : (isDark ? AppColors.darkBorder : AppColors.border),
            ),
          ),
          child: InkWell(
            onTap: () => _openBillDetails(inv),
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Checkbox(
                        value: isSelected,
                        onChanged: (val) {
                          setState(() {
                            if (val == true) {
                              _selectedInvoiceIds.add(inv.id);
                            } else {
                              _selectedInvoiceIds.remove(inv.id);
                            }
                          });
                        },
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          inv.tableNumber,
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: AppColors.primary),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '#${inv.invoiceNumber}',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                      const Spacer(),
                      _buildTableStatusChip(inv),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            inv.customerName?.trim().isNotEmpty == true ? inv.customerName! : 'Guest Walk-in',
                            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                          ),
                          Text(
                            dateFormatted,
                            style: TextStyle(
                              fontSize: 11,
                              color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                      Text(
                        '₹${inv.grandTotal.toStringAsFixed(2)}',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: inv.isVoided ? Colors.red : AppColors.primary,
                          decoration: inv.isVoided ? TextDecoration.lineThrough : null,
                        ),
                      ),
                    ],
                  ),
                  const Divider(height: 18),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      if (!inv.isVoided)
                        TextButton.icon(
                          icon: const Icon(Icons.block_rounded, size: 16, color: Colors.orange),
                          label: const Text('Reject', style: TextStyle(color: Colors.orange, fontSize: 12)),
                          onPressed: () => _quickRejectBill(inv),
                        ),
                      TextButton.icon(
                        icon: const Icon(Icons.delete_outline_rounded, size: 16, color: Colors.red),
                        label: const Text('Delete', style: TextStyle(color: Colors.red, fontSize: 12)),
                        onPressed: () => _handleSingleDelete(inv),
                      ),
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        icon: const Icon(Icons.visibility_outlined, size: 16),
                        label: const Text('Details', style: TextStyle(fontSize: 12)),
                        onPressed: () => _openBillDetails(inv),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildTableStatusChip(Invoice inv) {
    if (inv.isVoided) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: Colors.red.shade100,
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(
          'REJECTED',
          style: TextStyle(color: Colors.red.shade900, fontWeight: FontWeight.bold, fontSize: 10),
        ),
      );
    }
    if (inv.creditAmount > 0) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: Colors.amber.shade100,
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(
          'KHATA',
          style: TextStyle(color: Colors.amber.shade900, fontWeight: FontWeight.bold, fontSize: 10),
        ),
      );
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.green.shade100,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        'PAID',
        style: TextStyle(color: Colors.green.shade900, fontWeight: FontWeight.bold, fontSize: 10),
      ),
    );
  }
}
