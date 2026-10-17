import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../models/models.dart';
import '../services/kitchen_audio_service.dart';
import '../services/supabase_service.dart';

const _uuid = Uuid();

// --- 1. SETTINGS PROVIDER ---
class SettingsNotifier extends Notifier<RestaurantSettings> {
  @override
  RestaurantSettings build() => RestaurantSettings();

  void toggleGst(bool enabled) {
    state = state.copyWith(gstEnabled: enabled);
    if (SupabaseService.isInitialized) {
      SupabaseService.saveRestaurantSettings(state);
    }
  }

  void toggleInventoryTracking(bool enabled) {
    state = state.copyWith(inventoryTrackingEnabled: enabled);
    if (SupabaseService.isInitialized) {
      SupabaseService.saveRestaurantSettings(state);
    }
  }

  void updateSettings({
    String? name,
    String? tagline,
    String? address,
    String? phone,
    String? email,
    String? gstin,
    double? taxRate,
    double? serviceChargeRate,
    String? invoicePrefix,
    String? upiId,
    String? upiPayeeName,
    bool? inventoryTrackingEnabled,
    String? receiptFooterNote,
    int? thermalPaperWidth,
    bool? autoPrintReceipt,
  }) {
    state = state.copyWith(
      restaurantName: name,
      tagline: tagline,
      address: address,
      phone: phone,
      email: email,
      gstin: gstin,
      taxRate: taxRate,
      serviceChargeRate: serviceChargeRate,
      invoicePrefix: invoicePrefix,
      upiId: upiId,
      upiPayeeName: upiPayeeName,
      inventoryTrackingEnabled: inventoryTrackingEnabled,
      receiptFooterNote: receiptFooterNote,
      thermalPaperWidth: thermalPaperWidth,
      autoPrintReceipt: autoPrintReceipt,
    );
    if (SupabaseService.isInitialized) {
      SupabaseService.saveRestaurantSettings(state);
    }
  }

  Future<void> syncWithCloud() async {
    final cloudSettings = await SupabaseService.fetchRestaurantSettings();
    if (cloudSettings != null) {
      state = cloudSettings;
    }
  }

  String getNextInvoiceNumber() {
    final num = state.nextInvoiceNumber;
    state = state.copyWith(nextInvoiceNumber: num + 1);
    return '${state.invoicePrefix}${num.toString().padLeft(6, '0')}';
  }
}

final settingsProvider = NotifierProvider<SettingsNotifier, RestaurantSettings>(SettingsNotifier.new);

// --- 2. TABLES PROVIDER (10 Tables) ---
// --- 2. TABLES PROVIDER (Full CRUD, Section & Capacity Management) ---
class TablesNotifier extends Notifier<List<RestaurantTable>> {
  @override
  List<RestaurantTable> build() {
    if (SupabaseService.isInitialized) return [];

    final initialConfigs = [
      (num: 'T01', name: 'Window Booth 1', section: 'Indoor AC', cap: 4),
      (num: 'T02', name: 'Window Booth 2', section: 'Indoor AC', cap: 4),
      (num: 'T03', name: 'Main Hall Centre', section: 'Indoor AC', cap: 6),
      (num: 'T04', name: 'Family Round Table', section: 'Indoor AC', cap: 6),
      (num: 'T05', name: 'Executive Corner', section: 'Indoor AC', cap: 4),
      (num: 'T06', name: 'VIP Dining Lounge', section: 'Indoor AC', cap: 10),
      (num: 'T07', name: 'Garden Lawn Gazebo', section: 'Outdoor Lawn', cap: 6),
      (num: 'T08', name: 'Garden Lawn Corner', section: 'Outdoor Lawn', cap: 4),
      (num: 'T09', name: 'Rooftop Open Sky 1', section: 'Rooftop Terrace', cap: 4),
      (num: 'T10', name: 'Rooftop Skyline Cabana', section: 'Rooftop Terrace', cap: 6),
    ];

    return List.generate(initialConfigs.length, (index) {
      final cfg = initialConfigs[index];
      return RestaurantTable(
        id: 'tbl-$index',
        tableNumber: cfg.num,
        name: cfg.name,
        section: cfg.section,
        capacity: cfg.cap,
        status: TableState.available,
      );
    });
  }

  /// Create a new table
  ({bool success, String? error}) addTable({
    required String tableNumber,
    String? name,
    required String section,
    required int capacity,
  }) {
    final cleanNum = tableNumber.trim().toUpperCase();
    if (cleanNum.isEmpty) {
      return (success: false, error: 'Table number cannot be empty.');
    }
    if (state.any((t) => t.tableNumber.toUpperCase() == cleanNum)) {
      return (success: false, error: 'Table $cleanNum already exists! Please use a unique number.');
    }

    final newTable = RestaurantTable(
      id: 'tbl-${DateTime.now().millisecondsSinceEpoch}',
      tableNumber: cleanNum,
      name: (name != null && name.trim().isNotEmpty) ? name.trim() : 'Table $cleanNum',
      section: section.trim().isNotEmpty ? section.trim() : 'Indoor AC',
      capacity: capacity.clamp(1, 50),
      status: TableState.available,
    );

    state = [...state, newTable];

    if (SupabaseService.isInitialized) {
      SupabaseService.updateTable(newTable);
    }

    return (success: true, error: null);
  }

  /// Update existing table name, number, section, and sitting capacity
  ({bool success, String? error}) updateTableDetails({
    required String id,
    required String newTableNumber,
    required String newName,
    required String newSection,
    required int newCapacity,
  }) {
    final cleanNum = newTableNumber.trim().toUpperCase();
    if (cleanNum.isEmpty) {
      return (success: false, error: 'Table number cannot be empty.');
    }
    if (state.any((t) => t.id != id && t.tableNumber.toUpperCase() == cleanNum)) {
      return (success: false, error: 'Another table is already using number $cleanNum.');
    }

    final index = state.indexWhere((t) => t.id == id);
    if (index == -1) {
      return (success: false, error: 'Table not found.');
    }

    final oldTable = state[index];
    final oldTableNumber = oldTable.tableNumber;

    final updated = oldTable.copyWith(
      tableNumber: cleanNum,
      name: newName.trim(),
      section: newSection.trim().isNotEmpty ? newSection.trim() : 'Indoor AC',
      capacity: newCapacity.clamp(1, 50),
    );

    state = [
      for (int i = 0; i < state.length; i++)
        if (i == index)
          updated
        else if (state[i].mergedInto == oldTableNumber)
          state[i].copyWith(mergedInto: cleanNum)
        else if (state[i].mergedTables.contains(oldTableNumber))
          state[i].copyWith(
            mergedTables: state[i].mergedTables.map((t) => t == oldTableNumber ? cleanNum : t).toList(),
          )
        else
          state[i],
    ];

    if (SupabaseService.isInitialized) {
      SupabaseService.updateTable(updated);
    }

    return (success: true, error: null);
  }

  /// Delete a table safely
  ({bool success, String? error}) deleteTable(String id) {
    final index = state.indexWhere((t) => t.id == id);
    if (index == -1) {
      return (success: false, error: 'Table not found.');
    }

    final table = state[index];

    // Safeguard 1: Do not delete if occupied or billing
    if (table.status != TableState.available || table.activeOrderId != null) {
      return (
        success: false,
        error: 'Cannot delete ${table.tableNumber} while it is occupied or has an active order. Please free the table first.'
      );
    }

    // Safeguard 2: Do not delete if merged
    if (table.isMergedMaster || table.isMergedSecondary) {
      return (
        success: false,
        error: 'Cannot delete ${table.tableNumber} while it is part of a merged table group. Unmerge it first.'
      );
    }

    state = state.where((t) => t.id != id).toList();

    if (SupabaseService.isInitialized) {
      SupabaseService.deleteTable(id);
    }

    return (success: true, error: null);
  }

  void occupyTable(String tableNumber, int guests, String orderId) {
    state = [
      for (final table in state)
        if (table.tableNumber == tableNumber)
          table.copyWith(
            status: TableState.occupied,
            guestCount: guests,
            activeOrderId: orderId,
            openedAt: table.openedAt ?? DateTime.now(),
          )
        else
          table,
    ];
    if (SupabaseService.isInitialized) {
      final updated = state.firstWhere((t) => t.tableNumber == tableNumber);
      SupabaseService.updateTable(updated);
    }
  }

  void requestBill(String tableNumber) {
    state = [
      for (final table in state)
        if (table.tableNumber == tableNumber)
          table.copyWith(status: TableState.billing)
        else
          table,
    ];
    if (SupabaseService.isInitialized) {
      final updated = state.firstWhere((t) => t.tableNumber == tableNumber);
      SupabaseService.updateTable(updated);
    }
  }

  void setTableCleaning(String tableNumber) {
    state = [
      for (final table in state)
        if (table.tableNumber == tableNumber)
          table.copyWith(status: TableState.cleaning)
        else
          table,
    ];
    if (SupabaseService.isInitialized) {
      final updated = state.firstWhere((t) => t.tableNumber == tableNumber);
      SupabaseService.updateTable(updated);
    }
  }

  void mergeTables({
    required String masterTableNumber,
    required List<String> secondaryTableNumbers,
  }) {
    state = [
      for (final table in state)
        if (table.tableNumber == masterTableNumber)
          table.copyWith(
            mergedTables: {
              ...table.mergedTables,
              ...secondaryTableNumbers,
            }.toList(),
            status: table.status == TableState.available ? TableState.occupied : table.status,
            openedAt: table.openedAt ?? DateTime.now(),
          )
        else if (secondaryTableNumbers.contains(table.tableNumber))
          table.copyWith(
            mergedInto: masterTableNumber,
            status: TableState.occupied,
            activeOrderId: null,
          )
        else
          table,
    ];
    if (SupabaseService.isInitialized) {
      for (final t in state) {
        if (t.tableNumber == masterTableNumber || secondaryTableNumbers.contains(t.tableNumber)) {
          SupabaseService.updateTable(t);
        }
      }
    }
  }

  void unmergeTable(String tableNumber) {
    final current = state.firstWhere((t) => t.tableNumber == tableNumber, orElse: () => state.first);
    if (current.isMergedMaster) {
      final secondaries = List<String>.from(current.mergedTables);
      state = [
        for (final table in state)
          if (table.tableNumber == tableNumber)
            table.copyWith(mergedTables: const [])
          else if (secondaries.contains(table.tableNumber))
            table.copyWith(
              status: TableState.available,
              guestCount: 0,
              clearActiveOrderId: true,
              clearOpenedAt: true,
              clearMergedInto: true,
              mergedTables: const [],
            )
          else
            table,
      ];
    } else if (current.isMergedSecondary) {
      final masterNum = current.mergedInto!;
      state = [
        for (final table in state)
          if (table.tableNumber == masterNum)
            table.copyWith(
              mergedTables: table.mergedTables.where((t) => t != tableNumber).toList(),
            )
          else if (table.tableNumber == tableNumber)
            table.copyWith(
              status: TableState.available,
              guestCount: 0,
              clearActiveOrderId: true,
              clearOpenedAt: true,
              clearMergedInto: true,
              mergedTables: const [],
            )
          else
            table,
      ];
    }
    if (SupabaseService.isInitialized) {
      for (final t in state) {
        SupabaseService.updateTable(t);
      }
    }
  }

  void releaseTable(String tableNumber) {
    final current = state.where((t) => t.tableNumber == tableNumber).toList();
    final secondaries = current.isNotEmpty ? current.first.mergedTables : <String>[];

    state = [
      for (final table in state)
        if (table.tableNumber == tableNumber || secondaries.contains(table.tableNumber))
          table.copyWith(
            status: TableState.available,
            guestCount: 0,
            clearActiveOrderId: true,
            clearOpenedAt: true,
            clearMergedInto: true,
            mergedTables: const [],
          )
        else
          table,
    ];
    if (SupabaseService.isInitialized) {
      for (final t in state) {
        if (t.tableNumber == tableNumber || secondaries.contains(t.tableNumber)) {
          SupabaseService.updateTable(t);
        }
      }
    }
  }

  void toggleTableEnabled(String tableNumber) {
    state = [
      for (final table in state)
        if (table.tableNumber == tableNumber)
          table.copyWith(isEnabled: !table.isEnabled)
        else
          table,
    ];
    if (SupabaseService.isInitialized) {
      final updated = state.firstWhere((t) => t.tableNumber == tableNumber);
      SupabaseService.updateTable(updated);
    }
  }

  void forceResetTable(String tableNumber) {
    releaseTable(tableNumber);
  }

  Future<void> syncWithCloud() async {
    final cloudTables = await SupabaseService.fetchTables();
    if (cloudTables != null) {
      state = cloudTables;
    }
  }
}

final tablesProvider = NotifierProvider<TablesNotifier, List<RestaurantTable>>(TablesNotifier.new);

// --- 3. DYNAMIC MENU NOTIFIER PROVIDER (Full Add/Edit/Delete/Stock Control) ---
class MenuNotifier extends Notifier<List<MenuItem>> {
  @override
  List<MenuItem> build() {
    if (SupabaseService.isInitialized) return [];
    return [
      // Starters
      MenuItem(id: '1', name: 'Paneer Tikka', sku: 'STR-01', price: 220, category: 'Starters'),
      MenuItem(id: '2', name: 'Hara Bhara Kabab', sku: 'STR-02', price: 180, category: 'Starters'),
      MenuItem(id: '3', name: 'Veg Crispy', sku: 'STR-03', price: 190, category: 'Starters'),
      MenuItem(id: '4', name: 'Veg Spring Roll', sku: 'STR-04', price: 160, category: 'Starters'),
      MenuItem(id: '5', name: 'Crispy Corn Salt & Pepper', sku: 'STR-05', price: 170, category: 'Starters'),
      MenuItem(id: '6', name: 'Chilli Paneer Dry', sku: 'STR-06', price: 210, category: 'Starters'),

      // Main Course
      MenuItem(id: '7', name: 'Paneer Butter Masala', sku: 'MNC-01', price: 240, category: 'Main Course'),
      MenuItem(id: '8', name: 'Kadhai Paneer', sku: 'MNC-02', price: 250, category: 'Main Course'),
      MenuItem(id: '9', name: 'Shahi Paneer', sku: 'MNC-03', price: 260, category: 'Main Course'),
      MenuItem(id: '10', name: 'Dal Makhani', sku: 'MNC-04', price: 210, category: 'Main Course'),
      MenuItem(id: '11', name: 'Dal Tadka (Yellow)', sku: 'MNC-05', price: 170, category: 'Main Course'),
      MenuItem(id: '12', name: 'Mix Vegetable', sku: 'MNC-06', price: 190, category: 'Main Course'),
      MenuItem(id: '13', name: 'Chana Masala', sku: 'MNC-07', price: 180, category: 'Main Course'),
      MenuItem(id: '14', name: 'Malai Kofta', sku: 'MNC-08', price: 260, category: 'Main Course'),
      MenuItem(id: '15', name: 'Mushroom Do Pyaza', sku: 'MNC-09', price: 240, category: 'Main Course'),
      MenuItem(id: '16', name: 'Aloo Gobi Adraki', sku: 'MNC-10', price: 160, category: 'Main Course'),

      // Breads & Roti
      MenuItem(id: '17', name: 'Tandoori Roti Plain', sku: 'BRD-01', price: 15, category: 'Breads'),
      MenuItem(id: '18', name: 'Tandoori Butter Roti', sku: 'BRD-02', price: 20, category: 'Breads'),
      MenuItem(id: '19', name: 'Butter Naan', sku: 'BRD-03', price: 45, category: 'Breads'),
      MenuItem(id: '20', name: 'Garlic Naan', sku: 'BRD-04', price: 60, category: 'Breads'),
      MenuItem(id: '21', name: 'Lachha Paratha', sku: 'BRD-05', price: 40, category: 'Breads'),
      MenuItem(id: '22', name: 'Missi Roti', sku: 'BRD-06', price: 35, category: 'Breads'),

      // Rice & Biryani
      MenuItem(id: '23', name: 'Steamed Plain Rice', sku: 'RIC-01', price: 110, category: 'Rice'),
      MenuItem(id: '24', name: 'Jeera Rice', sku: 'RIC-02', price: 130, category: 'Rice'),
      MenuItem(id: '25', name: 'Veg Pulao', sku: 'RIC-03', price: 160, category: 'Rice'),
      MenuItem(id: '26', name: 'Special Veg Biryani with Raita', sku: 'RIC-04', price: 220, category: 'Rice'),

      // Desserts
      MenuItem(id: '27', name: 'Gulab Jamun (2 pcs)', sku: 'DES-01', price: 60, category: 'Desserts'),
      MenuItem(id: '28', name: 'Rasgulla (2 pcs)', sku: 'DES-02', price: 60, category: 'Desserts'),
      MenuItem(id: '29', name: 'Vanilla Ice Cream', sku: 'DES-03', price: 50, category: 'Desserts'),
      MenuItem(id: '30', name: 'Kesar Pista Kulfi', sku: 'DES-04', price: 70, category: 'Desserts'),

      // Packaged Snacks & Namkeen (Bikaji)
      MenuItem(id: '31', name: 'Bikaji Bhujia (200g)', sku: 'PKG-01', price: 65, category: 'Packaged Snacks', isPackaged: true, stockQuantity: 24, lowStockThreshold: 5),
      MenuItem(id: '32', name: 'Bikaji All-in-One (200g)', sku: 'PKG-02', price: 65, category: 'Packaged Snacks', isPackaged: true, stockQuantity: 18, lowStockThreshold: 5),
      MenuItem(id: '33', name: 'Bikaji Navratna Mixture', sku: 'PKG-03', price: 65, category: 'Packaged Snacks', isPackaged: true, stockQuantity: 4, lowStockThreshold: 5),
      MenuItem(id: '34', name: 'Parle-G Biscuit Pack', sku: 'PKG-04', price: 10, category: 'Packaged Snacks', isPackaged: true, stockQuantity: 30, lowStockThreshold: 10),
      MenuItem(id: '35', name: 'Britannia Good Day Butter', sku: 'PKG-05', price: 25, category: 'Packaged Snacks', isPackaged: true, stockQuantity: 2, lowStockThreshold: 5),

      // Beverages & Cold Drinks
      MenuItem(id: '36', name: 'Packaged Mineral Water (1L)', sku: 'BEV-01', price: 20, category: 'Beverages', isPackaged: true, stockQuantity: 48, lowStockThreshold: 12),
      MenuItem(id: '37', name: 'Thums Up (250ml Can)', sku: 'BEV-02', price: 35, category: 'Beverages', isPackaged: true, stockQuantity: 15, lowStockThreshold: 6),
      MenuItem(id: '38', name: 'Coca Cola (250ml Can)', sku: 'BEV-03', price: 35, category: 'Beverages', isPackaged: true, stockQuantity: 0, lowStockThreshold: 6, isAvailable: true),
      MenuItem(id: '39', name: 'Cold Drink Bottle (750ml)', sku: 'BEV-04', price: 50, category: 'Beverages', isPackaged: true, stockQuantity: 12, lowStockThreshold: 4),
      MenuItem(id: '40', name: 'Fresh Sweet Lassi', sku: 'BEV-05', price: 60, category: 'Beverages'),
    ];
  }

  void addItem(MenuItem item) {
    state = [...state, item];
    if (SupabaseService.isInitialized) {
      SupabaseService.upsertMenuItem(item);
    }
  }

  void updateItem(MenuItem updated) {
    state = [
      for (final item in state)
        if (item.id == updated.id) updated else item,
    ];
    if (SupabaseService.isInitialized) {
      SupabaseService.upsertMenuItem(updated);
    }
  }

  void deleteItem(String id) {
    state = state.where((item) => item.id != id).toList();
    if (SupabaseService.isInitialized) {
      SupabaseService.deleteMenuItem(id);
    }
  }

  void toggleAvailability(String id) {
    state = [
      for (final item in state)
        if (item.id == id)
          item.copyWith(isAvailable: !item.isAvailable)
        else
          item,
    ];
    if (SupabaseService.isInitialized) {
      final updated = state.firstWhere((it) => it.id == id);
      SupabaseService.upsertMenuItem(updated);
    }
  }

  void decrementStock(String menuItemId, int quantity) {
    state = [
      for (final item in state)
        if (item.id == menuItemId && item.isStockTracked)
          item.copyWith(
            stockQuantity: (item.stockQuantity - quantity).clamp(0, 99999),
            isAvailable: (item.stockQuantity - quantity) > 0,
          )
        else
          item,
    ];
    if (SupabaseService.isInitialized) {
      final updated = state.where((it) => it.id == menuItemId).firstOrNull;
      if (updated != null) SupabaseService.upsertMenuItem(updated);
    }
  }

  void restockItem(String menuItemId, int addQuantity) {
    state = [
      for (final item in state)
        if (item.id == menuItemId)
          item.copyWith(
            stockQuantity: (item.stockQuantity < 0 ? 0 : item.stockQuantity) + addQuantity,
            isAvailable: true,
          )
        else
          item,
    ];
    if (SupabaseService.isInitialized) {
      final updated = state.where((it) => it.id == menuItemId).firstOrNull;
      if (updated != null) SupabaseService.upsertMenuItem(updated);
    }
  }

  void setStock(String menuItemId, int newQuantity, {int? threshold}) {
    state = [
      for (final item in state)
        if (item.id == menuItemId)
          item.copyWith(
            stockQuantity: newQuantity,
            lowStockThreshold: threshold ?? item.lowStockThreshold,
            isAvailable: newQuantity > 0,
          )
        else
          item,
    ];
    if (SupabaseService.isInitialized) {
      final updated = state.where((it) => it.id == menuItemId).firstOrNull;
      if (updated != null) SupabaseService.upsertMenuItem(updated);
    }
  }

  Future<void> syncWithCloud() async {
    final cloudItems = await SupabaseService.fetchMenuItems();
    if (cloudItems != null) {
      state = cloudItems;
    }
  }

  void setAllItems(List<MenuItem> items) {
    state = items;
  }
}

final menuProvider = NotifierProvider<MenuNotifier, List<MenuItem>>(MenuNotifier.new);

// --- 4. ORDERS & CART PROVIDER ---
class OrdersNotifier extends Notifier<Map<String, Order>> {
  @override
  Map<String, Order> build() => {};

  void initializeOrder(String tableNumber, {String? customerName, String? customerPhone, double taxRate = 0.0}) {
    final order = Order(
      id: _uuid.v4(),
      orderNumber: 'ORD-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}',
      tableNumber: tableNumber,
      items: [],
      taxRate: taxRate,
      customerName: customerName,
      customerPhone: customerPhone,
    );
    state = {...state, tableNumber: order};
  }

  String createParcelOrder({
    String? customerName,
    String? customerPhone,
    double taxRate = 0.0,
    double packagingCharge = 15.0,
  }) {
    int index = 1;
    while (state.containsKey('Parcel P-${index.toString().padLeft(2, '0')}')) {
      index++;
    }
    final parcelId = 'Parcel P-${index.toString().padLeft(2, '0')}';
    final order = Order(
      id: _uuid.v4(),
      orderNumber: 'ORD-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}',
      tableNumber: parcelId,
      items: [],
      packagingCharge: packagingCharge,
      isTakeaway: true,
      taxRate: taxRate,
      customerName: customerName,
      customerPhone: customerPhone,
    );
    state = {...state, parcelId: order};
    return parcelId;
  }

  void updatePackagingCharge(String tableNumber, double charge) {
    final order = state[tableNumber];
    if (order == null) return;
    state = {
      ...state,
      tableNumber: order.copyWith(packagingCharge: charge),
    };
  }

  void addItemToOrder(String tableNumber, MenuItem menuItem, {int quantity = 1, String? notes}) {
    final order = state[tableNumber];
    if (order == null) return;

    final existingIndex = order.items.indexWhere((it) => it.menuItemId == menuItem.id && it.notes == notes);
    List<OrderItem> updatedItems;

    if (existingIndex >= 0) {
      final existing = order.items[existingIndex];
      updatedItems = [...order.items];
      updatedItems[existingIndex] = existing.copyWith(quantity: existing.quantity + quantity);
    } else {
      updatedItems = [
        ...order.items,
        OrderItem(
          id: _uuid.v4(),
          menuItemId: menuItem.id,
          name: menuItem.name,
          unitPrice: menuItem.price,
          quantity: quantity,
          notes: notes,
        ),
      ];
    }

    state = {
      ...state,
      tableNumber: order.copyWith(items: updatedItems),
    };
  }

  void removeItemFromOrder(String tableNumber, String orderItemId) {
    final order = state[tableNumber];
    if (order == null) return;

    final updatedItems = order.items.where((it) => it.id != orderItemId).toList();
    state = {
      ...state,
      tableNumber: order.copyWith(items: updatedItems),
    };
  }

  void updateQuantity(String tableNumber, String orderItemId, int newQty) {
    final order = state[tableNumber];
    if (order == null) return;

    if (newQty <= 0) {
      removeItemFromOrder(tableNumber, orderItemId);
      return;
    }

    final updatedItems = order.items.map((it) {
      if (it.id == orderItemId) {
        return it.copyWith(quantity: newQty);
      }
      return it;
    }).toList();

    state = {
      ...state,
      tableNumber: order.copyWith(items: updatedItems),
    };
  }

  void updateCustomer(String tableNumber, String name, String phone) {
    final order = state[tableNumber];
    if (order == null) return;
    state = {
      ...state,
      tableNumber: order.copyWith(customerName: name, customerPhone: phone),
    };
  }

  void mergeOrders(String masterTableNumber, List<String> secondaryTableNumbers) {
    Order masterOrder = state[masterTableNumber] ?? Order(
      id: _uuid.v4(),
      orderNumber: 'ORD-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}',
      tableNumber: masterTableNumber,
      items: [],
    );

    List<OrderItem> combinedItems = [...masterOrder.items];

    for (final secNum in secondaryTableNumbers) {
      final secOrder = state[secNum];
      if (secOrder != null) {
        for (final item in secOrder.items) {
          final existingIdx = combinedItems.indexWhere(
            (it) => it.menuItemId == item.menuItemId && it.notes == item.notes,
          );
          if (existingIdx >= 0) {
            final existing = combinedItems[existingIdx];
            combinedItems[existingIdx] = existing.copyWith(
              quantity: existing.quantity + item.quantity,
            );
          } else {
            combinedItems.add(item);
          }
        }
      }
    }

    final updated = Map<String, Order>.from(state);
    for (final secNum in secondaryTableNumbers) {
      updated.remove(secNum);
    }
    updated[masterTableNumber] = masterOrder.copyWith(items: combinedItems);
    state = updated;
  }

  void removeOrder(String tableNumber) {
    final updated = Map<String, Order>.from(state);
    updated.remove(tableNumber);
    state = updated;
  }
}

final ordersProvider = NotifierProvider<OrdersNotifier, Map<String, Order>>(OrdersNotifier.new);

// --- 5. KITCHEN TICKETS (KOT) PROVIDER ---
class KitchenTicketsNotifier extends Notifier<List<KitchenTicket>> {
  @override
  List<KitchenTicket> build() => [];

  String sendKot({required Order order}) {
    final kotNum = 'KOT-${DateTime.now().millisecondsSinceEpoch.toString().substring(8)}';
    final ticket = KitchenTicket(
      id: _uuid.v4(),
      kotNumber: kotNum,
      orderId: order.id,
      tableNumber: order.tableNumber,
      items: List.from(order.items),
    );
    state = [ticket, ...state];

    // Play kitchen order bell chime automatically
    KitchenAudioService.playNewOrderChime();

    if (SupabaseService.isInitialized) {
      SupabaseService.saveKitchenTicket(ticket);
    }

    return kotNum;
  }

  void toggleRush(String ticketId) {
    state = [
      for (final t in state)
        if (t.id == ticketId)
          KitchenTicket(
            id: t.id,
            kotNumber: t.kotNumber,
            orderId: t.orderId,
            tableNumber: t.tableNumber,
            items: t.items,
            status: t.status,
            timestamp: t.timestamp,
            isRush: !t.isRush,
          )
        else
          t,
    ];
    if (SupabaseService.isInitialized) {
      final updated = state.where((t) => t.id == ticketId).firstOrNull;
      if (updated != null) {
        SupabaseService.updateKitchenTicketRush(ticketId, updated.isRush);
      }
    }
  }

  void deleteTicket(String ticketId) {
    state = state.where((t) => t.id != ticketId).toList();
    if (SupabaseService.isInitialized) {
      SupabaseService.deleteKitchenTicket(ticketId);
    }
  }

  void updateTicketStatus(String ticketId, KotState newStatus) {
    state = [
      for (final t in state)
        if (t.id == ticketId)
          KitchenTicket(
            id: t.id,
            kotNumber: t.kotNumber,
            orderId: t.orderId,
            tableNumber: t.tableNumber,
            items: t.items,
            status: newStatus,
            timestamp: t.timestamp,
            isRush: t.isRush,
          )
        else
          t,
    ];

    if (SupabaseService.isInitialized) {
      SupabaseService.updateKitchenTicketStatus(ticketId, newStatus);
    }
  }

  Future<void> syncWithCloud() async {
    final cloudTickets = await SupabaseService.fetchKitchenTickets();
    if (cloudTickets != null) {
      state = cloudTickets;
    }
  }
}

final kitchenTicketsProvider = NotifierProvider<KitchenTicketsNotifier, List<KitchenTicket>>(KitchenTicketsNotifier.new);

class KitchenAudioMutedNotifier extends Notifier<bool> {
  @override
  bool build() => false;

  void toggle() {
    state = !state;
    KitchenAudioService.isMuted = state;
  }

  void setMuted(bool val) {
    state = val;
    KitchenAudioService.isMuted = val;
  }
}

final kitchenAudioMutedProvider = NotifierProvider<KitchenAudioMutedNotifier, bool>(KitchenAudioMutedNotifier.new);

// --- 6. CUSTOMER & IMMUTABLE FINANCIAL LEDGER ---
class CustomersNotifier extends Notifier<List<Customer>> {
  @override
  List<Customer> build() {
    if (SupabaseService.isInitialized) return [];
    return [
      Customer(id: 'c1', name: 'Raj Sharma', phone: '9829012345', notes: 'Monthly regular customer'),
      Customer(id: 'c2', name: 'Amit Traders (Verma Ji)', phone: '9414056789', notes: 'Staff dining account'),
      Customer(id: 'c3', name: 'Gupta Family', phone: '9783011223', notes: 'Nearby resident'),
    ];
  }

  Customer getOrCreate(String name, String phone) {
    final cleanPhone = phone.replaceAll(RegExp(r'\D'), '');
    for (final c in state) {
      if (c.phone.replaceAll(RegExp(r'\D'), '') == cleanPhone) {
        return c;
      }
    }

    final newCust = Customer(
      id: _uuid.v4(),
      name: name.trim().isEmpty ? 'Guest Customer' : name.trim(),
      phone: phone.trim(),
    );
    state = [...state, newCust];
    if (SupabaseService.isInitialized) {
      SupabaseService.upsertCustomer(newCust);
    }
    return newCust;
  }

  Customer addCustomer({
    required String name,
    required String phone,
    String? notes,
  }) {
    final cleanPhone = phone.replaceAll(RegExp(r'\D'), '');
    for (final c in state) {
      if (cleanPhone.isNotEmpty && c.phone.replaceAll(RegExp(r'\D'), '') == cleanPhone) {
        return c;
      }
    }

    final newCust = Customer(
      id: _uuid.v4(),
      name: name.trim().isEmpty ? 'Customer' : name.trim(),
      phone: phone.trim(),
      notes: notes?.trim().isNotEmpty == true ? notes!.trim() : null,
    );
    state = [newCust, ...state];
    if (SupabaseService.isInitialized) {
      SupabaseService.upsertCustomer(newCust);
    }
    return newCust;
  }

  void updateCustomer({
    required String id,
    String? name,
    String? phone,
    String? notes,
  }) {
    state = [
      for (final c in state)
        if (c.id == id)
          c.copyWith(
            name: name?.trim().isNotEmpty == true ? name!.trim() : null,
            phone: phone?.trim().isNotEmpty == true ? phone!.trim() : null,
            notes: notes != null ? (notes.trim().isNotEmpty ? notes.trim() : null) : c.notes,
          )
        else
          c,
    ];
    if (SupabaseService.isInitialized) {
      final updated = state.firstWhere((c) => c.id == id);
      SupabaseService.upsertCustomer(updated);
    }
  }

  void deleteCustomer(String id) {
    state = state.where((c) => c.id != id).toList();
    if (SupabaseService.isInitialized) {
      SupabaseService.deleteCustomer(id);
    }
  }

  Future<void> syncWithCloud() async {
    final cloudCustomers = await SupabaseService.fetchCustomers();
    if (cloudCustomers != null) {
      state = cloudCustomers;
    }
  }

  void setAllCustomers(List<Customer> customers) {
    state = customers;
  }
}

final customersProvider = NotifierProvider<CustomersNotifier, List<Customer>>(CustomersNotifier.new);

class LedgerNotifier extends Notifier<List<LedgerEntry>> {
  @override
  List<LedgerEntry> build() {
    if (SupabaseService.isInitialized) return [];
    return [
      LedgerEntry(
        id: 'l1',
        customerId: 'c1',
        type: LedgerType.debit,
        amount: 3850,
        referenceType: 'INVOICE',
        referenceNumber: 'MR-000001',
        description: 'Dinner Party - T06',
        date: DateTime.now().subtract(const Duration(days: 3)),
      ),
      LedgerEntry(
        id: 'l2',
        customerId: 'c1',
        type: LedgerType.credit,
        amount: 1000,
        referenceType: 'PAYMENT',
        referenceNumber: 'UPI-TXN-9021',
        description: 'UPI Settlement (GPay)',
        date: DateTime.now().subtract(const Duration(days: 1)),
      ),
      LedgerEntry(
        id: 'l3',
        customerId: 'c2',
        type: LedgerType.debit,
        amount: 12400,
        referenceType: 'INVOICE',
        referenceNumber: 'MR-000003',
        description: 'Office catering account',
        date: DateTime.now().subtract(const Duration(days: 5)),
      ),
    ];
  }

  void addEntry(LedgerEntry entry) {
    state = [entry, ...state];
    if (SupabaseService.isInitialized) {
      SupabaseService.addLedgerEntry(entry);
    }
  }

  LedgerEntry addPendingBill({
    required String customerId,
    required double amount,
    required String referenceNumber,
    required String description,
    DateTime? date,
    String referenceType = 'INVOICE',
  }) {
    final entry = LedgerEntry(
      id: _uuid.v4(),
      customerId: customerId,
      type: LedgerType.debit,
      amount: amount,
      referenceType: referenceType,
      referenceNumber: referenceNumber,
      description: description,
      date: date ?? DateTime.now(),
    );
    state = [entry, ...state];
    if (SupabaseService.isInitialized) {
      SupabaseService.addLedgerEntry(entry);
    }
    return entry;
  }

  LedgerEntry recordPayment({
    required String customerId,
    required double amount,
    required String paymentMode,
    String? referenceNumber,
    String? note,
    DateTime? date,
  }) {
    final ref = referenceNumber != null && referenceNumber.trim().isNotEmpty
        ? referenceNumber.trim()
        : 'REC-${DateTime.now().millisecondsSinceEpoch.toString().substring(8)}';
    final desc = note != null && note.trim().isNotEmpty
        ? '$paymentMode Payment - ${note.trim()}'
        : '$paymentMode Payment Received';

    final entry = LedgerEntry(
      id: _uuid.v4(),
      customerId: customerId,
      type: LedgerType.credit,
      amount: amount,
      referenceType: 'PAYMENT',
      referenceNumber: ref,
      description: desc,
      date: date ?? DateTime.now(),
    );
    state = [entry, ...state];
    if (SupabaseService.isInitialized) {
      SupabaseService.addLedgerEntry(entry);
    }
    return entry;
  }

  void updateEntry({
    required String entryId,
    double? amount,
    String? referenceNumber,
    String? description,
    DateTime? date,
    LedgerType? type,
  }) {
    state = [
      for (final e in state)
        if (e.id == entryId)
          e.copyWith(
            amount: amount != null && amount > 0 ? amount : null,
            referenceNumber: referenceNumber?.trim().isNotEmpty == true ? referenceNumber!.trim() : null,
            description: description?.trim().isNotEmpty == true ? description!.trim() : null,
            date: date,
            type: type,
          )
        else
          e,
    ];
    if (SupabaseService.isInitialized) {
      final updated = state.firstWhere((e) => e.id == entryId, orElse: () => state.first);
      SupabaseService.updateLedgerEntry(updated);
    }
  }

  void deleteEntry(String entryId) {
    state = state.where((e) => e.id != entryId).toList();
    if (SupabaseService.isInitialized) {
      SupabaseService.deleteLedgerEntries([entryId]);
    }
  }

  void deleteEntries(List<String> entryIds) {
    final idSet = entryIds.toSet();
    state = state.where((e) => !idSet.contains(e.id)).toList();
    if (SupabaseService.isInitialized) {
      SupabaseService.deleteLedgerEntries(entryIds);
    }
  }

  void deleteEntriesForCustomer(String customerId) {
    state = state.where((e) => e.customerId != customerId).toList();
    if (SupabaseService.isInitialized) {
      SupabaseService.deleteLedgerEntriesForCustomer(customerId);
    }
  }

  double getCustomerBalance(String customerId) {
    double balance = 0.0;
    for (final entry in state) {
      if (entry.customerId == customerId) {
        if (entry.type == LedgerType.debit) {
          balance += entry.amount;
        } else {
          balance -= entry.amount;
        }
      }
    }
    return balance;
  }

  List<LedgerEntry> getCustomerEntries(String customerId) {
    return state.where((entry) => entry.customerId == customerId).toList();
  }

  Future<void> syncWithCloud() async {
    final cloudEntries = await SupabaseService.fetchLedgerEntries();
    if (cloudEntries != null) {
      state = cloudEntries;
    }
  }

  void setAllEntries(List<LedgerEntry> entries) {
    state = entries;
  }
}

final ledgerProvider = NotifierProvider<LedgerNotifier, List<LedgerEntry>>(LedgerNotifier.new);

// --- 7. INVOICES PROVIDER ---
class InvoicesNotifier extends Notifier<List<Invoice>> {
  @override
  List<Invoice> build() => [];

  void addInvoice(Invoice invoice) {
    state = [invoice, ...state];
    if (SupabaseService.isInitialized) {
      SupabaseService.saveInvoice(invoice);
    }
  }

  Future<void> syncWithCloud() async {
    final cloudInvoices = await SupabaseService.fetchInvoices();
    if (cloudInvoices != null) {
      state = cloudInvoices;
    }
  }

  Future<bool> deleteInvoice(String id) async {
    state = state.where((inv) => inv.id != id).toList();
    if (SupabaseService.isInitialized) {
      return await SupabaseService.deleteInvoice(id);
    }
    return true;
  }

  Future<bool> bulkDeleteInvoices(List<String> ids) async {
    final idSet = ids.toSet();
    state = state.where((inv) => !idSet.contains(inv.id)).toList();
    if (SupabaseService.isInitialized) {
      return await SupabaseService.bulkDeleteInvoices(ids);
    }
    return true;
  }

  Future<bool> clearAllInvoices() async {
    state = [];
    if (SupabaseService.isInitialized) {
      return await SupabaseService.clearAllInvoices();
    }
    return true;
  }

  Future<({bool success, String message})> voidInvoice(String invoiceNumber, String reason) async {
    state = [
      for (final inv in state)
        if (inv.invoiceNumber == invoiceNumber)
          inv.copyWith(isVoided: true, voidReason: reason)
        else
          inv,
    ];

    if (SupabaseService.isInitialized) {
      return await SupabaseService.voidInvoice(invoiceNumber: invoiceNumber, reason: reason);
    }
    return (success: true, message: 'Invoice rejected/voided locally');
  }
}

final invoicesProvider = NotifierProvider<InvoicesNotifier, List<Invoice>>(InvoicesNotifier.new);

// --- 8. STAFF & QUICK 4-DIGIT PIN PROVIDERS ---
class StaffDirectoryNotifier extends Notifier<List<StaffMember>> {
  @override
  List<StaffMember> build() {
    return const [
      StaffMember(id: 's1', name: 'Aman Mehta', role: StaffRole.owner, pin: '1234', avatarIcon: '👑'),
      StaffMember(id: 's2', name: 'Sh. Mehta (Father)', role: StaffRole.manager, pin: '9999', avatarIcon: '👔'),
      StaffMember(id: 's3', name: 'Counter Cashier', role: StaffRole.cashier, pin: '2222', avatarIcon: '💳'),
      StaffMember(id: 's4', name: 'Ramesh (Waiter 1)', role: StaffRole.waiter, pin: '1001', avatarIcon: '🛎️'),
      StaffMember(id: 's5', name: 'Suresh (Waiter 2)', role: StaffRole.waiter, pin: '1002', avatarIcon: '🛎️'),
      StaffMember(id: 's6', name: 'Dinesh (Waiter 3)', role: StaffRole.waiter, pin: '1003', avatarIcon: '🛎️'),
      StaffMember(id: 's7', name: 'Kitchen Chef 1', role: StaffRole.kitchen, pin: '3333', avatarIcon: '👨‍🍳'),
      StaffMember(id: 's8', name: 'Kitchen Helper 2', role: StaffRole.kitchen, pin: '3334', avatarIcon: '👨‍🍳'),
    ];
  }

  void addStaff({
    required String name,
    required StaffRole role,
    required String pin,
  }) {
    String avatar = '🛎️';
    if (role == StaffRole.owner) avatar = '👑';
    if (role == StaffRole.manager) avatar = '👔';
    if (role == StaffRole.cashier) avatar = '💳';
    if (role == StaffRole.kitchen) avatar = '👨‍🍳';

    final newStaff = StaffMember(
      id: 's_${DateTime.now().millisecondsSinceEpoch}',
      name: name,
      role: role,
      pin: pin,
      avatarIcon: avatar,
    );

    state = [...state, newStaff];
    if (SupabaseService.isInitialized) {
      SupabaseService.upsertStaffProfile(newStaff);
    }
  }

  void deleteStaff(String id) {
    state = state.where((s) => s.id != id).toList();
    if (SupabaseService.isInitialized) {
      SupabaseService.deleteStaffProfile(id);
    }
  }

  Future<void> syncWithCloud() async {
    final cloudStaff = await SupabaseService.fetchStaffProfiles();
    if (cloudStaff != null && cloudStaff.isNotEmpty) {
      state = cloudStaff;
    }
  }
}

final staffDirectoryProvider =
    NotifierProvider<StaffDirectoryNotifier, List<StaffMember>>(StaffDirectoryNotifier.new);

// Backward-compatible alias
final staffListProvider = Provider<List<StaffMember>>((ref) {
  return ref.watch(staffDirectoryProvider);
});

class CurrentStaffNotifier extends Notifier<StaffMember> {
  @override
  StaffMember build() {
    final staffList = ref.watch(staffDirectoryProvider);
    return staffList.first; // Default to Aman Mehta (Owner)
  }

  bool switchStaffWithPin(String pin) {
    final staffList = ref.read(staffDirectoryProvider);
    final match = staffList.where((s) => s.pin == pin).firstOrNull;
    if (match != null) {
      state = match;
      return true;
    }
    return false;
  }

  void switchStaffDirect(StaffMember staff) {
    state = staff;
  }
}

final currentStaffProvider = NotifierProvider<CurrentStaffNotifier, StaffMember>(CurrentStaffNotifier.new);

// --- 9. SUPABASE CLOUD CONNECTION STATUS & GLOBAL SYNC ---
class SupabaseConnectionNotifier extends Notifier<bool> {
  @override
  bool build() => SupabaseService.isInitialized;

  void setConnected(bool connected) {
    state = connected;
  }
}

final supabaseConnectionProvider =
    NotifierProvider<SupabaseConnectionNotifier, bool>(SupabaseConnectionNotifier.new);

Future<void> syncAllCloudData(WidgetRef ref) async {
  if (!SupabaseService.isInitialized) return;
  await Future.wait([
    ref.read(settingsProvider.notifier).syncWithCloud(),
    ref.read(menuProvider.notifier).syncWithCloud(),
    ref.read(customersProvider.notifier).syncWithCloud(),
    ref.read(ledgerProvider.notifier).syncWithCloud(),
    ref.read(tablesProvider.notifier).syncWithCloud(),
    ref.read(kitchenTicketsProvider.notifier).syncWithCloud(),
    ref.read(invoicesProvider.notifier).syncWithCloud(),
    ref.read(staffDirectoryProvider.notifier).syncWithCloud(),
  ]);
}
