import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme.dart';
import '../../models/models.dart';
import '../../providers/restaurant_provider.dart';

class TableMergeDialog extends ConsumerStatefulWidget {
  final List<RestaurantTable> tables;
  final String? initialMasterTable;

  const TableMergeDialog({
    super.key,
    required this.tables,
    this.initialMasterTable,
  });

  @override
  ConsumerState<TableMergeDialog> createState() => _TableMergeDialogState();
}

class _TableMergeDialogState extends ConsumerState<TableMergeDialog> {
  late String _masterTable;
  final Set<String> _selectedSecondary = {};

  @override
  void initState() {
    super.initState();
    // Default to initial table or first available/occupied table
    final initial = widget.initialMasterTable;
    if (initial != null && widget.tables.any((t) => t.tableNumber == initial && !t.isMergedSecondary)) {
      _masterTable = initial;
    } else {
      final valid = widget.tables.firstWhere(
        (t) => !t.isMergedSecondary,
        orElse: () => widget.tables.first,
      );
      _masterTable = valid.tableNumber;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final liveTables = ref.watch(tablesProvider);
    final masterObj = liveTables.firstWhere((t) => t.tableNumber == _masterTable, orElse: () => liveTables.first);

    // Eligible secondary tables (not already secondary to someone else, and not the master)
    final eligibleTables = liveTables.where((t) => t.tableNumber != _masterTable && !t.isMergedSecondary).toList();

    final totalSeats = 6 * (1 + _selectedSecondary.length);

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      backgroundColor: isDark ? AppColors.darkCard : Colors.white,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 580),
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
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: const Color(0xFF6366F1).withValues(alpha: 0.14),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.link, color: Color(0xFF6366F1), size: 24),
                      ),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Merge Dining Tables',
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                          Text(
                            'Combine tables for large parties (>6 seats)',
                            style: TextStyle(
                              fontSize: 12,
                              color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary,
                            ),
                          ),
                        ],
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

              // Master Table Selection
              const Text(
                '1. Select Primary / Master Table',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                decoration: BoxDecoration(
                  border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.border),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _masterTable,
                    isExpanded: true,
                    items: liveTables.where((t) => !t.isMergedSecondary).map((t) {
                      final isOcc = t.status != TableState.available;
                      final extra = t.isMergedMaster ? ' (Already merged +${t.mergedTables.join(", ")})' : (isOcc ? ' (Occupied)' : ' (Available)');
                      return DropdownMenuItem(
                        value: t.tableNumber,
                        child: Text('${t.tableNumber} • 6 Seats$extra'),
                      );
                    }).toList(),
                    onChanged: (val) {
                      if (val != null) {
                        setState(() {
                          _masterTable = val;
                          _selectedSecondary.remove(val);
                        });
                      }
                    },
                  ),
                ),
              ),
              const SizedBox(height: 18),

              // Secondary Tables Multi-Select
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    '2. Select Table(s) to Join with Master',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                  Text(
                    '${_selectedSecondary.length} selected',
                    style: const TextStyle(fontSize: 12, color: Color(0xFF6366F1), fontWeight: FontWeight.w600),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: eligibleTables.map((t) {
                  final isSelected = _selectedSecondary.contains(t.tableNumber);
                  final isOcc = t.status != TableState.available;

                  return FilterChip(
                    selected: isSelected,
                    showCheckmark: true,
                    label: Text('${t.tableNumber} ${isOcc ? "(Active)" : "(Free)"}'),
                    selectedColor: const Color(0xFF6366F1).withValues(alpha: 0.2),
                    checkmarkColor: const Color(0xFF6366F1),
                    onSelected: (selected) {
                      setState(() {
                        if (selected) {
                          _selectedSecondary.add(t.tableNumber);
                        } else {
                          _selectedSecondary.remove(t.tableNumber);
                        }
                      });
                    },
                  );
                }).toList(),
              ),
              const SizedBox(height: 18),

              // Live Combined Metrics Box
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E293B) : const Color(0xFFEEF2FF),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: const Color(0xFF6366F1).withValues(alpha: 0.25),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Combined Seating Capacity:',
                          style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                        ),
                        Text(
                          '$totalSeats Seats',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF6366F1),
                          ),
                        ),
                      ],
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        const Text(
                          'Combined Label:',
                          style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                        ),
                        Text(
                          _selectedSecondary.isEmpty
                              ? _masterTable
                              : '$_masterTable + ${_selectedSecondary.join(" + ")}',
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              if (masterObj.isMergedMaster) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.amber.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.amber.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.info_outline, size: 16, color: Colors.amber),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '$_masterTable is already merged with: ${masterObj.mergedTables.join(", ")}',
                          style: const TextStyle(fontSize: 12),
                        ),
                      ),
                      TextButton(
                        onPressed: () {
                          ref.read(tablesProvider.notifier).unmergeTable(_masterTable);
                          Navigator.of(context).pop();
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Unmerged $_masterTable and restored separate tables!')),
                          );
                        },
                        child: const Text('Unmerge Now', style: TextStyle(color: Colors.red, fontSize: 12)),
                      ),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 22),

              // Action Buttons
              Wrap(
                alignment: WrapAlignment.end,
                spacing: 10,
                runSpacing: 8,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Cancel'),
                  ),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF6366F1),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    icon: const Icon(Icons.link, size: 18),
                    label: const Text('Merge Tables', style: TextStyle(fontWeight: FontWeight.bold)),
                    onPressed: _selectedSecondary.isEmpty
                        ? null
                        : () {
                            final secondaryList = _selectedSecondary.toList();

                            // 1. Merge tables in tablesProvider
                            ref.read(tablesProvider.notifier).mergeTables(
                              masterTableNumber: _masterTable,
                              secondaryTableNumbers: secondaryList,
                            );

                            // 2. Consolidate orders if any secondary tables had active orders
                            ref.read(ordersProvider.notifier).mergeOrders(
                              _masterTable,
                              secondaryList,
                            );

                            Navigator.of(context).pop();
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Tables merged! Combined group: $_masterTable + ${secondaryList.join(" + ")} ($totalSeats Seats)'),
                                backgroundColor: const Color(0xFF16A34A),
                              ),
                            );
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
