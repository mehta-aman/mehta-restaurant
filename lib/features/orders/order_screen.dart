import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme.dart';
import '../../models/models.dart';
import '../../providers/restaurant_provider.dart';
import '../billing/billing_dialog.dart';

class OrderScreen extends ConsumerStatefulWidget {
  final String tableNumber;

  const OrderScreen({super.key, required this.tableNumber});

  @override
  ConsumerState<OrderScreen> createState() => _OrderScreenState();
}

class _OrderScreenState extends ConsumerState<OrderScreen> {
  String _selectedCategory = 'All';
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final orders = ref.read(ordersProvider);
      if (!orders.containsKey(widget.tableNumber)) {
        final settings = ref.read(settingsProvider);
        ref.read(ordersProvider.notifier).initializeOrder(
          widget.tableNumber,
          taxRate: settings.gstEnabled ? settings.taxRate : 0.0,
        );
        if (!widget.tableNumber.startsWith('Parcel')) {
          ref.read(tablesProvider.notifier).occupyTable(widget.tableNumber, 2, 'temp');
        }
      }
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final allMenu = ref.watch(menuProvider);
    final orders = ref.watch(ordersProvider);
    final order = orders[widget.tableNumber];
    final settings = ref.watch(settingsProvider);
    final tables = ref.watch(tablesProvider);
    final currentTable = tables.where((t) => t.tableNumber == widget.tableNumber).firstOrNull;

    final categories = ['All', ...allMenu.map((m) => m.category).toSet()];

    final filteredMenu = allMenu.where((item) {
      final matchesCategory = _selectedCategory == 'All' || item.category == _selectedCategory;
      final matchesSearch = item.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          item.sku.toLowerCase().contains(_searchQuery.toLowerCase());
      return matchesCategory && matchesSearch;
    }).toList();

    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.keyK, meta: true): () => _searchFocusNode.requestFocus(),
        const SingleActivator(LogicalKeyboardKey.slash): () => _searchFocusNode.requestFocus(),
        const SingleActivator(LogicalKeyboardKey.enter, meta: true): () {
          if (order != null && order.items.isNotEmpty) _dispatchKot(order);
        },
        const SingleActivator(LogicalKeyboardKey.keyB, meta: true): () {
          if (order != null && order.items.isNotEmpty) _openBilling(order);
        },
      },
      child: Focus(
        autofocus: true,
        child: Scaffold(
          appBar: AppBar(
            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: widget.tableNumber.startsWith('Parcel') ? const Color(0xFFD97706) : AppColors.primary,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      if (widget.tableNumber.startsWith('Parcel')) ...[
                        const Icon(Icons.shopping_bag_outlined, color: Colors.white, size: 14),
                        const SizedBox(width: 4),
                      ],
                      Text(
                        widget.tableNumber,
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                      ),
                    ],
                  ),
                ),
                if (currentTable != null && currentTable.name.isNotEmpty && currentTable.name != widget.tableNumber) ...[
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      currentTable.name,
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
                if (currentTable != null) ...[
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                    decoration: BoxDecoration(
                      color: Theme.of(context).cardColor,
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: Theme.of(context).dividerColor),
                    ),
                    child: Text(
                      '${currentTable.section} • ${currentTable.capacity}p',
                      style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: AppColors.textSecondary),
                    ),
                  ),
                ],
                const SizedBox(width: 8),
                Text(
                  order != null ? '#${order.orderNumber}' : 'New Order',
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: AppColors.textSecondary),
                ),
                if (order != null && (order.isTakeaway || widget.tableNumber.startsWith('Parcel'))) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFFD97706).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: const Color(0xFFD97706)),
                    ),
                    child: const Text(
                      'PARCEL',
                      style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFFD97706)),
                    ),
                  ),
                ],
              ],
            ),
            actions: [
              IconButton(
                icon: Icon(
                  Theme.of(context).brightness == Brightness.dark
                      ? Icons.light_mode
                      : Icons.dark_mode,
                ),
                tooltip: 'Switch Theme',
                onPressed: () => ref.read(themeModeProvider.notifier).toggleTheme(),
              ),
              if (MediaQuery.of(context).size.width >= 850)
                Center(
                  child: Padding(
                    padding: const EdgeInsets.only(right: 16),
                    child: Text(
                      'Shortcuts: ⌘K Search • ⌘Enter KOT • ⌘B Bill',
                      style: TextStyle(
                        fontSize: 12,
                        color: Theme.of(context).brightness == Brightness.dark
                            ? AppColors.darkTextSecondary
                            : AppColors.textSecondary.withValues(alpha: 0.8),
                      ),
                    ),
                  ),
                ),
            ],
          ),
          body: LayoutBuilder(
            builder: (context, constraints) {
              final isMobile = constraints.maxWidth < 750;

              final menuWidget = Column(
                children: [
                  // Search & Category Filters
                  Container(
                    color: Theme.of(context).cardColor,
                    padding: EdgeInsets.symmetric(
                      horizontal: isMobile ? 12 : 16,
                      vertical: isMobile ? 8 : 12,
                    ),
                    child: Column(
                      children: [
                        TextField(
                          controller: _searchController,
                          focusNode: _searchFocusNode,
                          onChanged: (val) => setState(() => _searchQuery = val),
                          decoration: InputDecoration(
                            hintText: isMobile
                                ? 'Search dishes or SKU...'
                                : 'Search 30+ dishes, Bikaji snacks, beverages (Press ⌘K or / to search)...',
                            prefixIcon: const Icon(Icons.search, size: 20),
                            suffixIcon: _searchQuery.isNotEmpty
                                ? IconButton(
                                    icon: const Icon(Icons.clear, size: 18),
                                    onPressed: () {
                                      _searchController.clear();
                                      setState(() => _searchQuery = '');
                                    },
                                  )
                                : null,
                            isDense: true,
                            filled: true,
                            fillColor: AppColors.background,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: BorderSide.none,
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: categories.map((cat) {
                              final isSelected = _selectedCategory == cat;
                              return Padding(
                                padding: const EdgeInsets.only(right: 6),
                                child: ChoiceChip(
                                  label: Text(cat),
                                  selected: isSelected,
                                  selectedColor: AppColors.primary,
                                  labelStyle: TextStyle(
                                    color: isSelected ? Colors.white : AppColors.textPrimary,
                                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                    fontSize: 12,
                                  ),
                                  onSelected: (_) => setState(() => _selectedCategory = cat),
                                ),
                              );
                            }).toList(),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 1),

                  // Menu Grid
                  Expanded(
                    child: filteredMenu.isEmpty
                        ? const Center(child: Text('No menu items found.'))
                        : LayoutBuilder(
                            builder: (context, gridConstraints) {
                              final width = gridConstraints.maxWidth;
                              int crossAxisCount;
                              double mainAxisExtent;
                              if (width < 450) {
                                crossAxisCount = 2;
                                mainAxisExtent = 145;
                              } else if (width < 750) {
                                crossAxisCount = 3;
                                mainAxisExtent = 140;
                              } else if (width < 1100) {
                                crossAxisCount = 3;
                                mainAxisExtent = 140;
                              } else {
                                crossAxisCount = 4;
                                mainAxisExtent = 140;
                              }

                              return GridView.builder(
                                padding: EdgeInsets.all(isMobile ? 10 : 16),
                                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: crossAxisCount,
                                  mainAxisExtent: mainAxisExtent,
                                  crossAxisSpacing: isMobile ? 8 : 12,
                                  mainAxisSpacing: isMobile ? 8 : 12,
                                ),
                                itemCount: filteredMenu.length,
                                itemBuilder: (context, index) {
                                  final item = filteredMenu[index];
                                  return _buildMenuItemCard(item);
                                },
                              );
                            },
                          ),
                  ),
                ],
              );

              if (isMobile) {
                return Column(
                  children: [
                    Expanded(child: menuWidget),
                    _buildMobileBottomCartBar(order, settings),
                  ],
                );
              }

              return Row(
                children: [
                  Expanded(flex: 7, child: menuWidget),
                  Container(
                    width: 380,
                    decoration: BoxDecoration(
                      color: Theme.of(context).cardColor,
                      border: Border(left: BorderSide(color: Theme.of(context).dividerColor)),
                    ),
                    child: _buildCartPanel(order, settings, isModal: false),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildMobileBottomCartBar(Order? order, RestaurantSettings settings) {
    if (order == null || order.items.isEmpty) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          border: Border(top: BorderSide(color: Theme.of(context).dividerColor)),
        ),
        child: SafeArea(
          top: false,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: const [
              Icon(Icons.shopping_bag_outlined, size: 18, color: AppColors.textSecondary),
              SizedBox(width: 8),
              Text(
                'Cart is empty • Tap items above to order',
                style: TextStyle(fontSize: 12.5, color: AppColors.textSecondary),
              ),
            ],
          ),
        ),
      );
    }

    final totalItems = order.items.fold(0, (sum, i) => sum + i.quantity);

    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        border: Border(top: BorderSide(color: Theme.of(context).dividerColor)),
      ),
      child: SafeArea(
        top: false,
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            gradient: const LinearGradient(colors: [AppColors.primary, Color(0xFFC2410C)]),
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withValues(alpha: 0.35),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(14),
              onTap: () => _openMobileCartSheet(order, settings),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.shopping_bag_outlined, color: Colors.white, size: 18),
                    ),
                    const SizedBox(width: 10),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '$totalItems Item${totalItems > 1 ? "s" : ""} in Cart',
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13.5),
                        ),
                        Text(
                          '₹${order.grandTotal.toStringAsFixed(2)}',
                          style: const TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                    const Spacer(),
                    const Text(
                      'View Cart & KOT',
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13.5),
                    ),
                    const SizedBox(width: 4),
                    const Icon(Icons.arrow_forward_ios, color: Colors.white, size: 12),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _openMobileCartSheet(Order? order, RestaurantSettings settings) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Consumer(
          builder: (context, ref, _) {
            final liveOrders = ref.watch(ordersProvider);
            final liveOrder = liveOrders[widget.tableNumber];
            final liveSettings = ref.watch(settingsProvider);
            return Container(
              height: MediaQuery.of(context).size.height * 0.85,
              decoration: BoxDecoration(
                color: Theme.of(context).cardColor,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                child: _buildCartPanel(liveOrder, liveSettings, isModal: true),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildCartPanel(Order? order, RestaurantSettings settings, {bool isModal = false}) {
    if (order == null) {
      return const Center(child: CircularProgressIndicator());
    }

    final totalItems = order.items.fold(0, (sum, i) => sum + i.quantity);

    return Column(
      children: [
        // Cart Header
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          color: Theme.of(context).brightness == Brightness.dark
              ? const Color(0xFF111827)
              : AppColors.borderSubtle,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  if (isModal)
                    IconButton(
                      icon: const Icon(Icons.expand_more, size: 24),
                      onPressed: () => Navigator.of(context).pop(),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  if (isModal) const SizedBox(width: 8),
                  const Text(
                    'Current Cart',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.primaryLight,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '$totalItems items',
                  style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold, fontSize: 12),
                ),
              ),
            ],
          ),
        ),

        // Items List with Kitchen Modifiers
        Expanded(
          child: order.items.isEmpty
              ? const Center(
                  child: Text(
                    'Cart is empty.\nTap items on the left to add.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: AppColors.textSecondary),
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.all(12),
                  itemCount: order.items.length,
                  separatorBuilder: (_, _) => const Divider(height: 14),
                  itemBuilder: (context, idx) {
                    final item = order.items[idx];
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    item.name,
                                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                                  ),
                                  Text(
                                    '₹${item.unitPrice.toStringAsFixed(0)} each',
                                    style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                                  ),
                                ],
                              ),
                            ),
                            // Stepper
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.remove_circle_outline, size: 20),
                                  onPressed: () {
                                    ref.read(ordersProvider.notifier).updateQuantity(
                                          widget.tableNumber,
                                          item.id,
                                          item.quantity - 1,
                                        );
                                  },
                                ),
                                Text(
                                  '${item.quantity}',
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.add_circle_outline, size: 20),
                                  onPressed: () {
                                    ref.read(ordersProvider.notifier).updateQuantity(
                                          widget.tableNumber,
                                          item.id,
                                          item.quantity + 1,
                                        );
                                  },
                                ),
                              ],
                            ),
                            const SizedBox(width: 8),
                            Text(
                              '₹${item.totalPrice.toStringAsFixed(0)}',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                            ),
                          ],
                        ),
                        if (item.notes != null && item.notes!.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: Colors.amber.shade50,
                                    borderRadius: BorderRadius.circular(4),
                                    border: Border.all(color: Colors.amber.shade200),
                                  ),
                                  child: Text(
                                    'Note: ${item.notes}',
                                    style: TextStyle(fontSize: 11, color: Colors.brown.shade800, fontWeight: FontWeight.w500),
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    );
                  },
                ),
        ),

        // Checkout & Actions
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Theme.of(context).brightness == Brightness.dark
                ? const Color(0xFF111827)
                : AppColors.borderSubtle,
            border: Border(top: BorderSide(color: Theme.of(context).dividerColor)),
          ),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Subtotal:'),
                  Text('₹${order.subtotal.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.w600)),
                ],
              ),
              if (order.isTakeaway || widget.tableNumber.startsWith('Parcel')) ...[
                const SizedBox(height: 6),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: const [
                        Icon(Icons.takeout_dining, size: 16, color: Color(0xFFD97706)),
                        SizedBox(width: 4),
                        Text('Packaging Box Charges:'),
                      ],
                    ),
                    Text('₹${order.packagingCharge.toStringAsFixed(0)}', style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFFD97706))),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    const Text('Packaging: ', style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                    for (final amt in [0.0, 10.0, 15.0, 25.0]) ...[
                      InkWell(
                        onTap: () => ref.read(ordersProvider.notifier).updatePackagingCharge(order.tableNumber, amt),
                        borderRadius: BorderRadius.circular(4),
                        child: Container(
                          margin: const EdgeInsets.only(right: 6),
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                          decoration: BoxDecoration(
                            color: (order.packagingCharge == amt)
                                ? const Color(0xFFD97706).withValues(alpha: 0.2)
                                : (Theme.of(context).brightness == Brightness.dark ? const Color(0xFF1E293B) : Colors.grey.shade200),
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(
                              color: (order.packagingCharge == amt) ? const Color(0xFFD97706) : Colors.transparent,
                            ),
                          ),
                          child: Text(amt == 0.0 ? 'Free' : '₹${amt.toInt()}', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
              if (settings.gstEnabled) ...[
                const SizedBox(height: 4),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('GST (${settings.taxRate}%):'),
                    Text('₹${order.taxAmount.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.w600)),
                  ],
                ),
              ],
              const Divider(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Total Amount:', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  Text('₹${order.grandTotal.toStringAsFixed(2)}', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.primary)),
                ],
              ),
              const SizedBox(height: 16),

              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.soup_kitchen_outlined, size: 18),
                      label: const Text('Send KOT'),
                      onPressed: order.items.isEmpty ? null : () {
                        if (isModal) Navigator.of(context).pop();
                        _dispatchKot(order);
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.payment, size: 18),
                      label: const Text('Bill & Pay'),
                      onPressed: order.items.isEmpty ? null : () {
                        if (isModal) Navigator.of(context).pop();
                        _openBilling(order);
                      },
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _dispatchKot(Order order) {
    final kotNum = ref.read(kitchenTicketsProvider.notifier).sendKot(order: order);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$kotNum dispatched to Kitchen! (Chef alerted)'),
        backgroundColor: AppColors.secondary,
      ),
    );
  }

  void _openBilling(Order order) {
    showDialog(
      context: context,
      builder: (_) => BillingDialog(order: order),
    );
  }

  Widget _buildMenuItemCard(MenuItem item) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final settings = ref.watch(settingsProvider);
    final isSoldOut = !item.isAvailable || (settings.inventoryTrackingEnabled && item.isOutOfStock);

    return Card(
      clipBehavior: Clip.antiAlias,
      elevation: isSoldOut ? 0 : 1,
      color: isSoldOut
          ? (isDark ? const Color(0xFF1E293B).withValues(alpha: 0.5) : Colors.grey.shade100)
          : null,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: isSoldOut
              ? (isDark ? const Color(0xFF334155) : Colors.grey.shade300)
              : (isDark ? AppColors.darkBorder : AppColors.border),
        ),
      ),
      child: InkWell(
        onTap: isSoldOut
            ? () {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('${item.name} is currently SOLD OUT / Out of Stock!'),
                    backgroundColor: Colors.red,
                    duration: const Duration(seconds: 2),
                  ),
                );
              }
            : () {
                ref.read(ordersProvider.notifier).addItemToOrder(widget.tableNumber, item);
              },
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      item.name,
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 13.5,
                        decoration: isSoldOut ? TextDecoration.lineThrough : null,
                        color: isSoldOut ? Colors.grey : null,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (item.isPackaged)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF451A03) : Colors.amber.shade100,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        'MRP',
                        style: TextStyle(
                          fontSize: 9.5,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.amber : Colors.brown,
                        ),
                      ),
                    ),
                ],
              ),
              if (settings.inventoryTrackingEnabled && item.isStockTracked)
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Row(
                    children: [
                      if (isSoldOut)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                          decoration: BoxDecoration(
                            color: Colors.red.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text('Sold Out', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.red)),
                        )
                      else if (item.isLowStock)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                          decoration: BoxDecoration(
                            color: Colors.orange.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text('Only ${item.stockQuantity} left', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.orange)),
                        )
                      else
                        Text(
                          'Stock: ${item.stockQuantity}',
                          style: TextStyle(fontSize: 10, color: isDark ? Colors.grey.shade400 : Colors.grey.shade600),
                        ),
                    ],
                  ),
                ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '₹${item.price.toStringAsFixed(0)}',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: isSoldOut ? Colors.grey : (isDark ? const Color(0xFFFF7043) : AppColors.primary),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: isSoldOut
                          ? (isDark ? const Color(0xFF1E293B) : Colors.grey.shade200)
                          : (isDark ? const Color(0xFF334155) : AppColors.primaryLight),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      isSoldOut ? Icons.block : Icons.add,
                      size: 16,
                      color: isSoldOut
                          ? Colors.grey.shade500
                          : (isDark ? const Color(0xFFFF7043) : AppColors.primary),
                    ),
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
