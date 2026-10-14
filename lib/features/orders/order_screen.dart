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
        ref.read(tablesProvider.notifier).occupyTable(widget.tableNumber, 2, 'temp');
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
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    widget.tableNumber,
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  order != null ? 'Order #${order.orderNumber}' : 'New Order',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
              ],
            ),
            actions: [
              Center(
                child: Padding(
                  padding: const EdgeInsets.only(right: 16),
                  child: Text(
                    'Shortcuts: ⌘K Search • ⌘Enter KOT • ⌘B Bill',
                    style: TextStyle(fontSize: 12, color: AppColors.textSecondary.withValues(alpha: 0.8)),
                  ),
                ),
              ),
            ],
          ),
          body: Row(
            children: [
              // Left: Menu catalog & Search
              Expanded(
                flex: 7,
                child: Column(
                  children: [
                    // Search & Category Filters
                    Container(
                      color: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      child: Column(
                        children: [
                          TextField(
                            controller: _searchController,
                            focusNode: _searchFocusNode,
                            onChanged: (val) => setState(() => _searchQuery = val),
                            decoration: InputDecoration(
                              hintText: 'Search 30+ dishes, Bikaji snacks, beverages (Press ⌘K or / to search)...',
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
                          const SizedBox(height: 12),
                          SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: Row(
                              children: categories.map((cat) {
                                final isSelected = _selectedCategory == cat;
                                return Padding(
                                  padding: const EdgeInsets.only(right: 8),
                                  child: ChoiceChip(
                                    label: Text(cat),
                                    selected: isSelected,
                                    selectedColor: AppColors.primary,
                                    labelStyle: TextStyle(
                                      color: isSelected ? Colors.white : AppColors.textPrimary,
                                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                      fontSize: 13,
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
                          : GridView.builder(
                              padding: const EdgeInsets.all(16),
                              gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                                maxCrossAxisExtent: 220,
                                mainAxisExtent: 140,
                                crossAxisSpacing: 12,
                                mainAxisSpacing: 12,
                              ),
                              itemCount: filteredMenu.length,
                              itemBuilder: (context, index) {
                                final item = filteredMenu[index];
                                return _buildMenuItemCard(item);
                              },
                            ),
                    ),
                  ],
                ),
              ),

              // Right: Cart & Kitchen Modifiers
              Container(
                width: 390,
                decoration: const BoxDecoration(
                  color: Colors.white,
                  border: Border(left: BorderSide(color: AppColors.border)),
                ),
                child: order == null
                    ? const Center(child: CircularProgressIndicator())
                    : Column(
                        children: [
                          // Cart Header
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                            color: AppColors.background,
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text(
                                  'Current Cart',
                                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: AppColors.primaryLight,
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Text(
                                    '${order.items.fold(0, (sum, i) => sum + i.quantity)} items',
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
                                    separatorBuilder: (_, __) => const Divider(height: 14),
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
                            decoration: const BoxDecoration(
                              color: AppColors.background,
                              border: Border(top: BorderSide(color: AppColors.border)),
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
                                        onPressed: order.items.isEmpty ? null : () => _dispatchKot(order),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: ElevatedButton.icon(
                                        icon: const Icon(Icons.payment, size: 18),
                                        label: const Text('Bill & Pay'),
                                        onPressed: order.items.isEmpty ? null : () => _openBilling(order),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
              ),
            ],
          ),
        ),
      ),
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
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () {
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
                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (item.isPackaged)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.amber.shade100,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Text('MRP', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.brown)),
                    ),
                ],
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '₹${item.price.toStringAsFixed(0)}',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.primary),
                  ),
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: AppColors.primaryLight,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.add, size: 16, color: AppColors.primary),
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
