import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme.dart';
import '../../models/models.dart';
import '../../providers/restaurant_provider.dart';
import '../billing/billing_dialog.dart';
import '../orders/order_screen.dart';
import '../menu/digital_menu_screen.dart';
import 'table_merge_dialog.dart';
import 'table_qr_dialog.dart';
import 'add_edit_table_dialog.dart';
import 'delete_table_dialog.dart';

class TablesScreen extends ConsumerStatefulWidget {
  const TablesScreen({super.key});

  @override
  ConsumerState<TablesScreen> createState() => _TablesScreenState();
}

class _TablesScreenState extends ConsumerState<TablesScreen> {
  String _selectedSection = 'All';

  Color _getSectionColor(String section) {
    final s = section.toLowerCase();
    if (s.contains('outdoor') || s.contains('lawn') || s.contains('garden')) {
      return const Color(0xFF15803D);
    }
    if (s.contains('rooftop') || s.contains('terrace') || s.contains('sky')) {
      return const Color(0xFF7C3AED);
    }
    if (s.contains('banquet') || s.contains('hall') || s.contains('first')) {
      return const Color(0xFFD97706);
    }
    return const Color(0xFF0284C7); // Indoor AC
  }

  @override
  Widget build(BuildContext context) {
    final tables = ref.watch(tablesProvider);
    final orders = ref.watch(ordersProvider);
    final currentStaff = ref.watch(currentStaffProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 700;
    final isDesktop = screenWidth >= 1100;

    // Compute live hall metrics
    final totalTables = tables.length;
    final totalSeats = tables.fold<int>(0, (sum, t) => sum + t.capacity);
    final availableCount = tables.where((t) => t.status == TableState.available).length;
    final occupiedCount = tables.where((t) => t.status == TableState.occupied).length;
    final billingCount = tables.where((t) => t.status == TableState.billing).length;
    final cleaningCount = tables.where((t) => t.status == TableState.cleaning).length;
    final activeHallTotal = orders.values.fold(0.0, (sum, o) => sum + o.grandTotal);
    final activeParcels = orders.values.where((o) => o.isTakeaway || o.tableNumber.startsWith('Parcel')).toList();

    final allSections = ['All', ...{...tables.map((t) => t.section)}];
    final filteredTables = _selectedSection == 'All'
        ? tables
        : tables.where((t) => t.section == _selectedSection).toList();

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            // --- REDESIGNED UNIFIED TOP CONTROL BAR ---
            _buildRedesignedTopBar(
              context: context,
              isDark: isDark,
              isMobile: isMobile,
              isDesktop: isDesktop,
              totalTables: totalTables,
              totalSeats: totalSeats,
              availableCount: availableCount,
              occupiedCount: occupiedCount,
              billingCount: billingCount,
              cleaningCount: cleaningCount,
              activeHallTotal: activeHallTotal,
              allSections: allSections,
              tables: tables,
              activeParcels: activeParcels,
              currentStaff: currentStaff,
            ),

            // Adaptive Table Grid View
            Expanded(
              child: filteredTables.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.table_restaurant_outlined, size: 48, color: Colors.grey.shade400),
                          const SizedBox(height: 12),
                          Text(
                            'No tables found in "\$_selectedSection"',
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Add a table to this floor zone or switch to "All"',
                            style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                          ),
                          const SizedBox(height: 16),
                          FilledButton.icon(
                            style: FilledButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                            icon: const Icon(Icons.add, size: 18),
                            label: Text('Add Table to \$_selectedSection'),
                            onPressed: () => showDialog(
                              context: context,
                              builder: (_) => AddEditTableDialog(
                                table: _selectedSection != 'All'
                                    ? RestaurantTable(
                                        id: '',
                                        tableNumber: '',
                                        section: _selectedSection,
                                        capacity: 6,
                                      )
                                    : null,
                              ),
                            ),
                          ),
                        ],
                      ),
                    )
                  : LayoutBuilder(
                      builder: (context, constraints) {
                        final width = constraints.maxWidth;
                        int crossAxisCount;
                        double mainAxisExtent;
                        double spacing;

                        if (width < 500) {
                          crossAxisCount = 2;
                          mainAxisExtent = 190;
                          spacing = 10;
                        } else if (width < 850) {
                          crossAxisCount = 3;
                          mainAxisExtent = 195;
                          spacing = 12;
                        } else if (width < 1200) {
                          crossAxisCount = 4;
                          mainAxisExtent = 205;
                          spacing = 14;
                        } else {
                          crossAxisCount = 5;
                          mainAxisExtent = 210;
                          spacing = 16;
                        }

                        return GridView.builder(
                          padding: EdgeInsets.fromLTRB(
                            width < 450 ? 10 : 20,
                            4,
                            width < 450 ? 10 : 20,
                            16,
                          ),
                          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: crossAxisCount,
                            mainAxisExtent: mainAxisExtent,
                            crossAxisSpacing: spacing,
                            mainAxisSpacing: spacing,
                          ),
                          itemCount: filteredTables.length,
                          itemBuilder: (context, index) {
                            final table = filteredTables[index];
                            final order = orders[table.tableNumber];
                            return _buildModernTableCard(context, ref, table, order);
                          },
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRedesignedTopBar({
    required BuildContext context,
    required bool isDark,
    required bool isMobile,
    required bool isDesktop,
    required int totalTables,
    required int totalSeats,
    required int availableCount,
    required int occupiedCount,
    required int billingCount,
    required int cleaningCount,
    required double activeHallTotal,
    required List<String> allSections,
    required List<RestaurantTable> tables,
    required List<Order> activeParcels,
    required StaffMember currentStaff,
  }) {
    return Container(
      margin: EdgeInsets.fromLTRB(
        isMobile ? 10 : 20,
        isMobile ? 10 : 16,
        isMobile ? 10 : 20,
        8,
      ),
      padding: EdgeInsets.all(isMobile ? 12 : 18),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? AppColors.darkBorder : AppColors.border,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Row 1: Title, Hall Stats & Semantic Status Legend
          if (isMobile) ...[
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Floor & Tables',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.3,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF064E3B) : const Color(0xFFECFDF5),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.currency_rupee, size: 11, color: Color(0xFF10B981)),
                          Text(
                            activeHallTotal.toStringAsFixed(0),
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.bold,
                              color: isDark ? const Color(0xFF6EE7B7) : const Color(0xFF059669),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  ' Tables •  Total Seats',
                  style: TextStyle(
                    fontSize: 11.5,
                    color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 10),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _buildStatusPill('Available', availableCount, AppColors.statusAvailable, isDark),
                      const SizedBox(width: 6),
                      _buildStatusPill('Occupied', occupiedCount, AppColors.statusOccupied, isDark),
                      const SizedBox(width: 6),
                      _buildStatusPill('Billing', billingCount, AppColors.statusBilling, isDark),
                      const SizedBox(width: 6),
                      _buildStatusPill('Cleaning', cleaningCount, AppColors.statusCleaning, isDark),
                    ],
                  ),
                ),
              ],
            ),
          ] else ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Title & Metrics
                Row(
                  children: [
                    const Text(
                      'Floor & Tables',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.3,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: isDark ? AppColors.darkSurface : AppColors.primaryLight,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        ' Tables •  Seats',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: isDark ? const Color(0xFFFF9E80) : AppColors.primary,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF064E3B) : const Color(0xFFECFDF5),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.currency_rupee, size: 13, color: Color(0xFF10B981)),
                          Text(
                            'Live Total: ₹${activeHallTotal.toStringAsFixed(0)}',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: isDark ? const Color(0xFF6EE7B7) : const Color(0xFF059669),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                // Status Legend Badges
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildStatusPill('Available', availableCount, AppColors.statusAvailable, isDark),
                    const SizedBox(width: 8),
                    _buildStatusPill('Occupied', occupiedCount, AppColors.statusOccupied, isDark),
                    const SizedBox(width: 8),
                    _buildStatusPill('Billing', billingCount, AppColors.statusBilling, isDark),
                    const SizedBox(width: 8),
                    _buildStatusPill('Cleaning', cleaningCount, AppColors.statusCleaning, isDark),
                  ],
                ),
              ],
            ),
          ],

          Padding(
            padding: EdgeInsets.symmetric(vertical: isMobile ? 10 : 14),
            child: Divider(
              height: 1,
              thickness: 1,
              color: isDark ? AppColors.darkBorder : AppColors.border,
            ),
          ),

          // Row 2: Floor Zone Filter Tabs & Action Toolbar
          Row(
            children: [
              // Floor Section Filter Tabs (Pills)
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: allSections.map((sec) {
                      final isSelected = _selectedSection == sec;
                      final count = sec == 'All' ? totalTables : tables.where((t) => t.section == sec).length;
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: InkWell(
                          onTap: () => setState(() => _selectedSection = sec),
                          borderRadius: BorderRadius.circular(20),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 150),
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? AppColors.primary
                                  : (isDark ? AppColors.darkSurface : AppColors.surfaceSecondary),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: isSelected
                                    ? AppColors.primary
                                    : (isDark ? AppColors.darkBorder : AppColors.border),
                              ),
                              boxShadow: isSelected
                                  ? [
                                      BoxShadow(
                                        color: AppColors.primary.withValues(alpha: 0.25),
                                        blurRadius: 6,
                                        offset: const Offset(0, 2),
                                      ),
                                    ]
                                  : null,
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  sec,
                                  style: TextStyle(
                                    fontSize: 12.5,
                                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                                    color: isSelected
                                        ? Colors.white
                                        : (isDark ? AppColors.darkTextPrimary : AppColors.textPrimary),
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                                  decoration: BoxDecoration(
                                    color: isSelected
                                        ? Colors.white.withValues(alpha: 0.25)
                                        : (isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.06)),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Text(
                                    '$count',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      color: isSelected
                                          ? Colors.white
                                          : (isDark ? AppColors.darkTextSecondary : AppColors.textSecondary),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ),

              const SizedBox(width: 10),

              // Action Buttons
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      padding: EdgeInsets.symmetric(
                        horizontal: isMobile ? 10 : 14,
                        vertical: isMobile ? 8 : 10,
                      ),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      elevation: 0,
                    ),
                    icon: const Icon(Icons.add_rounded, size: 16),
                    label: Text(
                      isMobile ? 'Table' : '+ Add Table',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5),
                    ),
                    onPressed: () => showDialog(
                      context: context,
                      builder: (_) => const AddEditTableDialog(),
                    ),
                  ),

                  const SizedBox(width: 8),

                  FilledButton.tonalIcon(
                    style: FilledButton.styleFrom(
                      backgroundColor: isDark ? const Color(0xFF451A03) : const Color(0xFFFEF3C7),
                      foregroundColor: isDark ? const Color(0xFFFDBA74) : const Color(0xFFB45309),
                      padding: EdgeInsets.symmetric(
                        horizontal: isMobile ? 10 : 12,
                        vertical: isMobile ? 8 : 10,
                      ),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    icon: const Icon(Icons.shopping_bag_outlined, size: 15),
                    label: Text(
                      isMobile ? 'Parcel' : '+ Parcel',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5),
                    ),
                    onPressed: () {
                      final settings = ref.read(settingsProvider);
                      final parcelId = ref.read(ordersProvider.notifier).createParcelOrder(
                        taxRate: settings.gstEnabled ? settings.taxRate : 0.0,
                        packagingCharge: 15.0,
                      );
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => OrderScreen(tableNumber: parcelId),
                        ),
                      );
                    },
                  ),

                  if (isDesktop) ...[
                    const SizedBox(width: 8),
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        side: BorderSide(color: isDark ? AppColors.darkBorder : AppColors.border),
                      ),
                      icon: const Icon(Icons.swap_horiz_rounded, size: 16),
                      label: const Text('Move Table', style: TextStyle(fontSize: 12)),
                      onPressed: occupiedCount == 0
                          ? null
                          : () => _showTransferTableDialog(context, ref, tables),
                    ),
                    const SizedBox(width: 8),
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        side: BorderSide(color: isDark ? AppColors.darkBorder : AppColors.border),
                      ),
                      icon: const Icon(Icons.link_rounded, size: 16),
                      label: const Text('Merge', style: TextStyle(fontSize: 12)),
                      onPressed: () => showDialog(
                        context: context,
                        builder: (_) => TableMergeDialog(tables: tables),
                      ),
                    ),
                    const SizedBox(width: 8),
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        side: BorderSide(color: isDark ? AppColors.darkBorder : AppColors.border),
                      ),
                      icon: const Icon(Icons.qr_code_2_rounded, size: 16),
                      label: const Text('QR Cards', style: TextStyle(fontSize: 12)),
                      onPressed: () => showDialog(
                        context: context,
                        builder: (_) => TableQrCardsDialog(tables: tables),
                      ),
                    ),
                  ] else ...[
                    const SizedBox(width: 6),
                    PopupMenuButton<String>(
                      tooltip: 'More Floor Tools',
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      icon: Container(
                        padding: const EdgeInsets.all(7),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.border),
                        ),
                        child: const Icon(Icons.more_vert_rounded, size: 18),
                      ),
                      onSelected: (val) {
                        if (val == 'move') {
                          _showTransferTableDialog(context, ref, tables);
                        } else if (val == 'merge') {
                          showDialog(
                            context: context,
                            builder: (_) => TableMergeDialog(tables: tables),
                          );
                        } else if (val == 'qr') {
                          showDialog(
                            context: context,
                            builder: (_) => TableQrCardsDialog(tables: tables),
                          );
                        }
                      },
                      itemBuilder: (ctx) => [
                        PopupMenuItem(
                          value: 'move',
                          enabled: occupiedCount > 0,
                          child: const Row(
                            children: [
                              Icon(Icons.swap_horiz_rounded, size: 18),
                              SizedBox(width: 10),
                              Text('Move Table'),
                            ],
                          ),
                        ),
                        const PopupMenuItem(
                          value: 'merge',
                          child: Row(
                            children: [
                              Icon(Icons.link_rounded, size: 18),
                              SizedBox(width: 10),
                              Text('Merge Tables'),
                            ],
                          ),
                        ),
                        const PopupMenuItem(
                          value: 'qr',
                          child: Row(
                            children: [
                              Icon(Icons.qr_code_2_rounded, size: 18),
                              SizedBox(width: 10),
                              Text('Table QR Cards'),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ],
          ),

          // Row 3: Active Parcels Bar (if any)
          if (activeParcels.isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF261D15) : const Color(0xFFFFFBEB),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: isDark ? const Color(0xFF5A3A1A) : const Color(0xFFFDE68A),
                ),
              ),
              child: Row(
                children: [
                  const Icon(Icons.shopping_bag, size: 16, color: Color(0xFFD97706)),
                  const SizedBox(width: 6),
                  Text(
                    'Parcels (${activeParcels.length}):',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF92400E)),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: activeParcels.map((parcel) {
                          return Padding(
                            padding: const EdgeInsets.only(right: 6),
                            child: ActionChip(
                              avatar: const Icon(Icons.receipt_outlined, size: 12),
                              label: Text(
                                '${parcel.tableNumber} • ₹${parcel.grandTotal.toStringAsFixed(0)}',
                                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                              ),
                              onPressed: () {
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) => OrderScreen(tableNumber: parcel.tableNumber),
                                  ),
                                );
                              },
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildStatusPill(String label, int count, Color color, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: isDark ? 0.15 : 0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: isDark ? 0.3 : 0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Text(
            ' ',
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
              color: isDark ? color : color.withValues(alpha: 0.9),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildModernTableCard(BuildContext context, WidgetRef ref, RestaurantTable table, Order? order) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    Color statusColor;
    Color statusBg;
    String statusText;

    if (!table.isEnabled) {
      statusColor = isDark ? Colors.grey.shade400 : Colors.grey.shade700;
      statusBg = isDark ? const Color(0xFF334155) : Colors.grey.shade200;
      statusText = 'DISABLED / OFF';
    } else {
      switch (table.status) {
        case TableState.available:
          statusColor = AppColors.statusAvailable;
          statusBg = isDark ? const Color(0xFF064E3B) : AppColors.statusAvailableBg;
          statusText = 'AVAILABLE';
          break;
        case TableState.occupied:
          statusColor = AppColors.statusOccupied;
          statusBg = isDark ? const Color(0xFF4C0519) : AppColors.statusOccupiedBg;
          statusText = 'OCCUPIED';
          break;
        case TableState.billing:
          statusColor = AppColors.statusBilling;
          statusBg = isDark ? const Color(0xFF451A03) : AppColors.statusBillingBg;
          statusText = 'BILL PENDING';
          break;
        case TableState.cleaning:
          statusColor = AppColors.statusCleaning;
          statusBg = isDark ? const Color(0xFF0E2A54) : AppColors.statusCleaningBg;
          statusText = 'CLEANING';
          break;
      }
    }

    final isOccupied = table.isEnabled && table.status != TableState.available && order != null;
    final elapsedMinutes = table.openedAt != null
        ? DateTime.now().difference(table.openedAt!).inMinutes
        : 0;

    final isLongSitting = isOccupied && elapsedMinutes >= 45;

    return Card(
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: !table.isEnabled
              ? (isDark ? const Color(0xFF334155) : Colors.grey.shade400)
              : (isOccupied
                  ? (isLongSitting ? AppColors.accent : statusColor.withValues(alpha: 0.6))
                  : (isDark ? AppColors.darkBorder : AppColors.border)),
          width: isOccupied ? 1.5 : 1,
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () {
          if (!table.isEnabled) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('${table.tableNumber} is currently turned OFF. Turn it ON from the table menu.')),
            );
            return;
          }
          if (table.isMergedSecondary) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('${table.tableNumber} is merged into ${table.mergedInto}. Opening master order.'),
                duration: const Duration(seconds: 2),
              ),
            );
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => OrderScreen(tableNumber: table.mergedInto!),
              ),
            );
            return;
          }
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => OrderScreen(tableNumber: table.tableNumber),
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Header: Table Number & Status Pill & Context Menu
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: table.isMergedSecondary
                              ? const Color(0xFF64748B)
                              : (table.isMergedMaster
                                  ? const Color(0xFF6366F1)
                                  : (isOccupied ? AppColors.primary : (isDark ? const Color(0xFF334155) : AppColors.borderSubtle))),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          table.isMergedMaster
                              ? '${table.tableNumber} 🔗'
                              : (table.isMergedSecondary ? '${table.tableNumber} ↳' : table.tableNumber),
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: (isOccupied || table.isMergedMaster || table.isMergedSecondary) ? Colors.white : (isDark ? Colors.white : AppColors.textPrimary),
                          ),
                        ),
                      ),
                      if (isOccupied && !table.isMergedSecondary) ...[
                        const SizedBox(width: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1.5),
                          decoration: BoxDecoration(
                            color: isLongSitting
                                ? (isDark ? const Color(0xFF451A03) : AppColors.accentLight)
                                : (isDark ? const Color(0xFF1E293B) : AppColors.background),
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(color: isLongSitting ? AppColors.accent : (isDark ? AppColors.darkBorder : AppColors.border)),
                          ),
                          child: Text(
                            '${elapsedMinutes}m',
                            style: TextStyle(
                              fontSize: 9.5,
                              fontWeight: FontWeight.w600,
                              color: isLongSitting ? AppColors.accent : (isDark ? AppColors.darkTextSecondary : AppColors.textSecondary),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                        decoration: BoxDecoration(
                          color: table.isMergedSecondary ? const Color(0xFFEEF2FF) : statusBg,
                          borderRadius: BorderRadius.circular(5),
                        ),
                        child: Text(
                          table.isMergedSecondary ? 'MERGED' : statusText,
                          style: TextStyle(
                            color: table.isMergedSecondary ? const Color(0xFF6366F1) : statusColor,
                            fontWeight: FontWeight.bold,
                            fontSize: 8.5,
                            letterSpacing: 0.2,
                          ),
                        ),
                      ),
                      SizedBox(
                        width: 22,
                        height: 22,
                        child: PopupMenuButton<String>(
                          icon: const Icon(Icons.more_vert, size: 16, color: AppColors.textSecondary),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          splashRadius: 14,
                        onSelected: (val) {
                          if (val == 'edit_table') {
                            showDialog(
                              context: context,
                              builder: (_) => AddEditTableDialog(table: table),
                            );
                          } else if (val == 'delete_table') {
                            showDialog(
                              context: context,
                              builder: (_) => DeleteTableDialog(table: table),
                            );
                          } else if (val == 'view_qr') {
                            showDialog(
                              context: context,
                              builder: (_) => TableQrCardsDialog(
                                tables: ref.read(tablesProvider),
                                initialTable: table.tableNumber,
                              ),
                            );
                          } else if (val == 'preview_menu') {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => DigitalMenuScreen(tableNumber: table.tableNumber),
                              ),
                            );
                          } else if (val == 'unmerge') {
                            ref.read(tablesProvider.notifier).unmergeTable(table.tableNumber);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Unmerged ${table.tableNumber} and restored separate tables!')),
                            );
                          } else if (val == 'toggle_enable') {
                            ref.read(tablesProvider.notifier).toggleTableEnabled(table.tableNumber);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('${table.tableNumber} is now ${table.isEnabled ? "DISABLED / OFF" : "ENABLED / ON"}'),
                              ),
                            );
                          } else if (val == 'free_reset') {
                            ref.read(tablesProvider.notifier).forceResetTable(table.tableNumber);
                            ref.read(ordersProvider.notifier).removeOrder(table.tableNumber);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('${table.tableNumber} has been freed and reset to Available!'),
                                backgroundColor: AppColors.statusAvailable,
                              ),
                            );
                          }
                        },
                        itemBuilder: (context) => [
                          PopupMenuItem(
                            value: 'edit_table',
                            child: Row(
                              children: const [
                                Icon(Icons.edit_outlined, size: 18, color: AppColors.primary),
                                SizedBox(width: 8),
                                Text('Edit Table Details'),
                              ],
                            ),
                          ),
                          if (table.isMergedMaster || table.isMergedSecondary)
                            PopupMenuItem(
                              value: 'unmerge',
                              child: Row(
                                children: [
                                  const Icon(Icons.link_off, size: 18, color: Colors.orange),
                                  const SizedBox(width: 8),
                                  Text(table.isMergedMaster ? 'Unmerge Group Tables' : 'Unmerge from ${table.mergedInto}'),
                                ],
                              ),
                            ),
                          PopupMenuItem(
                            value: 'view_qr',
                            child: Row(
                              children: const [
                                Icon(Icons.qr_code_2, size: 18, color: AppColors.primary),
                                SizedBox(width: 8),
                                Text('Table QR Card'),
                              ],
                            ),
                          ),
                          PopupMenuItem(
                            value: 'preview_menu',
                            child: Row(
                              children: const [
                                Icon(Icons.restaurant_menu, size: 18, color: Colors.orange),
                                SizedBox(width: 8),
                                Text('Guest Digital Menu'),
                              ],
                            ),
                          ),
                          const PopupMenuDivider(),
                          PopupMenuItem(
                            value: 'free_reset',
                            child: Row(
                              children: const [
                                Icon(Icons.refresh, size: 18, color: Colors.blue),
                                SizedBox(width: 8),
                                Text('Free / Reset Table'),
                              ],
                            ),
                          ),
                          PopupMenuItem(
                            value: 'toggle_enable',
                            child: Row(
                              children: [
                                Icon(
                                  table.isEnabled ? Icons.block : Icons.check_circle_outline,
                                  size: 18,
                                  color: table.isEnabled ? Colors.red : Colors.green,
                                ),
                                SizedBox(width: 8),
                                Text(table.isEnabled ? 'Turn Table OFF' : 'Turn Table ON'),
                              ],
                            ),
                          ),
                          PopupMenuItem(
                            value: 'delete_table',
                            child: Row(
                              children: const [
                                Icon(Icons.delete_outline, size: 18, color: Colors.red),
                                SizedBox(width: 8),
                                Text('Delete Table'),
                              ],
                            ),
                          ),
                        ],
                      ),
                      ),
                    ],
                  ),
                ],
              ),

              // Line 2: Table Name & Floor Zone Badge
              Padding(
                padding: const EdgeInsets.only(top: 2, bottom: 2),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        table.displayName,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: isDark ? Colors.white70 : AppColors.textPrimary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1.5),
                      decoration: BoxDecoration(
                        color: _getSectionColor(table.section).withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: _getSectionColor(table.section).withValues(alpha: 0.25)),
                      ),
                      child: Text(
                        table.section,
                        style: TextStyle(
                          fontSize: 8.5,
                          fontWeight: FontWeight.bold,
                          color: _getSectionColor(table.section),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Middle: Order Content or Seating Info
              if (table.isMergedSecondary)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                      decoration: BoxDecoration(
                        color: const Color(0xFF6366F1).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.link, size: 14, color: Color(0xFF6366F1)),
                          const SizedBox(width: 4),
                          Text(
                            'Joined into ${table.mergedInto}',
                            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF6366F1)),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Seating (+${table.capacity}) added to ${table.mergedInto}',
                      style: TextStyle(
                        fontSize: 11,
                        color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary,
                      ),
                    ),
                  ],
                )
              else if (isOccupied)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (table.isMergedMaster) ...[
                      Container(
                        margin: const EdgeInsets.only(bottom: 4),
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFF6366F1).withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          '🔗 +${table.mergedTables.join(", ")} (${table.totalCapacity} Seats)',
                          style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF6366F1)),
                        ),
                      ),
                    ],
                    Text(
                      '${order.items.fold(0, (sum, i) => sum + i.quantity)} Items • ${order.orderNumber}',
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '₹${order.grandTotal.toStringAsFixed(2)}',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: isDark ? const Color(0xFFFF7043) : AppColors.primary,
                        letterSpacing: -0.5,
                      ),
                    ),
                  ],
                )
              else
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.people_outline,
                          size: 16,
                          color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            'Capacity: ${table.capacity} Guests',
                            style: TextStyle(
                              color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary,
                              fontSize: 13,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Tap to open & take order →',
                      style: TextStyle(
                        color: isDark ? const Color(0xFFFF7043) : AppColors.primary,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),

              // Bottom Actions
              if (table.isMergedSecondary)
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      minimumSize: Size.zero,
                      foregroundColor: const Color(0xFF6366F1),
                    ),
                    icon: const Icon(Icons.link, size: 14),
                    label: Text('Open Master (${table.mergedInto})', style: const TextStyle(fontSize: 12)),
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => OrderScreen(tableNumber: table.mergedInto!),
                        ),
                      );
                    },
                  ),
                )
              else if (isOccupied)
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
                          minimumSize: Size.zero,
                        ),
                        onPressed: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => OrderScreen(tableNumber: table.tableNumber),
                            ),
                          );
                        },
                        child: const FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text('Add Items', style: TextStyle(fontSize: 11)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
                          minimumSize: Size.zero,
                          backgroundColor: statusColor,
                        ),
                        onPressed: () {
                          showDialog(
                            context: context,
                            builder: (_) => BillingDialog(order: order),
                          );
                        },
                        child: const FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text('Bill & Pay', style: TextStyle(fontSize: 11)),
                        ),
                      ),
                    ),
                  ],
                )
              else
                const SizedBox(height: 6),
            ],
          ),
        ),
      ),
    );
  }

  void _showTransferTableDialog(BuildContext context, WidgetRef ref, List<RestaurantTable> tables) {
    final occupiedTables = tables.where((t) => t.status != TableState.available).toList();
    final availableTables = tables.where((t) => t.status == TableState.available).toList();

    if (occupiedTables.isEmpty || availableTables.isEmpty) return;

    String sourceTable = occupiedTables.first.tableNumber;
    String targetTable = availableTables.first.tableNumber;

    showDialog(
      context: context,
      builder: (_) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: const Text('Move / Transfer Table'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Move guest party and their current active order to a new table:'),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          initialValue: sourceTable,
                          decoration: const InputDecoration(labelText: 'From Table', border: OutlineInputBorder()),
                          items: occupiedTables.map((t) => DropdownMenuItem(value: t.tableNumber, child: Text(t.tableNumber))).toList(),
                          onChanged: (val) {
                            if (val != null) setModalState(() => sourceTable = val);
                          },
                        ),
                      ),
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 12),
                        child: Icon(Icons.arrow_forward),
                      ),
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          initialValue: targetTable,
                          decoration: const InputDecoration(labelText: 'To Table', border: OutlineInputBorder()),
                          items: availableTables.map((t) => DropdownMenuItem(value: t.tableNumber, child: Text(t.tableNumber))).toList(),
                          onChanged: (val) {
                            if (val != null) setModalState(() => targetTable = val);
                          },
                        ),
                      ),
                    ],
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
                    final orders = ref.read(ordersProvider);
                    final order = orders[sourceTable];
                    if (order != null) {
                      // Move order to target table
                      ref.read(ordersProvider.notifier).removeOrder(sourceTable);
                      final movedOrder = Order(
                        id: order.id,
                        orderNumber: order.orderNumber,
                        tableNumber: targetTable,
                        items: order.items,
                        discount: order.discount,
                        taxRate: order.taxRate,
                        customerName: order.customerName,
                        customerPhone: order.customerPhone,
                        createdAt: order.createdAt,
                      );
                      // Update orders map
                      ref.read(ordersProvider.notifier).initializeOrder(targetTable, taxRate: order.taxRate);
                      for (final item in order.items) {
                        final menuItem = ref.read(menuProvider).firstWhere((m) => m.id == item.menuItemId);
                        ref.read(ordersProvider.notifier).addItemToOrder(targetTable, menuItem, quantity: item.quantity, notes: item.notes);
                      }
                      ref.read(tablesProvider.notifier).occupyTable(targetTable, 4, movedOrder.id);
                      ref.read(tablesProvider.notifier).releaseTable(sourceTable);
                    }
                    Navigator.of(context).pop();
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Transferred from $sourceTable to $targetTable successfully!')),
                    );
                  },
                  child: const Text('Confirm Move'),
                ),
              ],
            );
          },
        );
      },
    );
  }
}
