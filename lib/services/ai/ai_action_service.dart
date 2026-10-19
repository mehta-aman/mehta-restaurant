import 'package:uuid/uuid.dart';
import '../../models/models.dart';
import '../../providers/restaurant_provider.dart';
import '../supabase_service.dart';
import 'ai_confirmation_manager.dart';
import 'ai_models.dart';
import 'ai_permission_guard.dart';
import 'ai_tool_registry.dart';

const _uuid = Uuid();

class AiActionService {
  static final List<AiAuditLogEntry> _recentAuditLogs = [];

  static List<AiAuditLogEntry> get auditLogs => List.unmodifiable(_recentAuditLogs);

  /// Prepares an action for user confirmation, performing schema validation,
  /// permission enforcement, state snapshotting, and token generation.
  static Future<AiToolResult> prepareAction({
    required String toolName,
    required Map<String, dynamic> arguments,
    required StaffMember staff,
    required dynamic ref,
  }) async {
    final tool = AiToolRegistry.getTool(toolName);
    if (tool == null) {
      return AiToolResult(
        toolName: toolName,
        success: false,
        summary: 'Unknown tool "$toolName".',
        errorMessage: 'Tool not found in registry.',
      );
    }

    // Role Permission Check
    final perm = AiPermissionGuard.checkPermission(
      staff: staff,
      tool: tool,
      arguments: arguments,
    );
    if (!perm.isAllowed) {
      _logAudit(
        staff: staff,
        toolName: toolName,
        arguments: arguments,
        success: false,
        errorMessage: perm.rejectionReason,
      );
      return AiToolResult(
        toolName: toolName,
        success: false,
        summary: perm.rejectionReason ?? 'Permission Denied.',
        errorMessage: perm.rejectionReason,
      );
    }

    switch (toolName) {
      case 'prepare_menu_item_create':
        return _prepareMenuItemCreate(arguments, staff, ref);
      case 'prepare_menu_item_update':
        return _prepareMenuItemUpdate(arguments, staff, ref);
      case 'prepare_bulk_menu_import':
        return _prepareBulkMenuImport(arguments, staff, ref);
      case 'prepare_customer_create':
        return _prepareCustomerCreate(arguments, staff, ref);
      case 'prepare_customer_balance_entry':
        return _prepareCustomerBalanceEntry(arguments, staff, ref);
      case 'prepare_table_status_change':
        return _prepareTableStatusChange(arguments, staff, ref);
      case 'prepare_order_change':
        return _prepareOrderChange(arguments, staff, ref);
      case 'prepare_payment':
        return _preparePayment(arguments, staff, ref);
      case 'prepare_invoice':
        return _prepareInvoice(arguments, staff, ref);
      case 'prepare_invoice_void':
        return _prepareInvoiceVoid(arguments, staff, ref);
      case 'prepare_settings_update':
        return _prepareSettingsUpdate(arguments, staff, ref);
      default:
        return AiToolResult(
          toolName: toolName,
          success: false,
          summary: 'Tool "$toolName" is not recognized as an action preparation tool.',
        );
    }
  }

  // ==========================================
  // PREPARATION HANDLERS
  // ==========================================

  // 1. PREPARE MENU ITEM CREATE
  static Future<AiToolResult> _prepareMenuItemCreate(
    Map<String, dynamic> args,
    StaffMember staff,
    dynamic ref,
  ) async {
    final name = (args['name']?.toString() ?? '').trim();
    if (name.isEmpty) {
      return const AiToolResult(
        toolName: 'prepare_menu_item_create',
        success: false,
        summary: 'Dish name cannot be empty.',
      );
    }

    final category = (args['category']?.toString() ?? 'Main Course').trim();
    final price = (args['price'] as num?)?.toDouble() ?? 0.0;
    if (price < 0) {
      return const AiToolResult(
        toolName: 'prepare_menu_item_create',
        success: false,
        summary: 'Price must be greater than or equal to 0.',
      );
    }

    final isVeg = args['is_veg'] as bool? ?? true;
    final isPackaged = args['is_packaged'] as bool? ?? false;
    final stockQuantity = (args['stock_quantity'] as num?)?.toInt() ?? 0;
    final sku = (args['sku']?.toString() ?? '').trim().isNotEmpty
        ? args['sku'].toString().trim()
        : 'SKU-${DateTime.now().millisecondsSinceEpoch % 10000}';
    final description = args['description']?.toString().trim();

    // Check duplicate
    final List<MenuItem> menu = ref.read(menuProvider);
    final isDuplicate = menu.any((m) => m.name.toLowerCase() == name.toLowerCase());

    final validatedParams = {
      'name': name,
      'category': category,
      'price': price,
      'is_veg': isVeg,
      'is_packaged': isPackaged,
      'stock_quantity': stockQuantity,
      'sku': sku,
      'description': description,
    };

    final token = AiConfirmationManager.issueToken(
      operationName: 'prepare_menu_item_create',
      validatedParameters: validatedParams,
      staff: staff,
      stateSnapshot: {'existing_menu_count': menu.length, 'is_duplicate': isDuplicate},
    );

    return AiToolResult(
      toolName: 'prepare_menu_item_create',
      success: true,
      summary: isDuplicate
          ? 'Warning: A dish named "$name" already exists. Confirm to add another instance for ₹${price.toStringAsFixed(0)} under $category.'
          : 'Ready to add "$name" for ₹${price.toStringAsFixed(0)} in $category (${isVeg ? 'Veg' : 'Non-Veg'}).',
      confirmationToken: token,
      data: {
        'preview_type': 'menu_item_create',
        'name': name,
        'category': category,
        'price': price,
        'is_veg': isVeg,
        'is_packaged': isPackaged,
        'stock_quantity': stockQuantity,
        'sku': sku,
        'description': description,
        'is_duplicate': isDuplicate,
      },
    );
  }

  // 2. PREPARE MENU ITEM UPDATE
  static Future<AiToolResult> _prepareMenuItemUpdate(
    Map<String, dynamic> args,
    StaffMember staff,
    dynamic ref,
  ) async {
    final nameOrId = (args['name_or_id']?.toString() ?? '').toLowerCase().trim();
    if (nameOrId.isEmpty) {
      return const AiToolResult(
        toolName: 'prepare_menu_item_update',
        success: false,
        summary: 'Please specify the dish name or ID to update.',
      );
    }

    final List<MenuItem> menu = ref.read(menuProvider);
    MenuItem? matched;
    for (final item in menu) {
      if (item.id.toLowerCase() == nameOrId || item.name.toLowerCase().contains(nameOrId)) {
        matched = item;
        break;
      }
    }

    if (matched == null) {
      return AiToolResult(
        toolName: 'prepare_menu_item_update',
        success: false,
        summary: 'Could not find dish matching "$nameOrId" in the menu catalog.',
      );
    }

    // Role check for price changes: kitchen cannot alter prices
    final newPrice = (args['new_price'] as num?)?.toDouble();
    if (newPrice != null && staff.role == StaffRole.kitchen) {
      return const AiToolResult(
        toolName: 'prepare_menu_item_update',
        success: false,
        summary: 'Permission Denied: Kitchen staff can only toggle dish availability, not edit prices.',
      );
    }

    final isAvailable = args['is_available'] as bool?;
    final newCategory = args['new_category']?.toString().trim();
    final stockQuantity = (args['stock_quantity'] as num?)?.toInt();

    final diff = <String, dynamic>{};
    if (newPrice != null && newPrice != matched.price) {
      diff['price'] = {'old': matched.price, 'new': newPrice};
    }
    if (isAvailable != null && isAvailable != matched.isAvailable) {
      diff['is_available'] = {'old': matched.isAvailable, 'new': isAvailable};
    }
    if (newCategory != null && newCategory.isNotEmpty && newCategory != matched.category) {
      diff['category'] = {'old': matched.category, 'new': newCategory};
    }
    if (stockQuantity != null && stockQuantity != matched.stockQuantity) {
      diff['stock_quantity'] = {'old': matched.stockQuantity, 'new': stockQuantity};
    }

    if (diff.isEmpty) {
      return AiToolResult(
        toolName: 'prepare_menu_item_update',
        success: false,
        summary: 'No changes detected for "${matched.name}".',
      );
    }

    final validatedParams = {
      'item_id': matched.id,
      'name': matched.name,
      'new_price': newPrice ?? matched.price,
      'is_available': isAvailable ?? matched.isAvailable,
      'new_category': newCategory ?? matched.category,
      'stock_quantity': stockQuantity ?? matched.stockQuantity,
      'diff': diff,
    };

    final token = AiConfirmationManager.issueToken(
      operationName: 'prepare_menu_item_update',
      validatedParameters: validatedParams,
      staff: staff,
      stateSnapshot: {
        'id': matched.id,
        'price': matched.price,
        'is_available': matched.isAvailable,
        'category': matched.category,
      },
    );

    final summaryParts = <String>[];
    if (diff.containsKey('price')) {
      summaryParts.add('Price: ₹${matched.price.toStringAsFixed(0)} ➔ ₹${newPrice!.toStringAsFixed(0)}');
    }
    if (diff.containsKey('is_available')) {
      summaryParts.add('Status: ${isAvailable! ? "In Stock" : "Out of Stock (86d)"}');
    }
    if (diff.containsKey('category')) {
      summaryParts.add('Category: ${matched.category} ➔ $newCategory');
    }

    return AiToolResult(
      toolName: 'prepare_menu_item_update',
      success: true,
      summary: 'Update "${matched.name}": ${summaryParts.join(", ")}.',
      confirmationToken: token,
      data: {
        'preview_type': 'menu_item_update',
        'item_id': matched.id,
        'item_name': matched.name,
        'diff': diff,
      },
    );
  }

  // 3. PREPARE BULK MENU IMPORT
  static Future<AiToolResult> _prepareBulkMenuImport(
    Map<String, dynamic> args,
    StaffMember staff,
    dynamic ref,
  ) async {
    final rawContent = (args['raw_content']?.toString() ?? '').trim();
    final mode = (args['mode']?.toString() ?? 'upsert').trim();

    if (rawContent.isEmpty) {
      return const AiToolResult(
        toolName: 'prepare_bulk_menu_import',
        success: false,
        summary: 'Bulk menu import content cannot be empty. Please provide CSV or line-delimited dishes.',
      );
    }

    final List<MenuItem> currentMenu = ref.read(menuProvider);
    final existingNames = {for (final m in currentMenu) m.name.toLowerCase(): m};

    final lines = rawContent.split(RegExp(r'\r?\n'));
    final List<Map<String, dynamic>> validItems = [];
    final List<Map<String, dynamic>> errors = [];
    int duplicateCount = 0;

    int lineNum = 0;
    for (final rawLine in lines) {
      lineNum++;
      final line = rawLine.trim();
      if (line.isEmpty) continue;

      // Skip header line if detected
      if (lineNum == 1 &&
          (line.toLowerCase().contains('name') || line.toLowerCase().contains('dish')) &&
          (line.toLowerCase().contains('price') || line.toLowerCase().contains('category'))) {
        continue;
      }

      // Format can be comma-separated or tab-separated or pipe-separated
      final delimiter = line.contains(',') ? ',' : (line.contains('\t') ? '\t' : '|');
      final parts = line.split(delimiter).map((s) => s.trim()).toList();

      if (parts.isEmpty || parts[0].isEmpty) {
        continue;
      }

      final name = parts[0];
      final category = parts.length > 1 && parts[1].isNotEmpty ? parts[1] : 'Main Course';
      final priceStr = parts.length > 2 ? parts[2].replaceAll(RegExp(r'[^\d.]'), '') : '100';
      final price = double.tryParse(priceStr) ?? 100.0;

      bool isVeg = true;
      if (parts.length > 3) {
        final vegRaw = parts[3].toLowerCase();
        if (vegRaw.contains('non') || vegRaw == 'nv' || vegRaw == 'false' || vegRaw == '0') {
          isVeg = false;
        }
      } else {
        final nLow = name.toLowerCase();
        if (nLow.contains('chicken') || nLow.contains('mutton') || nLow.contains('egg') || nLow.contains('fish')) {
          isVeg = false;
        }
      }

      final isExisting = existingNames.containsKey(name.toLowerCase());
      if (isExisting) duplicateCount++;

      if (mode == 'create_only' && isExisting) {
        errors.add({'line': lineNum, 'item': name, 'reason': 'Duplicate dish exists and mode is create_only'});
        continue;
      }

      validItems.add({
        'name': name,
        'category': category,
        'price': price,
        'is_veg': isVeg,
        'is_duplicate': isExisting,
        'sku': 'BULK-${DateTime.now().millisecondsSinceEpoch % 10000}-$lineNum',
      });
    }

    if (validItems.isEmpty) {
      return AiToolResult(
        toolName: 'prepare_bulk_menu_import',
        success: false,
        summary: 'No valid dishes could be parsed from the provided input.',
        data: {'errors': errors},
      );
    }

    final token = AiConfirmationManager.issueToken(
      operationName: 'prepare_bulk_menu_import',
      validatedParameters: {
        'items': validItems,
        'mode': mode,
        'total_count': validItems.length,
      },
      staff: staff,
      stateSnapshot: {'current_menu_count': currentMenu.length},
    );

    return AiToolResult(
      toolName: 'prepare_bulk_menu_import',
      success: true,
      summary: 'Parsed ${validItems.length} dishes ready for import ($duplicateCount existing names matching mode "$mode").',
      confirmationToken: token,
      data: {
        'preview_type': 'bulk_menu_import',
        'total_parsed': validItems.length,
        'duplicates': duplicateCount,
        'mode': mode,
        'sample_items': validItems.take(5).toList(),
        'has_more': validItems.length > 5,
        'errors': errors,
      },
    );
  }

  // 4. PREPARE CUSTOMER CREATE
  static Future<AiToolResult> _prepareCustomerCreate(
    Map<String, dynamic> args,
    StaffMember staff,
    dynamic ref,
  ) async {
    final name = (args['name']?.toString() ?? '').trim();
    final phone = (args['phone']?.toString() ?? '').replaceAll(RegExp(r'\D'), '').trim();
    final notes = args['notes']?.toString().trim();

    if (name.isEmpty) {
      return const AiToolResult(
        toolName: 'prepare_customer_create',
        success: false,
        summary: 'Customer name is required.',
      );
    }

    if (phone.length < 10) {
      return const AiToolResult(
        toolName: 'prepare_customer_create',
        success: false,
        summary: 'A valid 10-digit phone number is required.',
      );
    }

    final List<Customer> customers = ref.read(customersProvider);
    final existingWithPhone = customers.where((c) => c.phone.replaceAll(RegExp(r'\D'), '') == phone).firstOrNull;

    final token = AiConfirmationManager.issueToken(
      operationName: 'prepare_customer_create',
      validatedParameters: {
        'name': name,
        'phone': phone,
        'notes': notes,
      },
      staff: staff,
      stateSnapshot: {'existing_id': existingWithPhone?.id},
    );

    return AiToolResult(
      toolName: 'prepare_customer_create',
      success: true,
      summary: existingWithPhone != null
          ? 'Notice: Customer "${existingWithPhone.name}" already uses phone $phone. Confirm to register new account.'
          : 'Ready to create customer "$name" with phone $phone.',
      confirmationToken: token,
      data: {
        'preview_type': 'customer_create',
        'name': name,
        'phone': phone,
        'notes': notes,
        'existing_match': existingWithPhone?.name,
      },
    );
  }

  // 5. PREPARE CUSTOMER BALANCE ENTRY (KHATA DEBIT)
  static Future<AiToolResult> _prepareCustomerBalanceEntry(
    Map<String, dynamic> args,
    StaffMember staff,
    dynamic ref,
  ) async {
    final idOrName = (args['customer_name_or_id']?.toString() ?? '').toLowerCase().trim();
    final amount = (args['amount'] as num?)?.toDouble() ?? 0.0;
    final description = (args['description']?.toString() ?? 'Khata Credit Adjustment').trim();
    final refNum = (args['reference_number']?.toString() ?? 'ADJ-${DateTime.now().millisecondsSinceEpoch % 10000}').trim();

    if (idOrName.isEmpty || amount <= 0) {
      return const AiToolResult(
        toolName: 'prepare_customer_balance_entry',
        success: false,
        summary: 'Customer and an amount greater than 0 are required.',
      );
    }

    final List<Customer> customers = ref.read(customersProvider);
    Customer? matched = customers.where((c) => c.id.toLowerCase() == idOrName || c.name.toLowerCase().contains(idOrName)).firstOrNull;

    if (matched == null) {
      return AiToolResult(
        toolName: 'prepare_customer_balance_entry',
        success: false,
        summary: 'Could not find customer matching "$idOrName".',
      );
    }

    final currentBal = ref.read(ledgerProvider.notifier).getCustomerBalance(matched.id);
    final projectedBal = currentBal + amount;

    final token = AiConfirmationManager.issueToken(
      operationName: 'prepare_customer_balance_entry',
      validatedParameters: {
        'customer_id': matched.id,
        'customer_name': matched.name,
        'amount': amount,
        'description': description,
        'reference_number': refNum,
      },
      staff: staff,
      stateSnapshot: {'current_balance': currentBal},
    );

    return AiToolResult(
      toolName: 'prepare_customer_balance_entry',
      success: true,
      summary: 'Add ₹${amount.toStringAsFixed(0)} Khata credit to ${matched.name}. (Balance: ₹${currentBal.toStringAsFixed(0)} ➔ ₹${projectedBal.toStringAsFixed(0)}).',
      confirmationToken: token,
      data: {
        'preview_type': 'customer_balance_entry',
        'customer_id': matched.id,
        'customer_name': matched.name,
        'amount': amount,
        'current_balance': currentBal,
        'projected_balance': projectedBal,
        'description': description,
      },
    );
  }

  // 6. PREPARE TABLE STATUS CHANGE
  static Future<AiToolResult> _prepareTableStatusChange(
    Map<String, dynamic> args,
    StaffMember staff,
    dynamic ref,
  ) async {
    final rawTable = (args['table_number']?.toString() ?? '').toUpperCase().trim();
    final action = (args['action']?.toString() ?? '').toLowerCase().trim();
    final guests = (args['guests'] as num?)?.toInt();

    final List<RestaurantTable> tables = ref.read(tablesProvider);
    RestaurantTable? matched;
    for (final t in tables) {
      if (t.tableNumber.toUpperCase() == rawTable ||
          t.tableNumber.toUpperCase() == 'T${rawTable.padLeft(2, '0')}' ||
          t.tableNumber.toUpperCase() == 'T${_rawNum(rawTable)}') {
        matched = t;
        break;
      }
    }

    if (matched == null) {
      return AiToolResult(
        toolName: 'prepare_table_status_change',
        success: false,
        summary: 'Table "$rawTable" not found on dining floor.',
      );
    }

    final targetGuests = guests ?? matched.capacity;
    String targetStateStr = '';
    if (action == 'occupy') {
      targetStateStr = 'Occupied with $targetGuests guests';
    } else if (action == 'vacate' || action == 'clean') {
      targetStateStr = 'Vacated & Available';
    } else {
      return const AiToolResult(
        toolName: 'prepare_table_status_change',
        success: false,
        summary: 'Invalid table action. Use "occupy", "vacate", or "clean".',
      );
    }

    final token = AiConfirmationManager.issueToken(
      operationName: 'prepare_table_status_change',
      validatedParameters: {
        'table_number': matched.tableNumber,
        'action': action,
        'guests': targetGuests,
      },
      staff: staff,
      stateSnapshot: {
        'current_state': matched.status.name,
        'current_guests': matched.guestCount,
      },
    );

    return AiToolResult(
      toolName: 'prepare_table_status_change',
      success: true,
      summary: 'Change Table ${matched.tableNumber} status from "${matched.status.name.toUpperCase()}" to "$targetStateStr".',
      confirmationToken: token,
      data: {
        'preview_type': 'table_status_change',
        'table_number': matched.tableNumber,
        'action': action,
        'guests': targetGuests,
        'old_state': matched.status.name,
      },
    );
  }

  // 7. PREPARE ORDER CHANGE
  static Future<AiToolResult> _prepareOrderChange(
    Map<String, dynamic> args,
    StaffMember staff,
    dynamic ref,
  ) async {
    final rawTable = (args['table_number']?.toString() ?? '').toUpperCase().trim();
    final itemsToAdd = (args['items_to_add'] as List?)?.cast<Map<String, dynamic>>() ?? [];
    final itemsToRemove = (args['items_to_remove'] as List?)?.cast<Map<String, dynamic>>() ?? [];

    final List<RestaurantTable> tables = ref.read(tablesProvider);
    RestaurantTable? matchedTable = tables.where((t) =>
        t.tableNumber.toUpperCase() == rawTable ||
        t.tableNumber.toUpperCase() == 'T${rawTable.padLeft(2, '0')}').firstOrNull;

    if (matchedTable == null) {
      return AiToolResult(
        toolName: 'prepare_order_change',
        success: false,
        summary: 'Table "$rawTable" not found.',
      );
    }

    final List<MenuItem> menu = ref.read(menuProvider);
    final List<({MenuItem item, int qty, String? notes})> resolvedAdds = [];

    for (final raw in itemsToAdd) {
      final name = raw['name']?.toString().toLowerCase().trim() ?? '';
      final qty = (raw['quantity'] as num?)?.toInt() ?? 1;
      final notes = raw['notes']?.toString();

      final m = menu.where((i) => i.name.toLowerCase().contains(name)).firstOrNull;
      if (m != null) {
        resolvedAdds.add((item: m, qty: qty, notes: notes));
      }
    }

    double deltaPrice = 0.0;
    for (final a in resolvedAdds) {
      deltaPrice += (a.item.price * a.qty);
    }

    final Map<String, Order> orders = ref.read(ordersProvider);
    final currentOrder = orders[matchedTable.tableNumber];
    final currentTotal = currentOrder?.grandTotal ?? 0.0;
    final projectedTotal = currentTotal + deltaPrice;

    final token = AiConfirmationManager.issueToken(
      operationName: 'prepare_order_change',
      validatedParameters: {
        'table_number': matchedTable.tableNumber,
        'items_to_add': resolvedAdds.map((a) => {
          'id': a.item.id,
          'name': a.item.name,
          'price': a.item.price,
          'qty': a.qty,
          'notes': a.notes,
        }).toList(),
        'items_to_remove': itemsToRemove,
      },
      staff: staff,
      stateSnapshot: {'order_id': currentOrder?.id, 'current_total': currentTotal},
    );

    final addSummary = resolvedAdds.map((a) => '${a.qty}x ${a.item.name}').join(', ');

    return AiToolResult(
      toolName: 'prepare_order_change',
      success: true,
      summary: 'Order for Table ${matchedTable.tableNumber}: Add $addSummary (+₹${deltaPrice.toStringAsFixed(0)}). New Total: ₹${projectedTotal.toStringAsFixed(0)}.',
      confirmationToken: token,
      data: {
        'preview_type': 'order_change',
        'table_number': matchedTable.tableNumber,
        'items_added': resolvedAdds.map((a) => {'name': a.item.name, 'qty': a.qty, 'price': a.item.price}).toList(),
        'delta_price': deltaPrice,
        'projected_total': projectedTotal,
      },
    );
  }

  // 8. PREPARE PAYMENT (KHATA SETTLEMENT)
  static Future<AiToolResult> _preparePayment(
    Map<String, dynamic> args,
    StaffMember staff,
    dynamic ref,
  ) async {
    final idOrName = (args['customer_name_or_id']?.toString() ?? '').toLowerCase().trim();
    final amount = (args['amount'] as num?)?.toDouble() ?? 0.0;
    final paymentMode = (args['payment_mode']?.toString() ?? 'cash').toUpperCase().trim();
    final refNum = args['reference_number']?.toString().trim();
    final note = args['note']?.toString().trim();

    if (idOrName.isEmpty || amount <= 0) {
      return const AiToolResult(
        toolName: 'prepare_payment',
        success: false,
        summary: 'Customer and a payment amount greater than 0 are required.',
      );
    }

    final List<Customer> customers = ref.read(customersProvider);
    Customer? matched = customers.where((c) => c.id.toLowerCase() == idOrName || c.name.toLowerCase().contains(idOrName)).firstOrNull;

    if (matched == null) {
      return AiToolResult(
        toolName: 'prepare_payment',
        success: false,
        summary: 'Could not find customer matching "$idOrName".',
      );
    }

    final currentBal = ref.read(ledgerProvider.notifier).getCustomerBalance(matched.id);
    final newBal = (currentBal - amount).clamp(0.0, double.infinity);

    final token = AiConfirmationManager.issueToken(
      operationName: 'prepare_payment',
      validatedParameters: {
        'customer_id': matched.id,
        'customer_name': matched.name,
        'amount': amount,
        'payment_mode': paymentMode,
        'reference_number': refNum,
        'note': note,
      },
      staff: staff,
      stateSnapshot: {'current_balance': currentBal},
    );

    return AiToolResult(
      toolName: 'prepare_payment',
      success: true,
      summary: 'Record $paymentMode payment of ₹${amount.toStringAsFixed(0)} from ${matched.name}. (Khata: ₹${currentBal.toStringAsFixed(0)} ➔ ₹${newBal.toStringAsFixed(0)}).',
      confirmationToken: token,
      data: {
        'preview_type': 'payment_settlement',
        'customer_id': matched.id,
        'customer_name': matched.name,
        'payment_mode': paymentMode,
        'amount': amount,
        'old_balance': currentBal,
        'new_balance': newBal,
      },
    );
  }

  // 9. PREPARE INVOICE FINALIZATION
  static Future<AiToolResult> _prepareInvoice(
    Map<String, dynamic> args,
    StaffMember staff,
    dynamic ref,
  ) async {
    final rawTable = (args['table_number']?.toString() ?? '').toUpperCase().trim();
    final cashPaid = (args['cash_paid'] as num?)?.toDouble() ?? 0.0;
    final upiPaid = (args['upi_paid'] as num?)?.toDouble() ?? 0.0;
    final creditAmount = (args['credit_amount'] as num?)?.toDouble() ?? 0.0;
    final custName = args['customer_name']?.toString().trim();
    final custPhone = args['customer_phone']?.toString().trim();

    final Map<String, Order> orders = ref.read(ordersProvider);
    final Order? activeOrder = orders[rawTable] ?? orders['T$rawTable'] ?? orders['T${rawTable.padLeft(2, '0')}'];

    if (activeOrder == null || activeOrder.items.isEmpty) {
      return AiToolResult(
        toolName: 'prepare_invoice',
        success: false,
        summary: 'No active order with items found for Table "$rawTable".',
      );
    }

    final grandTotal = activeOrder.grandTotal;
    final tenderTotal = cashPaid + upiPaid + creditAmount;

    // If no tenders specified, default to cash in full
    double effectiveCash = cashPaid;
    if (tenderTotal == 0) {
      effectiveCash = grandTotal;
    } else if ((tenderTotal - grandTotal).abs() > 0.01) {
      return AiToolResult(
        toolName: 'prepare_invoice',
        success: false,
        summary: 'Tender mismatch: Grand total is ₹${grandTotal.toStringAsFixed(0)} but sum of payments is ₹${tenderTotal.toStringAsFixed(0)}.',
      );
    }

    if (creditAmount > 0 && (custName == null || custName.isEmpty)) {
      return const AiToolResult(
        toolName: 'prepare_invoice',
        success: false,
        summary: 'Customer name is required when billing on Khata (Credit).',
      );
    }

    final token = AiConfirmationManager.issueToken(
      operationName: 'prepare_invoice',
      validatedParameters: {
        'table_number': activeOrder.tableNumber,
        'order_id': activeOrder.id,
        'subtotal': activeOrder.subtotal,
        'tax_amount': activeOrder.taxAmount,
        'grand_total': grandTotal,
        'cash_paid': effectiveCash,
        'upi_paid': upiPaid,
        'credit_amount': creditAmount,
        'customer_name': custName,
        'customer_phone': custPhone,
        'items_count': activeOrder.items.length,
      },
      staff: staff,
      stateSnapshot: {'order_id': activeOrder.id, 'grand_total': grandTotal},
    );

    return AiToolResult(
      toolName: 'prepare_invoice',
      success: true,
      summary: 'Finalize bill for Table ${activeOrder.tableNumber}: Total ₹${grandTotal.toStringAsFixed(0)} (Cash: ₹${effectiveCash.toStringAsFixed(0)}, UPI: ₹${upiPaid.toStringAsFixed(0)}, Khata: ₹${creditAmount.toStringAsFixed(0)}).',
      confirmationToken: token,
      data: {
        'preview_type': 'invoice_finalize',
        'table_number': activeOrder.tableNumber,
        'grand_total': grandTotal,
        'cash_paid': effectiveCash,
        'upi_paid': upiPaid,
        'credit_amount': creditAmount,
        'customer_name': custName,
      },
    );
  }

  // 10. PREPARE INVOICE VOID
  static Future<AiToolResult> _prepareInvoiceVoid(
    Map<String, dynamic> args,
    StaffMember staff,
    dynamic ref,
  ) async {
    final invNum = (args['invoice_number']?.toString() ?? '').trim();
    final reason = (args['reason']?.toString() ?? '').trim();

    if (invNum.isEmpty || reason.isEmpty) {
      return const AiToolResult(
        toolName: 'prepare_invoice_void',
        success: false,
        summary: 'Invoice number and an audit void reason are required.',
      );
    }

    final List<Invoice> invoices = ref.read(invoicesProvider);
    final matched = invoices.where((i) => i.invoiceNumber.toLowerCase() == invNum.toLowerCase()).firstOrNull;

    if (matched == null) {
      return AiToolResult(
        toolName: 'prepare_invoice_void',
        success: false,
        summary: 'Invoice "$invNum" not found.',
      );
    }

    if (matched.isVoided) {
      return AiToolResult(
        toolName: 'prepare_invoice_void',
        success: false,
        summary: 'Invoice "$invNum" is already voided.',
      );
    }

    final token = AiConfirmationManager.issueToken(
      operationName: 'prepare_invoice_void',
      validatedParameters: {
        'invoice_number': matched.invoiceNumber,
        'reason': reason,
        'grand_total': matched.grandTotal,
      },
      staff: staff,
      stateSnapshot: {'is_voided': false, 'grand_total': matched.grandTotal},
    );

    return AiToolResult(
      toolName: 'prepare_invoice_void',
      success: true,
      summary: 'Void Invoice ${matched.invoiceNumber} (₹${matched.grandTotal.toStringAsFixed(0)}). Reason: "$reason".',
      confirmationToken: token,
      data: {
        'preview_type': 'invoice_void',
        'invoice_number': matched.invoiceNumber,
        'grand_total': matched.grandTotal,
        'reason': reason,
      },
    );
  }

  // 11. PREPARE SETTINGS UPDATE
  static Future<AiToolResult> _prepareSettingsUpdate(
    Map<String, dynamic> args,
    StaffMember staff,
    dynamic ref,
  ) async {
    final RestaurantSettings currentSettings = ref.read(settingsProvider);
    final diff = <String, dynamic>{};

    if (args.containsKey('restaurant_name') && args['restaurant_name'] != currentSettings.restaurantName) {
      diff['restaurant_name'] = {'old': currentSettings.restaurantName, 'new': args['restaurant_name']};
    }
    if (args.containsKey('tagline') && args['tagline'] != currentSettings.tagline) {
      diff['tagline'] = {'old': currentSettings.tagline, 'new': args['tagline']};
    }
    if (args.containsKey('address') && args['address'] != currentSettings.address) {
      diff['address'] = {'old': currentSettings.address, 'new': args['address']};
    }
    if (args.containsKey('phone') && args['phone'] != currentSettings.phone) {
      diff['phone'] = {'old': currentSettings.phone, 'new': args['phone']};
    }
    if (args.containsKey('receipt_footer_note') && args['receipt_footer_note'] != currentSettings.receiptFooterNote) {
      diff['receipt_footer_note'] = {'old': currentSettings.receiptFooterNote, 'new': args['receipt_footer_note']};
    }

    if (diff.isEmpty) {
      return const AiToolResult(
        toolName: 'prepare_settings_update',
        success: false,
        summary: 'No settings changes detected.',
      );
    }

    final token = AiConfirmationManager.issueToken(
      operationName: 'prepare_settings_update',
      validatedParameters: {'diff': diff, 'changes': args},
      staff: staff,
      stateSnapshot: {'restaurant_name': currentSettings.restaurantName},
    );

    return AiToolResult(
      toolName: 'prepare_settings_update',
      success: true,
      summary: 'Update restaurant settings: ${diff.keys.join(", ")}.',
      confirmationToken: token,
      data: {
        'preview_type': 'settings_update',
        'diff': diff,
      },
    );
  }

  // ==========================================
  // CONFIRMED ACTION EXECUTION
  // ==========================================

  /// Consumes the verified token and executes the actual database / Riverpod mutation.
  static Future<AiToolResult> executeConfirmedAction({
    required String confirmationToken,
    required StaffMember staff,
    required dynamic ref,
    String? userPrompt,
  }) async {
    // 1. Peek token to determine operationName
    // We determine expected operation or consume safely
    // Let's consume token
    final result = _consumeAnyToken(confirmationToken, staff);
    if (!result.isValid || result.token == null) {
      _logAudit(
        staff: staff,
        toolName: 'execute_confirmed_action',
        arguments: {'token': confirmationToken},
        success: false,
        errorMessage: result.error,
        userPrompt: userPrompt,
      );
      return AiToolResult(
        toolName: 'execute_confirmed_action',
        success: false,
        summary: result.error ?? 'Invalid confirmation token.',
        errorMessage: result.error,
      );
    }

    final token = result.token!;
    final op = token.operationName;
    final params = token.validatedParameters;

    try {
      AiToolResult execResult;
      switch (op) {
        case 'prepare_menu_item_create':
          execResult = await _executeMenuItemCreate(params, ref);
          break;
        case 'prepare_menu_item_update':
          execResult = await _executeMenuItemUpdate(params, ref);
          break;
        case 'prepare_bulk_menu_import':
          execResult = await _executeBulkMenuImport(params, staff, ref);
          break;
        case 'prepare_customer_create':
          execResult = await _executeCustomerCreate(params, ref);
          break;
        case 'prepare_customer_balance_entry':
          execResult = await _executeCustomerBalanceEntry(params, ref);
          break;
        case 'prepare_table_status_change':
          execResult = await _executeTableStatusChange(params, ref);
          break;
        case 'prepare_order_change':
          execResult = await _executeOrderChange(params, ref);
          break;
        case 'prepare_payment':
          execResult = await _executePayment(params, ref);
          break;
        case 'prepare_invoice':
          execResult = await _executeInvoice(params, ref);
          break;
        case 'prepare_invoice_void':
          execResult = await _executeInvoiceVoid(params, ref);
          break;
        case 'prepare_settings_update':
          execResult = await _executeSettingsUpdate(params, ref);
          break;
        default:
          execResult = AiToolResult(
            toolName: op,
            success: false,
            summary: 'Unsupported confirmed operation: $op.',
          );
      }

      _logAudit(
        staff: staff,
        toolName: op,
        arguments: params,
        success: execResult.success,
        errorMessage: execResult.errorMessage,
        userPrompt: userPrompt,
        confirmationToken: confirmationToken,
      );

      return execResult;
    } catch (e) {
      _logAudit(
        staff: staff,
        toolName: op,
        arguments: params,
        success: false,
        errorMessage: e.toString(),
        userPrompt: userPrompt,
        confirmationToken: confirmationToken,
      );
      return AiToolResult(
        toolName: op,
        success: false,
        summary: 'Error executing confirmed action: $e',
        errorMessage: e.toString(),
      );
    }
  }

  // --- PRIVATE EXECUTORS ---

  static Future<AiToolResult> _executeMenuItemCreate(Map<String, dynamic> p, dynamic ref) async {
    final newItem = MenuItem(
      id: _uuid.v4(),
      name: p['name'] as String,
      category: p['category'] as String,
      price: (p['price'] as num).toDouble(),
      isVeg: p['is_veg'] as bool? ?? true,
      isPackaged: p['is_packaged'] as bool? ?? false,
      stockQuantity: (p['stock_quantity'] as num?)?.toInt() ?? 0,
      sku: p['sku'] as String? ?? 'SKU-${DateTime.now().millisecondsSinceEpoch % 10000}',
      description: p['description'] as String?,
      isAvailable: true,
    );

    ref.read(menuProvider.notifier).addItem(newItem);

    return AiToolResult(
      toolName: 'execute_menu_item_create',
      success: true,
      summary: 'Added "${newItem.name}" (₹${newItem.price.toStringAsFixed(0)}) under ${newItem.category} and saved to Supabase.',
      data: {'item_id': newItem.id, 'name': newItem.name, 'price': newItem.price},
    );
  }

  static Future<AiToolResult> _executeMenuItemUpdate(Map<String, dynamic> p, dynamic ref) async {
    final itemId = p['item_id'] as String;
    final List<MenuItem> menu = ref.read(menuProvider);
    final item = menu.where((m) => m.id == itemId).firstOrNull;

    if (item == null) {
      return const AiToolResult(
        toolName: 'execute_menu_item_update',
        success: false,
        summary: 'Target dish was removed before confirmation could execute.',
      );
    }

    final updated = item.copyWith(
      price: (p['new_price'] as num).toDouble(),
      isAvailable: p['is_available'] as bool,
      category: p['new_category'] as String,
      stockQuantity: (p['stock_quantity'] as num?)?.toInt(),
    );

    ref.read(menuProvider.notifier).updateItem(updated);

    return AiToolResult(
      toolName: 'execute_menu_item_update',
      success: true,
      summary: 'Updated "${updated.name}" successfully in the cloud catalog.',
      data: {'item_id': updated.id, 'name': updated.name, 'diff': p['diff']},
    );
  }

  static Future<AiToolResult> _executeBulkMenuImport(Map<String, dynamic> p, StaffMember staff, dynamic ref) async {
    final items = (p['items'] as List).cast<Map<String, dynamic>>();
    final mode = p['mode'] as String? ?? 'upsert';

    int addedCount = 0;
    for (final it in items) {
      final name = it['name'] as String;
      final category = it['category'] as String;
      final price = (it['price'] as num).toDouble();
      final isVeg = it['is_veg'] as bool? ?? true;
      final sku = it['sku'] as String? ?? 'BULK-${DateTime.now().millisecondsSinceEpoch % 10000}';

      final newItem = MenuItem(
        id: _uuid.v4(),
        name: name,
        category: category,
        price: price,
        isVeg: isVeg,
        isAvailable: true,
        sku: sku,
      );
      ref.read(menuProvider.notifier).addItem(newItem);
      addedCount++;
    }

    // Also trigger cloud batch RPC if connected
    if (SupabaseService.isInitialized) {
      SupabaseService.importMenuItemsBatch(
        items: items,
        mode: mode,
        staffId: staff.id,
      );
    }

    return AiToolResult(
      toolName: 'execute_bulk_menu_import',
      success: true,
      summary: 'Successfully imported $addedCount dishes into Mehta Restaurant catalog.',
      data: {'imported_count': addedCount, 'mode': mode},
    );
  }

  static Future<AiToolResult> _executeCustomerCreate(Map<String, dynamic> p, dynamic ref) async {
    final customer = ref.read(customersProvider.notifier).addCustomer(
      name: p['name'] as String,
      phone: p['phone'] as String,
    );

    return AiToolResult(
      toolName: 'execute_customer_create',
      success: true,
      summary: 'Customer "${customer.name}" (Phone: ${customer.phone}) registered and synced.',
      data: {'customer_id': customer.id, 'name': customer.name, 'phone': customer.phone},
    );
  }

  static Future<AiToolResult> _executeCustomerBalanceEntry(Map<String, dynamic> p, dynamic ref) async {
    final customerId = p['customer_id'] as String;
    final amount = (p['amount'] as num).toDouble();
    final description = p['description'] as String;
    final refNum = p['reference_number'] as String;

    ref.read(ledgerProvider.notifier).addPendingBill(
      customerId: customerId,
      amount: amount,
      referenceType: 'KHATA',
      referenceNumber: refNum,
      description: description,
    );

    final newBal = ref.read(ledgerProvider.notifier).getCustomerBalance(customerId);

    return AiToolResult(
      toolName: 'execute_customer_balance_entry',
      success: true,
      summary: 'Added ₹${amount.toStringAsFixed(0)} Khata credit for ${p['customer_name']}. New balance: ₹${newBal.toStringAsFixed(0)}.',
      data: {'customer_id': customerId, 'amount': amount, 'new_balance': newBal},
    );
  }

  static Future<AiToolResult> _executeTableStatusChange(Map<String, dynamic> p, dynamic ref) async {
    final tableNum = p['table_number'] as String;
    final action = p['action'] as String;
    final guests = (p['guests'] as num?)?.toInt() ?? 2;

    if (action == 'occupy') {
      ref.read(tablesProvider.notifier).occupyTable(tableNum, guests, _uuid.v4());
      return AiToolResult(
        toolName: 'execute_table_status_change',
        success: true,
        summary: 'Table $tableNum is now Occupied with $guests guests.',
        data: {'table_number': tableNum, 'status': 'occupied', 'guests': guests},
      );
    } else {
      ref.read(tablesProvider.notifier).releaseTable(tableNum);
      return AiToolResult(
        toolName: 'execute_table_status_change',
        success: true,
        summary: 'Table $tableNum is now Cleaned, Vacated & Available.',
        data: {'table_number': tableNum, 'status': 'available'},
      );
    }
  }

  static Future<AiToolResult> _executeOrderChange(Map<String, dynamic> p, dynamic ref) async {
    final tableNum = p['table_number'] as String;
    final adds = (p['items_to_add'] as List).cast<Map<String, dynamic>>();

    ref.read(ordersProvider.notifier).initializeOrder(tableNum);

    final List<MenuItem> menu = ref.read(menuProvider);
    for (final a in adds) {
      final item = menu.where((m) => m.id == a['id'] || m.name == a['name']).firstOrNull;
      if (item != null) {
        ref.read(ordersProvider.notifier).addItemToOrder(
          tableNum,
          item,
          quantity: (a['qty'] as num).toInt(),
          notes: a['notes'] as String?,
        );
      }
    }

    final activeOrder = ref.read(ordersProvider)[tableNum];
    if (activeOrder != null) {
      ref.read(kitchenTicketsProvider.notifier).sendKot(order: activeOrder);
    }

    return AiToolResult(
      toolName: 'execute_order_change',
      success: true,
      summary: 'Order updated for Table $tableNum. KOT sent to kitchen (Total: ₹${activeOrder?.grandTotal.toStringAsFixed(0) ?? "0"}).',
      data: {'table_number': tableNum, 'order_id': activeOrder?.id, 'grand_total': activeOrder?.grandTotal},
    );
  }

  static Future<AiToolResult> _executePayment(Map<String, dynamic> p, dynamic ref) async {
    final customerId = p['customer_id'] as String;
    final amount = (p['amount'] as num).toDouble();
    final paymentMode = p['payment_mode'] as String;
    final note = p['note'] as String?;
    final refNum = p['reference_number'] as String?;

    ref.read(ledgerProvider.notifier).recordPayment(
      customerId: customerId,
      amount: amount,
      paymentMode: paymentMode,
      referenceNumber: refNum,
      note: note ?? 'AI Assistant confirmed settlement',
    );

    final newBal = ref.read(ledgerProvider.notifier).getCustomerBalance(customerId);

    return AiToolResult(
      toolName: 'execute_payment',
      success: true,
      summary: 'Recorded $paymentMode payment of ₹${amount.toStringAsFixed(0)} for ${p['customer_name']}. Remaining Khata: ₹${newBal.toStringAsFixed(0)}.',
      data: {'customer_id': customerId, 'amount': amount, 'new_balance': newBal},
    );
  }

  static Future<AiToolResult> _executeInvoice(Map<String, dynamic> p, dynamic ref) async {
    final tableNum = p['table_number'] as String;
    final Map<String, Order> orders = ref.read(ordersProvider);
    final activeOrder = orders[tableNum];

    final invId = _uuid.v4();
    final invNum = 'MR-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}';

    final invoice = Invoice(
      id: invId,
      invoiceNumber: invNum,
      tableNumber: tableNum,
      items: activeOrder?.items ?? [],
      subtotal: (p['subtotal'] as num).toDouble(),
      taxAmount: (p['tax_amount'] as num).toDouble(),
      grandTotal: (p['grand_total'] as num).toDouble(),
      cashPaid: (p['cash_paid'] as num).toDouble(),
      upiPaid: (p['upi_paid'] as num).toDouble(),
      creditAmount: (p['credit_amount'] as num).toDouble(),
      customerName: p['customer_name'] as String?,
      customerPhone: p['customer_phone'] as String?,
      issuedAt: DateTime.now(),
    );

    // Save invoice
    ref.read(invoicesProvider.notifier).addInvoice(invoice);

    // If Khata credit, also record to ledger
    if (invoice.creditAmount > 0 && invoice.customerName != null) {
      final List<Customer> customers = ref.read(customersProvider);
      final Customer? existing = customers.where((cu) => cu.name.toLowerCase() == invoice.customerName!.toLowerCase()).firstOrNull;
      final Customer customer = existing ?? ref.read(customersProvider.notifier).addCustomer(
        name: invoice.customerName!,
        phone: invoice.customerPhone ?? '9876543210',
      );
      ref.read(ledgerProvider.notifier).addPendingBill(
        customerId: customer.id,
        amount: invoice.creditAmount,
        referenceNumber: invNum,
        description: 'Billed on Table $tableNum',
      );
    }

    // Release table
    ref.read(tablesProvider.notifier).releaseTable(tableNum);

    return AiToolResult(
      toolName: 'execute_invoice',
      success: true,
      summary: 'Invoice $invNum generated for Table $tableNum (Total: ₹${invoice.grandTotal.toStringAsFixed(0)}). Table vacated.',
      data: {'invoice_number': invNum, 'grand_total': invoice.grandTotal},
    );
  }

  static Future<AiToolResult> _executeInvoiceVoid(Map<String, dynamic> p, dynamic ref) async {
    final invNum = p['invoice_number'] as String;
    final reason = p['reason'] as String;

    final voidRes = await ref.read(invoicesProvider.notifier).voidInvoice(invNum, reason);

    return AiToolResult(
      toolName: 'execute_invoice_void',
      success: voidRes.success,
      summary: voidRes.message,
      data: {'invoice_number': invNum, 'reason': reason},
    );
  }

  static Future<AiToolResult> _executeSettingsUpdate(Map<String, dynamic> p, dynamic ref) async {
    final changes = p['changes'] as Map<String, dynamic>? ?? {};

    ref.read(settingsProvider.notifier).updateSettings(
      restaurantName: changes['restaurant_name'] as String?,
      tagline: changes['tagline'] as String?,
      address: changes['address'] as String?,
      phone: changes['phone'] as String?,
      receiptFooterNote: changes['receipt_footer_note'] as String?,
    );

    return const AiToolResult(
      toolName: 'execute_settings_update',
      success: true,
      summary: 'Restaurant profile settings updated and saved.',
    );
  }

  // --- TOKEN CONSUMPTION HELPER ---

  static ({bool isValid, String? error, AiActionConfirmationToken? token}) _consumeAnyToken(
    String tokenStr,
    StaffMember staff,
  ) {
    return AiConfirmationManager.consumeToken(
      tokenString: tokenStr,
      staff: staff,
    );
  }

  static void _logAudit({
    required StaffMember staff,
    required String toolName,
    required Map<String, dynamic> arguments,
    required bool success,
    String? errorMessage,
    String? userPrompt,
    String? confirmationToken,
  }) {
    final entry = AiAuditLogEntry(
      id: _uuid.v4(),
      timestamp: DateTime.now(),
      staffId: staff.id,
      staffName: staff.name,
      staffRole: staff.role,
      toolName: toolName,
      arguments: arguments,
      success: success,
      errorMessage: errorMessage,
      userPrompt: userPrompt,
      confirmationToken: confirmationToken,
    );

    _recentAuditLogs.insert(0, entry);
    if (_recentAuditLogs.length > 100) {
      _recentAuditLogs.removeLast();
    }

    // Persist to Supabase in background
    if (SupabaseService.isInitialized) {
      SupabaseService.recordAiAuditLog(entry);
    }
  }

  static String _rawNum(String input) {
    return input.replaceAll(RegExp(r'\D'), '');
  }
}
