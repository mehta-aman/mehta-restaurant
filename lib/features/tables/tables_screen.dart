import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme.dart';
import '../../models/models.dart';
import '../../providers/restaurant_provider.dart';
import '../billing/billing_dialog.dart';
import '../orders/order_screen.dart';

class TablesScreen extends ConsumerWidget {
  const TablesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tables = ref.watch(tablesProvider);
    final orders = ref.watch(ordersProvider);

    // Compute live hall metrics
    final availableCount = tables.where((t) => t.status == TableState.available).length;
    final occupiedCount = tables.where((t) => t.status != TableState.available).length;
    final activeHallTotal = orders.values.fold(0.0, (sum, o) => sum + o.grandTotal);

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: const [
            Text('Floor & Tables Overview'),
            Text(
              'Ground Floor • Main Hall (10 Tables • 60 Seats)',
              style: TextStyle(fontSize: 12, color: AppColors.textSecondary, fontWeight: FontWeight.normal),
            ),
          ],
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 20),
            child: Row(
              children: [
                _buildStatusLegend('Available', AppColors.statusAvailable),
                const SizedBox(width: 14),
                _buildStatusLegend('Occupied', AppColors.statusOccupied),
                const SizedBox(width: 14),
                _buildStatusLegend('Billing', AppColors.statusBilling),
              ],
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // Live Floor Summary Banner
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(bottom: BorderSide(color: AppColors.border)),
            ),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildHallStatItem('Available Tables', '$availableCount / 10', AppColors.statusAvailable, Icons.check_circle_outline),
                  const SizedBox(width: 20),
                  _buildHallStatItem('Occupied Tables', '$occupiedCount / 10', AppColors.statusOccupied, Icons.people_alt_outlined),
                  const SizedBox(width: 20),
                  _buildHallStatItem('Live Dining Total', '₹${activeHallTotal.toStringAsFixed(0)}', AppColors.primary, Icons.currency_rupee),
                  const SizedBox(width: 24),
                  OutlinedButton.icon(
                    icon: const Icon(Icons.swap_horiz, size: 18),
                    label: const Text('Move / Transfer Table'),
                    onPressed: occupiedCount == 0
                        ? null
                        : () => _showTransferTableDialog(context, ref, tables),
                  ),
                ],
              ),
            ),
          ),

          // 10-Table Grid View
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: GridView.builder(
                gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                  maxCrossAxisExtent: 280,
                  mainAxisExtent: 200,
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                ),
                itemCount: tables.length,
                itemBuilder: (context, index) {
                  final table = tables[index];
                  final order = orders[table.tableNumber];
                  return _buildModernTableCard(context, ref, table, order);
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHallStatItem(String label, String value, Color color, IconData icon) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: color, size: 20),
        ),
        const SizedBox(width: 10),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary, fontWeight: FontWeight.w500)),
            Text(value, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: color)),
          ],
        ),
      ],
    );
  }

  Widget _buildStatusLegend(String label, Color color) {
    return Row(
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
      ],
    );
  }

  Widget _buildModernTableCard(BuildContext context, WidgetRef ref, RestaurantTable table, Order? order) {
    Color statusColor;
    Color statusBg;
    String statusText;

    if (!table.isEnabled) {
      statusColor = Colors.grey.shade700;
      statusBg = Colors.grey.shade200;
      statusText = 'DISABLED / OFF';
    } else {
      switch (table.status) {
        case TableState.available:
          statusColor = AppColors.statusAvailable;
          statusBg = AppColors.statusAvailableBg;
          statusText = 'AVAILABLE';
          break;
        case TableState.occupied:
          statusColor = AppColors.statusOccupied;
          statusBg = AppColors.statusOccupiedBg;
          statusText = 'OCCUPIED';
          break;
        case TableState.billing:
          statusColor = AppColors.statusBilling;
          statusBg = AppColors.statusBillingBg;
          statusText = 'BILL PENDING';
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
              ? Colors.grey.shade400
              : (isOccupied
                  ? (isLongSitting ? AppColors.accent : statusColor.withValues(alpha: 0.6))
                  : AppColors.border),
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
                          color: isOccupied ? AppColors.secondary : AppColors.background,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          table.tableNumber,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: isOccupied ? Colors.white : AppColors.textPrimary,
                          ),
                        ),
                      ),
                      if (isOccupied) ...[
                        const SizedBox(width: 5),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                          decoration: BoxDecoration(
                            color: isLongSitting ? AppColors.accentLight : AppColors.background,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: isLongSitting ? AppColors.accent : AppColors.border),
                          ),
                          child: Text(
                            '⏱ ${elapsedMinutes}m',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: isLongSitting ? Colors.brown : AppColors.textSecondary,
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
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                        decoration: BoxDecoration(
                          color: statusBg,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          statusText,
                          style: TextStyle(
                            color: statusColor,
                            fontWeight: FontWeight.bold,
                            fontSize: 9.5,
                            letterSpacing: 0.3,
                          ),
                        ),
                      ),
                      PopupMenuButton<String>(
                        icon: const Icon(Icons.more_vert, size: 16, color: AppColors.textSecondary),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        splashRadius: 14,
                        onSelected: (val) {
                          if (val == 'toggle_enable') {
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
                                const SizedBox(width: 8),
                                Text(table.isEnabled ? 'Turn Table OFF' : 'Turn Table ON'),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),

              // Middle: Order Content or Seating Info
              if (isOccupied)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${order.items.fold(0, (sum, i) => sum + i.quantity)} Items • ${order.orderNumber}',
                      style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '₹${order.grandTotal.toStringAsFixed(2)}',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primary,
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
                        const Icon(Icons.people_outline, size: 16, color: AppColors.textSecondary),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            'Capacity: ${table.capacity} Guests',
                            style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Tap to open & take order →',
                      style: TextStyle(color: AppColors.primary, fontSize: 12.5, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),

              // Bottom Actions
              if (isOccupied)
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          minimumSize: Size.zero,
                        ),
                        onPressed: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => OrderScreen(tableNumber: table.tableNumber),
                            ),
                          );
                        },
                        child: const Text('Add Items', style: TextStyle(fontSize: 12)),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          minimumSize: Size.zero,
                          backgroundColor: statusColor,
                        ),
                        onPressed: () {
                          showDialog(
                            context: context,
                            builder: (_) => BillingDialog(order: order),
                          );
                        },
                        child: const Text('Bill & Pay', style: TextStyle(fontSize: 12)),
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
                          value: sourceTable,
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
                          value: targetTable,
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
