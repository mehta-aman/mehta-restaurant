import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mehta_restaurant/models/models.dart';
import 'package:mehta_restaurant/providers/restaurant_provider.dart';
import 'package:mehta_restaurant/services/whatsapp_service.dart';
import 'package:mehta_restaurant/services/kitchen_audio_service.dart';
import 'package:mehta_restaurant/services/supabase_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Feature #1: Dynamic UPI QR Code Generation', () {
    test('generateUpiUri builds compliant UPI deep link', () {
      final settings = RestaurantSettings(
        upiId: 'mehtarestaurant@okhdfcbank',
        upiPayeeName: 'Mehta Restaurant',
      );

      final uri = settings.generateUpiUri(amount: 450.0, note: 'Table T01 Bill');
      expect(uri, contains('upi://pay?pa=mehtarestaurant@okhdfcbank'));
      expect(uri, contains('pn=Mehta%20Restaurant'));
      expect(uri, contains('am=450.00'));
      expect(uri, contains('cu=INR'));
      expect(uri, contains('tn=Table%20T01%20Bill'));
    });
  });

  group('Feature #3: Bikaji & Inventory Management', () {
    test('Stock tracking correctly identifies low stock and out of stock', () {
      final item = MenuItem(
        id: 'bikaji_1',
        name: 'Bikaji Bhujia 200g',
        sku: 'PKG-001',
        category: 'Packaged Goods',
        price: 55.0,
        isPackaged: true,
        stockQuantity: 4,
        lowStockThreshold: 5,
      );

      expect(item.isLowStock, isTrue);
      expect(item.isOutOfStock, isFalse);
      expect(item.isStockTracked, isTrue);

      final outOfStockItem = item.copyWith(stockQuantity: 0);
      expect(outOfStockItem.isOutOfStock, isTrue);
      expect(outOfStockItem.isLowStock, isFalse); // isLowStock is stockQuantity > 0 && <= lowStockThreshold
    });

    test('Provider decrements and restocks inventory correctly', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final initialItems = container.read(menuProvider);
      final bhujia = initialItems.firstWhere((i) => i.id == '31'); // Bikaji Bhujia
      final initialStock = bhujia.stockQuantity;

      // Decrement 5 items
      container.read(menuProvider.notifier).decrementStock('31', 5);
      final afterDecrement = container.read(menuProvider).firstWhere((i) => i.id == '31');
      expect(afterDecrement.stockQuantity, equals(initialStock - 5));

      // Restock 10 items
      container.read(menuProvider.notifier).restockItem('31', 10);
      final afterRestock = container.read(menuProvider).firstWhere((i) => i.id == '31');
      expect(afterRestock.stockQuantity, equals(initialStock - 5 + 10));
    });

    test('RestaurantSettings defaults to inventoryTrackingEnabled = false', () {
      final settings = RestaurantSettings();
      expect(settings.inventoryTrackingEnabled, isFalse);

      final toggled = settings.copyWith(inventoryTrackingEnabled: true);
      expect(toggled.inventoryTrackingEnabled, isTrue);
    });

    test('SettingsNotifier toggles inventoryTrackingEnabled', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      expect(container.read(settingsProvider).inventoryTrackingEnabled, isFalse);
      container.read(settingsProvider.notifier).toggleInventoryTracking(true);
      expect(container.read(settingsProvider).inventoryTrackingEnabled, isTrue);
      container.read(settingsProvider.notifier).toggleInventoryTracking(false);
      expect(container.read(settingsProvider).inventoryTrackingEnabled, isFalse);
    });

    test('Initial menu seed items are available by default even if stock is 0', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final menu = container.read(menuProvider);
      final coke = menu.firstWhere((i) => i.id == '38');
      expect(coke.isAvailable, isTrue);

      // When tracking is disabled, an item with 0 stock is not sold out
      final settings = container.read(settingsProvider);
      expect(settings.inventoryTrackingEnabled, isFalse);
      final isEffectivelySoldOut = !coke.isAvailable || (settings.inventoryTrackingEnabled && coke.isOutOfStock);
      expect(isEffectivelySoldOut, isFalse);
    });
  });

  group('Feature #4: Parcel / Takeaway Fast-Billing', () {
    test('createParcelOrder generates token and adds packaging charge', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final parcelId = container.read(ordersProvider.notifier).createParcelOrder(
        taxRate: 0.05,
        packagingCharge: 15.0,
      );

      expect(parcelId, startsWith('Parcel P-'));
      final order = container.read(ordersProvider)[parcelId];
      expect(order, isNotNull);
      expect(order!.isTakeaway, isTrue);
      expect(order.packagingCharge, equals(15.0));

      // Table states must remain unaffected
      final tables = container.read(tablesProvider);
      final allAvailable = tables.every((t) => t.status == TableState.available);
      expect(allAvailable, isTrue);
    });
  });

  group('Feature #5: WhatsApp EOD Digest Formatting', () {
    test('formatDailyEodMessage creates complete breakdown text', () {
      final digest = WhatsAppService.formatDailyEodMessage(
        restaurantName: 'Mehta Restaurant',
        date: DateTime.now(),
        totalSales: 735.0,
        totalBills: 2,
        cashCollected: 546.0,
        upiCollected: 189.0,
        creditGiven: 0.0,
        khataRecoveries: 0.0,
        topSellingItems: ['Paneer Butter Masala (2)', 'Butter Naan (4)'],
      );

      expect(digest, contains('DAILY CLOSING REPORT • Mehta Restaurant'));
      expect(digest, contains('TOTAL REVENUE: ₹735.00'));
      expect(digest, contains('Total Invoices: *2 bills*'));
      expect(digest, contains('Cash at Counter: *₹546.00*'));
      expect(digest, contains('UPI Payments: *₹189.00*'));
      expect(digest, contains('Paneer Butter Masala (2)'));
      expect(digest, contains('*Net Cash in Hand / Drawer:* *₹546.00*'));
    });
  });

  group('Feature #6: Staff Role-Based Access & Quick PIN Switch', () {
    test('Role permissions strictly govern management actions', () {
      const waiter = StaffMember(
        id: 'w1',
        name: 'Ramesh',
        role: StaffRole.waiter,
        pin: '1001',
        avatarIcon: '🧑‍🍳',
      );

      const manager = StaffMember(
        id: 'm1',
        name: 'Sh. Mehta (Father)',
        role: StaffRole.manager,
        pin: '9999',
        avatarIcon: '👔',
      );

      expect(waiter.canTakeOrders, isTrue);
      expect(waiter.canEditMenu, isFalse);
      expect(waiter.canManageSettings, isFalse);
      expect(waiter.canManageAccounts, isFalse);

      expect(manager.canTakeOrders, isTrue);
      expect(manager.canEditMenu, isTrue);
      expect(manager.canManageSettings, isTrue);
      expect(manager.canManageAccounts, isTrue);
    });

    test('Provider validates 4-digit PIN accurately and rejects invalid PINs', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      // Default staff is Aman Mehta (1234)
      expect(container.read(currentStaffProvider).name, equals('Aman Mehta'));

      // Switch to Waiter Ramesh using PIN '1001'
      final ok = container.read(currentStaffProvider.notifier).switchStaffWithPin('1001');
      expect(ok, isTrue);
      expect(container.read(currentStaffProvider).name, equals('Ramesh (Waiter 1)'));
      expect(container.read(currentStaffProvider).role, equals(StaffRole.waiter));

      // Attempt invalid PIN
      final fail = container.read(currentStaffProvider.notifier).switchStaffWithPin('0000');
      expect(fail, isFalse);
      // Current staff remains Ramesh
      expect(container.read(currentStaffProvider).name, equals('Ramesh (Waiter 1)'));

      // Switch to Father (Manager) using PIN '9999'
      final fatherOk = container.read(currentStaffProvider.notifier).switchStaffWithPin('9999');
      expect(fatherOk, isTrue);
      expect(container.read(currentStaffProvider).name, equals('Sh. Mehta (Father)'));
      expect(container.read(currentStaffProvider).role, equals(StaffRole.manager));
    });
  });

  group('Feature #7: Table Merging & Multi-Payer Split Billing', () {
    test('mergeTables and unmergeTable correctly manage secondary tables and capacities', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      // Merge T03 + T04
      container.read(tablesProvider.notifier).mergeTables(
        masterTableNumber: 'T03',
        secondaryTableNumbers: ['T04'],
      );

      final tablesAfterMerge = container.read(tablesProvider);
      final t03 = tablesAfterMerge.firstWhere((t) => t.tableNumber == 'T03');
      final t04 = tablesAfterMerge.firstWhere((t) => t.tableNumber == 'T04');

      expect(t03.isMergedMaster, isTrue);
      expect(t03.mergedTables, contains('T04'));
      expect(t03.totalCapacity, equals(12)); // 6 + 6
      expect(t03.displayTableNumber, equals('T03 + T04'));

      expect(t04.isMergedSecondary, isTrue);
      expect(t04.mergedInto, equals('T03'));
      expect(t04.status, equals(TableState.occupied));

      // Unmerge T03
      container.read(tablesProvider.notifier).unmergeTable('T03');

      final tablesAfterUnmerge = container.read(tablesProvider);
      final t03Reset = tablesAfterUnmerge.firstWhere((t) => t.tableNumber == 'T03');
      final t04Reset = tablesAfterUnmerge.firstWhere((t) => t.tableNumber == 'T04');

      expect(t03Reset.isMergedMaster, isFalse);
      expect(t03Reset.mergedTables, isEmpty);
      expect(t04Reset.isMergedSecondary, isFalse);
      expect(t04Reset.status, equals(TableState.available));
    });

    test('mergeOrders consolidates active orders from secondary table into master order', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final dalMakhani = MenuItem(
        id: '10',
        name: 'Dal Makhani',
        sku: 'MNC-04',
        price: 210,
        category: 'Main Course',
      );
      final butterNaan = MenuItem(
        id: '19',
        name: 'Butter Naan',
        sku: 'BRD-03',
        price: 45,
        category: 'Breads',
      );

      // Order on T01: 1 Dal Makhani
      container.read(ordersProvider.notifier).initializeOrder('T01');
      container.read(ordersProvider.notifier).addItemToOrder('T01', dalMakhani, quantity: 1);

      // Order on T02: 4 Butter Naans
      container.read(ordersProvider.notifier).initializeOrder('T02');
      container.read(ordersProvider.notifier).addItemToOrder('T02', butterNaan, quantity: 4);

      // Merge T02 into T01
      container.read(ordersProvider.notifier).mergeOrders('T01', ['T02']);

      final orders = container.read(ordersProvider);
      expect(orders.containsKey('T02'), isFalse);
      expect(orders.containsKey('T01'), isTrue);

      final combinedOrder = orders['T01']!;
      expect(combinedOrder.items.length, equals(2));
      expect(combinedOrder.subtotal, equals(210 + (4 * 45))); // 390.0
    });

    test('PayerSplit accurately divides total across multiple payers', () {
      const double total = 1200.0;
      const int payerCount = 3;
      final eachAmt = total / payerCount;

      final splits = List.generate(payerCount, (i) {
        return PayerSplit(
          id: 'sp_$i',
          label: 'Payer ${i + 1}',
          amount: eachAmt,
          paymentMode: i == 0 ? 'Cash' : 'UPI',
          isPaid: true,
        );
      });

      final invoice = Invoice(
        id: 'inv_split',
        invoiceNumber: 'MR-2001',
        tableNumber: 'T05',
        items: [],
        subtotal: 1200.0,
        taxAmount: 0.0,
        grandTotal: 1200.0,
        cashPaid: 400.0,
        upiPaid: 800.0,
        creditAmount: 0.0,
        splits: splits,
        splitSummary: '3 Payers • Rs. 400 each',
      );

      expect(invoice.isSplitBill, isTrue);
      expect(invoice.splits!.length, equals(3));
      expect(invoice.cashPaid, equals(400.0));
      expect(invoice.upiPaid, equals(800.0));
    });
  });

  group('Feature #8: Kitchen Chimes & Delay Alert Notifications', () {
    test('KitchenTicket accurately computes elapsed time and delay escalation thresholds', () {
      final now = DateTime.now();

      // 1. Fresh ticket (just received)
      final freshTicket = KitchenTicket(
        id: 'k1',
        kotNumber: 'KOT-001',
        orderId: 'ord_1',
        tableNumber: 'T01',
        items: [],
        timestamp: now,
      );
      expect(freshTicket.elapsedMinutes, lessThanOrEqualTo(1));
      expect(freshTicket.isWarning, isFalse);
      expect(freshTicket.isDelayed, isFalse);

      // 2. Warning ticket (11 minutes elapsed)
      final warningTicket = KitchenTicket(
        id: 'k2',
        kotNumber: 'KOT-002',
        orderId: 'ord_2',
        tableNumber: 'T02',
        items: [],
        timestamp: now.subtract(const Duration(minutes: 11)),
      );
      expect(warningTicket.elapsedMinutes, equals(11));
      expect(warningTicket.isWarning, isTrue);
      expect(warningTicket.isDelayed, isFalse);

      // 3. Delayed critical ticket (18 minutes elapsed)
      final delayedTicket = KitchenTicket(
        id: 'k3',
        kotNumber: 'KOT-003',
        orderId: 'ord_3',
        tableNumber: 'T03',
        items: [],
        timestamp: now.subtract(const Duration(minutes: 18)),
      );
      expect(delayedTicket.elapsedMinutes, equals(18));
      expect(delayedTicket.isWarning, isFalse);
      expect(delayedTicket.isDelayed, isTrue);

      // 4. Served ticket is never flagged as delayed
      final servedTicket = KitchenTicket(
        id: 'k4',
        kotNumber: 'KOT-004',
        orderId: 'ord_4',
        tableNumber: 'T04',
        items: [],
        status: KotState.served,
        timestamp: now.subtract(const Duration(minutes: 30)),
      );
      expect(servedTicket.isDelayed, isFalse);
      expect(servedTicket.isWarning, isFalse);
    });

    test('KitchenTicketsNotifier toggles rush priority on tickets', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      // Create an order and send KOT
      final order = Order(
        id: 'ord_test',
        orderNumber: 'ORD-001',
        tableNumber: 'T02',
        items: [
          OrderItem(
            id: 'oi_1',
            menuItemId: '1',
            name: 'Paneer Butter Masala',
            unitPrice: 250,
            quantity: 2,
          ),
        ],
      );

      container.read(kitchenTicketsProvider.notifier).sendKot(order: order);
      final tickets = container.read(kitchenTicketsProvider);
      expect(tickets.isNotEmpty, isTrue);

      final firstId = tickets.first.id;
      final initialRush = tickets.first.isRush;

      // Toggle rush flag
      container.read(kitchenTicketsProvider.notifier).toggleRush(firstId);
      final updatedTickets = container.read(kitchenTicketsProvider);
      final updatedFirst = updatedTickets.firstWhere((t) => t.id == firstId);
      expect(updatedFirst.isRush, equals(!initialRush));

      // Toggle back
      container.read(kitchenTicketsProvider.notifier).toggleRush(firstId);
      final revertedTickets = container.read(kitchenTicketsProvider);
      final revertedFirst = revertedTickets.firstWhere((t) => t.id == firstId);
      expect(revertedFirst.isRush, equals(initialRush));
    });

    test('KitchenAudioService generates valid PCM WAV binary data', () {
      final wavBytes = KitchenAudioService.generateChimeWav(durationSeconds: 0.2);

      // RIFF header validation
      expect(wavBytes.length, greaterThan(44));
      // First 4 bytes are 'RIFF'
      expect(String.fromCharCodes(wavBytes.sublist(0, 4)), equals('RIFF'));
      // Bytes 8-12 are 'WAVE'
      expect(String.fromCharCodes(wavBytes.sublist(8, 12)), equals('WAVE'));
      // Bytes 12-16 are 'fmt '
      expect(String.fromCharCodes(wavBytes.sublist(12, 16)), equals('fmt '));
      // Bytes 36-40 are 'data'
      expect(String.fromCharCodes(wavBytes.sublist(36, 40)), equals('data'));
    });

    test('KitchenAudioMutedNotifier accurately toggles and sets mute state', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      // Initial state is unmuted (false)
      expect(container.read(kitchenAudioMutedProvider), isFalse);
      expect(KitchenAudioService.isMuted, isFalse);

      // Toggle to muted
      container.read(kitchenAudioMutedProvider.notifier).toggle();
      expect(container.read(kitchenAudioMutedProvider), isTrue);
      expect(KitchenAudioService.isMuted, isTrue);

      // Explicit set to unmuted
      container.read(kitchenAudioMutedProvider.notifier).setMuted(false);
      expect(container.read(kitchenAudioMutedProvider), isFalse);
      expect(KitchenAudioService.isMuted, isFalse);
    });
  });

  group('Credit Ledger (Khata): Customer Creation & Pending Bills', () {
    test('addCustomer creates a new customer account and prevents duplicates', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final initialCustomers = container.read(customersProvider);
      final count = initialCustomers.length;

      // Add new customer
      final newCustomer = container.read(customersProvider.notifier).addCustomer(
        name: 'Sanjay Agarwal',
        phone: '9829099999',
        notes: 'Monthly regular guest',
      );

      final afterAdd = container.read(customersProvider);
      expect(afterAdd.length, equals(count + 1));
      expect(newCustomer.name, equals('Sanjay Agarwal'));
      expect(newCustomer.phone, equals('9829099999'));
      expect(newCustomer.notes, equals('Monthly regular guest'));

      // Re-adding with same phone should return existing customer and not duplicate
      final duplicate = container.read(customersProvider.notifier).addCustomer(
        name: 'Sanjay Agarwal Duplicate',
        phone: '9829099999',
      );
      expect(duplicate.id, equals(newCustomer.id));
      expect(container.read(customersProvider).length, equals(count + 1));
    });

    test('addPendingBill increases customer debt and updates ledger history', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final cust = container.read(customersProvider.notifier).addCustomer(
        name: 'Deepak Sharma',
        phone: '9876500000',
      );

      // Initial balance is 0
      expect(container.read(ledgerProvider.notifier).getCustomerBalance(cust.id), equals(0.0));

      // Add a pending bill of ₹1,850
      container.read(ledgerProvider.notifier).addPendingBill(
        customerId: cust.id,
        amount: 1850.0,
        referenceNumber: 'BILL-104',
        description: 'Table T03 Dinner (4 Persons)',
      );

      // Balance should be ₹1,850
      expect(container.read(ledgerProvider.notifier).getCustomerBalance(cust.id), equals(1850.0));

      // Add another bill of ₹450
      container.read(ledgerProvider.notifier).addPendingBill(
        customerId: cust.id,
        amount: 450.0,
        referenceNumber: 'BILL-105',
        description: 'Bikaji Namkeen Packets',
      );

      // Balance should be ₹2,300
      expect(container.read(ledgerProvider.notifier).getCustomerBalance(cust.id), equals(2300.0));

      // Record a partial payment settlement of ₹1,000
      container.read(ledgerProvider.notifier).recordPayment(
        customerId: cust.id,
        amount: 1000.0,
        paymentMode: 'UPI',
        referenceNumber: 'UPI-9871',
      );

      // Balance should now be ₹1,300
      expect(container.read(ledgerProvider.notifier).getCustomerBalance(cust.id), equals(1300.0));

      // Check transaction entries
      final entries = container.read(ledgerProvider.notifier).getCustomerEntries(cust.id);
      expect(entries.length, equals(3));
      expect(entries.where((e) => e.type == LedgerType.debit).length, equals(2));
      expect(entries.where((e) => e.type == LedgerType.credit).length, equals(1));
    });

    test('updateCustomer and deleteCustomer modify and clean customer state', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final cust = container.read(customersProvider.notifier).addCustomer(
        name: 'Manoj Kumar',
        phone: '9414011111',
        notes: 'Old shopkeeper',
      );

      // Update customer details
      container.read(customersProvider.notifier).updateCustomer(
        id: cust.id,
        name: 'Manoj Kumar (Verma Traders)',
        notes: 'VIP shopkeeper',
      );

      final updatedCust = container.read(customersProvider).firstWhere((c) => c.id == cust.id);
      expect(updatedCust.name, equals('Manoj Kumar (Verma Traders)'));
      expect(updatedCust.notes, equals('VIP shopkeeper'));
      expect(updatedCust.phone, equals('9414011111')); // unchanged

      // Delete customer
      container.read(customersProvider.notifier).deleteCustomer(cust.id);
      expect(container.read(customersProvider).any((c) => c.id == cust.id), isFalse);
    });

    test('updateEntry, deleteEntry, and simultaneous deleteEntries manage ledger accurately', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final cust = container.read(customersProvider.notifier).addCustomer(
        name: 'Kailash Chand',
        phone: '9828001122',
      );

      // Add 3 separate pending bills
      final b1 = container.read(ledgerProvider.notifier).addPendingBill(
        customerId: cust.id,
        amount: 500.0,
        referenceNumber: 'BILL-01',
        description: 'Snacks & Tea',
      );
      final b2 = container.read(ledgerProvider.notifier).addPendingBill(
        customerId: cust.id,
        amount: 1200.0,
        referenceNumber: 'BILL-02',
        description: 'Dinner Table T05',
      );
      final b3 = container.read(ledgerProvider.notifier).addPendingBill(
        customerId: cust.id,
        amount: 300.0,
        referenceNumber: 'BILL-03',
        description: 'Packaged Biscuits',
      );

      // Balance is 500 + 1200 + 300 = 2000
      expect(container.read(ledgerProvider.notifier).getCustomerBalance(cust.id), equals(2000.0));

      // 1. Update bill 1 amount from 500 to 750
      container.read(ledgerProvider.notifier).updateEntry(
        entryId: b1.id,
        amount: 750.0,
        description: 'Snacks, Tea & Cold Drinks',
      );
      expect(container.read(ledgerProvider.notifier).getCustomerBalance(cust.id), equals(2250.0));

      // 2. Delete single bill 3 (300)
      container.read(ledgerProvider.notifier).deleteEntry(b3.id);
      expect(container.read(ledgerProvider.notifier).getCustomerBalance(cust.id), equals(1950.0));

      // 3. Simultaneous batch deletion of b1 and b2
      container.read(ledgerProvider.notifier).deleteEntries([b1.id, b2.id]);
      expect(container.read(ledgerProvider.notifier).getCustomerBalance(cust.id), equals(0.0));
      expect(container.read(ledgerProvider.notifier).getCustomerEntries(cust.id), isEmpty);
    });
  });

  group('Feature #9: Supabase Cloud Database & Dynamic Data Integration', () {
    test('SupabaseService handles uninitialized local mode safely', () async {
      expect(SupabaseService.isInitialized, isFalse);

      final menu = await SupabaseService.fetchMenuItems();
      expect(menu, isNull);

      final customers = await SupabaseService.fetchCustomers();
      expect(customers, isNull);

      final ledger = await SupabaseService.fetchLedgerEntries();
      expect(ledger, isNull);

      final tables = await SupabaseService.fetchTables();
      expect(tables, isNull);
    });

    test('testConnection returns error when credentials are blank', () async {
      final res = await SupabaseService.testConnection(url: '', anonKey: '');
      expect(res.success, isFalse);
      expect(res.message, contains('Please enter both'));
    });

    test('Provider syncWithCloud does not corrupt local state when offline', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final initialCount = container.read(menuProvider).length;
      expect(initialCount, greaterThan(0));

      // Attempt cloud sync while offline
      await container.read(menuProvider.notifier).syncWithCloud();

      // State remains intact with local dataset
      expect(container.read(menuProvider).length, equals(initialCount));
    });

    test('SupabaseConnectionNotifier tracks connection state changes', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      expect(container.read(supabaseConnectionProvider), isFalse);

      container.read(supabaseConnectionProvider.notifier).setConnected(true);
      expect(container.read(supabaseConnectionProvider), isTrue);

      container.read(supabaseConnectionProvider.notifier).setConnected(false);
      expect(container.read(supabaseConnectionProvider), isFalse);
    });
  });

  group('Feature #10: Table & Floor Section Management (CRUD & Zones)', () {
    test('addTable creates new table with custom number, name, section, and capacity', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final initialCount = container.read(tablesProvider).length;

      final res = container.read(tablesProvider.notifier).addTable(
        tableNumber: 'G01',
        name: 'Garden Lawn Gazebo 1',
        section: 'Outdoor Lawn',
        capacity: 8,
      );

      expect(res.success, isTrue);
      expect(res.error, isNull);

      final tables = container.read(tablesProvider);
      expect(tables.length, equals(initialCount + 1));

      final created = tables.firstWhere((t) => t.tableNumber == 'G01');
      expect(created.name, equals('Garden Lawn Gazebo 1'));
      expect(created.displayName, equals('Garden Lawn Gazebo 1'));
      expect(created.section, equals('Outdoor Lawn'));
      expect(created.capacity, equals(8));
      expect(created.status, equals(TableState.available));
    });

    test('addTable prevents empty and duplicate table numbers', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      // Empty number
      final emptyRes = container.read(tablesProvider.notifier).addTable(
        tableNumber: '',
        name: 'Invalid Table',
        section: 'Indoor AC',
        capacity: 4,
      );
      expect(emptyRes.success, isFalse);
      expect(emptyRes.error, contains('cannot be empty'));

      // Duplicate number (T01 exists)
      final dupRes = container.read(tablesProvider.notifier).addTable(
        tableNumber: 't01', // case insensitive check
        name: 'Duplicate T01',
        section: 'Indoor AC',
        capacity: 4,
      );
      expect(dupRes.success, isFalse);
      expect(dupRes.error, contains('already exists'));
    });

    test('updateTableDetails modifies table name, number, section, and capacity accurately', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final t01 = container.read(tablesProvider).firstWhere((t) => t.tableNumber == 'T01');

      final updateRes = container.read(tablesProvider.notifier).updateTableDetails(
        id: t01.id,
        newTableNumber: 'VIP-01',
        newName: 'Presidential Window Suite',
        newSection: 'Rooftop Terrace',
        newCapacity: 12,
      );

      expect(updateRes.success, isTrue);

      final updated = container.read(tablesProvider).firstWhere((t) => t.id == t01.id);
      expect(updated.tableNumber, equals('VIP-01'));
      expect(updated.name, equals('Presidential Window Suite'));
      expect(updated.displayName, equals('Presidential Window Suite'));
      expect(updated.section, equals('Rooftop Terrace'));
      expect(updated.capacity, equals(12));
    });

    test('deleteTable successfully removes available table and safeguards occupied/merged tables', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      // Add temporary table
      container.read(tablesProvider.notifier).addTable(
        tableNumber: 'DEL-01',
        name: 'To Delete',
        section: 'Banquet Hall',
        capacity: 4,
      );

      final tempTable = container.read(tablesProvider).firstWhere((t) => t.tableNumber == 'DEL-01');

      // Attempt to delete when occupied
      container.read(tablesProvider.notifier).occupyTable('DEL-01', 2, 'ord-test');
      final occupiedDeleteRes = container.read(tablesProvider.notifier).deleteTable(tempTable.id);
      expect(occupiedDeleteRes.success, isFalse);
      expect(occupiedDeleteRes.error, contains('occupied or has an active order'));

      // Free table
      container.read(tablesProvider.notifier).releaseTable('DEL-01');

      // Delete successfully when available
      final safeDeleteRes = container.read(tablesProvider.notifier).deleteTable(tempTable.id);
      expect(safeDeleteRes.success, isTrue);

      final tableExists = container.read(tablesProvider).any((t) => t.tableNumber == 'DEL-01');
      expect(tableExists, isFalse);
    });

    test('toggleTableEnabled and releaseTable manage activation and preserve capacities', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final t02 = container.read(tablesProvider).firstWhere((t) => t.tableNumber == 'T02');
      expect(t02.isEnabled, isTrue);
      final originalCapacity = t02.capacity;

      // Toggle off
      container.read(tablesProvider.notifier).toggleTableEnabled('T02');
      expect(container.read(tablesProvider).firstWhere((t) => t.tableNumber == 'T02').isEnabled, isFalse);

      // Toggle back on
      container.read(tablesProvider.notifier).toggleTableEnabled('T02');
      expect(container.read(tablesProvider).firstWhere((t) => t.tableNumber == 'T02').isEnabled, isTrue);

      // Occupy and release - verify capacity is preserved (not reset to default 6)
      container.read(tablesProvider.notifier).occupyTable('T02', 4, 'order-123');
      container.read(tablesProvider.notifier).releaseTable('T02');
      final released = container.read(tablesProvider).firstWhere((t) => t.tableNumber == 'T02');
      expect(released.status, equals(TableState.available));
      expect(released.capacity, equals(originalCapacity));
    });
  });
}

