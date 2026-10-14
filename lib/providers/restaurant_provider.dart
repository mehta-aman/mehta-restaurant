import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../models/models.dart';

const _uuid = Uuid();

// --- 1. SETTINGS PROVIDER ---
class SettingsNotifier extends Notifier<RestaurantSettings> {
  @override
  RestaurantSettings build() => RestaurantSettings();

  void toggleGst(bool enabled) {
    state = state.copyWith(gstEnabled: enabled);
  }

  void updateSettings({
    String? name,
    String? address,
    String? phone,
    String? gstin,
    double? taxRate,
    String? invoicePrefix,
  }) {
    state = state.copyWith(
      restaurantName: name,
      address: address,
      phone: phone,
      gstin: gstin,
      taxRate: taxRate,
      invoicePrefix: invoicePrefix,
    );
  }

  String getNextInvoiceNumber() {
    final num = state.nextInvoiceNumber;
    state = state.copyWith(nextInvoiceNumber: num + 1);
    return '${state.invoicePrefix}${num.toString().padLeft(6, '0')}';
  }
}

final settingsProvider = NotifierProvider<SettingsNotifier, RestaurantSettings>(SettingsNotifier.new);

// --- 2. TABLES PROVIDER (10 Tables) ---
class TablesNotifier extends Notifier<List<RestaurantTable>> {
  @override
  List<RestaurantTable> build() {
    return List.generate(10, (index) {
      final tableNum = 'T${(index + 1).toString().padLeft(2, '0')}';
      return RestaurantTable(
        id: 'tbl-$index',
        tableNumber: tableNum,
        capacity: 6,
        status: TableState.available,
      );
    });
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
  }

  void requestBill(String tableNumber) {
    state = [
      for (final table in state)
        if (table.tableNumber == tableNumber)
          table.copyWith(status: TableState.billing)
        else
          table,
    ];
  }

  void releaseTable(String tableNumber) {
    state = [
      for (final table in state)
        if (table.tableNumber == tableNumber)
          RestaurantTable(
            id: table.id,
            tableNumber: table.tableNumber,
            capacity: table.capacity,
            status: TableState.available,
            guestCount: 0,
            activeOrderId: null,
            openedAt: null,
            isEnabled: table.isEnabled,
          )
        else
          table,
    ];
  }

  void toggleTableEnabled(String tableNumber) {
    state = [
      for (final table in state)
        if (table.tableNumber == tableNumber)
          table.copyWith(isEnabled: !table.isEnabled)
        else
          table,
    ];
  }

  void forceResetTable(String tableNumber) {
    state = [
      for (final table in state)
        if (table.tableNumber == tableNumber)
          RestaurantTable(
            id: table.id,
            tableNumber: table.tableNumber,
            capacity: table.capacity,
            status: TableState.available,
            guestCount: 0,
            activeOrderId: null,
            openedAt: null,
            isEnabled: table.isEnabled,
          )
        else
          table,
    ];
  }
}

final tablesProvider = NotifierProvider<TablesNotifier, List<RestaurantTable>>(TablesNotifier.new);

// --- 3. DYNAMIC MENU NOTIFIER PROVIDER (Full Add/Edit/Delete/Stock Control) ---
class MenuNotifier extends Notifier<List<MenuItem>> {
  @override
  List<MenuItem> build() {
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
      MenuItem(id: '31', name: 'Bikaji Bhujia (200g)', sku: 'PKG-01', price: 65, category: 'Packaged Snacks', isPackaged: true),
      MenuItem(id: '32', name: 'Bikaji All-in-One (200g)', sku: 'PKG-02', price: 65, category: 'Packaged Snacks', isPackaged: true),
      MenuItem(id: '33', name: 'Bikaji Navratna Mixture', sku: 'PKG-03', price: 65, category: 'Packaged Snacks', isPackaged: true),
      MenuItem(id: '34', name: 'Parle-G Biscuit Pack', sku: 'PKG-04', price: 10, category: 'Packaged Snacks', isPackaged: true),
      MenuItem(id: '35', name: 'Britannia Good Day Butter', sku: 'PKG-05', price: 25, category: 'Packaged Snacks', isPackaged: true),

      // Beverages & Cold Drinks
      MenuItem(id: '36', name: 'Packaged Mineral Water (1L)', sku: 'BEV-01', price: 20, category: 'Beverages', isPackaged: true),
      MenuItem(id: '37', name: 'Thums Up (250ml Can)', sku: 'BEV-02', price: 35, category: 'Beverages', isPackaged: true),
      MenuItem(id: '38', name: 'Coca Cola (250ml Can)', sku: 'BEV-03', price: 35, category: 'Beverages', isPackaged: true),
      MenuItem(id: '39', name: 'Cold Drink Bottle (750ml)', sku: 'BEV-04', price: 50, category: 'Beverages', isPackaged: true),
      MenuItem(id: '40', name: 'Fresh Sweet Lassi', sku: 'BEV-05', price: 60, category: 'Beverages'),
    ];
  }

  void addItem(MenuItem item) {
    state = [...state, item];
  }

  void updateItem(MenuItem updated) {
    state = [
      for (final item in state)
        if (item.id == updated.id) updated else item,
    ];
  }

  void deleteItem(String id) {
    state = state.where((item) => item.id != id).toList();
  }

  void toggleAvailability(String id) {
    state = [
      for (final item in state)
        if (item.id == id)
          MenuItem(
            id: item.id,
            name: item.name,
            sku: item.sku,
            price: item.price,
            category: item.category,
            isPackaged: item.isPackaged,
            isVeg: item.isVeg,
            isAvailable: !item.isAvailable,
          )
        else
          item,
    ];
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

  Order? getOrder(String tableNumber) => state[tableNumber];

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
    return kotNum;
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
          )
        else
          t,
    ];
  }
}

final kitchenTicketsProvider = NotifierProvider<KitchenTicketsNotifier, List<KitchenTicket>>(KitchenTicketsNotifier.new);

// --- 6. CUSTOMER & IMMUTABLE FINANCIAL LEDGER ---
class CustomersNotifier extends Notifier<List<Customer>> {
  @override
  List<Customer> build() {
    return [
      Customer(id: 'c1', name: 'Raj Sharma', phone: '9829012345', notes: 'Monthly regular customer'),
      Customer(id: 'c2', name: 'Amit Traders (Verma Ji)', phone: '9414056789', notes: 'Staff dining account'),
      Customer(id: 'c3', name: 'Gupta Family', phone: '9783011223', notes: 'Nearby resident'),
    ];
  }

  Customer getOrCreate(String name, String phone) {
    final cleanPhone = phone.replaceAll(RegExp(r'\D'), '');
    final match = state.cast<Customer?>().firstWhere(
      (c) => c?.phone.replaceAll(RegExp(r'\D'), '') == cleanPhone,
      orElse: () => null,
    );

    if (match != null) return match;

    final newCust = Customer(
      id: _uuid.v4(),
      name: name.trim().isEmpty ? 'Guest Customer' : name.trim(),
      phone: phone.trim(),
    );
    state = [...state, newCust];
    return newCust;
  }
}

final customersProvider = NotifierProvider<CustomersNotifier, List<Customer>>(CustomersNotifier.new);

class LedgerNotifier extends Notifier<List<LedgerEntry>> {
  @override
  List<LedgerEntry> build() {
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
}

final ledgerProvider = NotifierProvider<LedgerNotifier, List<LedgerEntry>>(LedgerNotifier.new);

// --- 7. INVOICES PROVIDER ---
class InvoicesNotifier extends Notifier<List<Invoice>> {
  @override
  List<Invoice> build() => [];

  void addInvoice(Invoice invoice) {
    state = [invoice, ...state];
  }
}

final invoicesProvider = NotifierProvider<InvoicesNotifier, List<Invoice>>(InvoicesNotifier.new);
