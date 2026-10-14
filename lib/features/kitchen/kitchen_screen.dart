import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../core/theme.dart';
import '../../models/models.dart';
import '../../providers/restaurant_provider.dart';

class KitchenScreen extends ConsumerWidget {
  const KitchenScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tickets = ref.watch(kitchenTicketsProvider);
    final activeTickets = tickets.where((t) => t.status != KotState.served).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Kitchen Display System (KDS)'),
        actions: [
          Center(
            child: Padding(
              padding: const EdgeInsets.only(right: 16),
              child: Text(
                '${activeTickets.length} Active Orders',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
            ),
          ),
        ],
      ),
      body: activeTickets.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: const [
                  Icon(Icons.done_all, size: 64, color: AppColors.statusAvailable),
                  SizedBox(height: 16),
                  Text(
                    'All caught up!',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 6),
                  Text(
                    'No pending KOTs in the kitchen.',
                    style: TextStyle(color: AppColors.textSecondary),
                  ),
                ],
              ),
            )
          : GridView.builder(
              padding: const EdgeInsets.all(16),
              gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                maxCrossAxisExtent: 360,
                mainAxisExtent: 320,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
              ),
              itemCount: activeTickets.length,
              itemBuilder: (context, index) {
                final ticket = activeTickets[index];
                return _buildKotCard(context, ref, ticket);
              },
            ),
    );
  }

  Widget _buildKotCard(BuildContext context, WidgetRef ref, KitchenTicket ticket) {
    final timeFormat = DateFormat('hh:mm a');
    final elapsedMinutes = DateTime.now().difference(ticket.timestamp).inMinutes;

    Color headerColor;
    String statusLabel;

    switch (ticket.status) {
      case KotState.newTicket:
        headerColor = Colors.orange.shade700;
        statusLabel = 'NEW';
        break;
      case KotState.preparing:
        headerColor = Colors.blue.shade700;
        statusLabel = 'PREPARING';
        break;
      case KotState.ready:
        headerColor = AppColors.statusAvailable;
        statusLabel = 'READY TO SERVE';
        break;
      case KotState.served:
        headerColor = Colors.grey;
        statusLabel = 'SERVED';
        break;
    }

    return Card(
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: headerColor, width: 2),
      ),
      child: Column(
        children: [
          // Header Bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            color: headerColor,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Text(
                      ticket.tableNumber,
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      ticket.kotNumber,
                      style: const TextStyle(color: Colors.white70, fontSize: 13),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    '$statusLabel • ${timeFormat.format(ticket.timestamp)} (${elapsedMinutes}m ago)',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 11),
                  ),
                ),
              ],
            ),
          ),

          // Items List
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.all(12),
              itemCount: ticket.items.length,
              separatorBuilder: (_, __) => const Divider(height: 10),
              itemBuilder: (context, idx) {
                final item = ticket.items[idx];
                return Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.background,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Text(
                        '${item.quantity}x',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        item.name,
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),

          // Footer Action
          Container(
            padding: const EdgeInsets.all(10),
            color: AppColors.background,
            child: Row(
              children: [
                if (ticket.status == KotState.newTicket)
                  Expanded(
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.blue.shade700),
                      icon: const Icon(Icons.soup_kitchen, size: 16),
                      label: const Text('Start Prep'),
                      onPressed: () {
                        ref.read(kitchenTicketsProvider.notifier).updateTicketStatus(ticket.id, KotState.preparing);
                      },
                    ),
                  )
                else if (ticket.status == KotState.preparing)
                  Expanded(
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(backgroundColor: AppColors.statusAvailable),
                      icon: const Icon(Icons.check_circle_outline, size: 16),
                      label: const Text('Mark Ready'),
                      onPressed: () {
                        ref.read(kitchenTicketsProvider.notifier).updateTicketStatus(ticket.id, KotState.ready);
                      },
                    ),
                  )
                else if (ticket.status == KotState.ready)
                  Expanded(
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.grey.shade800),
                      icon: const Icon(Icons.delivery_dining, size: 16),
                      label: const Text('Mark Served'),
                      onPressed: () {
                        ref.read(kitchenTicketsProvider.notifier).updateTicketStatus(ticket.id, KotState.served);
                      },
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
