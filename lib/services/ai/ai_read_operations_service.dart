import 'package:intl/intl.dart';
import '../../models/models.dart';
import '../../providers/restaurant_provider.dart';
import 'ai_models.dart';
import 'ai_permission_guard.dart';
import 'ai_tool_registry.dart';

class AiReadOperationsService {
  /// Executes a registered read-only tool with caller role validation
  static Future<AiToolResult> executeReadTool({
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
    final perm = AiPermissionGuard.checkPermission(staff: staff, tool: tool, arguments: arguments);
    if (!perm.isAllowed) {
      return AiToolResult(
        toolName: toolName,
        success: false,
        summary: perm.rejectionReason ?? 'Permission Denied.',
        errorMessage: perm.rejectionReason,
      );
    }

    switch (toolName) {
      case 'search_menu':
        return _searchMenu(arguments, ref);
      case 'list_categories':
        return _listCategories(ref);
      case 'search_customers':
        return _searchCustomers(arguments, ref);
      case 'get_table_status':
        return _getTableStatus(arguments, ref);
      case 'get_active_orders':
        return _getActiveOrders(arguments, ref);
      case 'get_kitchen_tickets':
        return _getKitchenTickets(arguments, ref);
      case 'get_invoice_summary':
        return _getInvoiceSummary(arguments, ref);
      case 'get_sales_report':
        return _getSalesReport(arguments, ref);
      case 'get_customer_balances':
        return _getCustomerBalances(arguments, ref);
      case 'get_restaurant_settings':
        return _getRestaurantSettings(ref);
      case 'get_item_sales_performance':
        return _getItemSalesPerformance(arguments, ref);
      default:
        return AiToolResult(
          toolName: toolName,
          success: false,
          summary: 'Tool "$toolName" is not a read-only tool.',
        );
    }
  }

  // --- 1. SEARCH MENU ---
  static AiToolResult _searchMenu(Map<String, dynamic> args, dynamic ref) {
    final List<MenuItem> menu = ref.read(menuProvider);
    final query = (args['query']?.toString() ?? '').toLowerCase().trim();
    final category = args['category']?.toString().toLowerCase().trim();
    final isVeg = args['is_veg'] as bool?;
    final availableOnly = args['available_only'] as bool? ?? false;

    var matches = menu.where((item) {
      if (query.isNotEmpty && !item.name.toLowerCase().contains(query) && !(item.description?.toLowerCase().contains(query) ?? false)) {
        return false;
      }
      if (category != null && category.isNotEmpty && item.category.toLowerCase() != category) {
        return false;
      }
      if (isVeg != null && item.isVeg != isVeg) {
        return false;
      }
      if (availableOnly && !item.isAvailable) {
        return false;
      }
      return true;
    }).toList();

    if (matches.isEmpty) {
      return AiToolResult(
        toolName: 'search_menu',
        success: true,
        summary: query.isNotEmpty
            ? 'No dishes found matching "$query".'
            : 'No menu items match the specified filters.',
        data: {'count': 0, 'items': []},
      );
    }

    final itemsList = matches.take(15).map((it) => {
      'id': it.id,
      'name': it.name,
      'category': it.category,
      'price': it.price,
      'is_veg': it.isVeg,
      'is_available': it.isAvailable,
      'stock': it.isPackaged ? it.stockQuantity : null,
    }).toList();

    final buffer = StringBuffer('Found ${matches.length} matching menu items:\n');
    for (final it in matches.take(8)) {
      final vegIcon = it.isVeg ? '🟢 Veg' : '🔴 Non-Veg';
      final avail = it.isAvailable ? 'In Stock' : '❌ Out of Stock';
      buffer.writeln('• ${it.name} (₹${it.price.toStringAsFixed(0)}) — ${it.category} • $vegIcon • $avail');
    }
    if (matches.length > 8) {
      buffer.writeln('... and ${matches.length - 8} more dishes.');
    }

    return AiToolResult(
      toolName: 'search_menu',
      success: true,
      summary: buffer.toString().trim(),
      data: {'count': matches.length, 'items': itemsList},
    );
  }

  // --- 2. LIST CATEGORIES ---
  static AiToolResult _listCategories(dynamic ref) {
    final List<MenuItem> menu = ref.read(menuProvider);
    final categories = menu.map((m) => m.category).toSet().toList()..sort();

    final counts = <String, int>{};
    for (final item in menu) {
      counts[item.category] = (counts[item.category] ?? 0) + 1;
    }

    final buffer = StringBuffer('Menu Categories (${categories.length}):\n');
    for (final cat in categories) {
      buffer.writeln('• $cat (${counts[cat]} items)');
    }

    return AiToolResult(
      toolName: 'list_categories',
      success: true,
      summary: buffer.toString().trim(),
      data: {'categories': categories, 'item_counts': counts},
    );
  }

  // --- 3. SEARCH CUSTOMERS ---
  static AiToolResult _searchCustomers(Map<String, dynamic> args, dynamic ref) {
    final List<Customer> customers = ref.read(customersProvider);
    final query = (args['query']?.toString() ?? '').toLowerCase().trim();
    final phone = (args['phone']?.toString() ?? '').replaceAll(RegExp(r'\D'), '');

    final matches = customers.where((c) {
      if (query.isNotEmpty && !c.name.toLowerCase().contains(query)) return false;
      if (phone.isNotEmpty && !c.phone.contains(phone)) return false;
      return true;
    }).toList();

    if (matches.isEmpty) {
      return const AiToolResult(
        toolName: 'search_customers',
        success: true,
        summary: 'No customers found matching the search criteria.',
        data: {'count': 0, 'customers': []},
      );
    }

    final LedgerNotifier ledger = ref.read(ledgerProvider.notifier);
    final buffer = StringBuffer('Found ${matches.length} customer records:\n');
    for (final c in matches.take(6)) {
      final balance = ledger.getCustomerBalance(c.id);
      buffer.writeln('• ${c.name} (${c.phone}) — Outstanding Balance: ₹${balance.toStringAsFixed(2)}');
    }

    return AiToolResult(
      toolName: 'search_customers',
      success: true,
      summary: buffer.toString().trim(),
      data: {
        'count': matches.length,
        'customers': matches.map((c) => {
          'id': c.id,
          'name': c.name,
          'phone': c.phone,
          'balance': ledger.getCustomerBalance(c.id),
        }).toList(),
      },
    );
  }

  // --- 4. GET TABLE STATUS ---
  static AiToolResult _getTableStatus(Map<String, dynamic> args, dynamic ref) {
    final List<RestaurantTable> tables = ref.read(tablesProvider);
    final filterNum = args['table_number']?.toString().toUpperCase().trim();

    if (filterNum != null && filterNum.isNotEmpty) {
      final match = tables.where((t) => t.tableNumber.toUpperCase() == filterNum).firstOrNull;
      if (match == null) {
        return AiToolResult(
          toolName: 'get_table_status',
          success: false,
          summary: 'Table "$filterNum" does not exist in floor plan.',
        );
      }

      final statusStr = match.status.name.toUpperCase();
      return AiToolResult(
        toolName: 'get_table_status',
        success: true,
        summary: 'Table ${match.tableNumber} (${match.name}) is currently $statusStr. '
            'Capacity: ${match.capacity} guests | Current guests: ${match.guestCount}.',
        data: {
          'table_number': match.tableNumber,
          'name': match.name,
          'section': match.section,
          'status': match.status.name,
          'capacity': match.capacity,
          'guest_count': match.guestCount,
          'active_order_id': match.activeOrderId,
        },
      );
    }

    final total = tables.length;
    final occupied = tables.where((t) => t.status == TableState.occupied).length;
    final available = tables.where((t) => t.status == TableState.available).length;
    final billing = tables.where((t) => t.status == TableState.billing).length;
    final cleaning = tables.where((t) => t.status == TableState.cleaning).length;

    final buffer = StringBuffer('Dining Floor Status ($total Tables Total):\n');
    buffer.writeln('• Occupied: $occupied tables');
    buffer.writeln('• Available: $available tables');
    if (billing > 0) buffer.writeln('• Bill Requested: $billing tables');
    if (cleaning > 0) buffer.writeln('• Cleaning: $cleaning tables');

    return AiToolResult(
      toolName: 'get_table_status',
      success: true,
      summary: buffer.toString().trim(),
      data: {
        'total': total,
        'occupied': occupied,
        'available': available,
        'billing': billing,
        'cleaning': cleaning,
      },
    );
  }

  // --- 5. GET ACTIVE ORDERS ---
  static AiToolResult _getActiveOrders(Map<String, dynamic> args, dynamic ref) {
    final Map<String, Order> orders = ref.read(ordersProvider);
    final target = args['table_number']?.toString().trim();

    if (target != null && target.isNotEmpty) {
      final order = orders[target];
      if (order == null || order.items.isEmpty) {
        return AiToolResult(
          toolName: 'get_active_orders',
          success: true,
          summary: 'No active order currently open for "$target".',
          data: {'table': target, 'has_order': false},
        );
      }

      final buffer = StringBuffer('Active Order for $target (${order.items.length} items):\n');
      for (final it in order.items) {
        buffer.writeln('• ${it.name} x ${it.quantity} = ₹${(it.unitPrice * it.quantity).toStringAsFixed(0)}');
      }
      buffer.writeln('Subtotal: ₹${order.subtotal.toStringAsFixed(2)} | Grand Total: ₹${order.grandTotal.toStringAsFixed(2)}');

      return AiToolResult(
        toolName: 'get_active_orders',
        success: true,
        summary: buffer.toString().trim(),
        data: {
          'table': target,
          'subtotal': order.subtotal,
          'grand_total': order.grandTotal,
          'items': order.items.map((i) => {'name': i.name, 'quantity': i.quantity, 'price': i.unitPrice}).toList(),
        },
      );
    }

    final activeList = orders.values.where((o) => o.items.isNotEmpty).toList();
    if (activeList.isEmpty) {
      return const AiToolResult(
        toolName: 'get_active_orders',
        success: true,
        summary: 'There are no active orders currently open.',
        data: {'count': 0, 'orders': []},
      );
    }

    final buffer = StringBuffer('Currently ${activeList.length} Active Orders:\n');
    for (final o in activeList) {
      buffer.writeln('• ${o.tableNumber}: ${o.items.length} items (₹${o.grandTotal.toStringAsFixed(0)})');
    }

    return AiToolResult(
      toolName: 'get_active_orders',
      success: true,
      summary: buffer.toString().trim(),
      data: {
        'count': activeList.length,
        'orders': activeList.map((o) => {'table': o.tableNumber, 'total': o.grandTotal, 'items_count': o.items.length}).toList(),
      },
    );
  }

  // --- 6. GET KITCHEN TICKETS ---
  static AiToolResult _getKitchenTickets(Map<String, dynamic> args, dynamic ref) {
    final List<KitchenTicket> tickets = ref.read(kitchenTicketsProvider);
    final statusFilter = args['status']?.toString();

    var filtered = tickets;
    if (statusFilter != null && statusFilter.isNotEmpty) {
      filtered = tickets.where((t) => t.status.name == statusFilter).toList();
    }

    if (filtered.isEmpty) {
      return const AiToolResult(
        toolName: 'get_kitchen_tickets',
        success: true,
        summary: 'No active kitchen tickets found.',
        data: {'count': 0, 'tickets': []},
      );
    }

    final buffer = StringBuffer('Active Kitchen Tickets (${filtered.length}):\n');
    for (final t in filtered.take(6)) {
      final rush = t.isRush ? ' 🔥 RUSH' : '';
      buffer.writeln('• ${t.kotNumber} for ${t.tableNumber} [${t.status.name.toUpperCase()}]$rush — ${t.items.length} items');
    }

    return AiToolResult(
      toolName: 'get_kitchen_tickets',
      success: true,
      summary: buffer.toString().trim(),
      data: {'count': filtered.length, 'tickets': filtered.map((t) => {'id': t.id, 'kot': t.kotNumber, 'table': t.tableNumber, 'status': t.status.name, 'rush': t.isRush}).toList()},
    );
  }

  // --- 7. GET INVOICE SUMMARY ---
  static AiToolResult _getInvoiceSummary(Map<String, dynamic> args, dynamic ref) {
    final List<Invoice> invoices = ref.read(invoicesProvider);
    final invNum = args['invoice_number']?.toString().toUpperCase().trim();

    if (invNum != null && invNum.isNotEmpty) {
      final inv = invoices.where((i) => i.invoiceNumber.toUpperCase() == invNum).firstOrNull;
      if (inv == null) {
        return AiToolResult(
          toolName: 'get_invoice_summary',
          success: false,
          summary: 'Invoice "$invNum" not found.',
        );
      }

      final voidStatus = inv.isVoided ? ' (VOIDED: ${inv.voidReason ?? 'No reason'})' : '';
      return AiToolResult(
        toolName: 'get_invoice_summary',
        success: true,
        summary: 'Invoice ${inv.invoiceNumber}$voidStatus\n'
            'Table: ${inv.tableNumber} | Date: ${DateFormat('d MMM y, hh:mm a').format(inv.issuedAt)}\n'
            'Total: ₹${inv.grandTotal.toStringAsFixed(2)} '
            '(Cash: ₹${inv.cashPaid.toStringAsFixed(0)}, UPI: ₹${inv.upiPaid.toStringAsFixed(0)}, Credit: ₹${inv.creditAmount.toStringAsFixed(0)})\n'
            'Customer: ${inv.customerName ?? 'Walk-in'}',
        data: {
          'invoice_number': inv.invoiceNumber,
          'grand_total': inv.grandTotal,
          'cash_paid': inv.cashPaid,
          'upi_paid': inv.upiPaid,
          'credit_amount': inv.creditAmount,
          'is_voided': inv.isVoided,
        },
      );
    }

    final recent = invoices.take(5).toList();
    final buffer = StringBuffer('Recent Bills (${invoices.length} Total Issued):\n');
    for (final i in recent) {
      final v = i.isVoided ? ' [VOID]' : '';
      buffer.writeln('• ${i.invoiceNumber}$v: ₹${i.grandTotal.toStringAsFixed(0)} (${i.tableNumber}) — ${DateFormat('d MMM, hh:mm a').format(i.issuedAt)}');
    }

    return AiToolResult(
      toolName: 'get_invoice_summary',
      success: true,
      summary: buffer.toString().trim(),
      data: {'total_count': invoices.length},
    );
  }

  // --- 8. GET SALES REPORT ---
  static AiToolResult _getSalesReport(Map<String, dynamic> args, dynamic ref) {
    final List<Invoice> invoices = ref.read(invoicesProvider);
    final period = args['period']?.toString() ?? 'today';

    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);
    final yesterdayStart = todayStart.subtract(const Duration(days: 1));

    List<Invoice> filtered = [];
    if (period == 'today') {
      filtered = invoices.where((i) => i.issuedAt.isAfter(todayStart)).toList();
    } else if (period == 'yesterday') {
      filtered = invoices.where((i) => i.issuedAt.isAfter(yesterdayStart) && i.issuedAt.isBefore(todayStart)).toList();
    } else if (period == 'this_week') {
      final weekStart = todayStart.subtract(Duration(days: now.weekday - 1));
      filtered = invoices.where((i) => i.issuedAt.isAfter(weekStart)).toList();
    } else {
      filtered = invoices;
    }

    double totalSales = 0.0;
    double cashTotal = 0.0;
    double upiTotal = 0.0;
    double creditTotal = 0.0;
    int validCount = 0;
    int voidedCount = 0;

    for (final inv in filtered) {
      if (inv.isVoided) {
        voidedCount++;
        continue;
      }
      totalSales += inv.grandTotal;
      cashTotal += inv.cashPaid;
      upiTotal += inv.upiPaid;
      creditTotal += inv.creditAmount;
      validCount++;
    }

    final avgBill = validCount > 0 ? (totalSales / validCount) : 0.0;

    final buffer = StringBuffer('Authoritative Sales Report (${period.replaceAll('_', ' ').toUpperCase()}):\n');
    buffer.writeln('• Net Sales: ₹${NumberFormat('#,##0.00').format(totalSales)}');
    buffer.writeln('• Cash Collected: ₹${NumberFormat('#,##0.00').format(cashTotal)}');
    buffer.writeln('• UPI Collected: ₹${NumberFormat('#,##0.00').format(upiTotal)}');
    buffer.writeln('• Khata Credit Issued: ₹${NumberFormat('#,##0.00').format(creditTotal)}');
    buffer.writeln('• Finalized Bills: $validCount bills (Avg: ₹${avgBill.toStringAsFixed(0)})');
    if (voidedCount > 0) {
      buffer.writeln('• Voided Bills: $voidedCount bills (Excluded from sales)');
    }

    return AiToolResult(
      toolName: 'get_sales_report',
      success: true,
      summary: buffer.toString().trim(),
      data: {
        'period': period,
        'net_sales': totalSales,
        'cash_collected': cashTotal,
        'upi_collected': upiTotal,
        'credit_issued': creditTotal,
        'bill_count': validCount,
        'voided_count': voidedCount,
        'avg_bill_value': avgBill,
      },
    );
  }

  // --- 9. GET CUSTOMER BALANCES ---
  static AiToolResult _getCustomerBalances(Map<String, dynamic> args, dynamic ref) {
    final List<Customer> customers = ref.read(customersProvider);
    final LedgerNotifier ledger = ref.read(ledgerProvider.notifier);
    final minBalance = (args['min_balance'] as num?)?.toDouble() ?? 0.01;

    final debtors = <Map<String, dynamic>>[];
    double totalOutstanding = 0.0;

    for (final c in customers) {
      final bal = ledger.getCustomerBalance(c.id);
      if (bal >= minBalance) {
        debtors.add({'id': c.id, 'name': c.name, 'phone': c.phone, 'balance': bal});
        totalOutstanding += bal;
      }
    }

    debtors.sort((a, b) => (b['balance'] as double).compareTo(a['balance'] as double));

    if (debtors.isEmpty) {
      return const AiToolResult(
        toolName: 'get_customer_balances',
        success: true,
        summary: 'All customer accounts are currently fully settled! No outstanding Khata balances.',
        data: {'total_outstanding': 0.0, 'debtors': []},
      );
    }

    final buffer = StringBuffer('Customer Khata Balances (Total Outstanding: ₹${NumberFormat('#,##0.00').format(totalOutstanding)} across ${debtors.length} customers):\n');
    for (final d in debtors.take(6)) {
      buffer.writeln('• ${d['name']} (${d['phone']}): ₹${NumberFormat('#,##0.00').format(d['balance'])}');
    }
    if (debtors.length > 6) {
      buffer.writeln('... and ${debtors.length - 6} more customers with pending balance.');
    }

    return AiToolResult(
      toolName: 'get_customer_balances',
      success: true,
      summary: buffer.toString().trim(),
      data: {'total_outstanding': totalOutstanding, 'debtors': debtors},
    );
  }

  // --- 10. GET RESTAURANT SETTINGS ---
  static AiToolResult _getRestaurantSettings(dynamic ref) {
    final RestaurantSettings s = ref.read(settingsProvider);
    return AiToolResult(
      toolName: 'get_restaurant_settings',
      success: true,
      summary: 'Restaurant Profile:\n'
          '• Name: ${s.restaurantName}\n'
          '• Tagline: ${s.tagline}\n'
          '• Phone: ${s.phone}\n'
          '• Address: ${s.address}\n'
          '• UPI ID: ${s.upiId} (${s.upiPayeeName})\n'
          '• GST Status: ${s.gstEnabled ? 'Enabled (${s.taxRate}%)' : 'Disabled'}',
      data: {
        'restaurant_name': s.restaurantName,
        'tagline': s.tagline,
        'phone': s.phone,
        'address': s.address,
        'upi_id': s.upiId,
        'gst_enabled': s.gstEnabled,
        'tax_rate': s.taxRate,
      },
    );
  }

  // --- 11. GET ITEM SALES PERFORMANCE ---
  static AiToolResult _getItemSalesPerformance(Map<String, dynamic> args, dynamic ref) {
    final List<Invoice> invoices = ref.read(invoicesProvider);
    final limit = (args['limit'] as num?)?.toInt() ?? 5;

    final itemSales = <String, ({int count, double revenue})>{};

    for (final inv in invoices) {
      if (inv.isVoided) continue;
      for (final it in inv.items) {
        final int currentCount = itemSales[it.name]?.count ?? 0;
        final double currentRevenue = itemSales[it.name]?.revenue ?? 0.0;
        final int newCount = (currentCount + it.quantity).toInt();
        final double newRevenue = (currentRevenue + (it.unitPrice * it.quantity)).toDouble();
        itemSales[it.name] = (
          count: newCount,
          revenue: newRevenue,
        );
      }
    }

    final sorted = itemSales.entries.toList()
      ..sort((a, b) => b.value.revenue.compareTo(a.value.revenue));

    if (sorted.isEmpty) {
      return const AiToolResult(
        toolName: 'get_item_sales_performance',
        success: true,
        summary: 'No finalized billing records available yet to rank item performance.',
        data: {'items': []},
      );
    }

    final buffer = StringBuffer('Top Selling Menu Items by Revenue:\n');
    for (final entry in sorted.take(limit)) {
      buffer.writeln('• ${entry.key}: ${entry.value.count} sold (₹${NumberFormat('#,##0.00').format(entry.value.revenue)})');
    }

    return AiToolResult(
      toolName: 'get_item_sales_performance',
      success: true,
      summary: buffer.toString().trim(),
      data: {
        'items': sorted.take(limit).map((e) => {'name': e.key, 'count': e.value.count, 'revenue': e.value.revenue}).toList(),
      },
    );
  }
}
