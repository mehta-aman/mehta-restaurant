import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../core/theme.dart';
import '../../models/models.dart';
import '../../providers/restaurant_provider.dart';
import '../staff/staff_switch_dialog.dart';

class MenuManagementScreen extends ConsumerStatefulWidget {
  const MenuManagementScreen({super.key});

  @override
  ConsumerState<MenuManagementScreen> createState() => _MenuManagementScreenState();
}

class _MenuManagementScreenState extends ConsumerState<MenuManagementScreen> {
  String _selectedCategory = 'All';
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();
  final _uuid = const Uuid();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final allMenu = ref.watch(menuProvider);
    final currentStaff = ref.watch(currentStaffProvider);
    final settings = ref.watch(settingsProvider);
    final isStockTracking = settings.inventoryTrackingEnabled;

    final lowStockItems = isStockTracking
        ? allMenu.where((i) => i.isStockTracked && (i.isLowStock || i.isOutOfStock)).toList()
        : <MenuItem>[];
    final categories = [
      'All',
      if (isStockTracking && lowStockItems.isNotEmpty) '⚠️ Low Stock (${lowStockItems.length})',
      ...allMenu.map((m) => m.category).toSet(),
    ];

    final filteredMenu = allMenu.where((item) {
      bool matchesCategory;
      if (_selectedCategory == 'All') {
        matchesCategory = true;
      } else if (_selectedCategory.startsWith('⚠️ Low Stock')) {
        matchesCategory = isStockTracking && item.isStockTracked && (item.isLowStock || item.isOutOfStock);
      } else {
        matchesCategory = item.category == _selectedCategory;
      }
      final matchesSearch = item.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          item.sku.toLowerCase().contains(_searchQuery.toLowerCase());
      return matchesCategory && matchesSearch;
    }).toList();

    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 650;

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(isMobile ? 'Menu & Stock' : 'Menu Management & Live Stock Control'),
            Text(
              isMobile
                  ? '${allMenu.length} items (${allMenu.where((i) => i.isAvailable).length} active • ${allMenu.where((i) => !i.isAvailable).length} sold)'
                  : '${allMenu.length} Total Items (${allMenu.where((i) => i.isAvailable).length} Available • ${allMenu.where((i) => !i.isAvailable).length} Sold Out)',
              style: const TextStyle(fontSize: 11, color: AppColors.textSecondary, fontWeight: FontWeight.normal),
            ),
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
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: isMobile
                ? IconButton.filled(
                    icon: const Icon(Icons.add, size: 20),
                    tooltip: 'Add Menu Item',
                    onPressed: () {
                      if (!currentStaff.canEditMenu) {
                        showDialog(
                          context: context,
                          builder: (_) => const StaffSwitchDialog(),
                        );
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('🔒 Manager PIN required to add dishes! Current: ${currentStaff.roleDisplayName}'),
                            backgroundColor: Colors.orange.shade800,
                          ),
                        );
                        return;
                      }
                      _showAddEditItemDialog(context);
                    },
                  )
                : ElevatedButton.icon(
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('Add Menu Item'),
                    onPressed: () {
                      if (!currentStaff.canEditMenu) {
                        showDialog(
                          context: context,
                          builder: (_) => const StaffSwitchDialog(),
                        );
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('🔒 Manager PIN required to add dishes! Current: ${currentStaff.roleDisplayName}'),
                            backgroundColor: Colors.orange.shade800,
                          ),
                        );
                        return;
                      }
                      _showAddEditItemDialog(context);
                    },
                  ),
          ),
        ],
      ),
      body: Column(
        children: [
          // Filter Bar
          Container(
            padding: EdgeInsets.symmetric(horizontal: isMobile ? 12 : 20, vertical: 10),
            color: Theme.of(context).cardColor,
            child: isMobile
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TextField(
                        controller: _searchController,
                        onChanged: (val) => setState(() => _searchQuery = val),
                        decoration: InputDecoration(
                          hintText: 'Search items, SKU or snacks...',
                          prefixIcon: const Icon(Icons.search, size: 20),
                          isDense: true,
                          filled: true,
                          fillColor: Theme.of(context).brightness == Brightness.dark
                              ? const Color(0xFF1E293B)
                              : AppColors.borderSubtle,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: BorderSide.none,
                          ),
                          contentPadding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
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
                                visualDensity: VisualDensity.compact,
                                labelStyle: TextStyle(
                                  color: isSelected
                                      ? Colors.white
                                      : (Theme.of(context).brightness == Brightness.dark
                                          ? Colors.white
                                          : AppColors.textPrimary),
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
                  )
                : Row(
                    children: [
                      Expanded(
                        flex: 3,
                        child: TextField(
                          controller: _searchController,
                          onChanged: (val) => setState(() => _searchQuery = val),
                          decoration: InputDecoration(
                            hintText: 'Search items by name, SKU or packaged snacks...',
                            prefixIcon: const Icon(Icons.search, size: 20),
                            isDense: true,
                            filled: true,
                            fillColor: Theme.of(context).brightness == Brightness.dark
                                ? const Color(0xFF1E293B)
                                : AppColors.borderSubtle,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: BorderSide.none,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        flex: 5,
                        child: SingleChildScrollView(
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
                                    color: isSelected
                                        ? Colors.white
                                        : (Theme.of(context).brightness == Brightness.dark
                                            ? Colors.white
                                            : AppColors.textPrimary),
                                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                    fontSize: 13,
                                  ),
                                  onSelected: (_) => setState(() => _selectedCategory = cat),
                                ),
                              );
                            }).toList(),
                          ),
                        ),
                      ),
                    ],
                  ),
          ),
          const Divider(height: 1),

          // Inventory Tracking Status Notice
          if (!isStockTracking)
            Container(
              margin: EdgeInsets.fromLTRB(isMobile ? 12 : 20, 10, isMobile ? 12 : 20, 4),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: Theme.of(context).brightness == Brightness.dark ? const Color(0xFF1E293B) : const Color(0xFFEFF6FF),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: Theme.of(context).brightness == Brightness.dark ? const Color(0xFF334155) : const Color(0xFFBFDBFE),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.inventory_2_outlined,
                    size: 20,
                    color: Theme.of(context).brightness == Brightness.dark ? const Color(0xFF60A5FA) : const Color(0xFF2563EB),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Live Stock Tracking is OFF. All menu items & packaged snacks are freely available for billing without inventory limits. (Turn ON anytime in Settings)',
                      style: TextStyle(
                        fontSize: 12.5,
                        color: Theme.of(context).brightness == Brightness.dark ? Colors.grey.shade300 : const Color(0xFF1E3A8A),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  TextButton(
                    onPressed: () {
                      ref.read(settingsProvider.notifier).toggleInventoryTracking(true);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Live Inventory & Stock Tracking turned ON!'),
                          backgroundColor: Colors.green,
                        ),
                      );
                    },
                    child: const Text('Turn ON'),
                  ),
                ],
              ),
            ),

          // Menu List Table
          Expanded(
            child: filteredMenu.isEmpty
                ? const Center(child: Text('No menu items match your search.'))
                : ListView.separated(
                    padding: EdgeInsets.all(isMobile ? 12 : 20),
                    itemCount: filteredMenu.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final item = filteredMenu[index];
                      return _buildMenuItemRow(context, item, isMobile: isMobile, isStockTracking: isStockTracking);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildMenuItemRow(BuildContext context, MenuItem item, {bool isMobile = false, bool isStockTracking = false}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (isMobile) {
      return Card(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(
            color: item.isAvailable
                ? (isDark ? AppColors.darkBorder : AppColors.border)
                : (isDark ? const Color(0xFF881337) : Colors.red.shade200),
          ),
        ),
        color: item.isAvailable
            ? Theme.of(context).cardColor
            : (isDark ? const Color(0xFF4C0519) : Colors.red.shade50.withValues(alpha: 0.3)),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Row 1: Veg Icon, Name, Packaged Badge, Price
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(2),
                    decoration: BoxDecoration(
                      border: Border.all(color: item.isVeg ? Colors.green : Colors.brown, width: 1.5),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Icon(Icons.circle, size: 8, color: item.isVeg ? Colors.green : Colors.brown),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Row(
                      children: [
                        Flexible(
                          child: Text(
                            item.name,
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                              decoration: item.isAvailable ? null : TextDecoration.lineThrough,
                              color: item.isAvailable
                                  ? (isDark ? Colors.white : AppColors.textPrimary)
                                  : (isDark ? AppColors.darkTextSecondary : AppColors.textSecondary),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (item.isPackaged) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                            decoration: BoxDecoration(
                              color: isDark ? const Color(0xFF451A03) : Colors.amber.shade100,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              'MRP',
                              style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                                color: isDark ? Colors.amber : Colors.brown,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '₹${item.price.toStringAsFixed(2)}',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: isDark ? const Color(0xFFFF7043) : AppColors.primary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),

              // Row 2: SKU, Category & Stock Badge
              Wrap(
                spacing: 8,
                runSpacing: 4,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text(
                    'SKU: ${item.sku} • ${item.category}',
                    style: TextStyle(
                      fontSize: 11,
                      color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary,
                    ),
                  ),
                  if (isStockTracking && item.isStockTracked) ...[
                    if (item.isOutOfStock)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF4C0519) : Colors.red.shade100,
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: Colors.red),
                        ),
                        child: const Text(
                          '🔴 Out of Stock',
                          style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.red),
                        ),
                      )
                    else if (item.isLowStock)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF451A03) : Colors.orange.shade100,
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: Colors.orange.shade700),
                        ),
                        child: Text(
                          '⚠️ Low: ${item.stockQuantity}',
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                            color: isDark ? Colors.orange.shade300 : Colors.orange.shade900,
                          ),
                        ),
                      )
                    else
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF064E3B) : Colors.green.shade100,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          '✓ Stock: ${item.stockQuantity}',
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                            color: isDark ? const Color(0xFF34D399) : Colors.green.shade900,
                          ),
                        ),
                      ),
                  ],
                ],
              ),
              const Divider(height: 16),

              // Row 3: Available Switch, Restock, Edit, Delete
              Row(
                children: [
                  Text(
                    item.isAvailable ? 'In Stock' : 'Sold Out',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: item.isAvailable ? AppColors.statusAvailable : Colors.red,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Transform.scale(
                    scale: 0.8,
                    child: Switch(
                      value: item.isAvailable,
                      activeThumbColor: AppColors.statusAvailable,
                      onChanged: (_) {
                        ref.read(menuProvider.notifier).toggleAvailability(item.id);
                      },
                    ),
                  ),
                  const Spacer(),
                  if (isStockTracking && item.isStockTracked) ...[
                    FilledButton.tonal(
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        visualDensity: VisualDensity.compact,
                        backgroundColor: AppColors.primary.withValues(alpha: isDark ? 0.25 : 0.12),
                        foregroundColor: isDark ? const Color(0xFFFF8A65) : AppColors.primary,
                      ),
                      onPressed: () {
                        ref.read(menuProvider.notifier).restockItem(item.id, 10);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Row(
                              children: [
                                const Icon(Icons.add_shopping_cart, color: Colors.white, size: 18),
                                const SizedBox(width: 8),
                                Text('+10 units restocked for ${item.name}!'),
                              ],
                            ),
                            backgroundColor: Colors.green,
                            duration: const Duration(seconds: 2),
                          ),
                        );
                      },
                      child: const Text('+10', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                    ),
                    const SizedBox(width: 6),
                  ],
                  IconButton(
                    icon: const Icon(Icons.edit_outlined, size: 18),
                    tooltip: 'Edit Item',
                    visualDensity: VisualDensity.compact,
                    onPressed: () {
                      final currentStaff = ref.read(currentStaffProvider);
                      if (!currentStaff.canEditMenu) {
                        showDialog(
                          context: context,
                          builder: (_) => const StaffSwitchDialog(),
                        );
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('🔒 Manager PIN required to edit prices! Current: ${currentStaff.roleDisplayName}'),
                            backgroundColor: Colors.orange.shade800,
                          ),
                        );
                        return;
                      }
                      _showAddEditItemDialog(context, existingItem: item);
                    },
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete_outline, size: 18, color: Colors.red),
                    tooltip: 'Delete Item',
                    visualDensity: VisualDensity.compact,
                    onPressed: () {
                      final currentStaff = ref.read(currentStaffProvider);
                      if (!currentStaff.canEditMenu) {
                        showDialog(
                          context: context,
                          builder: (_) => const StaffSwitchDialog(),
                        );
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('🔒 Manager PIN required to delete items! Current: ${currentStaff.roleDisplayName}'),
                            backgroundColor: Colors.orange.shade800,
                          ),
                        );
                        return;
                      }
                      _confirmDeleteItem(context, item);
                    },
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    }

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(
          color: item.isAvailable
              ? (isDark ? AppColors.darkBorder : AppColors.border)
              : (isDark ? const Color(0xFF881337) : Colors.red.shade200),
        ),
      ),
      color: item.isAvailable
          ? Theme.of(context).cardColor
          : (isDark ? const Color(0xFF4C0519) : Colors.red.shade50.withValues(alpha: 0.3)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            // Veg / Non-Veg Indicator
            Container(
              padding: const EdgeInsets.all(2),
              decoration: BoxDecoration(
                border: Border.all(color: item.isVeg ? Colors.green : Colors.brown, width: 1.5),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Icon(Icons.circle, size: 8, color: item.isVeg ? Colors.green : Colors.brown),
            ),
            const SizedBox(width: 12),

            // Item Name & SKU
            Expanded(
              flex: 4,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        item.name,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                          decoration: item.isAvailable ? null : TextDecoration.lineThrough,
                          color: item.isAvailable
                              ? (isDark ? Colors.white : AppColors.textPrimary)
                              : (isDark ? AppColors.darkTextSecondary : AppColors.textSecondary),
                        ),
                      ),
                      if (item.isPackaged) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFF451A03) : Colors.amber.shade100,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            'MRP PACKAGED',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: isDark ? Colors.amber : Colors.brown,
                            ),
                          ),
                        ),
                      ],
                      if (isStockTracking && item.isStockTracked) ...[
                        const SizedBox(width: 8),
                        if (item.isOutOfStock)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                            decoration: BoxDecoration(
                              color: isDark ? const Color(0xFF4C0519) : Colors.red.shade100,
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(color: Colors.red),
                            ),
                            child: const Text(
                              '🔴 Out of Stock (0)',
                              style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.red),
                            ),
                          )
                        else if (item.isLowStock)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                            decoration: BoxDecoration(
                              color: isDark ? const Color(0xFF451A03) : Colors.orange.shade100,
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(color: Colors.orange.shade700),
                            ),
                            child: Text(
                              '⚠️ Low Stock: ${item.stockQuantity} left (Alert: ≤${item.lowStockThreshold})',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: isDark ? Colors.orange.shade300 : Colors.orange.shade900,
                              ),
                            ),
                          )
                        else
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                            decoration: BoxDecoration(
                              color: isDark ? const Color(0xFF064E3B) : Colors.green.shade100,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              '✓ Stock: ${item.stockQuantity}',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: isDark ? const Color(0xFF34D399) : Colors.green.shade900,
                              ),
                            ),
                          ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'SKU: ${item.sku}  •  Category: ${item.category}',
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),

            // Price Tag
            Expanded(
              flex: 2,
              child: Text(
                '₹${item.price.toStringAsFixed(2)}',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                  color: isDark ? const Color(0xFFFF7043) : AppColors.primary,
                ),
              ),
            ),

            // Quick Restock Button for Packaged / Tracked items
            if (isStockTracking && item.isStockTracked) ...[
              FilledButton.tonal(
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  visualDensity: VisualDensity.compact,
                  backgroundColor: AppColors.primary.withValues(alpha: isDark ? 0.25 : 0.12),
                  foregroundColor: isDark ? const Color(0xFFFF8A65) : AppColors.primary,
                ),
                onPressed: () {
                  ref.read(menuProvider.notifier).restockItem(item.id, 10);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Row(
                        children: [
                          const Icon(Icons.add_shopping_cart, color: Colors.white, size: 18),
                          const SizedBox(width: 8),
                          Text('+10 units restocked for ${item.name}! (Total: ${(item.stockQuantity < 0 ? 0 : item.stockQuantity) + 10})'),
                        ],
                      ),
                      backgroundColor: Colors.green,
                      duration: const Duration(seconds: 2),
                    ),
                  );
                },
                child: const Text('+10 Restock', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
              ),
              const SizedBox(width: 10),
            ],

            // Stock Toggle (Available / Sold Out)
            Row(
              children: [
                Text(
                  item.isAvailable ? 'In Stock' : 'Sold Out',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: item.isAvailable ? AppColors.statusAvailable : Colors.red,
                  ),
                ),
                Switch(
                  value: item.isAvailable,
                  activeThumbColor: AppColors.statusAvailable,
                  onChanged: (_) {
                    ref.read(menuProvider.notifier).toggleAvailability(item.id);
                  },
                ),
              ],
            ),
            const SizedBox(width: 12),

            // Actions (Edit & Delete)
            IconButton(
              icon: const Icon(Icons.edit_outlined, size: 20),
              tooltip: 'Edit Item',
              onPressed: () {
                final currentStaff = ref.read(currentStaffProvider);
                if (!currentStaff.canEditMenu) {
                  showDialog(
                    context: context,
                    builder: (_) => const StaffSwitchDialog(),
                  );
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('🔒 Manager PIN required to edit prices! Current: ${currentStaff.roleDisplayName}'),
                      backgroundColor: Colors.orange.shade800,
                    ),
                  );
                  return;
                }
                _showAddEditItemDialog(context, existingItem: item);
              },
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline, size: 20, color: Colors.red),
              tooltip: 'Delete Item',
              onPressed: () {
                final currentStaff = ref.read(currentStaffProvider);
                if (!currentStaff.canEditMenu) {
                  showDialog(
                    context: context,
                    builder: (_) => const StaffSwitchDialog(),
                  );
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('🔒 Manager PIN required to delete items! Current: ${currentStaff.roleDisplayName}'),
                      backgroundColor: Colors.orange.shade800,
                    ),
                  );
                  return;
                }
                _confirmDeleteItem(context, item);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showAddEditItemDialog(BuildContext context, {MenuItem? existingItem}) {
    final isEditing = existingItem != null;
    final allMenu = ref.read(menuProvider);
    final existingCategories = allMenu.map((m) => m.category).toSet().toList();

    final nameController = TextEditingController(text: existingItem?.name ?? '');
    final skuController = TextEditingController(text: existingItem?.sku ?? 'ITM-${DateTime.now().millisecondsSinceEpoch.toString().substring(8)}');
    final priceController = TextEditingController(text: existingItem != null ? existingItem.price.toStringAsFixed(0) : '');
    final stockController = TextEditingController(
      text: existingItem != null && existingItem.stockQuantity >= 0
          ? existingItem.stockQuantity.toString()
          : '25',
    );
    final thresholdController = TextEditingController(
      text: existingItem?.lowStockThreshold != null ? existingItem!.lowStockThreshold.toString() : '5',
    );
    String category = existingItem?.category ?? (existingCategories.isNotEmpty ? existingCategories.first : 'Main Course');
    bool isPackaged = existingItem?.isPackaged ?? false;
    bool isVeg = existingItem?.isVeg ?? true;

    showDialog(
      context: context,
      builder: (_) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
              title: Text(isEditing ? 'Edit Menu Item' : 'Add New Menu Item'),
              content: Container(
                constraints: const BoxConstraints(maxWidth: 480),
                width: MediaQuery.of(context).size.width,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextField(
                        controller: nameController,
                        decoration: const InputDecoration(
                          labelText: 'Item / Dish Name',
                          hintText: 'e.g. Shahi Paneer, Bikaji Bhujia 400g',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: skuController,
                              decoration: const InputDecoration(
                                labelText: 'SKU / Item Code',
                                border: OutlineInputBorder(),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextField(
                              controller: priceController,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(
                                labelText: 'Price (₹)',
                                prefixText: '₹ ',
                                border: OutlineInputBorder(),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        initialValue: existingCategories.contains(category) ? category : existingCategories.first,
                        decoration: const InputDecoration(
                          labelText: 'Category',
                          border: OutlineInputBorder(),
                        ),
                        items: existingCategories.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                        onChanged: (val) {
                          if (val != null) setDialogState(() => category = val);
                        },
                      ),
                      const SizedBox(height: 16),
                      // Toggles
                      SwitchListTile(
                        title: const Text('Packaged / MRP Product?'),
                        subtitle: const Text('Enable for Bikaji snacks, biscuits, cold drinks'),
                        value: isPackaged,
                        contentPadding: EdgeInsets.zero,
                        onChanged: (val) => setDialogState(() => isPackaged = val),
                      ),
                      if (isPackaged) ...[
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: stockController,
                                keyboardType: TextInputType.number,
                                decoration: const InputDecoration(
                                  labelText: 'Stock Units on Shelf',
                                  hintText: 'e.g. 24',
                                  prefixIcon: Icon(Icons.inventory_2_outlined, size: 18),
                                  border: OutlineInputBorder(),
                                  isDense: true,
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: TextField(
                                controller: thresholdController,
                                keyboardType: TextInputType.number,
                                decoration: const InputDecoration(
                                  labelText: 'Low Stock Alert At',
                                  hintText: 'e.g. 5',
                                  prefixIcon: Icon(Icons.warning_amber_outlined, size: 18),
                                  border: OutlineInputBorder(),
                                  isDense: true,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                      ],
                      SwitchListTile(
                        title: const Text('Pure Vegetarian?'),
                        value: isVeg,
                        contentPadding: EdgeInsets.zero,
                        onChanged: (val) => setDialogState(() => isVeg = val),
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () {
                    final name = nameController.text.trim();
                    final price = double.tryParse(priceController.text) ?? 0.0;
                    final sku = skuController.text.trim();
                    final stockQty = isPackaged ? (int.tryParse(stockController.text) ?? 20) : -1;
                    final threshold = isPackaged ? (int.tryParse(thresholdController.text) ?? 5) : 5;

                    if (name.isEmpty || price <= 0) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Please enter a valid item name and price!')),
                      );
                      return;
                    }

                    if (isEditing) {
                      ref.read(menuProvider.notifier).updateItem(
                            MenuItem(
                              id: existingItem.id,
                              name: name,
                              sku: sku,
                              price: price,
                              category: category,
                              isPackaged: isPackaged,
                              isVeg: isVeg,
                              isAvailable: isPackaged ? stockQty > 0 : existingItem.isAvailable,
                              stockQuantity: stockQty,
                              lowStockThreshold: threshold,
                            ),
                          );
                    } else {
                      ref.read(menuProvider.notifier).addItem(
                            MenuItem(
                              id: _uuid.v4(),
                              name: name,
                              sku: sku,
                              price: price,
                              category: category,
                              isPackaged: isPackaged,
                              isVeg: isVeg,
                              isAvailable: isPackaged ? stockQty > 0 : true,
                              stockQuantity: stockQty,
                              lowStockThreshold: threshold,
                            ),
                          );
                    }

                    Navigator.of(context).pop();
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(isEditing ? '$name updated!' : '$name added to menu!')),
                    );
                  },
                  child: Text(isEditing ? 'Save Changes' : 'Add Item'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _confirmDeleteItem(BuildContext context, MenuItem item) {
    showDialog(
      context: context,
      builder: (_) {
        return AlertDialog(
          title: Text('Delete "${item.name}"?'),
          content: Text('Are you sure you want to remove this item from Mehta Restaurant menu?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              onPressed: () {
                ref.read(menuProvider.notifier).deleteItem(item.id);
                Navigator.of(context).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('${item.name} removed from menu')),
                );
              },
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );
  }
}
