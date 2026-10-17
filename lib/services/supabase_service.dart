import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/models.dart';

class SupabaseService {
  static SupabaseClient? _client;
  static bool get isInitialized => _client != null;

  // Compile-time environment configuration (--dart-define or --dart-define-from-file)
  static const String _envUrl = String.fromEnvironment('SUPABASE_URL', defaultValue: '');
  static const String _envAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY', defaultValue: '');

  static String supabaseUrl = _envUrl;
  static String supabaseAnonKey = _envAnonKey;

  static const String _prefUrlKey = 'mehta_supabase_url';
  static const String _prefAnonKey = 'mehta_supabase_anon_key';

  /// Auto-initialize from stored SharedPreferences or --dart-define on app startup.
  /// Fails safely to offline local mode when credentials are not configured.
  static Future<bool> initFromPreferences() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      var url = prefs.getString(_prefUrlKey)?.trim() ?? '';
      var anonKey = prefs.getString(_prefAnonKey)?.trim() ?? '';

      // If preferences are empty, fall back to compile-time environment variables
      if (url.isEmpty || anonKey.isEmpty) {
        url = _envUrl.trim();
        anonKey = _envAnonKey.trim();
      }

      if (url.isNotEmpty && anonKey.isNotEmpty) {
        final host = Uri.tryParse(url)?.host ?? 'configured-host';
        debugPrint('Configured Supabase credentials detected for $host. Initializing...');
        return await initialize(url: url, anonKey: anonKey);
      } else {
        debugPrint('No Supabase credentials configured. Running securely in standalone Local Mode.');
      }
    } catch (e) {
      debugPrint('Error reading Supabase preferences: $e');
    }
    return false;
  }

  /// Initialize Supabase client if valid URL and key are provided
  static Future<bool> initialize({required String url, required String anonKey}) async {
    final cleanUrl = url.trim();
    final cleanKey = anonKey.trim();

    if (cleanUrl.isEmpty || cleanKey.isEmpty) {
      debugPrint('Supabase credentials empty. Operating in standalone Local Mode.');
      _client = null;
      supabaseUrl = '';
      supabaseAnonKey = '';
      return false;
    }

    try {
      try {
        await Supabase.initialize(
          url: cleanUrl,
          // ignore: deprecated_member_use
          anonKey: cleanKey,
        );
        _client = Supabase.instance.client;
      } catch (e) {
        // If Supabase was already initialized previously in this runtime, use direct SupabaseClient
        _client = SupabaseClient(cleanUrl, cleanKey);
      }

      supabaseUrl = cleanUrl;
      supabaseAnonKey = cleanKey;
      final host = Uri.tryParse(cleanUrl)?.host ?? cleanUrl;
      debugPrint('Supabase successfully initialized for: $host');
      return true;
    } catch (e) {
      debugPrint('Supabase initialization error: $e');
      _client = null;
      return false;
    }
  }

  /// Save credentials to SharedPreferences and initialize connection
  static Future<bool> saveAndInitialize({required String url, required String anonKey}) async {
    final cleanUrl = url.trim();
    final cleanKey = anonKey.trim();

    final success = await initialize(url: cleanUrl, anonKey: cleanKey);
    if (success) {
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(_prefUrlKey, cleanUrl);
        await prefs.setString(_prefAnonKey, cleanKey);
      } catch (e) {
        debugPrint('Error saving Supabase preferences: $e');
      }
    }
    return success;
  }

  /// Disconnect and reset to local in-memory fallback mode
  static Future<void> disconnect() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_prefUrlKey);
      await prefs.remove(_prefAnonKey);
    } catch (e) {
      debugPrint('Error clearing Supabase preferences: $e');
    }
    _client = null;
    supabaseUrl = _envUrl;
    supabaseAnonKey = _envAnonKey;
  }

  /// Test connection with provided or existing credentials
  static Future<({bool success, String message})> testConnection({String? url, String? anonKey}) async {
    final testUrl = (url ?? supabaseUrl).trim();
    final testKey = (anonKey ?? supabaseAnonKey).trim();

    if (testUrl.isEmpty || testKey.isEmpty) {
      return (success: false, message: 'Please enter both the Supabase URL and Anon Key.');
    }

    try {
      final client = SupabaseClient(testUrl, testKey);
      // Query settings table to verify schema
      final res = await client.from('restaurant_settings').select('restaurant_name').limit(1);
      return (
        success: true,
        message: 'Connected successfully! Found ${res.length} restaurant profile row(s).'
      );
    } on PostgrestException catch (e) {
      if (e.code == '42P01') {
        return (
          success: false,
          message: 'Connected to Supabase, but schema tables are missing. Please execute "supabase_schema.sql" in your Supabase SQL Editor.'
        );
      }
      return (success: false, message: 'Supabase Database Error: ${e.message} (Code: ${e.code})');
    } catch (e) {
      return (success: false, message: 'Connection failed: $e');
    }
  }

  // --- 1. RESTAURANT SETTINGS (Cloud Sync) ---
  static Future<RestaurantSettings?> fetchRestaurantSettings() async {
    if (!isInitialized) return null;
    try {
      final data = await _client!
          .from('restaurant_settings')
          .select()
          .order('updated_at', ascending: false)
          .limit(1)
          .maybeSingle();
      if (data == null) return null;

      return RestaurantSettings(
        id: data['id']?.toString() ?? '',
        restaurantName: data['restaurant_name']?.toString() ?? 'Mehta Restaurant & Sweets',
        tagline: data['tagline']?.toString() ?? 'Pure Veg Restaurant & Sweets',
        address: data['address']?.toString() ?? 'Main Road, Station Road Market',
        phone: data['phone']?.toString() ?? '+91 98290 12345',
        email: data['email']?.toString() ?? '',
        gstin: data['gstin']?.toString() ?? '08AAAAA0000A1Z5',
        gstEnabled: data['gst_enabled'] as bool? ?? true,
        taxRate: (data['tax_rate'] as num?)?.toDouble() ?? 5.0,
        serviceChargeRate: (data['service_charge_rate'] as num?)?.toDouble() ?? 0.0,
        invoicePrefix: data['invoice_prefix']?.toString() ?? 'MR-',
        nextInvoiceNumber: (data['next_invoice_number'] as num?)?.toInt() ?? 1001,
        upiId: data['upi_id']?.toString() ?? 'mehtarestaurant@okhdfcbank',
        upiPayeeName: data['upi_payee_name']?.toString() ?? 'Mehta Restaurant',
        inventoryTrackingEnabled: data['inventory_tracking_enabled'] as bool? ?? false,
        receiptFooterNote: data['receipt_footer_note']?.toString() ?? 'Thank you! Visit Again.',
        thermalPaperWidth: (data['thermal_paper_width'] as num?)?.toInt() ?? 80,
        autoPrintReceipt: data['auto_print_receipt'] as bool? ?? false,
      );
    } catch (e) {
      debugPrint('Error fetching settings from Supabase: $e');
      return null;
    }
  }

  static Future<bool> saveRestaurantSettings(RestaurantSettings s) async {
    if (!isInitialized) return false;
    try {
      // 1. Try RPC save_restaurant_settings first (handles security definer and singleton)
      try {
        final rpcRes = await _client!.rpc('save_restaurant_settings', params: {
          'p_restaurant_name': s.restaurantName,
          'p_address': s.address,
          'p_phone': s.phone,
          'p_gstin': s.gstin,
          'p_gst_enabled': s.gstEnabled,
          'p_tax_rate': s.taxRate,
          'p_invoice_prefix': s.invoicePrefix,
          'p_next_invoice_number': s.nextInvoiceNumber,
          'p_upi_id': s.upiId,
          'p_upi_payee_name': s.upiPayeeName,
          'p_inventory_tracking_enabled': s.inventoryTrackingEnabled,
          'p_tagline': s.tagline,
          'p_email': s.email,
          'p_receipt_footer_note': s.receiptFooterNote,
          'p_thermal_paper_width': s.thermalPaperWidth,
        });
        debugPrint('Settings updated via RPC save_restaurant_settings: $rpcRes');
        return true;
      } catch (rpcErr) {
        debugPrint('save_restaurant_settings RPC fallback to direct update: $rpcErr');
      }

      // 2. Direct database update fallback
      final Map<String, dynamic> row = {
        'restaurant_name': s.restaurantName,
        'tagline': s.tagline,
        'address': s.address,
        'phone': s.phone,
        'email': s.email,
        'gstin': s.gstin,
        'gst_enabled': s.gstEnabled,
        'tax_rate': s.taxRate,
        'service_charge_rate': s.serviceChargeRate,
        'invoice_prefix': s.invoicePrefix,
        'next_invoice_number': s.nextInvoiceNumber,
        'upi_id': s.upiId,
        'upi_payee_name': s.upiPayeeName,
        'inventory_tracking_enabled': s.inventoryTrackingEnabled,
        'receipt_footer_note': s.receiptFooterNote,
        'thermal_paper_width': s.thermalPaperWidth,
        'auto_print_receipt': s.autoPrintReceipt,
        'updated_at': DateTime.now().toIso8601String(),
      };

      if (s.id.isNotEmpty) {
        await _client!.from('restaurant_settings').update(row).eq('id', s.id);
      } else {
        final latest = await _client!
            .from('restaurant_settings')
            .select('id')
            .order('updated_at', ascending: false)
            .limit(1)
            .maybeSingle();
        if (latest != null && latest['id'] != null) {
          await _client!.from('restaurant_settings').update(row).eq('id', latest['id']);
        } else {
          await _client!.from('restaurant_settings').insert(row);
        }
      }
      return true;
    } catch (e) {
      debugPrint('Error saving settings to Supabase: $e');
      return false;
    }
  }

  // --- 2. MENU ITEMS (Cloud Sync) ---
  static Future<List<MenuItem>?> fetchMenuItems() async {
    if (!isInitialized) return null;
    try {
      final data = await _client!.from('menu_items').select().order('category');
      final List<MenuItem> items = [];
      for (final row in data) {
        items.add(
          MenuItem(
            id: row['id']?.toString() ?? '',
            sku: row['sku']?.toString() ?? '',
            name: row['name']?.toString() ?? '',
            category: row['category']?.toString() ?? 'Main Course',
            price: (row['price'] as num?)?.toDouble() ?? 0.0,
            isVeg: row['is_veg'] as bool? ?? true,
            isAvailable: row['is_available'] as bool? ?? true,
            isPackaged: row['is_packaged'] as bool? ?? false,
            stockQuantity: (row['stock_quantity'] as num?)?.toInt() ?? 0,
            lowStockThreshold: (row['low_stock_threshold'] as num?)?.toInt() ?? 5,
            description: row['description']?.toString(),
            imageUrl: row['image_url']?.toString(),
          ),
        );
      }
      return items;
    } catch (e) {
      debugPrint('Error fetching menu from Supabase: $e');
      return null;
    }
  }

  static Future<bool> upsertMenuItem(MenuItem item) async {
    if (!isInitialized) return false;
    try {
      await _client!.from('menu_items').upsert({
        'id': item.id,
        'sku': item.sku,
        'name': item.name,
        'category': item.category,
        'price': item.price,
        'is_veg': item.isVeg,
        'is_available': item.isAvailable,
        'is_packaged': item.isPackaged,
        'stock_quantity': item.stockQuantity,
        'low_stock_threshold': item.lowStockThreshold,
        'description': item.description,
        'image_url': item.imageUrl,
        'updated_at': DateTime.now().toIso8601String(),
      });
      return true;
    } catch (e) {
      debugPrint('Error upserting menu item to Supabase: $e');
      return false;
    }
  }

  static Future<bool> deleteMenuItem(String id) async {
    if (!isInitialized) return false;
    try {
      await _client!.from('menu_items').delete().eq('id', id);
      return true;
    } catch (e) {
      debugPrint('Error deleting menu item: $e');
      return false;
    }
  }

  // --- 3. CUSTOMERS (Cloud Sync) ---
  static Future<List<Customer>?> fetchCustomers() async {
    if (!isInitialized) return null;
    try {
      final data = await _client!.from('customers').select().order('name');
      final List<Customer> customers = [];
      for (final row in data) {
        customers.add(
          Customer(
            id: row['id']?.toString() ?? '',
            name: row['name']?.toString() ?? '',
            phone: row['phone']?.toString() ?? '',
            notes: row['notes']?.toString(),
          ),
        );
      }
      return customers;
    } catch (e) {
      debugPrint('Error fetching customers from Supabase: $e');
      return null;
    }
  }

  static Future<bool> upsertCustomer(Customer customer) async {
    if (!isInitialized) return false;
    try {
      await _client!.from('customers').upsert({
        'id': customer.id,
        'name': customer.name,
        'phone': customer.phone,
        'notes': customer.notes,
        'updated_at': DateTime.now().toIso8601String(),
      });
      return true;
    } catch (e) {
      debugPrint('Error upserting customer: $e');
      return false;
    }
  }

  static Future<bool> deleteCustomer(String id) async {
    if (!isInitialized) return false;
    try {
      await _client!.from('customers').delete().eq('id', id);
      return true;
    } catch (e) {
      debugPrint('Error deleting customer: $e');
      return false;
    }
  }

  // --- 4. LEDGER ENTRIES (Cloud Sync) ---
  static Future<List<LedgerEntry>?> fetchLedgerEntries() async {
    if (!isInitialized) return null;
    try {
      final data = await _client!.from('ledger_entries').select().order('date', ascending: false);
      final List<LedgerEntry> entries = [];
      for (final row in data) {
        entries.add(
          LedgerEntry(
            id: row['id']?.toString() ?? '',
            customerId: row['customer_id']?.toString() ?? '',
            type: row['type'] == 'credit' ? LedgerType.credit : LedgerType.debit,
            amount: (row['amount'] as num?)?.toDouble() ?? 0.0,
            referenceType: row['reference_type']?.toString() ?? 'INVOICE',
            referenceNumber: row['reference_number']?.toString() ?? '',
            description: row['description']?.toString() ?? '',
            date: DateTime.tryParse(row['date']?.toString() ?? '') ?? DateTime.now(),
          ),
        );
      }
      return entries;
    } catch (e) {
      debugPrint('Error fetching ledger from Supabase: $e');
      return null;
    }
  }

  static Future<bool> addLedgerEntry(LedgerEntry entry) async {
    if (!isInitialized) return false;
    try {
      if (entry.type == LedgerType.credit && entry.referenceType == 'PAYMENT') {
        try {
          final res = await recordKhataSettlement(
            customerId: entry.customerId,
            amount: entry.amount,
            paymentMethod: entry.description.toLowerCase().contains('upi') ? 'upi' : 'cash',
            referenceNumber: entry.referenceNumber,
            description: entry.description,
          );
          if (res.success) return true;
        } catch (rpcErr) {
          debugPrint('Settlement RPC failed, falling back to direct insert: $rpcErr');
        }
      }

      if (entry.referenceType == 'INVOICE') {
        try {
          final existing = await _client!
              .from('ledger_entries')
              .select('id')
              .eq('customer_id', entry.customerId)
              .eq('reference_number', entry.referenceNumber)
              .limit(1);
          if (existing.isNotEmpty) {
            debugPrint('Ledger entry for ${entry.referenceNumber} already recorded by RPC. Skipping duplicate.');
            return true;
          }
        } catch (_) {}
      }

      await _client!.from('ledger_entries').insert({
        'id': entry.id,
        'customer_id': entry.customerId,
        'type': entry.type == LedgerType.credit ? 'credit' : 'debit',
        'amount': entry.amount,
        'reference_type': entry.referenceType,
        'reference_number': entry.referenceNumber,
        'description': entry.description,
        'date': entry.date.toIso8601String(),
      });
      return true;
    } catch (e) {
      debugPrint('Error adding ledger entry: $e');
      return false;
    }
  }

  static Future<bool> updateLedgerEntry(LedgerEntry entry) async {
    if (!isInitialized) return false;
    try {
      try {
        final res = await _client!.rpc('update_ledger_record', params: {
          'p_id': entry.id,
          'p_amount': entry.amount,
          'p_type': entry.type == LedgerType.credit ? 'credit' : 'debit',
          'p_reference_type': entry.referenceType,
          'p_reference_number': entry.referenceNumber,
          'p_description': entry.description,
          'p_date': entry.date.toIso8601String(),
        });
        if (res != null) return true;
      } catch (_) {}

      await _client!.from('ledger_entries').update({
        'amount': entry.amount,
        'type': entry.type == LedgerType.credit ? 'credit' : 'debit',
        'reference_type': entry.referenceType,
        'reference_number': entry.referenceNumber,
        'description': entry.description,
        'date': entry.date.toIso8601String(),
      }).eq('id', entry.id);
      return true;
    } catch (e) {
      debugPrint('Error updating ledger entry in Supabase: $e');
      return false;
    }
  }

  static Future<bool> deleteLedgerEntries(List<String> ids) async {
    if (!isInitialized || ids.isEmpty) return false;
    try {
      try {
        final res = await _client!.rpc('delete_ledger_records', params: {'p_ids': ids});
        if (res != null) return true;
      } catch (_) {}

      await _client!.from('ledger_entries').delete().filter('id', 'in', ids);
      return true;
    } catch (e) {
      debugPrint('Error deleting ledger entries: $e');
      return false;
    }
  }

  static Future<bool> deleteLedgerEntriesForCustomer(String customerId) async {
    if (!isInitialized) return false;
    try {
      try {
        final res = await _client!.rpc('delete_customer_ledger_records', params: {'p_customer_id': customerId});
        if (res != null) return true;
      } catch (_) {}

      await _client!.from('ledger_entries').delete().eq('customer_id', customerId);
      return true;
    } catch (e) {
      debugPrint('Error deleting customer ledger entries: $e');
      return false;
    }
  }

  // --- 5. TABLES (Cloud Sync) ---
  static Future<List<RestaurantTable>?> fetchTables() async {
    if (!isInitialized) return null;
    try {
      final data = await _client!.from('tables').select().order('table_number');
      final List<RestaurantTable> tables = [];
      for (final row in data) {
        TableState state = TableState.available;
        final st = row['status']?.toString();
        if (st == 'occupied') state = TableState.occupied;
        if (st == 'billed' || st == 'billing') state = TableState.billing;
        if (st == 'cleaning') state = TableState.cleaning;

        tables.add(
          RestaurantTable(
            id: row['id']?.toString() ?? '',
            tableNumber: row['table_number']?.toString() ?? '',
            name: row['name']?.toString() ?? '',
            section: row['section']?.toString() ?? 'Indoor AC',
            capacity: (row['capacity'] as num?)?.toInt() ?? 6,
            status: state,
            guestCount: (row['guest_count'] as num?)?.toInt() ?? 0,
            activeOrderId: row['active_order_id']?.toString(),
            mergedInto: row['merged_into']?.toString(),
          ),
        );
      }
      return tables;
    } catch (e) {
      debugPrint('Error fetching tables from Supabase: $e');
      return null;
    }
  }

  static Future<bool> updateTable(RestaurantTable table) async {
    if (!isInitialized) return false;
    try {
      String statusStr = 'available';
      if (table.status == TableState.occupied) statusStr = 'occupied';
      if (table.status == TableState.billing) statusStr = 'billed';
      if (table.status == TableState.cleaning) statusStr = 'cleaning';

      final Map<String, dynamic> row = {
        'id': table.id,
        'table_number': table.tableNumber,
        'name': table.name,
        'section': table.section,
        'capacity': table.capacity,
        'status': statusStr,
        'guest_count': table.guestCount,
        'active_order_id': table.activeOrderId,
        'merged_into': table.mergedInto,
        'updated_at': DateTime.now().toIso8601String(),
      };

      try {
        await _client!.from('tables').upsert(row);
      } catch (err) {
        // Fallback without name & section if columns don't exist yet in Supabase schema
        row.remove('name');
        row.remove('section');
        await _client!.from('tables').upsert(row);
      }
      return true;
    } catch (e) {
      debugPrint('Error updating table in Supabase: $e');
      return false;
    }
  }

  static Future<bool> deleteTable(String id) async {
    if (!isInitialized) return false;
    try {
      await _client!.from('tables').delete().eq('id', id);
      return true;
    } catch (e) {
      debugPrint('Error deleting table from Supabase: $e');
      return false;
    }
  }

  // --- 6. INVOICES & ORDERS (Atomic RPC & Cloud Storage) ---
  static Future<bool> saveInvoice(Invoice invoice) async {
    if (!isInitialized) return false;
    try {
      final itemsJson = invoice.items.map((it) => {
        'menu_item_id': it.menuItemId,
        'name': it.name,
        'unit_price': it.unitPrice,
        'quantity': it.quantity,
        'notes': it.notes,
      }).toList();

      // Preferred: Call server-side atomic procedure finalize_invoice_transaction
      try {
        final res = await _client!.rpc('finalize_invoice_transaction', params: {
          'p_idempotency_key': invoice.id,
          'p_table_number': invoice.tableNumber,
          'p_subtotal': invoice.subtotal,
          'p_tax_amount': invoice.taxAmount,
          'p_grand_total': invoice.grandTotal,
          'p_cash_paid': invoice.cashPaid,
          'p_upi_paid': invoice.upiPaid,
          'p_credit_amount': invoice.creditAmount,
          'p_customer_name': invoice.customerName,
          'p_customer_phone': invoice.customerPhone,
          'p_customer_id': null,
          'p_staff_id': null,
          'p_upi_reference': null,
          'p_items': itemsJson,
        });
        debugPrint('Invoice finalized atomically via RPC: $res');
        return true;
      } catch (rpcErr) {
        debugPrint('RPC finalize_invoice_transaction fallback to direct upsert: $rpcErr');
        final Map<String, dynamic> row = {
          'id': invoice.id,
          'invoice_number': invoice.invoiceNumber,
          'table_number': invoice.tableNumber,
          'subtotal': invoice.subtotal,
          'tax_amount': invoice.taxAmount,
          'grand_total': invoice.grandTotal,
          'cash_paid': invoice.cashPaid,
          'upi_paid': invoice.upiPaid,
          'credit_amount': invoice.creditAmount,
          'customer_name': invoice.customerName,
          'customer_phone': invoice.customerPhone,
          'items': itemsJson,
          'created_at': invoice.issuedAt.toIso8601String(),
        };
        if (invoice.splits != null && invoice.splits!.isNotEmpty) {
          row['splits'] = invoice.splits!.map((s) => {
            'id': s.id,
            'label': s.label,
            'amount': s.amount,
            'payment_mode': s.paymentMode,
            'is_paid': s.isPaid,
            'customer_name': s.customerName,
            'customer_phone': s.customerPhone,
          }).toList();
        }
        if (invoice.splitSummary != null) {
          row['split_summary'] = invoice.splitSummary;
        }

        try {
          final rowWithVoid = Map<String, dynamic>.from(row);
          rowWithVoid['is_voided'] = invoice.isVoided;
          rowWithVoid['void_reason'] = invoice.voidReason;
          await _client!.from('invoices').upsert(rowWithVoid);
        } catch (_) {
          await _client!.from('invoices').upsert(row);
        }
        return true;
      }
    } catch (e) {
      debugPrint('Error saving invoice to Supabase: $e');
      return false;
    }
  }

  static Future<List<Invoice>?> fetchInvoices() async {
    if (!isInitialized) return null;
    try {
      final data = await _client!
          .from('invoices')
          .select()
          .order('created_at', ascending: false);

      final List<Invoice> result = [];
      for (final row in data) {
        final itemsRaw = row['items'];
        final List<OrderItem> items = [];
        if (itemsRaw is List) {
          for (final it in itemsRaw) {
            if (it is Map) {
              items.add(OrderItem(
                id: it['id']?.toString() ?? it['menu_item_id']?.toString() ?? 'it_${DateTime.now().microsecondsSinceEpoch}',
                menuItemId: it['menu_item_id']?.toString() ?? '',
                name: it['name']?.toString() ?? '',
                unitPrice: (it['unit_price'] as num?)?.toDouble() ?? 0.0,
                quantity: (it['quantity'] as num?)?.toInt() ?? 1,
                notes: it['notes']?.toString(),
              ));
            }
          }
        }

        List<PayerSplit>? splits;
        final splitsRaw = row['splits'];
        if (splitsRaw is List && splitsRaw.isNotEmpty) {
          splits = [];
          for (final sp in splitsRaw) {
            if (sp is Map) {
              splits.add(PayerSplit(
                id: sp['id']?.toString() ?? 'sp_${DateTime.now().microsecondsSinceEpoch}',
                label: sp['label']?.toString() ?? 'Payer',
                amount: (sp['amount'] as num?)?.toDouble() ?? 0.0,
                paymentMode: sp['payment_mode']?.toString() ?? 'UPI',
                isPaid: sp['is_paid'] as bool? ?? true,
                customerName: sp['customer_name']?.toString(),
                customerPhone: sp['customer_phone']?.toString(),
              ));
            }
          }
        }

        final issuedAt = DateTime.tryParse(row['created_at']?.toString() ?? '') ?? DateTime.now();
        final isVoided = row['is_voided'] as bool? ?? false;
        final voidReason = row['void_reason']?.toString();

        result.add(Invoice(
          id: row['id']?.toString() ?? '',
          invoiceNumber: row['invoice_number']?.toString() ?? '',
          tableNumber: row['table_number']?.toString() ?? '',
          customerName: row['customer_name']?.toString(),
          customerPhone: row['customer_phone']?.toString(),
          items: items,
          subtotal: (row['subtotal'] as num?)?.toDouble() ?? 0.0,
          taxAmount: (row['tax_amount'] as num?)?.toDouble() ?? 0.0,
          grandTotal: (row['grand_total'] as num?)?.toDouble() ?? 0.0,
          cashPaid: (row['cash_paid'] as num?)?.toDouble() ?? 0.0,
          upiPaid: (row['upi_paid'] as num?)?.toDouble() ?? 0.0,
          creditAmount: (row['credit_amount'] as num?)?.toDouble() ?? 0.0,
          issuedAt: issuedAt,
          splits: splits,
          splitSummary: row['split_summary']?.toString(),
          isVoided: isVoided,
          voidReason: voidReason,
        ));
      }
      return result;
    } catch (e) {
      debugPrint('Error fetching invoices from Supabase: $e');
      return null;
    }
  }

  static Future<bool> deleteInvoice(String id) async {
    if (!isInitialized) return false;
    try {
      try {
        final res = await _client!.rpc('delete_invoice_records', params: {
          'p_ids': [id],
        });
        if (res != null) return true;
      } catch (_) {}

      await _client!.from('invoices').delete().eq('id', id);
      return true;
    } catch (e) {
      debugPrint('Error deleting invoice from Supabase: $e');
      return false;
    }
  }

  static Future<bool> bulkDeleteInvoices(List<String> ids) async {
    if (!isInitialized || ids.isEmpty) return false;
    try {
      try {
        final res = await _client!.rpc('delete_invoice_records', params: {
          'p_ids': ids,
        });
        if (res != null) return true;
      } catch (_) {}

      await _client!.from('invoices').delete().filter('id', 'in', ids);
      return true;
    } catch (e) {
      debugPrint('Error bulk deleting invoices from Supabase: $e');
      return false;
    }
  }

  static Future<bool> clearAllInvoices() async {
    if (!isInitialized) return false;
    try {
      try {
        final res = await _client!.rpc('clear_all_invoice_records');
        if (res != null) return true;
      } catch (_) {}

      await _client!.from('invoices').delete().neq('id', '00000000-0000-0000-0000-000000000000');
      return true;
    } catch (e) {
      debugPrint('Error clearing all invoices from Supabase: $e');
      return false;
    }
  }

  /// Atomic Khata Settlement RPC (Records repayment and updates ledger)
  static Future<({bool success, String? message, double? newBalance})> recordKhataSettlement({
    required String customerId,
    required double amount,
    String paymentMethod = 'cash',
    String? referenceNumber,
    String description = 'Khata Repayment',
  }) async {
    if (!isInitialized) return (success: false, message: 'Supabase offline', newBalance: null);
    try {
      final res = await _client!.rpc('record_khata_settlement', params: {
        'p_customer_id': customerId,
        'p_amount': amount,
        'p_payment_method': paymentMethod,
        'p_reference_number': referenceNumber,
        'p_description': description,
      });
      if (res is Map && res['success'] == true) {
        final nb = (res['new_balance'] as num?)?.toDouble();
        return (success: true, message: null, newBalance: nb);
      }
      return (success: false, message: 'Settlement RPC returned unexpected result', newBalance: null);
    } catch (e) {
      debugPrint('Error recording settlement via RPC: $e');
      return (success: false, message: e.toString(), newBalance: null);
    }
  }

  /// Server-Enforced PIN Verification with 5-Attempt / 5-Minute Terminal Lockout
  static Future<({
    bool success,
    bool locked,
    String message,
    int? remainingAttempts,
    int? retryAfterSeconds,
    Map<String, dynamic>? staff,
  })> verifyStaffPin({
    required String pin,
    String terminalId = 'default_terminal',
  }) async {
    if (!isInitialized) {
      return (
        success: false,
        locked: false,
        message: 'Supabase offline - using local verification',
        remainingAttempts: null,
        retryAfterSeconds: null,
        staff: null,
      );
    }
    try {
      final res = await _client!.rpc('verify_staff_pin', params: {
        'p_terminal_id': terminalId,
        'p_pin': pin,
      });
      if (res is Map) {
        final success = res['success'] == true;
        final locked = res['locked'] == true;
        final message = res['message']?.toString() ?? (success ? 'Authentication successful' : 'Incorrect PIN');
        final attemptsRemaining = (res['attempts_remaining'] as num?)?.toInt();
        final retryAfter = (res['retry_after_seconds'] as num?)?.toInt();
        final staffData = res['staff'] is Map ? Map<String, dynamic>.from(res['staff'] as Map) : null;
        return (
          success: success,
          locked: locked,
          message: message,
          remainingAttempts: attemptsRemaining,
          retryAfterSeconds: retryAfter,
          staff: staffData,
        );
      }
      return (
        success: false,
        locked: false,
        message: 'Invalid response from server',
        remainingAttempts: null,
        retryAfterSeconds: null,
        staff: null,
      );
    } catch (e) {
      debugPrint('Error verifying staff PIN via Supabase RPC: $e');
      return (
        success: false,
        locked: false,
        message: 'Verification failed: $e',
        remainingAttempts: null,
        retryAfterSeconds: null,
        staff: null,
      );
    }
  }

  /// Void Invoice RPC (Restricted to Owner/Manager, reverses Khata credit if issued)
  static Future<({bool success, String message})> voidInvoice({
    required String invoiceNumber,
    required String reason,
  }) async {
    if (!isInitialized) return (success: false, message: 'Supabase offline');
    try {
      final res = await _client!.rpc('void_invoice_transaction', params: {
        'p_invoice_number': invoiceNumber,
        'p_reason': reason,
      });
      if (res is Map && res['success'] == true) {
        return (success: true, message: res['message']?.toString() ?? 'Invoice voided successfully');
      }
      return (success: false, message: 'Void RPC failed');
    } catch (e) {
      debugPrint('Error voiding invoice via RPC, falling back to direct update: $e');
      try {
        await _client!.from('invoices').update({
          'is_voided': true,
          'void_reason': reason,
        }).eq('invoice_number', invoiceNumber);
        return (success: true, message: 'Invoice marked voided in database');
      } catch (err2) {
        debugPrint('Direct void update failed: $err2');
        return (success: false, message: e.toString());
      }
    }
  }

  // --- 7. KITCHEN TICKETS & KDS (Cloud Sync) ---
  static Future<List<KitchenTicket>?> fetchKitchenTickets() async {
    if (!isInitialized) return null;
    try {
      final data = await _client!
          .from('kitchen_tickets')
          .select()
          .order('created_at', ascending: true);
      final List<KitchenTicket> tickets = [];
      for (final row in data) {
        final itemsList = (row['items'] as List<dynamic>?) ?? [];
        final items = itemsList.map((it) => OrderItem(
          id: it['id']?.toString() ?? 'item_${DateTime.now().microsecondsSinceEpoch}',
          menuItemId: it['menu_item_id']?.toString() ?? '',
          name: it['name']?.toString() ?? '',
          unitPrice: (it['unit_price'] as num?)?.toDouble() ?? 0.0,
          quantity: (it['quantity'] as num?)?.toInt() ?? 1,
          notes: it['notes']?.toString(),
        )).toList();

        KotState status = KotState.newTicket;
        final st = row['status']?.toString();
        if (st == 'preparing') status = KotState.preparing;
        if (st == 'ready') status = KotState.ready;
        if (st == 'served') status = KotState.served;

        tickets.add(KitchenTicket(
          id: row['id']?.toString() ?? '',
          kotNumber: row['kot_number']?.toString() ?? '',
          orderId: row['order_id']?.toString() ?? '',
          tableNumber: row['table_number']?.toString() ?? '',
          items: items,
          status: status,
          isRush: row['is_rush'] as bool? ?? false,
          timestamp: DateTime.tryParse(row['created_at']?.toString() ?? '') ?? DateTime.now(),
        ));
      }
      return tickets;
    } catch (e) {
      debugPrint('Error fetching kitchen tickets from Supabase: $e');
      return null;
    }
  }

  static Future<bool> saveKitchenTicket(KitchenTicket ticket) async {
    if (!isInitialized) return false;
    try {
      final itemsJson = ticket.items.map((it) => {
        'menu_item_id': it.menuItemId,
        'name': it.name,
        'unit_price': it.unitPrice,
        'quantity': it.quantity,
        'notes': it.notes,
      }).toList();

      await _client!.from('kitchen_tickets').upsert({
        'id': ticket.id,
        'kot_number': ticket.kotNumber,
        'order_id': ticket.orderId,
        'table_number': ticket.tableNumber,
        'status': ticket.status.name,
        'is_rush': ticket.isRush,
        'items': itemsJson,
        'created_at': ticket.timestamp.toIso8601String(),
      });
      return true;
    } catch (e) {
      debugPrint('Error saving kitchen ticket to Supabase: $e');
      return false;
    }
  }

  static Future<bool> updateKitchenTicketStatus(String ticketId, KotState status) async {
    if (!isInitialized) return false;
    try {
      await _client!.from('kitchen_tickets').update({
        'status': status.name,
      }).eq('id', ticketId);
      return true;
    } catch (e) {
      debugPrint('Error updating ticket status in Supabase: $e');
      return false;
    }
  }

  static Future<bool> updateKitchenTicketRush(String ticketId, bool isRush) async {
    if (!isInitialized) return false;
    try {
      await _client!.from('kitchen_tickets').update({
        'is_rush': isRush,
      }).eq('id', ticketId);
      return true;
    } catch (e) {
      debugPrint('Error updating ticket rush in Supabase: $e');
      return false;
    }
  }

  static Future<bool> deleteKitchenTicket(String ticketId) async {
    if (!isInitialized) return false;
    try {
      await _client!.from('kitchen_tickets').delete().eq('id', ticketId);
      return true;
    } catch (e) {
      debugPrint('Error deleting ticket in Supabase: $e');
      return false;
    }
  }

  // --- 8. STAFF PROFILES (Cloud Sync & Management) ---
  static Future<List<StaffMember>?> fetchStaffProfiles() async {
    if (!isInitialized) return null;
    try {
      final data = await _client!.from('staff_profiles').select().order('staff_code');
      final List<StaffMember> list = [];
      for (final row in data) {
        StaffRole role = StaffRole.waiter;
        final roleStr = row['role']?.toString().toLowerCase();
        if (roleStr == 'owner') role = StaffRole.owner;
        if (roleStr == 'manager') role = StaffRole.manager;
        if (roleStr == 'cashier') role = StaffRole.cashier;
        if (roleStr == 'kitchen') role = StaffRole.kitchen;

        list.add(
          StaffMember(
            id: row['id']?.toString() ?? '',
            name: row['full_name']?.toString() ?? 'Staff Member',
            role: role,
            pin: '',
            avatarIcon: row['avatar_icon']?.toString() ?? '👤',
          ),
        );
      }
      return list;
    } catch (e) {
      debugPrint('Error fetching staff profiles from Supabase: $e');
      return null;
    }
  }

  static Future<bool> upsertStaffProfile(StaffMember staff) async {
    if (!isInitialized) return false;
    try {
      await _client!.from('staff_profiles').upsert({
        'id': staff.id,
        'full_name': staff.name,
        'role': staff.role.name,
        'avatar_icon': staff.avatarIcon,
        'is_active': true,
        'updated_at': DateTime.now().toIso8601String(),
      });
      return true;
    } catch (e) {
      debugPrint('Error saving staff profile to Supabase: $e');
      return false;
    }
  }

  static Future<bool> deleteStaffProfile(String id) async {
    if (!isInitialized) return false;
    try {
      await _client!.from('staff_profiles').delete().eq('id', id);
      return true;
    } catch (e) {
      debugPrint('Error deleting staff profile from Supabase: $e');
      return false;
    }
  }

  // --- 9. REALTIME BROADCAST & MULTI-DEVICE SYNC ---
  static RealtimeChannel? _realtimeChannel;

  static void subscribeToRealtimeChanges(void Function() onDataChanged) {
    if (!isInitialized) return;
    try {
      _realtimeChannel?.unsubscribe();
      _realtimeChannel = _client!
          .channel('mehta_restaurant_live_sync')
          .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            callback: (payload) {
              debugPrint('Supabase Realtime event: ${payload.eventType} on ${payload.table}');
              onDataChanged();
            },
          )
          .subscribe();
      debugPrint('Subscribed to Supabase Realtime changes.');
    } catch (e) {
      debugPrint('Error subscribing to Realtime: $e');
    }
  }

  static void unsubscribeRealtime() {
    try {
      _realtimeChannel?.unsubscribe();
      _realtimeChannel = null;
    } catch (_) {}
  }
}

