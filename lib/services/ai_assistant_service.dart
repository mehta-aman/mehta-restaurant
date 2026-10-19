import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../models/models.dart';
import '../providers/restaurant_provider.dart';
import 'ai/ai_action_service.dart';
import 'ai/ai_confirmation_manager.dart';
import 'ai/ai_read_operations_service.dart';

const _uuid = Uuid();

enum AiActionType {
  addMenuItem,
  bulkMenuImport,
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
  finalizeInvoice,
  voidInvoice,
  querySales,
  queryOrders,
  queryTables,
  queryPerformance,
  searchMenu,
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
  final bool requiresConfirmation;
  final String? confirmationToken;
  final Map<String, dynamic> previewData;
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
    this.requiresConfirmation = false,
    this.confirmationToken,
    this.previewData = const {},
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
  /// Processes a natural language command (text or voice) with full authorization,
  /// structured validation, read queries, and two-step action confirmations.
  static Future<({String replyText, AiActionResult? actionResult})> executeCommand({
    required String prompt,
    required dynamic ref,
    StaffMember? staff,
    String? pendingToken,
  }) async {
    final clean = prompt.trim();
    if (clean.isEmpty) {
      return (
        replyText: 'I did not catch that. Please speak or type your command.',
        actionResult: null,
      );
    }

    final activeStaff = staff ?? ref.read(currentStaffProvider) as StaffMember;
    final lower = clean.toLowerCase();

    // 0. VOICE / TEXT CONFIRMATION OF PENDING ACTION
    if (pendingToken != null && pendingToken.isNotEmpty) {
      if (_matchesConfirmation(lower)) {
        final execRes = await AiActionService.executeConfirmedAction(
          confirmationToken: pendingToken,
          staff: activeStaff,
          ref: ref,
          userPrompt: clean,
        );

        return (
          replyText: execRes.summary,
          actionResult: AiActionResult(
            type: AiActionType.unknown,
            success: execRes.success,
            title: execRes.success ? 'Action Executed' : 'Execution Failed',
            description: execRes.summary,
            icon: execRes.success ? Icons.check_circle_rounded : Icons.error_outline_rounded,
            color: execRes.success ? const Color(0xFF10B981) : Colors.red,
            isDatabaseSynced: execRes.success,
            requiresConfirmation: false,
          ),
        );
      }

      if (_matchesCancellation(lower)) {
        AiConfirmationManager.cancelToken(pendingToken);
        return (
          replyText: 'Action cancelled. No database changes were made.',
          actionResult: const AiActionResult(
            type: AiActionType.unknown,
            success: true,
            title: 'Action Cancelled',
            description: 'Operation was discarded upon user request.',
            icon: Icons.cancel_outlined,
            color: Colors.grey,
            isDatabaseSynced: false,
            requiresConfirmation: false,
          ),
        );
      }
    }

    // 1. READ: TODAY'S SALES / REVENUE
    if (_matchesSalesQuery(lower)) {
      final res = await AiReadOperationsService.executeReadTool(
        toolName: 'get_sales_report',
        arguments: {'period': 'today'},
        staff: activeStaff,
        ref: ref,
      );
      return (
        replyText: res.summary,
        actionResult: AiActionResult(
          type: AiActionType.querySales,
          success: res.success,
          title: "Today's Revenue Report",
          description: res.summary,
          icon: Icons.payments_rounded,
          color: const Color(0xFF10B981),
          isDatabaseSynced: false,
        ),
      );
    }

    // 2. READ: ACTIVE ORDERS / KOTs
    if (_matchesOrdersQuery(lower)) {
      final res = await AiReadOperationsService.executeReadTool(
        toolName: 'get_kitchen_tickets',
        arguments: {},
        staff: activeStaff,
        ref: ref,
      );
      return (
        replyText: res.summary,
        actionResult: AiActionResult(
          type: AiActionType.queryOrders,
          success: res.success,
          title: 'Kitchen Tickets & Active Orders',
          description: res.summary,
          icon: Icons.soup_kitchen_rounded,
          color: const Color(0xFFF59E0B),
          isDatabaseSynced: false,
        ),
      );
    }

    // 3. READ: TABLE OCCUPANCY / STATUS
    if (_matchesTablesQuery(lower)) {
      final res = await AiReadOperationsService.executeReadTool(
        toolName: 'get_table_status',
        arguments: {},
        staff: activeStaff,
        ref: ref,
      );
      return (
        replyText: res.summary,
        actionResult: AiActionResult(
          type: AiActionType.queryTables,
          success: res.success,
          title: 'Dining Floor Status',
          description: res.summary,
          icon: Icons.grid_view_rounded,
          color: const Color(0xFF6366F1),
          isDatabaseSynced: false,
        ),
      );
    }

    // 4. READ: TOP DISHES / PERFORMANCE
    if (_matchesPerformanceQuery(lower)) {
      final res = await AiReadOperationsService.executeReadTool(
        toolName: 'get_item_sales_performance',
        arguments: {'limit': 5},
        staff: activeStaff,
        ref: ref,
      );
      return (
        replyText: res.summary,
        actionResult: AiActionResult(
          type: AiActionType.queryPerformance,
          success: res.success,
          title: 'Top Dish Sales Performance',
          description: res.summary,
          icon: Icons.leaderboard_rounded,
          color: const Color(0xFFEC4899),
          isDatabaseSynced: false,
        ),
      );
    }

    // 5. READ: CHECK CUSTOMER KHATA BALANCE
    if (_matchesCheckBalance(lower)) {
      return _handleCheckBalance(clean, lower, activeStaff, ref);
    }

    // 6. READ: SEARCH MENU ITEMS
    if (_matchesSearchMenu(lower)) {
      return _handleSearchMenu(clean, lower, activeStaff, ref);
    }

    // 7. WRITE (PREPARATION): BULK MENU IMPORT (CSV / MULTI-LINE)
    if (_matchesBulkImport(clean, lower)) {
      return _handleBulkImport(clean, lower, activeStaff, ref);
    }

    // 8. WRITE (PREPARATION): ADD SINGLE MENU ITEM
    if (_matchesAddMenuItem(lower)) {
      return _handleAddMenuItem(clean, lower, activeStaff, ref);
    }

    // 9. WRITE (PREPARATION): TOGGLE STOCK / 86 DISH
    if (_matchesToggleStock(lower)) {
      return _handleToggleStock(clean, lower, activeStaff, ref);
    }

    // 10. WRITE (PREPARATION): UPDATE DISH PRICE
    if (_matchesUpdatePrice(lower)) {
      return _handleUpdatePrice(clean, lower, activeStaff, ref);
    }

    // 11. WRITE (PREPARATION): OCCUPY TABLE
    if (_matchesOccupyTable(lower)) {
      return _handleOccupyTable(clean, lower, activeStaff, ref);
    }

    // 12. WRITE (PREPARATION): RESET / VACATE / CLEAN TABLE
    if (_matchesResetTable(lower)) {
      return _handleResetTable(clean, lower, activeStaff, ref);
    }

    // 13. WRITE (PREPARATION): ADD CUSTOMER
    if (_matchesAddCustomer(lower)) {
      return _handleAddCustomer(clean, lower, activeStaff, ref);
    }

    // 14. WRITE (PREPARATION): RECORD CUSTOMER PAYMENT / SETTLEMENT
    if (_matchesRecordPayment(lower)) {
      return _handleRecordPayment(clean, lower, activeStaff, ref);
    }

    // 15. WRITE (PREPARATION): GIVE CUSTOMER CREDIT (KHATA DEBIT)
    if (_matchesGiveCredit(lower)) {
      return _handleGiveCredit(clean, lower, activeStaff, ref);
    }

    // 16. WRITE (PREPARATION): CREATE TABLE ORDER
    if (_matchesCreateOrder(lower)) {
      return _handleCreateOrder(clean, lower, activeStaff, ref);
    }

    // 17. WRITE (PREPARATION): VOID INVOICE
    if (_matchesVoidInvoice(lower)) {
      return _handleVoidInvoice(clean, lower, activeStaff, ref);
    }

    // 18. WRITE (PREPARATION): UPDATE SETTINGS
    if (_matchesUpdateSettings(lower)) {
      return _handleUpdateSettings(clean, lower, activeStaff, ref);
    }

    // 19. HELP / CAPABILITIES
    if (lower.contains('help') || lower.contains('what can you do') || lower.contains('capabilities')) {
      return (
        replyText: 'I can query real-time sales, manage dishes, bulk import menus from CSV, update prices, toggle out-of-stock items, seat guests, record Khata payments, and dispatch kitchen orders.',
        actionResult: const AiActionResult(
          type: AiActionType.generalHelp,
          success: true,
          title: 'Mehta AI Capabilities',
          description: 'Try: "Add Paneer Lababdar for 280 in Main Course", "What is today\'s sales?", "Suresh paid 500 rupees", or "Occupy Table 3 for 4 guests".',
          icon: Icons.auto_awesome,
          color: Color(0xFF6366F1),
          isDatabaseSynced: false,
        ),
      );
    }

    // Fallback unknown
    return (
      replyText: 'I understand you said "$clean", but I did not find an actionable match. Try: "Today\'s sales", "Add Paneer Tikka for 260", or "Occupy table 2 for 4 guests".',
      actionResult: AiActionResult(
        type: AiActionType.unknown,
        success: false,
        title: 'Command Not Recognized',
        description: 'No database action prepared for: "$clean"',
        icon: Icons.help_outline_rounded,
        color: Colors.orange,
        isDatabaseSynced: false,
      ),
    );
  }

  // ==========================================
  // INTENT MATCHERS
  // ==========================================

  static bool _matchesConfirmation(String l) {
    return l == 'confirm' ||
        l == 'yes' ||
        l == 'proceed' ||
        l == 'approve' ||
        l == 'do it' ||
        l == 'yes please' ||
        l == 'execute' ||
        l == 'save' ||
        l == 'haan' ||
        l == 'theek hai';
  }

  static bool _matchesCancellation(String l) {
    return l == 'cancel' ||
        l == 'no' ||
        l == 'abort' ||
        l == 'stop' ||
        l == 'discard' ||
        l == 'nahin' ||
        l == 'don\'t do it';
  }

  static bool _matchesSalesQuery(String l) {
    return (l.contains('today') || l.contains('daily') || l.contains('total')) &&
        (l.contains('sales') || l.contains('revenue') || l.contains('collection') || l.contains('earn'));
  }

  static bool _matchesOrdersQuery(String l) {
    return (l.contains('how many') || l.contains('show') || l.contains('pending') || l.contains('active')) &&
        (l.contains('order') || l.contains('kot') || l.contains('kitchen'));
  }

  static bool _matchesTablesQuery(String l) {
    return (l.contains('how many') || l.contains('show') || l.contains('which') || l.contains('check')) &&
        (l.contains('tables') || l.contains('table status') || l.contains('floor'));
  }

  static bool _matchesPerformanceQuery(String l) {
    return l.contains('top dish') ||
        l.contains('best seller') ||
        l.contains('performance') ||
        l.contains('most popular') ||
        l.contains('most ordered');
  }

  static bool _matchesCheckBalance(String l) {
    return (l.contains('balance') || l.contains('khata') || l.contains('owe')) &&
        (l.contains('what is') || l.contains('check') || l.contains('how much') || l.contains('show'));
  }

  static bool _matchesSearchMenu(String l) {
    return (l.startsWith('search') || l.startsWith('find') || l.startsWith('show menu') || l.contains('dishes in')) &&
        !l.contains('add ') && !l.contains('create ');
  }

  static bool _matchesBulkImport(String orig, String l) {
    return l.startsWith('bulk import') ||
        l.startsWith('import menu') ||
        l.contains('csv import') ||
        (orig.contains('\n') && (l.contains(',') || l.contains('veg') || l.contains('starter') || l.contains('course')));
  }

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

  static bool _matchesOccupyTable(String l) {
    return (l.contains('occupy') || l.contains('seat') || l.contains('book')) && l.contains('table');
  }

  static bool _matchesResetTable(String l) {
    return (l.contains('reset') || l.contains('vacate') || l.contains('clean') || l.contains('clear')) && l.contains('table');
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

  static bool _matchesCreateOrder(String l) {
    return (l.startsWith('create order') || l.startsWith('place order') || l.startsWith('order for table')) &&
        l.contains('table');
  }

  static bool _matchesVoidInvoice(String l) {
    return (l.startsWith('void') || l.contains('cancel bill') || l.contains('cancel invoice')) &&
        (l.contains('bill') || l.contains('invoice') || l.contains('mr-'));
  }

  static bool _matchesUpdateSettings(String l) {
    return (l.contains('tagline') || l.contains('restaurant phone') || l.contains('footer note')) &&
        (l.contains('update') || l.contains('set') || l.contains('change'));
  }

  // ==========================================
  // ACTION PREPARATION HANDLERS
  // ==========================================

  static Future<({String replyText, AiActionResult? actionResult})> _handleAddMenuItem(
    String original,
    String lower,
    StaffMember staff,
    dynamic ref,
  ) async {
    final priceRegex = RegExp(r'(?:₹|rs\.?|inr|price|for)?\s*(\d+(?:\.\d+)?)', caseSensitive: false);
    final priceMatch = priceRegex.allMatches(lower).lastOrNull;
    final price = double.tryParse(priceMatch?.group(1) ?? '') ?? 150.0;

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

    final isVeg = !(lower.contains('chicken') ||
        lower.contains('mutton') ||
        lower.contains('egg') ||
        lower.contains('fish') ||
        lower.contains('non-veg') ||
        lower.contains('non veg'));

    String dishName = original;
    dishName = dishName.replaceAll(RegExp(r'^(?:add|create|new)\s+(?:menu\s+item|dish|item)?\s*', caseSensitive: false), '');
    dishName = dishName.replaceAll(RegExp(r'\s+(?:for|at|price|cost|rs\.?|₹|inr)\s*\d+(?:\.\d+)?.*$', caseSensitive: false), '');
    dishName = dishName.replaceAll(RegExp(r'\s+in\s+[a-zA-Z\s&]+$', caseSensitive: false), '');
    dishName = dishName.replaceAll(RegExp(r'\s+under\s+[a-zA-Z\s&]+$', caseSensitive: false), '');
    dishName = dishName.trim();

    if (dishName.isEmpty) dishName = 'Chef Special Dish';

    final prepRes = await AiActionService.prepareAction(
      toolName: 'prepare_menu_item_create',
      arguments: {
        'name': dishName,
        'category': category,
        'price': price,
        'is_veg': isVeg,
      },
      staff: staff,
      ref: ref,
    );

    return (
      replyText: prepRes.summary,
      actionResult: AiActionResult(
        type: AiActionType.addMenuItem,
        success: prepRes.success,
        title: prepRes.success ? 'Confirm Adding Menu Item' : 'Cannot Add Dish',
        description: prepRes.summary,
        icon: Icons.restaurant_menu_rounded,
        color: const Color(0xFF10B981),
        isDatabaseSynced: false,
        requiresConfirmation: prepRes.requiresConfirmation,
        confirmationToken: prepRes.confirmationToken?.token,
        previewData: prepRes.data,
      ),
    );
  }

  static Future<({String replyText, AiActionResult? actionResult})> _handleBulkImport(
    String original,
    String lower,
    StaffMember staff,
    dynamic ref,
  ) async {
    String content = original;
    content = content.replaceAll(RegExp(r'^(?:bulk import|import menu|csv import):?\s*', caseSensitive: false), '');

    final prepRes = await AiActionService.prepareAction(
      toolName: 'prepare_bulk_menu_import',
      arguments: {
        'raw_content': content,
        'mode': 'upsert',
      },
      staff: staff,
      ref: ref,
    );

    return (
      replyText: prepRes.summary,
      actionResult: AiActionResult(
        type: AiActionType.bulkMenuImport,
        success: prepRes.success,
        title: prepRes.success ? 'Confirm Bulk Menu Import' : 'Import Parse Failed',
        description: prepRes.summary,
        icon: Icons.file_upload_rounded,
        color: const Color(0xFF6366F1),
        isDatabaseSynced: false,
        requiresConfirmation: prepRes.requiresConfirmation,
        confirmationToken: prepRes.confirmationToken?.token,
        previewData: prepRes.data,
      ),
    );
  }

  static Future<({String replyText, AiActionResult? actionResult})> _handleToggleStock(
    String original,
    String lower,
    StaffMember staff,
    dynamic ref,
  ) async {
    final isMarkingOut = lower.contains('out of stock') || lower.contains('86') || lower.contains('unavailable') || lower.contains('disable');

    final List<MenuItem> menu = ref.read(menuProvider);
    MenuItem? matchedItem;
    for (final item in menu) {
      if (lower.contains(item.name.toLowerCase())) {
        matchedItem = item;
        break;
      }
    }

    if (matchedItem == null) {
      return (
        replyText: 'Could not find a menu item matching that name. Please verify the dish name in the menu.',
        actionResult: null,
      );
    }

    final prepRes = await AiActionService.prepareAction(
      toolName: 'prepare_menu_item_update',
      arguments: {
        'name_or_id': matchedItem.id,
        'is_available': !isMarkingOut,
      },
      staff: staff,
      ref: ref,
    );

    return (
      replyText: prepRes.summary,
      actionResult: AiActionResult(
        type: AiActionType.toggleStock,
        success: prepRes.success,
        title: prepRes.success ? 'Confirm Stock Availability' : 'Update Failed',
        description: prepRes.summary,
        icon: isMarkingOut ? Icons.remove_shopping_cart_rounded : Icons.check_circle_rounded,
        color: isMarkingOut ? Colors.orange : const Color(0xFF10B981),
        isDatabaseSynced: false,
        requiresConfirmation: prepRes.requiresConfirmation,
        confirmationToken: prepRes.confirmationToken?.token,
        previewData: prepRes.data,
      ),
    );
  }

  static Future<({String replyText, AiActionResult? actionResult})> _handleUpdatePrice(
    String original,
    String lower,
    StaffMember staff,
    dynamic ref,
  ) async {
    final priceRegex = RegExp(r'(?:to|price|is|₹|rs\.?)\s*(\d+(?:\.\d+)?)', caseSensitive: false);
    final match = priceRegex.firstMatch(lower);
    final newPrice = double.tryParse(match?.group(1) ?? '');

    if (newPrice == null) {
      return (
        replyText: 'Please specify the new price, e.g.: "Change Butter Naan price to 45".',
        actionResult: null,
      );
    }

    final List<MenuItem> menu = ref.read(menuProvider);
    MenuItem? matchedItem;
    for (final item in menu) {
      if (lower.contains(item.name.toLowerCase())) {
        matchedItem = item;
        break;
      }
    }

    if (matchedItem == null) {
      return (
        replyText: 'Could not find that dish in the menu.',
        actionResult: null,
      );
    }

    final prepRes = await AiActionService.prepareAction(
      toolName: 'prepare_menu_item_update',
      arguments: {
        'name_or_id': matchedItem.id,
        'new_price': newPrice,
      },
      staff: staff,
      ref: ref,
    );

    return (
      replyText: prepRes.summary,
      actionResult: AiActionResult(
        type: AiActionType.updatePrice,
        success: prepRes.success,
        title: prepRes.success ? 'Confirm Price Change' : 'Price Change Rejected',
        description: prepRes.summary,
        icon: Icons.currency_rupee_rounded,
        color: const Color(0xFF10B981),
        isDatabaseSynced: false,
        requiresConfirmation: prepRes.requiresConfirmation,
        confirmationToken: prepRes.confirmationToken?.token,
        previewData: prepRes.data,
      ),
    );
  }

  static Future<({String replyText, AiActionResult? actionResult})> _handleOccupyTable(
    String original,
    String lower,
    StaffMember staff,
    dynamic ref,
  ) async {
    final tableNumMatch = RegExp(r'table\s*(?:no\.?|#)?\s*([0-9a-zA-Z]+)', caseSensitive: false).firstMatch(lower);
    final rawNum = tableNumMatch?.group(1)?.toUpperCase() ?? '';

    final guestsMatch = RegExp(r'(?:for|with)?\s*(\d+)\s*(?:guest|people|person|pax)?', caseSensitive: false).firstMatch(lower);
    final guests = int.tryParse(guestsMatch?.group(1) ?? '');

    final prepRes = await AiActionService.prepareAction(
      toolName: 'prepare_table_status_change',
      arguments: {
        'table_number': rawNum,
        'action': 'occupy',
        'guests': ?guests,
      },
      staff: staff,
      ref: ref,
    );

    return (
      replyText: prepRes.summary,
      actionResult: AiActionResult(
        type: AiActionType.occupyTable,
        success: prepRes.success,
        title: prepRes.success ? 'Confirm Table Seating' : 'Table Action Failed',
        description: prepRes.summary,
        icon: Icons.table_restaurant_rounded,
        color: const Color(0xFF3B82F6),
        isDatabaseSynced: false,
        requiresConfirmation: prepRes.requiresConfirmation,
        confirmationToken: prepRes.confirmationToken?.token,
        previewData: prepRes.data,
      ),
    );
  }

  static Future<({String replyText, AiActionResult? actionResult})> _handleResetTable(
    String original,
    String lower,
    StaffMember staff,
    dynamic ref,
  ) async {
    final tableNumMatch = RegExp(r'table\s*(?:no\.?|#)?\s*([0-9a-zA-Z]+)', caseSensitive: false).firstMatch(lower);
    final rawNum = tableNumMatch?.group(1)?.toUpperCase() ?? '';

    final prepRes = await AiActionService.prepareAction(
      toolName: 'prepare_table_status_change',
      arguments: {
        'table_number': rawNum,
        'action': 'vacate',
      },
      staff: staff,
      ref: ref,
    );

    return (
      replyText: prepRes.summary,
      actionResult: AiActionResult(
        type: AiActionType.resetTable,
        success: prepRes.success,
        title: prepRes.success ? 'Confirm Vacating Table' : 'Table Reset Failed',
        description: prepRes.summary,
        icon: Icons.cleaning_services_rounded,
        color: const Color(0xFF10B981),
        isDatabaseSynced: false,
        requiresConfirmation: prepRes.requiresConfirmation,
        confirmationToken: prepRes.confirmationToken?.token,
        previewData: prepRes.data,
      ),
    );
  }

  static Future<({String replyText, AiActionResult? actionResult})> _handleAddCustomer(
    String original,
    String lower,
    StaffMember staff,
    dynamic ref,
  ) async {
    final phoneMatch = RegExp(r'\b(\d{10})\b').firstMatch(original);
    final phone = phoneMatch?.group(1) ?? '9876543210';

    String name = original;
    name = name.replaceAll(RegExp(r'^(?:add|create|new)\s+customer\s*', caseSensitive: false), '');
    name = name.replaceAll(RegExp(r'\s*(?:with\s+phone|phone|mobile)?\s*\d{10}.*$', caseSensitive: false), '');
    name = name.trim();

    if (name.isEmpty) name = 'New Guest';

    final prepRes = await AiActionService.prepareAction(
      toolName: 'prepare_customer_create',
      arguments: {
        'name': name,
        'phone': phone,
      },
      staff: staff,
      ref: ref,
    );

    return (
      replyText: prepRes.summary,
      actionResult: AiActionResult(
        type: AiActionType.addCustomer,
        success: prepRes.success,
        title: prepRes.success ? 'Confirm Customer Registration' : 'Registration Failed',
        description: prepRes.summary,
        icon: Icons.person_add_rounded,
        color: const Color(0xFF10B981),
        isDatabaseSynced: false,
        requiresConfirmation: prepRes.requiresConfirmation,
        confirmationToken: prepRes.confirmationToken?.token,
        previewData: prepRes.data,
      ),
    );
  }

  static Future<({String replyText, AiActionResult? actionResult})> _handleRecordPayment(
    String original,
    String lower,
    StaffMember staff,
    dynamic ref,
  ) async {
    final amtMatch = RegExp(r'(\d+(?:\.\d+)?)').firstMatch(lower);
    final amount = double.tryParse(amtMatch?.group(1) ?? '');

    if (amount == null) {
      return (
        replyText: 'Please state the amount paid, e.g.: "Suresh paid 500 rupees".',
        actionResult: null,
      );
    }

    final mode = lower.contains('upi') ? 'UPI' : 'Cash';

    final List<Customer> customers = ref.read(customersProvider);
    Customer? matchedCustomer;
    for (final c in customers) {
      if (lower.contains(c.name.toLowerCase())) {
        matchedCustomer = c;
        break;
      }
    }

    if (matchedCustomer == null) {
      return (
        replyText: 'Could not match the customer name in your Khata accounts.',
        actionResult: null,
      );
    }

    final prepRes = await AiActionService.prepareAction(
      toolName: 'prepare_payment',
      arguments: {
        'customer_name_or_id': matchedCustomer.name,
        'amount': amount,
        'payment_mode': mode,
      },
      staff: staff,
      ref: ref,
    );

    return (
      replyText: prepRes.summary,
      actionResult: AiActionResult(
        type: AiActionType.recordPayment,
        success: prepRes.success,
        title: prepRes.success ? 'Confirm Khata Settlement' : 'Payment Prep Failed',
        description: prepRes.summary,
        icon: Icons.account_balance_wallet_rounded,
        color: const Color(0xFF10B981),
        isDatabaseSynced: false,
        requiresConfirmation: prepRes.requiresConfirmation,
        confirmationToken: prepRes.confirmationToken?.token,
        previewData: prepRes.data,
      ),
    );
  }

  static Future<({String replyText, AiActionResult? actionResult})> _handleGiveCredit(
    String original,
    String lower,
    StaffMember staff,
    dynamic ref,
  ) async {
    final amtMatch = RegExp(r'(\d+(?:\.\d+)?)').firstMatch(lower);
    final amount = double.tryParse(amtMatch?.group(1) ?? '');

    if (amount == null) {
      return (
        replyText: 'Please specify the credit amount, e.g.: "Give Ramesh 300 rupees credit".',
        actionResult: null,
      );
    }

    final List<Customer> customers = ref.read(customersProvider);
    Customer? matchedCustomer;
    for (final c in customers) {
      if (lower.contains(c.name.toLowerCase())) {
        matchedCustomer = c;
        break;
      }
    }

    if (matchedCustomer == null) {
      return (
        replyText: 'Customer not found in Khata accounts.',
        actionResult: null,
      );
    }

    final prepRes = await AiActionService.prepareAction(
      toolName: 'prepare_customer_balance_entry',
      arguments: {
        'customer_name_or_id': matchedCustomer.name,
        'amount': amount,
        'description': 'AI Assistant Credit Entry',
      },
      staff: staff,
      ref: ref,
    );

    return (
      replyText: prepRes.summary,
      actionResult: AiActionResult(
        type: AiActionType.giveCredit,
        success: prepRes.success,
        title: prepRes.success ? 'Confirm Khata Credit Entry' : 'Credit Prep Failed',
        description: prepRes.summary,
        icon: Icons.credit_score_rounded,
        color: Colors.orange,
        isDatabaseSynced: false,
        requiresConfirmation: prepRes.requiresConfirmation,
        confirmationToken: prepRes.confirmationToken?.token,
        previewData: prepRes.data,
      ),
    );
  }

  static Future<({String replyText, AiActionResult? actionResult})> _handleCreateOrder(
    String original,
    String lower,
    StaffMember staff,
    dynamic ref,
  ) async {
    final tableNumMatch = RegExp(r'table\s*(?:no\.?|#)?\s*([0-9a-zA-Z]+)', caseSensitive: false).firstMatch(lower);
    final rawNum = tableNumMatch?.group(1)?.toUpperCase() ?? '';

    final List<MenuItem> menu = ref.read(menuProvider);
    final List<Map<String, dynamic>> itemsToAdd = [];

    for (final m in menu) {
      if (lower.contains(m.name.toLowerCase())) {
        final pattern = RegExp('(\\d+)\\s*${RegExp.escape(m.name.toLowerCase())}', caseSensitive: false);
        final qMatch = pattern.firstMatch(lower);
        final qty = int.tryParse(qMatch?.group(1) ?? '') ?? 1;

        itemsToAdd.add({
          'name': m.name,
          'quantity': qty,
        });
      }
    }

    if (itemsToAdd.isEmpty) {
      return (
        replyText: 'Could not match dishes from the menu. Please specify dish names.',
        actionResult: null,
      );
    }

    final prepRes = await AiActionService.prepareAction(
      toolName: 'prepare_order_change',
      arguments: {
        'table_number': rawNum,
        'items_to_add': itemsToAdd,
      },
      staff: staff,
      ref: ref,
    );

    return (
      replyText: prepRes.summary,
      actionResult: AiActionResult(
        type: AiActionType.createOrder,
        success: prepRes.success,
        title: prepRes.success ? 'Confirm Order & KOT Dispatch' : 'Order Prep Failed',
        description: prepRes.summary,
        icon: Icons.receipt_long_rounded,
        color: const Color(0xFF10B981),
        isDatabaseSynced: false,
        requiresConfirmation: prepRes.requiresConfirmation,
        confirmationToken: prepRes.confirmationToken?.token,
        previewData: prepRes.data,
      ),
    );
  }

  static Future<({String replyText, AiActionResult? actionResult})> _handleVoidInvoice(
    String original,
    String lower,
    StaffMember staff,
    dynamic ref,
  ) async {
    final invMatch = RegExp(r'(mr-[0-9a-zA-Z-]+)', caseSensitive: false).firstMatch(original);
    final invNum = invMatch?.group(1)?.toUpperCase() ?? '';

    String reason = 'Requested by staff';
    final reasonMatch = RegExp(r'reason\s*[:=]?\s*(.+)$', caseSensitive: false).firstMatch(original);
    if (reasonMatch != null && reasonMatch.group(1)!.trim().isNotEmpty) {
      reason = reasonMatch.group(1)!.trim();
    }

    final prepRes = await AiActionService.prepareAction(
      toolName: 'prepare_invoice_void',
      arguments: {
        'invoice_number': invNum,
        'reason': reason,
      },
      staff: staff,
      ref: ref,
    );

    return (
      replyText: prepRes.summary,
      actionResult: AiActionResult(
        type: AiActionType.voidInvoice,
        success: prepRes.success,
        title: prepRes.success ? 'Confirm Voiding Invoice' : 'Void Rejected',
        description: prepRes.summary,
        icon: Icons.remove_circle_outline_rounded,
        color: Colors.redAccent,
        isDatabaseSynced: false,
        requiresConfirmation: prepRes.requiresConfirmation,
        confirmationToken: prepRes.confirmationToken?.token,
        previewData: prepRes.data,
      ),
    );
  }

  static Future<({String replyText, AiActionResult? actionResult})> _handleUpdateSettings(
    String original,
    String lower,
    StaffMember staff,
    dynamic ref,
  ) async {
    final Map<String, dynamic> changes = {};

    if (lower.contains('tagline')) {
      final match = RegExp(r'tagline\s*(?:to|is)?\s*["\x27]?([^"\x27]+)["\x27]?$', caseSensitive: false).firstMatch(original);
      if (match != null && match.group(1)!.trim().isNotEmpty) {
        changes['tagline'] = match.group(1)!.trim();
      }
    }

    if (changes.isEmpty) {
      return (
        replyText: 'Please specify the exact setting, e.g.: "Update tagline to \'Royal Taste of Rajasthan\'".',
        actionResult: null,
      );
    }

    final prepRes = await AiActionService.prepareAction(
      toolName: 'prepare_settings_update',
      arguments: changes,
      staff: staff,
      ref: ref,
    );

    return (
      replyText: prepRes.summary,
      actionResult: AiActionResult(
        type: AiActionType.updateSettings,
        success: prepRes.success,
        title: prepRes.success ? 'Confirm Settings Update' : 'Update Rejected',
        description: prepRes.summary,
        icon: Icons.settings_rounded,
        color: const Color(0xFF6366F1),
        isDatabaseSynced: false,
        requiresConfirmation: prepRes.requiresConfirmation,
        confirmationToken: prepRes.confirmationToken?.token,
        previewData: prepRes.data,
      ),
    );
  }

  static Future<({String replyText, AiActionResult? actionResult})> _handleCheckBalance(
    String original,
    String lower,
    StaffMember staff,
    dynamic ref,
  ) async {
    final List<Customer> customers = ref.read(customersProvider);
    Customer? matchedCustomer;
    for (final c in customers) {
      if (lower.contains(c.name.toLowerCase())) {
        matchedCustomer = c;
        break;
      }
    }

    final res = await AiReadOperationsService.executeReadTool(
      toolName: 'get_customer_balances',
      arguments: {
        if (matchedCustomer != null) 'customer_id': matchedCustomer.id,
      },
      staff: staff,
      ref: ref,
    );

    return (
      replyText: res.summary,
      actionResult: AiActionResult(
        type: AiActionType.checkBalance,
        success: res.success,
        title: 'Customer Khata Balance',
        description: res.summary,
        icon: Icons.person_rounded,
        color: const Color(0xFF10B981),
        isDatabaseSynced: false,
      ),
    );
  }

  static Future<({String replyText, AiActionResult? actionResult})> _handleSearchMenu(
    String original,
    String lower,
    StaffMember staff,
    dynamic ref,
  ) async {
    String q = original;
    q = q.replaceAll(RegExp(r'^(?:search|find|show\s+menu\s+for|dishes\s+in)\s*', caseSensitive: false), '').trim();

    final res = await AiReadOperationsService.executeReadTool(
      toolName: 'search_menu',
      arguments: {'query': q},
      staff: staff,
      ref: ref,
    );

    return (
      replyText: res.summary,
      actionResult: AiActionResult(
        type: AiActionType.searchMenu,
        success: res.success,
        title: 'Menu Search Results',
        description: res.summary,
        icon: Icons.menu_book_rounded,
        color: const Color(0xFF6366F1),
        isDatabaseSynced: false,
      ),
    );
  }
}
