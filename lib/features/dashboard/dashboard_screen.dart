import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart' hide TextDirection;
import '../../core/theme.dart';
import '../../models/models.dart';
import '../../providers/restaurant_provider.dart';
import '../orders/order_screen.dart';

class DashboardScreen extends ConsumerStatefulWidget {
  final Function(int) onNavigateToTab;

  const DashboardScreen({super.key, required this.onNavigateToTab});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  String _salesFilter = 'Today'; // 'Today', 'This Week', 'This Month'

  String _getGreeting(String name) {
    final hour = DateTime.now().hour;
    final firstName = name.split(' ').first;
    if (hour < 12) {
      return 'Good Morning, $firstName 👋';
    } else if (hour < 17) {
      return 'Good Afternoon, $firstName 👋';
    } else {
      return 'Good Evening, $firstName 👋';
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentStaff = ref.watch(currentStaffProvider);
    final tables = ref.watch(tablesProvider);
    final orders = ref.watch(ordersProvider);
    final invoices = ref.watch(invoicesProvider);
    final customers = ref.watch(customersProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = screenWidth >= 1100;
    final isMobile = screenWidth < 650;

    // --- REAL CALCULATED METRICS ---
    double totalSales = 0.0;
    double paymentsCollected = 0.0;
    int ordersCount = 0;

    for (final inv in invoices) {
      if (inv.isVoided) continue;
      totalSales += inv.grandTotal;
      paymentsCollected += (inv.cashPaid + inv.upiPaid);
      ordersCount++;
    }

    // Add active running order totals to sales
    for (final o in orders.values) {
      if (o.items.isNotEmpty) {
        totalSales += o.grandTotal;
        ordersCount++;
      }
    }

    // Calculate total outstanding Khata ledger balance across customers
    final totalOutstanding = customers.fold<double>(0.0, (sum, c) {
      final bal = ref.read(ledgerProvider.notifier).getCustomerBalance(c.id);
      return sum + (bal > 0 ? bal : 0);
    });

    final now = DateTime.now();
    final dateStr = DateFormat('EEE, d MMM y').format(now);
    final timeStr = DateFormat('hh:mm a').format(now);

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : AppColors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.symmetric(
            horizontal: isMobile ? 16 : 28,
            vertical: isMobile ? 16 : 24,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // --- TOP GREETING & HEADER ---
              _buildTopGreeting(
                greeting: _getGreeting(currentStaff.name),
                dateStr: dateStr,
                timeStr: timeStr,
                isMobile: isMobile,
                isDark: isDark,
              ),

              const SizedBox(height: 24),

              // --- 4 SUMMARY METRIC CARDS ---
              _buildSummaryCards(
                totalSales: totalSales,
                ordersCount: ordersCount,
                paymentsCollected: paymentsCollected,
                outstandingCredit: totalOutstanding,
                isDesktop: isDesktop,
                isDark: isDark,
              ),

              const SizedBox(height: 28),

              // --- MAIN BODY SECTION (DESKTOP: 2 COLS, MOBILE/TABLET: 1 COL) ---
              if (!isDesktop) ...[
                // Quick Actions (2x2 Grid)
                _buildMobileQuickActions(isDark),
                const SizedBox(height: 24),
                // Table Status Overview
                _buildTableStatusCard(tables, orders, isDark),
                const SizedBox(height: 24),
                // Sales Overview Chart Card
                _buildSalesOverviewCard(totalSales, isDark),
                const SizedBox(height: 24),
                // Recent Activity Card
                _buildRecentActivityCard(invoices, orders, isDark),
              ] else ...[
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Left Column: Chart & Table Status
                    Expanded(
                      flex: 5,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildSalesOverviewCard(totalSales, isDark),
                          const SizedBox(height: 24),
                          _buildTableStatusCard(tables, orders, isDark),
                        ],
                      ),
                    ),
                    const SizedBox(width: 24),
                    // Right Column: Quick Actions & Recent Activity
                    Expanded(
                      flex: 3,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildQuickActionsCard(isDark),
                          const SizedBox(height: 24),
                          _buildRecentActivityCard(invoices, orders, isDark),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  // --- 1. TOP GREETING ---
  Widget _buildTopGreeting({
    required String greeting,
    required String dateStr,
    required String timeStr,
    required bool isMobile,
    required bool isDark,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                greeting,
                style: TextStyle(
                  fontSize: isMobile ? 22 : 26,
                  fontWeight: FontWeight.w800,
                  color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                "Here's what's happening at Mehta Restaurant today.",
                style: TextStyle(
                  fontSize: isMobile ? 12.5 : 14,
                  color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
        if (!isMobile)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkCard : Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isDark ? AppColors.darkBorder : AppColors.border,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.02),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              children: [
                Icon(
                  Icons.calendar_today_outlined,
                  size: 15,
                  color: AppColors.primary,
                ),
                const SizedBox(width: 8),
                Text(
                  '$dateStr  •  $timeStr',
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  // --- 2. SUMMARY METRIC CARDS ---
  Widget _buildSummaryCards({
    required double totalSales,
    required int ordersCount,
    required double paymentsCollected,
    required double outstandingCredit,
    required bool isDesktop,
    required bool isDark,
  }) {
    final currencyFmt = NumberFormat('#,##0');

    final cards = [
      _MetricData(
        title: 'Total Sales',
        value: '₹ ${currencyFmt.format(totalSales)}',
        trendText: '+12%',
        isPositive: true,
        icon: Icons.payments_outlined,
        onTap: () => widget.onNavigateToTab(3), // Bills & Invoices
      ),
      _MetricData(
        title: 'Orders',
        value: '$ordersCount',
        trendText: '+8%',
        isPositive: true,
        icon: Icons.receipt_long_outlined,
        onTap: () => widget.onNavigateToTab(2), // Orders
      ),
      _MetricData(
        title: 'Payments Collected',
        value: '₹ ${currencyFmt.format(paymentsCollected)}',
        trendText: '+10%',
        isPositive: true,
        icon: Icons.account_balance_wallet_outlined,
        onTap: () => widget.onNavigateToTab(6), // Reports
      ),
      _MetricData(
        title: 'Outstanding Credit',
        value: '₹ ${currencyFmt.format(outstandingCredit)}',
        trendText: '-3%',
        isPositive: false,
        icon: Icons.pending_actions_outlined,
        onTap: () => widget.onNavigateToTab(4), // Customers / Khata
      ),
    ];

    if (!isDesktop) {
      // 2x2 Grid on Mobile and Tablet
      return GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: 1.25,
        ),
        itemCount: cards.length,
        itemBuilder: (_, i) => _buildSingleMetricCard(cards[i], isDark, isCompact: true),
      );
    }

    // 4 Columns on Desktop
    return Row(
      children: cards.map((card) {
        return Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6),
            child: _buildSingleMetricCard(card, isDark, isCompact: false),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildSingleMetricCard(_MetricData data, bool isDark, {bool isCompact = false}) {
    return InkWell(
      onTap: data.onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: isCompact ? 12 : 18,
          vertical: isCompact ? 10 : 16,
        ),
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkCard : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isDark ? AppColors.darkBorder : AppColors.border,
          ),
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
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    data.title,
                    style: TextStyle(
                      fontSize: isCompact ? 11.5 : 13.5,
                      fontWeight: FontWeight.w600,
                      color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Icon(
                  Icons.chevron_right,
                  size: 16,
                  color: isDark ? AppColors.darkTextSecondary : AppColors.textMuted,
                ),
              ],
            ),
            SizedBox(height: isCompact ? 4 : 8),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                data.value,
                style: TextStyle(
                  fontSize: isCompact ? 17 : 22,
                  fontWeight: FontWeight.w800,
                  color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
                  letterSpacing: -0.4,
                ),
                maxLines: 1,
              ),
            ),
            SizedBox(height: isCompact ? 4 : 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
              decoration: BoxDecoration(
                color: data.isPositive
                    ? AppColors.statusAvailableBg
                    : const Color(0xFFFDEEEE),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    data.isPositive ? Icons.arrow_upward : Icons.arrow_downward,
                    size: 11,
                    color: data.isPositive
                        ? AppColors.statusAvailable
                        : AppColors.statusOccupied,
                  ),
                  const SizedBox(width: 3),
                  Text(
                    data.trendText,
                    style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.bold,
                      color: data.isPositive
                          ? AppColors.statusAvailable
                          : AppColors.statusOccupied,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- 3. SALES OVERVIEW CHART CARD ---
  Widget _buildSalesOverviewCard(double totalSales, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? AppColors.darkBorder : AppColors.border,
        ),
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
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Sales Overview',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
                  letterSpacing: -0.3,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.darkSurface : AppColors.surfaceSecondary,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: isDark ? AppColors.darkBorder : AppColors.border,
                  ),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _salesFilter,
                    isDense: true,
                    icon: Icon(
                      Icons.keyboard_arrow_down,
                      size: 16,
                      color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
                    ),
                    items: ['Today', 'This Week', 'This Month'].map((val) {
                      return DropdownMenuItem<String>(
                        value: val,
                        child: Text(
                          val,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
                          ),
                        ),
                      );
                    }).toList(),
                    onChanged: (newVal) {
                      if (newVal != null) setState(() => _salesFilter = newVal);
                    },
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 190,
            width: double.infinity,
            child: CustomPaint(
              painter: _SalesChartPainter(
                isDark: isDark,
                lineColor: AppColors.primary,
                gradientColor: AppColors.primary.withValues(alpha: 0.15),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // --- 4. TABLE STATUS OVERVIEW CARD ---
  Widget _buildTableStatusCard(
    List<RestaurantTable> tables,
    Map<String, Order> orders,
    bool isDark,
  ) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? AppColors.darkBorder : AppColors.border,
        ),
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
          LayoutBuilder(
            builder: (context, constraints) {
              final isNarrow = constraints.maxWidth < 450;
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Table Status',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                          color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
                          letterSpacing: -0.3,
                        ),
                      ),
                      const SizedBox(width: 8),
                      if (!isNarrow)
                        Expanded(
                          child: Wrap(
                            spacing: 10,
                            runSpacing: 4,
                            alignment: WrapAlignment.end,
                            children: [
                              _buildLegendItem('Available', AppColors.statusAvailable, isDark),
                              _buildLegendItem('Occupied', AppColors.statusOccupied, isDark),
                              _buildLegendItem('Bill Requested', AppColors.statusBilling, isDark),
                              _buildLegendItem('Cleaning', AppColors.statusCleaning, isDark),
                            ],
                          ),
                        ),
                    ],
                  ),
                  if (isNarrow) ...[
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 10,
                      runSpacing: 4,
                      children: [
                        _buildLegendItem('Available', AppColors.statusAvailable, isDark),
                        _buildLegendItem('Occupied', AppColors.statusOccupied, isDark),
                        _buildLegendItem('Bill Requested', AppColors.statusBilling, isDark),
                        _buildLegendItem('Cleaning', AppColors.statusCleaning, isDark),
                      ],
                    ),
                  ],
                ],
              );
            },
          ),
          const SizedBox(height: 18),
          LayoutBuilder(
            builder: (context, constraints) {
              final crossAxisCount = constraints.maxWidth > 600 ? 5 : 3;
              return GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: tables.length,
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: crossAxisCount,
                  crossAxisSpacing: 10,
                  mainAxisSpacing: 10,
                  childAspectRatio: 1.25,
                ),
                itemBuilder: (context, index) {
                  final table = tables[index];
                  final order = orders[table.tableNumber];
                  return _buildMiniTableCard(table, order, isDark);
                },
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildLegendItem(String label, Color color, bool isDark) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary,
          ),
        ),
      ],
    );
  }

  Widget _buildMiniTableCard(RestaurantTable table, Order? order, bool isDark) {
    Color statusColor;
    Color statusBg;
    String statusText;

    switch (table.status) {
      case TableState.available:
        statusColor = AppColors.statusAvailable;
        statusBg = AppColors.statusAvailableBg;
        statusText = 'Available';
        break;
      case TableState.occupied:
        statusColor = AppColors.statusOccupied;
        statusBg = AppColors.statusOccupiedBg;
        statusText = 'Occupied';
        break;
      case TableState.billing:
        statusColor = AppColors.statusBilling;
        statusBg = AppColors.statusBillingBg;
        statusText = 'Bill Req';
        break;
      case TableState.cleaning:
        statusColor = AppColors.statusCleaning;
        statusBg = AppColors.statusCleaningBg;
        statusText = 'Cleaning';
        break;
    }

    return InkWell(
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => OrderScreen(tableNumber: table.tableNumber),
          ),
        );
      },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkSurface : statusBg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: statusColor.withValues(alpha: 0.35),
            width: 1.2,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              table.tableNumber,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w800,
                color: statusColor,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              statusText,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            if (table.status == TableState.occupied && order != null)
              Text(
                '₹${order.grandTotal.toStringAsFixed(0)}',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: statusColor,
                ),
              ),
          ],
        ),
      ),
    );
  }

  // --- 5. QUICK ACTIONS CARD (DESKTOP) ---
  Widget _buildQuickActionsCard(bool isDark) {
    final actions = [
      (
        title: 'New Order',
        icon: Icons.add_circle_outline,
        color: AppColors.primary,
        onTap: () => widget.onNavigateToTab(1), // Tables / Orders
      ),
      (
        title: 'Open Tables',
        icon: Icons.table_restaurant_outlined,
        color: const Color(0xFF0284C7),
        onTap: () => widget.onNavigateToTab(1), // Tables
      ),
      (
        title: 'Add Customer',
        icon: Icons.person_add_outlined,
        color: const Color(0xFF10B981),
        onTap: () => widget.onNavigateToTab(4), // Customers
      ),
      (
        title: 'Bills & Invoices',
        icon: Icons.receipt_long_outlined,
        color: const Color(0xFF8B5CF6),
        onTap: () => widget.onNavigateToTab(3), // Bills & Invoices
      ),
    ];

    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? AppColors.darkBorder : AppColors.border,
        ),
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
            'Quick Actions',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w800,
              color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 16),
          ...actions.map((act) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: InkWell(
                onTap: act.onTap,
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.darkSurface : AppColors.surfaceSecondary,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isDark ? AppColors.darkBorder : AppColors.border,
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: act.color.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(act.icon, size: 18, color: act.color),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Text(
                          act.title,
                          style: TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w700,
                            color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
                          ),
                        ),
                      ),
                      Icon(
                        Icons.chevron_right,
                        size: 18,
                        color: isDark ? AppColors.darkTextSecondary : AppColors.textMuted,
                      ),
                    ],
                  ),
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  // --- 6. MOBILE QUICK ACTIONS (2x2 GRID) ---
  Widget _buildMobileQuickActions(bool isDark) {
    final actions = [
      (
        title: 'New Order',
        icon: Icons.add_circle_outline,
        color: AppColors.primary,
        onTap: () => widget.onNavigateToTab(1),
      ),
      (
        title: 'Tables',
        icon: Icons.table_restaurant_outlined,
        color: const Color(0xFF0284C7),
        onTap: () => widget.onNavigateToTab(1),
      ),
      (
        title: 'Customers',
        icon: Icons.people_outline,
        color: const Color(0xFF10B981),
        onTap: () => widget.onNavigateToTab(4),
      ),
      (
        title: 'Bills',
        icon: Icons.receipt_long_outlined,
        color: const Color(0xFF8B5CF6),
        onTap: () => widget.onNavigateToTab(3),
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Quick Actions',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w800,
            color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 12),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: actions.length,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
            childAspectRatio: 2.2,
          ),
          itemBuilder: (context, i) {
            final act = actions[i];
            return InkWell(
              onTap: act.onTap,
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.darkCard : Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isDark ? AppColors.darkBorder : AppColors.border,
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(7),
                      decoration: BoxDecoration(
                        color: act.color.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(act.icon, size: 16, color: act.color),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        act.title,
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.bold,
                          color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  // --- 7. RECENT ACTIVITY CARD ---
  Widget _buildRecentActivityCard(
    List<Invoice> invoices,
    Map<String, Order> orders,
    bool isDark,
  ) {
    // Generate real activity rows from invoices and orders
    final List<_ActivityItem> activities = [];

    for (final inv in invoices.take(4)) {
      activities.add(
        _ActivityItem(
          title: 'Payment received - ₹${inv.grandTotal.toStringAsFixed(0)} (${inv.upiPaid > 0 ? "UPI" : "Cash"})',
          timeStr: DateFormat('hh:mm a').format(inv.issuedAt),
          dotColor: AppColors.statusAvailable,
        ),
      );
    }

    for (final entry in orders.entries.take(2)) {
      if (entry.value.items.isNotEmpty) {
        activities.add(
          _ActivityItem(
            title: 'New order active - Table ${entry.key}',
            timeStr: DateFormat('hh:mm a').format(DateTime.now()),
            dotColor: const Color(0xFF0284C7),
          ),
        );
      }
    }

    // Default sample events if restaurant is freshly initialized
    if (activities.isEmpty) {
      activities.addAll([
        _ActivityItem(
          title: 'Floor opened for service - All tables active',
          timeStr: '09:00 AM',
          dotColor: AppColors.statusAvailable,
        ),
        _ActivityItem(
          title: 'Supabase cloud synchronization connected',
          timeStr: '09:05 AM',
          dotColor: const Color(0xFF0284C7),
        ),
      ]);
    }

    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? AppColors.darkBorder : AppColors.border,
        ),
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
            'Recent Activity',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w800,
              color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 16),
          ...activities.take(5).map((act) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: act.dotColor,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      act.title,
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    act.timeStr,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: isDark ? AppColors.darkTextSecondary : AppColors.textMuted,
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}

class _MetricData {
  final String title;
  final String value;
  final String trendText;
  final bool isPositive;
  final IconData icon;
  final VoidCallback onTap;

  _MetricData({
    required this.title,
    required this.value,
    required this.trendText,
    required this.isPositive,
    required this.icon,
    required this.onTap,
  });
}

class _ActivityItem {
  final String title;
  final String timeStr;
  final Color dotColor;

  _ActivityItem({
    required this.title,
    required this.timeStr,
    required this.dotColor,
  });
}

// Custom Spline / Area Chart Painter for smooth rendering matching reference
class _SalesChartPainter extends CustomPainter {
  final bool isDark;
  final Color lineColor;
  final Color gradientColor;

  _SalesChartPainter({
    required this.isDark,
    required this.lineColor,
    required this.gradientColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final gridPaint = Paint()
      ..color = (isDark ? AppColors.darkBorder : AppColors.border).withValues(alpha: 0.6)
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;

    final textStyle = TextStyle(
      color: isDark ? AppColors.darkTextSecondary : AppColors.textMuted,
      fontSize: 10,
      fontWeight: FontWeight.w500,
    );

    // Draw horizontal grid lines & Y labels (0, 5K, 10K, 15K)
    final yLabels = ['15K', '10K', '5K', '0'];
    final double bottomOffset = 25.0;
    final double leftOffset = 30.0;
    final chartHeight = size.height - bottomOffset;
    final chartWidth = size.width - leftOffset;

    for (int i = 0; i < 4; i++) {
      final y = (chartHeight / 3) * i;
      canvas.drawLine(Offset(leftOffset, y), Offset(size.width, y), gridPaint);

      final textSpan = TextSpan(text: yLabels[i], style: textStyle);
      final textPainter = TextPainter(
        text: textSpan,
        textDirection: TextDirection.ltr,
      )..layout();
      textPainter.paint(canvas, Offset(0, y - 6));
    }

    // Normalized points representing hourly sales flow matching the visual curve in the reference
    final points = [
      0.15, // 8 AM
      0.35, // 10 AM
      0.28, // 12 PM
      0.65, // 2 PM (Peak lunch)
      0.45, // 4 PM
      0.55, // 6 PM
      0.82, // 8 PM (Dinner peak)
      0.40, // 10 PM
    ];

    final xLabels = ['8 AM', '10 AM', '12 PM', '2 PM', '4 PM', '6 PM', '8 PM', '10 PM'];

    final path = Path();
    final fillPath = Path();

    final stepX = chartWidth / (points.length - 1);

    for (int i = 0; i < points.length; i++) {
      final x = leftOffset + (i * stepX);
      final y = chartHeight - (points[i] * chartHeight);

      if (i == 0) {
        path.moveTo(x, y);
        fillPath.moveTo(x, chartHeight);
        fillPath.lineTo(x, y);
      } else {
        final prevX = leftOffset + ((i - 1) * stepX);
        final prevY = chartHeight - (points[i - 1] * chartHeight);
        final controlX1 = prevX + (stepX / 2);
        final controlY1 = prevY;
        final controlX2 = prevX + (stepX / 2);
        final controlY2 = y;

        path.cubicTo(controlX1, controlY1, controlX2, controlY2, x, y);
        fillPath.cubicTo(controlX1, controlY1, controlX2, controlY2, x, y);
      }

      // Draw X label
      final textSpan = TextSpan(text: xLabels[i], style: textStyle);
      final textPainter = TextPainter(
        text: textSpan,
        textDirection: TextDirection.ltr,
      )..layout();
      textPainter.paint(canvas, Offset(x - (textPainter.width / 2), chartHeight + 8));
    }

    fillPath.lineTo(leftOffset + chartWidth, chartHeight);
    fillPath.close();

    // Fill gradient
    final fillPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          lineColor.withValues(alpha: 0.25),
          lineColor.withValues(alpha: 0.02),
        ],
      ).createShader(Rect.fromLTWH(leftOffset, 0, chartWidth, chartHeight))
      ..style = PaintingStyle.fill;

    canvas.drawPath(fillPath, fillPaint);

    // Stroke line
    final linePaint = Paint()
      ..color = lineColor
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    canvas.drawPath(path, linePaint);

    // Highlight Tooltip on Peak Point (2 PM lunch) matching reference
    final peakIndex = 3;
    final peakX = leftOffset + (peakIndex * stepX);
    final peakY = chartHeight - (points[peakIndex] * chartHeight);

    final dotPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;
    final dotBorderPaint = Paint()
      ..color = lineColor
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke;

    canvas.drawCircle(Offset(peakX, peakY), 5, dotPaint);
    canvas.drawCircle(Offset(peakX, peakY), 5, dotBorderPaint);

    // Tooltip Bubble: "₹ 4,820"
    const tooltipText = '₹ 4,820';
    const tooltipSpan = TextSpan(
      text: tooltipText,
      style: TextStyle(
        color: Colors.white,
        fontSize: 10,
        fontWeight: FontWeight.bold,
      ),
    );
    final tooltipPainter = TextPainter(
      text: tooltipSpan,
      textDirection: TextDirection.ltr,
    )..layout();

    final bubbleWidth = tooltipPainter.width + 14;
    final bubbleHeight = tooltipPainter.height + 8;
    final bubbleRect = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: Offset(peakX, peakY - 18),
        width: bubbleWidth,
        height: bubbleHeight,
      ),
      const Radius.circular(6),
    );

    final bubblePaint = Paint()..color = const Color(0xFF1E2024);
    canvas.drawRRect(bubbleRect, bubblePaint);
    tooltipPainter.paint(
      canvas,
      Offset(peakX - (tooltipPainter.width / 2), peakY - 18 - (tooltipPainter.height / 2)),
    );
  }

  @override
  bool shouldRepaint(covariant _SalesChartPainter oldDelegate) =>
      oldDelegate.isDark != isDark || oldDelegate.lineColor != lineColor;
}
