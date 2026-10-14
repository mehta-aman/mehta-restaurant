import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../core/theme.dart';
import '../../models/models.dart';
import '../../providers/restaurant_provider.dart';

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

    final categories = ['All', ...allMenu.map((m) => m.category).toSet()];

    final filteredMenu = allMenu.where((item) {
      final matchesCategory = _selectedCategory == 'All' || item.category == _selectedCategory;
      final matchesSearch = item.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          item.sku.toLowerCase().contains(_searchQuery.toLowerCase());
      return matchesCategory && matchesSearch;
    }).toList();

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Menu Management & Live Stock Control'),
            Text(
              '${allMenu.length} Total Items (${allMenu.where((i) => i.isAvailable).length} Available • ${allMenu.where((i) => !i.isAvailable).length} Sold Out)',
              style: const TextStyle(fontSize: 12, color: AppColors.textSecondary, fontWeight: FontWeight.normal),
            ),
          ],
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: ElevatedButton.icon(
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Add Menu Item'),
              onPressed: () => _showAddEditItemDialog(context),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // Filter Bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            color: Colors.white,
            child: Row(
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
                      fillColor: AppColors.background,
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
                ),
              ],
            ),
          ),
          const Divider(height: 1),

          // Menu List Table
          Expanded(
            child: filteredMenu.isEmpty
                ? const Center(child: Text('No menu items match your search.'))
                : ListView.separated(
                    padding: const EdgeInsets.all(20),
                    itemCount: filteredMenu.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final item = filteredMenu[index];
                      return _buildMenuItemRow(context, item);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildMenuItemRow(BuildContext context, MenuItem item) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: item.isAvailable ? AppColors.border : Colors.red.shade200),
      ),
      color: item.isAvailable ? Colors.white : Colors.red.shade50.withValues(alpha: 0.3),
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
                          color: item.isAvailable ? AppColors.textPrimary : AppColors.textSecondary,
                        ),
                      ),
                      if (item.isPackaged) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.amber.shade100,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text('MRP PACKAGED', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.brown)),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'SKU: ${item.sku}  •  Category: ${item.category}',
                    style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                  ),
                ],
              ),
            ),

            // Price Tag
            Expanded(
              flex: 2,
              child: Text(
                '₹${item.price.toStringAsFixed(2)}',
                style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: AppColors.primary),
              ),
            ),

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
                  activeColor: AppColors.statusAvailable,
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
              onPressed: () => _showAddEditItemDialog(context, existingItem: item),
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline, size: 20, color: Colors.red),
              tooltip: 'Delete Item',
              onPressed: () => _confirmDeleteItem(context, item),
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
              title: Text(isEditing ? 'Edit Menu Item' : 'Add New Menu Item'),
              content: SizedBox(
                width: 480,
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
                        value: existingCategories.contains(category) ? category : existingCategories.first,
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
                              isAvailable: existingItem.isAvailable,
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
                              isAvailable: true,
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
