import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../core/theme.dart';
import '../../models/models.dart';
import '../../providers/restaurant_provider.dart';
import '../../services/kitchen_audio_service.dart';

enum KdsFilter { all, delayed, rush, newTickets, prep, ready }

class KitchenScreen extends ConsumerStatefulWidget {
  const KitchenScreen({super.key});

  @override
  ConsumerState<KitchenScreen> createState() => _KitchenScreenState();
}

class _KitchenScreenState extends ConsumerState<KitchenScreen> {
  Timer? _ticker;
  KdsFilter _selectedFilter = KdsFilter.all;

  @override
  void initState() {
    super.initState();
    // Auto-refresh elapsed times every 15 seconds
    _ticker = Timer.periodic(const Duration(seconds: 15), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tickets = ref.watch(kitchenTicketsProvider);
    final isMuted = ref.watch(kitchenAudioMutedProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final activeTickets = tickets.where((t) => t.status != KotState.served).toList();

    // Derived counts
    final delayedCount = activeTickets.where((t) => t.isDelayed).length;
    final rushCount = activeTickets.where((t) => t.isRush).length;
    final newCount = activeTickets.where((t) => t.status == KotState.newTicket).length;
    final prepCount = activeTickets.where((t) => t.status == KotState.preparing).length;
    final readyCount = activeTickets.where((t) => t.status == KotState.ready).length;

    // Filter tickets based on selected chip
    List<KitchenTicket> displayedTickets;
    switch (_selectedFilter) {
      case KdsFilter.all:
        displayedTickets = activeTickets;
        break;
      case KdsFilter.delayed:
        displayedTickets = activeTickets.where((t) => t.isDelayed).toList();
        break;
      case KdsFilter.rush:
        displayedTickets = activeTickets.where((t) => t.isRush).toList();
        break;
      case KdsFilter.newTickets:
        displayedTickets = activeTickets.where((t) => t.status == KotState.newTicket).toList();
        break;
      case KdsFilter.prep:
        displayedTickets = activeTickets.where((t) => t.status == KotState.preparing).toList();
        break;
      case KdsFilter.ready:
        displayedTickets = activeTickets.where((t) => t.status == KotState.ready).toList();
        break;
    }

    // Sort: Rush tickets first, then delayed tickets first, then oldest first
    displayedTickets.sort((a, b) {
      if (a.isRush != b.isRush) return a.isRush ? -1 : 1;
      if (a.isDelayed != b.isDelayed) return a.isDelayed ? -1 : 1;
      return a.timestamp.compareTo(b.timestamp);
    });

    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 700;
    final isDesktop = screenWidth >= 1100;

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            // --- REDESIGNED UNIFIED KDS TOP BAR ---
            _buildRedesignedKdsTopBar(
              context: context,
              isDark: isDark,
              isMobile: isMobile,
              isDesktop: isDesktop,
              activeCount: activeTickets.length,
              delayedCount: delayedCount,
              rushCount: rushCount,
              newCount: newCount,
              prepCount: prepCount,
              readyCount: readyCount,
              isMuted: isMuted,
            ),

            // Main KOT Tickets Grid
            Expanded(
              child: displayedTickets.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.done_all, size: 64, color: AppColors.statusAvailable),
                          const SizedBox(height: 16),
                          Text(
                            _selectedFilter == KdsFilter.all
                                ? 'All caught up!'
                                : 'No orders under this filter.',
                            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 6),
                          const Text(
                            'No pending KOTs in the kitchen.',
                            style: TextStyle(color: AppColors.textSecondary),
                          ),
                        ],
                      ),
                    )
                  : LayoutBuilder(
                      builder: (context, constraints) {
                        final isNarrow = constraints.maxWidth < 600;
                        return GridView.builder(
                          padding: EdgeInsets.fromLTRB(
                            isNarrow ? 10 : 20,
                            4,
                            isNarrow ? 10 : 20,
                            16,
                          ),
                          gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
                            maxCrossAxisExtent: isNarrow ? constraints.maxWidth : 380,
                            mainAxisExtent: isNarrow ? 330 : 350,
                            crossAxisSpacing: isNarrow ? 12 : 16,
                            mainAxisSpacing: isNarrow ? 12 : 16,
                          ),
                          itemCount: displayedTickets.length,
                          itemBuilder: (context, index) {
                            final ticket = displayedTickets[index];
                            return _buildKotCard(context, ref, ticket);
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

  Widget _buildRedesignedKdsTopBar({
    required BuildContext context,
    required bool isDark,
    required bool isMobile,
    required bool isDesktop,
    required int activeCount,
    required int delayedCount,
    required int rushCount,
    required int newCount,
    required int prepCount,
    required int readyCount,
    required bool isMuted,
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
          // Row 1: Title, Queue Stats & Kitchen Bell Controls
          if (isMobile) ...[
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Kitchen Orders (KDS)',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.3,
                      ),
                    ),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Bell Sound Status Pill Button
                        InkWell(
                          borderRadius: BorderRadius.circular(8),
                          onTap: () {
                            ref.read(kitchenAudioMutedProvider.notifier).toggle();
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(isMuted ? '🔔 Kitchen Bell Sound ENABLED' : '🔕 Kitchen Bell Sound MUTED'),
                                duration: const Duration(seconds: 1),
                              ),
                            );
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: isMuted
                                  ? (isDark ? const Color(0xFF450A0A) : const Color(0xFFFEE2E2))
                                  : (isDark ? const Color(0xFF064E3B) : const Color(0xFFECFDF5)),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: isMuted
                                    ? (isDark ? const Color(0xFF991B1B) : const Color(0xFFFECACA))
                                    : (isDark ? const Color(0xFF047857) : const Color(0xFFA7F3D0)),
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  isMuted ? Icons.volume_off : Icons.volume_up,
                                  size: 14,
                                  color: isMuted ? Colors.red : const Color(0xFF059669),
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  isMuted ? 'Muted' : 'Sound On',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: isMuted ? Colors.red : const Color(0xFF059669),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        IconButton(
                          icon: const Icon(Icons.notifications_active, size: 18, color: AppColors.primary),
                          tooltip: 'Test Kitchen Bell 🔔',
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          onPressed: () async {
                            await KitchenAudioService.playNewOrderChime();
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('🔔 Kitchen Bell Chime Played!'),
                                  duration: Duration(milliseconds: 1500),
                                ),
                              );
                            }
                          },
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: [
                    Text(
                      ' Active Orders',
                      style: TextStyle(
                        fontSize: 11.5,
                        color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary,
                      ),
                    ),
                    if (delayedCount > 0)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF450A0A) : const Color(0xFFFEE2E2),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          '🔥  Delayed >15m',
                          style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.red),
                        ),
                      ),
                    if (rushCount > 0)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF451A03) : const Color(0xFFFEF3C7),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          '⚡  Rush',
                          style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFFD97706)),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ] else ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Title and Metrics Badges
                Row(
                  children: [
                    const Text(
                      'Kitchen Orders (KDS)',
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
                        ' Active Tickets',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: isDark ? const Color(0xFFFF9E80) : AppColors.primary,
                        ),
                      ),
                    ),
                    if (delayedCount > 0) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF450A0A) : const Color(0xFFFEE2E2),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: isDark ? const Color(0xFF991B1B) : const Color(0xFFFECACA),
                          ),
                        ),
                        child: Text(
                          '🔥  Delayed (>15m)',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: isDark ? const Color(0xFFFCA5A5) : const Color(0xFFDC2626),
                          ),
                        ),
                      ),
                    ],
                    if (rushCount > 0) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF451A03) : const Color(0xFFFEF3C7),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: isDark ? const Color(0xFF78350F) : const Color(0xFFFDE68A),
                          ),
                        ),
                        child: Text(
                          '⚡ $rushCount Rush Order${rushCount > 1 ? "s" : ""}',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: isDark ? const Color(0xFFFDBA74) : const Color(0xFFB45309),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),

                // Kitchen Bell Controls
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Sound Status Pill Button
                    InkWell(
                      borderRadius: BorderRadius.circular(10),
                      onTap: () {
                        ref.read(kitchenAudioMutedProvider.notifier).toggle();
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(isMuted ? '🔔 Kitchen Bell Sound ENABLED' : '🔕 Kitchen Bell Sound MUTED'),
                            duration: const Duration(seconds: 1),
                          ),
                        );
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                        decoration: BoxDecoration(
                          color: isMuted
                              ? (isDark ? const Color(0xFF450A0A) : const Color(0xFFFEE2E2))
                              : (isDark ? const Color(0xFF064E3B) : const Color(0xFFECFDF5)),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: isMuted
                                ? (isDark ? const Color(0xFF991B1B) : const Color(0xFFFECACA))
                                : (isDark ? const Color(0xFF047857) : const Color(0xFFA7F3D0)),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              isMuted ? Icons.volume_off : Icons.volume_up,
                              size: 16,
                              color: isMuted ? Colors.red : const Color(0xFF059669),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              isMuted ? 'Bell Muted' : 'Kitchen Bell Active',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: isMuted ? Colors.red : const Color(0xFF059669),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    FilledButton.tonalIcon(
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      icon: const Icon(Icons.notifications_active, size: 16),
                      label: const Text('Test Chime 🔔', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                      onPressed: () async {
                        await KitchenAudioService.playNewOrderChime();
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('🔔 Kitchen Bell Chime Played!'),
                              duration: Duration(milliseconds: 1500),
                            ),
                          );
                        }
                      },
                    ),
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

          // Row 2: Pipeline Stage Filter Tabs (Pills)
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildKdsFilterPill(
                  label: 'All Active',
                  count: activeCount,
                  filter: KdsFilter.all,
                  color: AppColors.primary,
                  isDark: isDark,
                ),
                const SizedBox(width: 8),
                if (delayedCount > 0) ...[
                  _buildKdsFilterPill(
                    label: '🔥 Delayed >15m',
                    count: delayedCount,
                    filter: KdsFilter.delayed,
                    color: Colors.red,
                    isDark: isDark,
                  ),
                  const SizedBox(width: 8),
                ],
                if (rushCount > 0) ...[
                  _buildKdsFilterPill(
                    label: '⚡ Rush Priority',
                    count: rushCount,
                    filter: KdsFilter.rush,
                    color: const Color(0xFFD97706),
                    isDark: isDark,
                  ),
                  const SizedBox(width: 8),
                ],
                _buildKdsFilterPill(
                  label: 'New Orders',
                  count: newCount,
                  filter: KdsFilter.newTickets,
                  color: Colors.orange.shade700,
                  isDark: isDark,
                ),
                const SizedBox(width: 8),
                _buildKdsFilterPill(
                  label: 'In Preparation',
                  count: prepCount,
                  filter: KdsFilter.prep,
                  color: Colors.blue.shade700,
                  isDark: isDark,
                ),
                const SizedBox(width: 8),
                _buildKdsFilterPill(
                  label: 'Ready to Serve',
                  count: readyCount,
                  filter: KdsFilter.ready,
                  color: const Color(0xFF16A34A),
                  isDark: isDark,
                ),
              ],
            ),
          ),

          // Row 3 (Conditional Alert Banner): Critical Delay Callout
          if (delayedCount > 0) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF450A0A) : const Color(0xFFFEF2F2),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: isDark ? const Color(0xFF991B1B) : const Color(0xFFFECACA),
                ),
              ),
              child: Row(
                children: [
                  const Icon(Icons.warning_amber_rounded, size: 18, color: Color(0xFFDC2626)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Attention Chef: $delayedCount kitchen order(s) waiting over 15 minutes! Please expedite.',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                        color: isDark ? const Color(0xFFFCA5A5) : const Color(0xFFB91C1C),
                      ),
                    ),
                  ),
                  if (_selectedFilter != KdsFilter.delayed)
                    TextButton(
                      style: TextButton.styleFrom(
                        visualDensity: VisualDensity.compact,
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        foregroundColor: const Color(0xFFDC2626),
                      ),
                      onPressed: () => setState(() => _selectedFilter = KdsFilter.delayed),
                      child: const Text('Filter Delayed', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                    ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildKdsFilterPill({
    required String label,
    required int count,
    required KdsFilter filter,
    required Color color,
    required bool isDark,
  }) {
    final isSelected = _selectedFilter == filter;
    return InkWell(
      onTap: () => setState(() => _selectedFilter = filter),
      borderRadius: BorderRadius.circular(20),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: isSelected
              ? (filter == KdsFilter.all ? AppColors.primary : color)
              : (isDark ? AppColors.darkSurface : AppColors.surfaceSecondary),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected
                ? (filter == KdsFilter.all ? AppColors.primary : color)
                : (isDark ? AppColors.darkBorder : AppColors.border),
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: (filter == KdsFilter.all ? AppColors.primary : color).withValues(alpha: 0.25),
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
              label,
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
    );
  }

  Widget _buildKotCard(BuildContext context, WidgetRef ref, KitchenTicket ticket) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final timeFormat = DateFormat('hh:mm a');
    final elapsed = ticket.elapsedMinutes;

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
        headerColor = const Color(0xFF16A34A);
        statusLabel = 'READY TO SERVE';
        break;
      case KotState.served:
        headerColor = Colors.grey;
        statusLabel = 'SERVED';
        break;
    }

    if (ticket.isDelayed) {
      headerColor = const Color(0xFFDC2626); // Bright Red
    }

    return Card(
      clipBehavior: Clip.antiAlias,
      elevation: ticket.isDelayed || ticket.isRush ? 6 : 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(
          color: ticket.isDelayed
              ? Colors.red
              : (ticket.isRush ? Colors.amber.shade700 : headerColor),
          width: ticket.isDelayed || ticket.isRush ? 2.5 : 1.5,
        ),
      ),
      child: Column(
        children: [
          // Top Alert Strip if Delayed or Rush
          if (ticket.isDelayed)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              color: Colors.red.shade900,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.timer_off_outlined, size: 14, color: Colors.white),
                      const SizedBox(width: 4),
                      Text(
                        '🔥 CRITICAL DELAY: ${elapsed}m WAIT',
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11),
                      ),
                    ],
                  ),
                  const Text('EXPEDITE NOW', style: TextStyle(color: Colors.white70, fontSize: 10, fontWeight: FontWeight.bold)),
                ],
              ),
            )
          else if (ticket.isRush)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
              color: Colors.amber.shade800,
              child: Row(
                children: const [
                  Icon(Icons.bolt, size: 14, color: Colors.white),
                  SizedBox(width: 4),
                  Text('⚡ RUSH / PRIORITY ORDER', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11)),
                ],
              ),
            ),

          // Header Bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            color: headerColor,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    if (ticket.tableNumber.contains('Parcel'))
                      Container(
                        margin: const EdgeInsets.only(right: 6),
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.amber.shade300,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Row(
                          children: const [
                            Icon(Icons.shopping_bag, size: 12, color: Colors.black87),
                            SizedBox(width: 3),
                            Text('BOX', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.black87)),
                          ],
                        ),
                      ),
                    Text(
                      ticket.tableNumber,
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
                    ),
                    const SizedBox(width: 8),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          ticket.kotNumber,
                          style: const TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w600),
                        ),
                        Text(
                          timeFormat.format(ticket.timestamp),
                          style: const TextStyle(color: Colors.white60, fontSize: 10),
                        ),
                      ],
                    ),
                  ],
                ),
                Row(
                  children: [
                    // Rush Toggle Button
                    IconButton(
                      icon: Icon(
                        ticket.isRush ? Icons.bolt : Icons.bolt_outlined,
                        color: ticket.isRush ? Colors.amberAccent : Colors.white70,
                        size: 20,
                      ),
                      tooltip: ticket.isRush ? 'Unmark Rush' : 'Mark as Rush Order',
                      onPressed: () {
                        ref.read(kitchenTicketsProvider.notifier).toggleRush(ticket.id);
                      },
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.22),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        '$statusLabel • ${elapsed}m',
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 11),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Items List
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.all(12),
              itemCount: ticket.items.length,
              separatorBuilder: (_, _) => const Divider(height: 8),
              itemBuilder: (context, idx) {
                final item = ticket.items[idx];
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF1E293B) : AppColors.background,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.border),
                      ),
                      child: Text(
                        '${item.quantity}x',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.name,
                            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                          ),
                          if (item.notes != null && item.notes!.isNotEmpty) ...[
                            const SizedBox(height: 2),
                            Text(
                              'Note: ${item.notes}',
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.amber.shade700,
                                fontStyle: FontStyle.italic,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                );
              },
            ),
          ),

          // Footer Action
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            color: isDark ? const Color(0xFF1E293B) : AppColors.borderSubtle,
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
                      style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF16A34A)),
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
