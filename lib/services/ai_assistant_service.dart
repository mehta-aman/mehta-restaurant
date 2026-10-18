import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import '../models/models.dart';
import '../providers/restaurant_provider.dart';

const _uuid = Uuid();

enum AiActionType {
  addMenuItem,
  updatePrice,
  toggleStock,
  deleteMenuItem,
  occupyTable,
  resetTable,
  addCustomer,
  recordPayment,
  giveCredit,
  checkBalance,
  createOrder,
  querySales,
  queryOrders,
  queryTables,
  updateSettings,
  generalHelp,
  unknown,
}

class AiActionResult {
  final AiActionType type;
  final bool success;
  final String title;
  final String description;
  final IconData icon;
  final Color color;
  final bool isDatabaseSynced;
  final Future<void> Function()? undoAction;
  final Map<String, dynamic> metadata;

  const AiActionResult({
    required this.type,
    required this.success,
    required this.title,
    required this.description,
    required this.icon,
    required this.color,
    this.isDatabaseSynced = true,
    this.undoAction,
    this.metadata = const {},
  });
}

class AiMessage {
  final String id;
  final bool isUser;
  final String text;
  final DateTime timestamp;
  final AiActionResult? actionResult;

  AiMessage({
    String? id,
    required this.isUser,
    required this.text,
    DateTime? timestamp,
    this.actionResult,
  })  : id = id ?? _uuid.v4(),
        timestamp = timestamp ?? DateTime.now();
}

class AiAssistantService {
  /// Processes a natural language command (text or voice) and executes real database operations
  static Future<({String replyText, AiActionResult? actionResult})> executeCommand({
    required String prompt,
    required WidgetRef ref,
  }) async {
    final clean = prompt.trim();
    if (clean.isEmpty) {
      return (
        replyText: 'I did not catch that. Please speak or type your command.',
        actionResult: null,
      );
    }

    final lower = clean.toLowerCase();

    // 1. ADD MENU ITEM
    if (_matchesAddMenuItem(lower)) {
      return _handleAddMenuItem(clean, lower, ref);
    }

    // 2. TOGGLE STOCK / 86 DISH
    if (_matchesToggleStock(lower)) {
      return _handleToggleStock(clean, lower, ref);
    }

    // 3. UPDATE DISH PRICE
    if (_matchesUpdatePrice(lower)) {
      return _handleUpdatePrice(clean, lower, ref);
    }

    // 4. DELETE MENU ITEM
    if (_matchesDeleteMenuItem(lower)) {
      return _handleDeleteMenuItem(clean, lower, ref);
    }

    // 5. OCCUPY TABLE
    if (_matchesOccupyTable(lower)) {
      return _handleOccupyTable(clean, lower, ref);
    }

    // 6. RESET / VACATE / CLEAN TABLE
    if (_matchesResetTable(lower)) {
      return _handleResetTable(clean, lower, ref);
    }

    // 7. TODAY'S SALES / REVENUE
    if (_matchesSalesQuery(lower)) {
      return _handleSalesQuery(ref);
    }

    // 8. ACTIVE ORDERS / KOTs
    if (_matchesOrdersQuery(lower)) {
      return _handleOrdersQuery(ref);
    }

    // 9. TABLE OCCUPANCY QUERY
    if (_matchesTablesQuery(lower)) {
      return _handleTablesQuery(ref);
    }

    // 10. ADD CUSTOMER
    if (_matchesAddCustomer(lower)) {
      return _handleAddCustomer(clean, lower, ref);
    }

    // 11. RECORD CUSTOMER PAYMENT / SETTLEMENT
    if (_matchesRecordPayment(lower)) {
      return _handleRecordPayment(clean, lower, ref);
    }

    // 12. GIVE CUSTOMER CREDIT (KHATA)
    if (_matchesGiveCredit(lower)) {
      return _handleGiveCredit(clean, lower, ref);
    }

    // 13. CHECK CUSTOMER BALANCE
    if (_matchesCheckBalance(lower)) {
      return _handleCheckBalance(clean, lower, ref);
    }

    // 14. UPDATE SETTINGS
    if (_matchesUpdateSettings(lower)) {
      return _handleUpdateSettings(clean, lower, ref);
    }

    // 15. CREATE TABLE ORDER
    if (_matchesCreateOrder(lower)) {
      return _handleCreateOrder(clean, lower, ref);
    }

    // 16. HELP / CAPABILITIES
    if (lower.contains('help') || lower.contains('what can you do') || lower.contains('capabilities')) {
      return (
        replyText: 'I can manage dishes, update prices, toggle out-of-stock items, occupy or reset tables, check today\'s revenue, record customer Khata payments, and update restaurant settings.',
        actionResult: const AiActionResult(
          type: AiActionType.generalHelp,
          success: true,
          title: 'Mehta AI Capabilities',
          description: 'Try: "Add Paneer Lababdar for 280 in Main Course", "What is today\'s revenue?", or "Occupy Table 3 for 4 guests".',
          icon: Icons.auto_awesome,
          color: Color(0xFF6366F1),
          isDatabaseSynced: false,
        ),
      );
    }

    // Fallback unknown
    return (
      replyText: 'I understand you said "$clean", but I didn\'t find an actionable match. Try asking: "Add Paneer Tikka for 260", "Today\'s sales", or "Occupy table 2 for 4 guests".',
      actionResult: AiActionResult(
        type: AiActionType.unknown,
        success: false,
        title: 'Command Not Recognized',
        description: 'No database action was executed for: "$clean"',
        icon: Icons.help_outline_rounded,
        color: Colors.orange,
        isDatabaseSynced: false,
      ),
    );
  }

  // ==========================================
  // MATCHERS
  // ==========================================

  static bool _matchesAddMenuItem(String l) {
    return (l.startsWith('add ') || l.startsWith('create ') || l.startsWith('new ')) &&
        (l.contains('item') || l.contains('dish') || l.contains('for ') || l.contains('price ') || l.contains('rs') || l.contains('₹') || l.contains('in '));
  }

  static bool _matchesToggleStock(String l) {
    return l.contains('out of stock') ||
        l.contains('in stock') ||
        l.contains('86 ') ||
        l.contains('mark available') ||
        l.contains('mark unavailable') ||
        l.contains('disable ') ||
        l.contains('enable ');
  }

  static bool _matchesUpdatePrice(String l) {
    return (l.contains('price') || l.contains('rate')) &&
        (l.contains('change') || l.contains('update') || l.contains('set'));
  }

  static bool _matchesDeleteMenuItem(String l) {
    return (l.startsWith('delete') || l.startsWith('remove')) &&
        (l.contains('item') || l.contains('dish') || l.contains('menu'));
  }

  static bool _matchesOccupyTable(String l) {
    return (l.contains('occupy') || l.contains('seat') || l.contains('book')) && l.contains('table');
  }

  static bool _matchesResetTable(String l) {
    return (l.contains('reset') || l.contains('vacate') || l.contains('clean') || l.contains('clear')) && l.contains('table');
  }

  static bool _matchesSalesQuery(String l) {
    return l.contains('today') &&
        (l.contains('sales') || l.contains('revenue') || l.contains('collection') || l.contains('earn') || l.contains('total'));
  }

  static bool _matchesOrdersQuery(String l) {
    return (l.contains('how many') || l.contains('show') || l.contains('pending') || l.contains('active')) &&
        (l.contains('order') || l.contains('kot') || l.contains('kitchen'));
  }

  static bool _matchesTablesQuery(String l) {
    return (l.contains('how many') || l.contains('show') || l.contains('which')) &&
        (l.contains('tables are') || l.contains('free tables') || l.contains('occupied tables') || l.contains('table status'));
  }

  static bool _matchesAddCustomer(String l) {
    return (l.startsWith('add customer') || l.startsWith('create customer') || l.startsWith('new customer'));
  }

  static bool _matchesRecordPayment(String l) {
    return (l.contains('paid') || l.contains('payment') || l.contains('received') || l.contains('deposit')) &&
        !l.contains('what') && !l.contains('how');
  }

  static bool _matchesGiveCredit(String l) {
    return (l.contains('credit') || l.contains('khata') || l.contains('udhar')) &&
        (l.contains('give') || l.contains('add') || l.contains('record'));
  }

  static bool _matchesCheckBalance(String l) {
    return (l.contains('balance') || l.contains('khata')) &&
        (l.contains('what is') || l.contains('check') || l.contains('how much') || l.contains('show'));
  }

  static bool _matchesUpdateSettings(String l) {
    return (l.contains('tagline') || l.contains('restaurant phone') || l.contains('footer note')) &&
        (l.contains('update') || l.contains('set') || l.contains('change'));
  }

  static bool _matchesCreateOrder(String l) {
    return (l.startsWith('create order') || l.startsWith('place order') || l.startsWith('order for table')) &&
        l.contains('table');
  }

  // ==========================================
  // HANDLERS
  // ==========================================

  static ({String replyText, AiActionResult? actionResult}) _handleAddMenuItem(
    String original,
    String lower,
    WidgetRef ref,
  ) {
    // Extract price
    final priceRegex = RegExp(r'(?:₹|rs\.?|inr|price|for)?\s*(\d+(?:\.\d+)?)', caseSensitive: false);
    final priceMatch = priceRegex.allMatches(lower).lastOrNull;
    final price = double.tryParse(priceMatch?.group(1) ?? '') ?? 150.0;

    // Extract category
    String category = 'Main Course';
    if (lower.contains('starter') || lower.contains('appetizer')) {
      category = 'Starters';
    } else if (lower.contains('bread') || lower.contains('roti') || lower.contains('naan')) {
      category = 'Breads';
    } else if (lower.contains('drink') || lower.contains('beverage') || lower.contains('shake') || lower.contains('chai')) {
      category = 'Beverages';
    } else if (lower.contains('rice') || lower.contains('biryani') || lower.contains('pulao')) {
      category = 'Rice & Biryani';
    } else if (lower.contains('dessert') || lower.contains('sweet') || lower.contains('ice cream')) {
      category = 'Desserts';
    } else if (lower.contains('snack') || lower.contains('packaged') || lower.contains('bikaji')) {
      category = 'Packaged Snacks';
    }

    // Determine veg vs non-veg
    final isVeg = !(lower.contains('chicken') ||
        lower.contains('mutton') ||
        lower.contains('egg') ||
        lower.contains('fish') ||
        lower.contains('non-veg') ||
        lower.contains('non veg'));

    // Extract dish name
    String dishName = original;
    dishName = dishName.replaceAll(RegExp(r'^(?:add|create|new)\s+(?:menu\s+item|dish|item)?\s*', caseSensitive: false), '');
    dishName = dishName.replaceAll(RegExp(r'\s+(?:for|at|price|cost|rs\.?|₹|inr)\s*\d+(?:\.\d+)?.*$', caseSensitive: false), '');
    dishName = dishName.replaceAll(RegExp(r'\s+in\s+[a-zA-Z\s&]+$', caseSensitive: false), '');
    dishName = dishName.replaceAll(RegExp(r'\s+under\s+[a-zA-Z\s&]+$', caseSensitive: false), '');
    dishName = dishName.trim();

    if (dishName.isEmpty) {
      dishName = 'Special Chef Dish';
    }

    final newItem = MenuItem(
      id: _uuid.v4(),
      name: dishName,
      sku: 'AI-${DateTime.now().millisecondsSinceEpoch % 10000}',
      price: price,
      category: category,
      isVeg: isVeg,
      isAvailable: true,
    );

    // Write to Riverpod & Supabase
    ref.read(menuProvider.notifier).addItem(newItem);

    final reply = 'Done! Added "$dishName" for ₹${price.toStringAsFixed(0)} under $category (${isVeg ? 'Veg' : 'Non-Veg'}) and saved to Supabase.';

    return (
      replyText: reply,
      actionResult: AiActionResult(
        type: AiActionType.addMenuItem,
        success: true,
        title: 'Menu Item Added',
        description: '$dishName • ₹${price.toStringAsFixed(0)} • $category (${isVeg ? 'Veg' : 'Non-Veg'})',
        icon: Icons.restaurant_menu_rounded,
        color: const Color(0xFF10B981),
        isDatabaseSynced: true,
        undoAction: () async {
          ref.read(menuProvider.notifier).deleteItem(newItem.id);
        },
        metadata: {'itemId': newItem.id, 'name': dishName, 'price': price},
      ),
    );
  }

  static ({String replyText, AiActionResult? actionResult}) _handleToggleStock(
    String original,
    String lower,
    WidgetRef ref,
  ) {
    final isMarkingOut = lower.contains('out of stock') || lower.contains('86') || lower.contains('unavailable') || lower.contains('disable');

    final menu = ref.read(menuProvider);
    MenuItem? matchedItem;

    for (final item in menu) {
      if (lower.contains(item.name.toLowerCase())) {
        matchedItem = item;
        break;
      }
    }

    if (matchedItem == null) {
      return (
        replyText: 'I could not find a menu item matching that name. Please verify the dish name in your Menu list.',
        actionResult: const AiActionResult(
          type: AiActionType.toggleStock,
          success: false,
          title: 'Dish Not Found',
          description: 'Could not match the dish name in the menu database.',
          icon: Icons.search_off_rounded,
          color: Colors.red,
          isDatabaseSynced: false,
        ),
      );
    }

    ref.read(menuProvider.notifier).toggleAvailability(matchedItem.id);

    final statusWord = isMarkingOut ? 'Out of Stock (86\'d)' : 'In Stock & Available';
    final reply = '${matchedItem.name} has been marked as $statusWord in the database.';

    return (
      replyText: reply,
      actionResult: AiActionResult(
        type: AiActionType.toggleStock,
        success: true,
        title: 'Item Availability Updated',
        description: '${matchedItem.name} • $statusWord',
        icon: isMarkingOut ? Icons.remove_shopping_cart_rounded : Icons.check_circle_rounded,
        color: isMarkingOut ? Colors.orange : const Color(0xFF10B981),
        isDatabaseSynced: true,
        undoAction: () async {
          ref.read(menuProvider.notifier).toggleAvailability(matchedItem!.id);
        },
      ),
    );
  }

  static ({String replyText, AiActionResult? actionResult}) _handleUpdatePrice(
    String original,
    String lower,
    WidgetRef ref,
  ) {
    final priceRegex = RegExp(r'(?:to|price|is|₹|rs\.?)\s*(\d+(?:\.\d+)?)', caseSensitive: false);
    final match = priceRegex.firstMatch(lower);
    final newPrice = double.tryParse(match?.group(1) ?? '');

    if (newPrice == null) {
      return (
        replyText: 'Please specify the new price, for example: "Change Butter Naan price to 45".',
        actionResult: null,
      );
    }

    final menu = ref.read(menuProvider);
    MenuItem? matchedItem;
    for (final item in menu) {
      if (lower.contains(item.name.toLowerCase())) {
        matchedItem = item;
        break;
      }
    }

    if (matchedItem == null) {
      return (
        replyText: 'Could not find that dish in the menu. Please specify an existing menu item name.',
        actionResult: null,
      );
    }

    final oldPrice = matchedItem.price;
    final updated = matchedItem.copyWith(price: newPrice);
    ref.read(menuProvider.notifier).updateItem(updated);

    final reply = 'Updated ${matchedItem.name} price from ₹${oldPrice.toStringAsFixed(0)} to ₹${newPrice.toStringAsFixed(0)} in the cloud database.';

    return (
      replyText: reply,
      actionResult: AiActionResult(
        type: AiActionType.updatePrice,
        success: true,
        title: 'Price Updated',
        description: '${matchedItem.name}: ₹${oldPrice.toStringAsFixed(0)} ➔ ₹${newPrice.toStringAsFixed(0)}',
        icon: Icons.currency_rupee_rounded,
        color: const Color(0xFF10B981),
        isDatabaseSynced: true,
        undoAction: () async {
          ref.read(menuProvider.notifier).updateItem(matchedItem!.copyWith(price: oldPrice));
        },
      ),
    );
  }

  static ({String replyText, AiActionResult? actionResult}) _handleDeleteMenuItem(
    String original,
    String lower,
    WidgetRef ref,
  ) {
    final menu = ref.read(menuProvider);
    MenuItem? matchedItem;
    for (final item in menu) {
      if (lower.contains(item.name.toLowerCase())) {
        matchedItem = item;
        break;
      }
    }

    if (matchedItem == null) {
      return (
        replyText: 'Could not find the dish you want to delete. Please specify the exact dish name.',
        actionResult: null,
      );
    }

    ref.read(menuProvider.notifier).deleteItem(matchedItem.id);

    final reply = 'Removed "${matchedItem.name}" from the menu and deleted it from Supabase.';

    return (
      replyText: reply,
      actionResult: AiActionResult(
        type: AiActionType.deleteMenuItem,
        success: true,
        title: 'Menu Item Deleted',
        description: '${matchedItem.name} was removed from the database.',
        icon: Icons.delete_outline_rounded,
        color: Colors.redAccent,
        isDatabaseSynced: true,
        undoAction: () async {
          ref.read(menuProvider.notifier).addItem(matchedItem!);
        },
      ),
    );
  }

  static ({String replyText, AiActionResult? actionResult}) _handleOccupyTable(
    String original,
    String lower,
    WidgetRef ref,
  ) {
    final tableNumMatch = RegExp(r'table\s*(?:no\.?|#)?\s*([0-9a-zA-Z]+)', caseSensitive: false).firstMatch(lower);
    final rawNum = tableNumMatch?.group(1)?.toUpperCase() ?? '';

    final tables = ref.read(tablesProvider);
    RestaurantTable? matched;
    for (final t in tables) {
      if (t.tableNumber.toUpperCase() == rawNum ||
          t.tableNumber.toUpperCase() == 'T${rawNum.padLeft(2, '0')}' ||
          t.tableNumber.toUpperCase() == 'T$rawNum') {
        matched = t;
        break;
      }
    }

    if (matched == null) {
      return (
        replyText: 'Could not find table $rawNum. Please specify a valid table number, e.g., "Occupy Table 3".',
        actionResult: null,
      );
    }

    // Extract guest count
    final guestsMatch = RegExp(r'(?:for|with)?\s*(\d+)\s*(?:guest|people|person|pax)?', caseSensitive: false).firstMatch(lower);
    final guests = int.tryParse(guestsMatch?.group(1) ?? '') ?? matched.capacity;

    ref.read(tablesProvider.notifier).occupyTable(matched.tableNumber, guests, _uuid.v4());

    final reply = 'Table ${matched.tableNumber} is now marked as Occupied with $guests guests.';

    return (
      replyText: reply,
      actionResult: AiActionResult(
        type: AiActionType.occupyTable,
        success: true,
        title: 'Table Occupied',
        description: 'Table ${matched.tableNumber} • $guests Guests seated',
        icon: Icons.table_restaurant_rounded,
        color: const Color(0xFF3B82F6),
        isDatabaseSynced: true,
        undoAction: () async {
          ref.read(tablesProvider.notifier).releaseTable(matched!.tableNumber);
        },
      ),
    );
  }

  static ({String replyText, AiActionResult? actionResult}) _handleResetTable(
    String original,
    String lower,
    WidgetRef ref,
  ) {
    final tableNumMatch = RegExp(r'table\s*(?:no\.?|#)?\s*([0-9a-zA-Z]+)', caseSensitive: false).firstMatch(lower);
    final rawNum = tableNumMatch?.group(1)?.toUpperCase() ?? '';

    final tables = ref.read(tablesProvider);
    RestaurantTable? matched;
    for (final t in tables) {
      if (t.tableNumber.toUpperCase() == rawNum ||
          t.tableNumber.toUpperCase() == 'T${rawNum.padLeft(2, '0')}' ||
          t.tableNumber.toUpperCase() == 'T$rawNum') {
        matched = t;
        break;
      }
    }

    if (matched == null) {
      return (
        replyText: 'Could not find table $rawNum. Try: "Reset Table 3" or "Vacate Table 2".',
        actionResult: null,
      );
    }

    ref.read(tablesProvider.notifier).releaseTable(matched.tableNumber);

    final reply = 'Table ${matched.tableNumber} has been cleaned, vacated, and is now available.';

    return (
      replyText: reply,
      actionResult: AiActionResult(
        type: AiActionType.resetTable,
        success: true,
        title: 'Table Reset & Available',
        description: 'Table ${matched.tableNumber} is now ready for new guests.',
        icon: Icons.cleaning_services_rounded,
        color: const Color(0xFF10B981),
        isDatabaseSynced: true,
      ),
    );
  }

  static ({String replyText, AiActionResult? actionResult}) _handleSalesQuery(WidgetRef ref) {
    final invoices = ref.read(invoicesProvider);
    final now = DateTime.now();

    final todayInvoices = invoices.where((inv) {
      return !inv.isVoided &&
          inv.issuedAt.year == now.year &&
          inv.issuedAt.month == now.month &&
          inv.issuedAt.day == now.day;
    }).toList();

    double totalRevenue = 0;
    double cashTotal = 0;
    double upiTotal = 0;
    double creditTotal = 0;

    for (final inv in todayInvoices) {
      totalRevenue += inv.grandTotal;
      cashTotal += inv.cashPaid;
      upiTotal += inv.upiPaid;
      creditTotal += inv.creditAmount;
    }

    final currencyFmt = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);

    final reply = 'Today\'s total collection is ${currencyFmt.format(totalRevenue)} across ${todayInvoices.length} finalized bills. (Cash: ${currencyFmt.format(cashTotal)}, UPI: ${currencyFmt.format(upiTotal)}, Khata: ${currencyFmt.format(creditTotal)}).';

    return (
      replyText: reply,
      actionResult: AiActionResult(
        type: AiActionType.querySales,
        success: true,
        title: 'Today\'s Revenue Report',
        description: 'Total: ${currencyFmt.format(totalRevenue)} (${todayInvoices.length} Bills)\nCash: ${currencyFmt.format(cashTotal)} • UPI: ${currencyFmt.format(upiTotal)} • Khata: ${currencyFmt.format(creditTotal)}',
        icon: Icons.payments_rounded,
        color: const Color(0xFF10B981),
        isDatabaseSynced: false,
      ),
    );
  }

  static ({String replyText, AiActionResult? actionResult}) _handleOrdersQuery(WidgetRef ref) {
    final kots = ref.read(kitchenTicketsProvider);
    final active = kots.where((k) => k.status != KotState.served).toList();
    final preparing = active.where((k) => k.status == KotState.preparing).length;
    final newTickets = active.where((k) => k.status == KotState.newTicket).length;
    final ready = active.where((k) => k.status == KotState.ready).length;

    final reply = 'There are currently ${active.length} active kitchen tickets: $newTickets New, $preparing in Preparation, and $ready Ready for Serving.';

    return (
      replyText: reply,
      actionResult: AiActionResult(
        type: AiActionType.queryOrders,
        success: true,
        title: 'Kitchen Order Status',
        description: '${active.length} Total Active KOTs ($newTickets New • $preparing Cooking • $ready Ready)',
        icon: Icons.soup_kitchen_rounded,
        color: const Color(0xFFF59E0B),
        isDatabaseSynced: false,
      ),
    );
  }

  static ({String replyText, AiActionResult? actionResult}) _handleTablesQuery(WidgetRef ref) {
    final tables = ref.read(tablesProvider);
    final occupied = tables.where((t) => t.status == TableState.occupied).toList();
    final available = tables.where((t) => t.status == TableState.available).toList();
    final billing = tables.where((t) => t.status == TableState.billing).toList();

    final reply = '${occupied.length} tables are currently occupied, ${available.length} are available, and ${billing.length} are at the billing stage.';

    return (
      replyText: reply,
      actionResult: AiActionResult(
        type: AiActionType.queryTables,
        success: true,
        title: 'Table Occupancy',
        description: 'Available: ${available.length} • Occupied: ${occupied.length} • Billing: ${billing.length}',
        icon: Icons.grid_view_rounded,
        color: const Color(0xFF6366F1),
        isDatabaseSynced: false,
      ),
    );
  }

  static ({String replyText, AiActionResult? actionResult}) _handleAddCustomer(
    String original,
    String lower,
    WidgetRef ref,
  ) {
    final phoneMatch = RegExp(r'\b(\d{10})\b').firstMatch(original);
    final phone = phoneMatch?.group(1) ?? '9876543210';

    String name = original;
    name = name.replaceAll(RegExp(r'^(?:add|create|new)\s+customer\s*', caseSensitive: false), '');
    name = name.replaceAll(RegExp(r'\s*(?:with\s+phone|phone|mobile)?\s*\d{10}.*$', caseSensitive: false), '');
    name = name.trim();

    if (name.isEmpty) name = 'New Guest';

    final customer = ref.read(customersProvider.notifier).addCustomer(
      name: name,
      phone: phone,
    );

    final reply = 'Customer "$name" (Phone: ${customer.phone}) has been registered and synced to Supabase.';

    return (
      replyText: reply,
      actionResult: AiActionResult(
        type: AiActionType.addCustomer,
        success: true,
        title: 'Customer Added',
        description: '$name • Phone: ${customer.phone}',
        icon: Icons.person_add_rounded,
        color: const Color(0xFF10B981),
        isDatabaseSynced: true,
        undoAction: () async {
          ref.read(customersProvider.notifier).deleteCustomer(customer.id);
        },
      ),
    );
  }

  static ({String replyText, AiActionResult? actionResult}) _handleRecordPayment(
    String original,
    String lower,
    WidgetRef ref,
  ) {
    final amtMatch = RegExp(r'(\d+(?:\.\d+)?)').firstMatch(lower);
    final amount = double.tryParse(amtMatch?.group(1) ?? '');

    if (amount == null) {
      return (
        replyText: 'Please state the amount paid, for example: "Suresh paid 500 rupees".',
        actionResult: null,
      );
    }

    final customers = ref.read(customersProvider);
    Customer? matchedCustomer;
    for (final c in customers) {
      if (lower.contains(c.name.toLowerCase())) {
        matchedCustomer = c;
        break;
      }
    }

    if (matchedCustomer == null) {
      return (
        replyText: 'Could not match the customer name in your Khata directory.',
        actionResult: null,
      );
    }

    ref.read(ledgerProvider.notifier).recordPayment(
      customerId: matchedCustomer.id,
      amount: amount,
      paymentMode: 'Cash',
      note: 'Payment recorded via AI Assistant',
    );

    final newBalance = ref.read(ledgerProvider.notifier).getCustomerBalance(matchedCustomer.id);

    final reply = 'Recorded ₹${amount.toStringAsFixed(0)} payment for ${matchedCustomer.name}. Remaining Khata balance: ₹${newBalance.toStringAsFixed(0)}.';

    return (
      replyText: reply,
      actionResult: AiActionResult(
        type: AiActionType.recordPayment,
        success: true,
        title: 'Khata Payment Recorded',
        description: '${matchedCustomer.name} paid ₹${amount.toStringAsFixed(0)} • New Balance: ₹${newBalance.toStringAsFixed(0)}',
        icon: Icons.account_balance_wallet_rounded,
        color: const Color(0xFF10B981),
        isDatabaseSynced: true,
      ),
    );
  }

  static ({String replyText, AiActionResult? actionResult}) _handleGiveCredit(
    String original,
    String lower,
    WidgetRef ref,
  ) {
    final amtMatch = RegExp(r'(\d+(?:\.\d+)?)').firstMatch(lower);
    final amount = double.tryParse(amtMatch?.group(1) ?? '');

    if (amount == null) {
      return (
        replyText: 'Please specify the credit amount, for example: "Give Ramesh 300 rupees credit".',
        actionResult: null,
      );
    }

    final customers = ref.read(customersProvider);
    Customer? matchedCustomer;
    for (final c in customers) {
      if (lower.contains(c.name.toLowerCase())) {
        matchedCustomer = c;
        break;
      }
    }

    if (matchedCustomer == null) {
      return (
        replyText: 'Customer not found in Khata list.',
        actionResult: null,
      );
    }

    ref.read(ledgerProvider.notifier).addPendingBill(
      customerId: matchedCustomer.id,
      amount: amount,
      referenceType: 'KHATA',
      referenceNumber: 'AI-${DateTime.now().millisecondsSinceEpoch % 10000}',
      description: 'Credit entry via AI Assistant',
    );

    final newBalance = ref.read(ledgerProvider.notifier).getCustomerBalance(matchedCustomer.id);

    final reply = 'Added ₹${amount.toStringAsFixed(0)} credit for ${matchedCustomer.name}. Outstanding Khata: ₹${newBalance.toStringAsFixed(0)}.';

    return (
      replyText: reply,
      actionResult: AiActionResult(
        type: AiActionType.giveCredit,
        success: true,
        title: 'Customer Credit Added',
        description: '${matchedCustomer.name} owes ₹${newBalance.toStringAsFixed(0)} (+₹${amount.toStringAsFixed(0)})',
        icon: Icons.credit_score_rounded,
        color: Colors.orange,
        isDatabaseSynced: true,
      ),
    );
  }

  static ({String replyText, AiActionResult? actionResult}) _handleCheckBalance(
    String original,
    String lower,
    WidgetRef ref,
  ) {
    final customers = ref.read(customersProvider);
    Customer? matchedCustomer;
    for (final c in customers) {
      if (lower.contains(c.name.toLowerCase())) {
        matchedCustomer = c;
        break;
      }
    }

    if (matchedCustomer == null) {
      return (
        replyText: 'Could not find that customer in your accounts directory.',
        actionResult: null,
      );
    }

    final bal = ref.read(ledgerProvider.notifier).getCustomerBalance(matchedCustomer.id);
    final reply = '${matchedCustomer.name}\'s current Khata balance is ₹${bal.toStringAsFixed(0)} (${bal > 0 ? "Pending to pay" : "Settled"}).';

    return (
      replyText: reply,
      actionResult: AiActionResult(
        type: AiActionType.checkBalance,
        success: true,
        title: 'Customer Khata Balance',
        description: '${matchedCustomer.name}: ₹${bal.toStringAsFixed(0)} ${bal > 0 ? "Pending" : "Cleared"}',
        icon: Icons.person_rounded,
        color: bal > 0 ? Colors.orange : const Color(0xFF10B981),
        isDatabaseSynced: false,
      ),
    );
  }

  static ({String replyText, AiActionResult? actionResult}) _handleUpdateSettings(
    String original,
    String lower,
    WidgetRef ref,
  ) {
    if (lower.contains('tagline')) {
      final taglineMatch = RegExp(r'tagline\s*(?:to|is)?\s*["\x27]?([^"\x27]+)["\x27]?$', caseSensitive: false).firstMatch(original);
      final newTagline = taglineMatch?.group(1)?.trim();
      if (newTagline != null && newTagline.isNotEmpty) {
        ref.read(settingsProvider.notifier).updateSettings(tagline: newTagline);
        final reply = 'Updated restaurant tagline to "$newTagline" and saved to Supabase.';
        return (
          replyText: reply,
          actionResult: AiActionResult(
            type: AiActionType.updateSettings,
            success: true,
            title: 'Settings Updated',
            description: 'New Tagline: "$newTagline"',
            icon: Icons.settings_rounded,
            color: const Color(0xFF6366F1),
            isDatabaseSynced: true,
          ),
        );
      }
    }

    return (
      replyText: 'Please specify the exact setting, e.g.: "Update tagline to \'Royal Taste of Rajasthan\'".',
      actionResult: null,
    );
  }

  static ({String replyText, AiActionResult? actionResult}) _handleCreateOrder(
    String original,
    String lower,
    WidgetRef ref,
  ) {
    final tableNumMatch = RegExp(r'table\s*(?:no\.?|#)?\s*([0-9a-zA-Z]+)', caseSensitive: false).firstMatch(lower);
    final rawNum = tableNumMatch?.group(1)?.toUpperCase() ?? '';

    final tables = ref.read(tablesProvider);
    RestaurantTable? matchedTable;
    for (final t in tables) {
      if (t.tableNumber.toUpperCase() == rawNum ||
          t.tableNumber.toUpperCase() == 'T${rawNum.padLeft(2, '0')}' ||
          t.tableNumber.toUpperCase() == 'T$rawNum') {
        matchedTable = t;
        break;
      }
    }

    if (matchedTable == null) {
      return (
        replyText: 'Could not find table $rawNum to create order.',
        actionResult: null,
      );
    }

    // Match dishes mentioned in menu
    final menu = ref.read(menuProvider);
    final List<({MenuItem item, int qty})> matchedDishes = [];

    for (final m in menu) {
      if (lower.contains(m.name.toLowerCase())) {
        final pattern = RegExp('(\\d+)\\s*${RegExp.escape(m.name.toLowerCase())}', caseSensitive: false);
        final qMatch = pattern.firstMatch(lower);
        final qty = int.tryParse(qMatch?.group(1) ?? '') ?? 1;

        matchedDishes.add((item: m, qty: qty));
      }
    }

    if (matchedDishes.isEmpty) {
      return (
        replyText: 'Could not match any menu items for this order. Please mention dishes from the menu.',
        actionResult: null,
      );
    }

    // Initialize order
    ref.read(ordersProvider.notifier).initializeOrder(matchedTable.tableNumber);

    for (final pair in matchedDishes) {
      ref.read(ordersProvider.notifier).addItemToOrder(
        matchedTable.tableNumber,
        pair.item,
        quantity: pair.qty,
      );
    }

    final activeOrder = ref.read(ordersProvider)[matchedTable.tableNumber];
    if (activeOrder != null) {
      ref.read(tablesProvider.notifier).occupyTable(
        matchedTable.tableNumber,
        matchedTable.capacity,
        activeOrder.id,
      );
      ref.read(kitchenTicketsProvider.notifier).sendKot(order: activeOrder);
    }

    final itemsSummary = matchedDishes.map((i) => '${i.qty}x ${i.item.name}').join(', ');
    final total = activeOrder?.grandTotal ?? 0.0;
    final reply = 'Order placed for Table ${matchedTable.tableNumber}: $itemsSummary. (Total: ₹${total.toStringAsFixed(0)}). KOT sent to kitchen!';

    return (
      replyText: reply,
      actionResult: AiActionResult(
        type: AiActionType.createOrder,
        success: true,
        title: 'Order Created & KOT Dispatched',
        description: 'Table ${matchedTable.tableNumber} • $itemsSummary • Total: ₹${total.toStringAsFixed(0)}',
        icon: Icons.receipt_long_rounded,
        color: const Color(0xFF10B981),
        isDatabaseSynced: true,
      ),
    );
  }
}
