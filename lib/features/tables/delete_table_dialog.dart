import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/models.dart';
import '../../providers/restaurant_provider.dart';

class DeleteTableDialog extends ConsumerWidget {
  final RestaurantTable table;

  const DeleteTableDialog({super.key, required this.table});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isOccupied = table.status != TableState.available || table.activeOrderId != null;
    final isMerged = table.isMergedMaster || table.isMergedSecondary;
    final canDelete = !isOccupied && !isMerged;

    return AlertDialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.red.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.delete_outline, color: Colors.red, size: 24),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Delete Table ${table.tableNumber}?',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Are you sure you want to remove Table ${table.tableNumber} (${table.displayName}, ${table.section}, ${table.capacity} Seats)?',
              style: const TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 12),
            if (isOccupied)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.amber.shade50,
                  border: Border.all(color: Colors.amber.shade400),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.warning_amber_rounded, color: Colors.amber, size: 22),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'This table is currently OCCUPIED or has an active order. Please settle or free the table before deleting.',
                        style: TextStyle(color: Colors.amber.shade900, fontSize: 12, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
              )
            else if (isMerged)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.indigo.shade50,
                  border: Border.all(color: Colors.indigo.shade400),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.link_off, color: Colors.indigo, size: 22),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'This table is currently part of a merged group. Please unmerge the table before deleting.',
                        style: TextStyle(color: Colors.indigo.shade900, fontSize: 12, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
              )
            else
              Text(
                'This will permanently remove this table from the floor plan, QR standees, and settings. This action cannot be undone.',
                style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.red,
            foregroundColor: Colors.white,
          ),
          onPressed: canDelete
              ? () {
                  final res = ref.read(tablesProvider.notifier).deleteTable(table.id);
                  if (res.success) {
                    Navigator.of(context).pop(true);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Table ${table.tableNumber} deleted successfully!'),
                        backgroundColor: Colors.red.shade700,
                      ),
                    );
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(res.error ?? 'Failed to delete table'),
                        backgroundColor: Colors.red.shade700,
                      ),
                    );
                  }
                }
              : null,
          child: const Text('Delete Table'),
        ),
      ],
    );
  }
}
