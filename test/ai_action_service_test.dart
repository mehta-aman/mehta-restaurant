import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mehta_restaurant/models/models.dart';
import 'package:mehta_restaurant/providers/restaurant_provider.dart';
import 'package:mehta_restaurant/services/ai/ai_action_service.dart';
import 'package:mehta_restaurant/services/ai/ai_confirmation_manager.dart';
import 'package:mehta_restaurant/services/ai/ai_tool_registry.dart';

void main() {
  setUp(() {
    AiToolRegistry.initialize();
    AiConfirmationManager.clearAll();
  });

  const ownerStaff = StaffMember(
    id: 'staff-owner',
    name: 'Aman Mehta',
    role: StaffRole.owner,
    pin: '1234',
  );

  const managerStaff = StaffMember(
    id: 'staff-manager',
    name: 'Father Mehta',
    role: StaffRole.manager,
    pin: '2345',
  );

  const cashierStaff = StaffMember(
    id: 'staff-cashier',
    name: 'Cashier Rohan',
    role: StaffRole.cashier,
    pin: '3456',
  );

  const waiterStaff = StaffMember(
    id: 'staff-waiter',
    name: 'Waiter Ramesh',
    role: StaffRole.waiter,
    pin: '4567',
  );

  const kitchenStaff = StaffMember(
    id: 'staff-kitchen',
    name: 'Chef Vikas',
    role: StaffRole.kitchen,
    pin: '5678',
  );

  group('AiActionService - Preparation Tests', () {
    test('prepare_menu_item_create creates token and snapshot for Owner', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final res = await AiActionService.prepareAction(
        toolName: 'prepare_menu_item_create',
        arguments: {
          'name': 'Shahi Paneer Deluxe',
          'category': 'Main Course',
          'price': 320.0,
          'is_veg': true,
        },
        staff: ownerStaff,
        ref: container,
      );

      expect(res.success, isTrue);
      expect(res.confirmationToken, isNotNull);
      expect(res.data['name'], equals('Shahi Paneer Deluxe'));
      expect(res.data['price'], equals(320.0));
      expect(res.data['is_duplicate'], isFalse);
    });

    test('prepare_menu_item_create rejects Waiter under RBAC', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final res = await AiActionService.prepareAction(
        toolName: 'prepare_menu_item_create',
        arguments: {
          'name': 'Garlic Naan',
          'category': 'Breads',
          'price': 60.0,
        },
        staff: waiterStaff,
        ref: container,
      );

      expect(res.success, isFalse);
      expect(res.confirmationToken, isNull);
      expect(res.summary, contains('Access Denied'));
    });

    test('prepare_menu_item_create validates empty name and negative price', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final emptyName = await AiActionService.prepareAction(
        toolName: 'prepare_menu_item_create',
        arguments: {'name': '', 'price': 100.0},
        staff: ownerStaff,
        ref: container,
      );
      expect(emptyName.success, isFalse);
      expect(emptyName.summary, contains('name cannot be empty'));

      final negPrice = await AiActionService.prepareAction(
        toolName: 'prepare_menu_item_create',
        arguments: {'name': 'Lassi', 'price': -10.0},
        staff: ownerStaff,
        ref: container,
      );
      expect(negPrice.success, isFalse);
      expect(negPrice.summary, contains('greater than or equal to 0'));
    });

    test('prepare_menu_item_update generates price diff for Manager', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final menu = container.read(menuProvider);
      final firstDish = menu.first;

      final res = await AiActionService.prepareAction(
        toolName: 'prepare_menu_item_update',
        arguments: {
          'name_or_id': firstDish.name,
          'new_price': firstDish.price + 50.0,
        },
        staff: managerStaff,
        ref: container,
      );

      expect(res.success, isTrue);
      expect(res.confirmationToken, isNotNull);
      expect(res.data['diff']['price']['old'], equals(firstDish.price));
      expect(res.data['diff']['price']['new'], equals(firstDish.price + 50.0));
    });

    test('prepare_menu_item_update denies Kitchen Chef from changing price', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final menu = container.read(menuProvider);
      final firstDish = menu.first;

      final res = await AiActionService.prepareAction(
        toolName: 'prepare_menu_item_update',
        arguments: {
          'name_or_id': firstDish.name,
          'new_price': 999.0,
        },
        staff: kitchenStaff,
        ref: container,
      );

      expect(res.success, isFalse);
      expect(res.summary, contains('Kitchen staff can only toggle dish availability, not edit prices'));
    });

    test('prepare_bulk_menu_import parses rows and identifies duplicates', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      const rawCsv = '''
Name, Category, Price, Veg
Tandoori Roti, Breads, 20, Veg
Chicken Tikka, Starters, 280, Non-Veg
Dal Tadka, Main Course, 180, Veg
''';

      final res = await AiActionService.prepareAction(
        toolName: 'prepare_bulk_menu_import',
        arguments: {
          'raw_content': rawCsv,
          'mode': 'upsert',
        },
        staff: ownerStaff,
        ref: container,
      );

      expect(res.success, isTrue);
      expect(res.confirmationToken, isNotNull);
      expect(res.data['total_parsed'], equals(3));
    });

    test('prepare_table_status_change prepares occupancy and seating', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final res = await AiActionService.prepareAction(
        toolName: 'prepare_table_status_change',
        arguments: {
          'table_number': 'T02',
          'action': 'occupy',
          'guests': 4,
        },
        staff: waiterStaff,
        ref: container,
      );

      expect(res.success, isTrue);
      expect(res.confirmationToken, isNotNull);
      expect(res.data['table_number'], equals('T02'));
      expect(res.data['guests'], equals(4));
    });

    test('prepare_payment calculates Khata balance deduction correctly', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final customers = container.read(customersProvider);
      final customer = customers.first;

      final initialBal = container.read(ledgerProvider.notifier).getCustomerBalance(customer.id);

      final res = await AiActionService.prepareAction(
        toolName: 'prepare_payment',
        arguments: {
          'customer_name_or_id': customer.name,
          'amount': 200.0,
          'payment_mode': 'UPI',
        },
        staff: cashierStaff,
        ref: container,
      );

      expect(res.success, isTrue);
      expect(res.confirmationToken, isNotNull);
      expect(res.data['old_balance'], equals(initialBal));
      expect(res.data['new_balance'], equals((initialBal - 200.0).clamp(0.0, double.infinity)));
    });
  });

  group('AiActionService - Two-Step Execution & Audit Lifecycle', () {
    test('End-to-End: Prepare menu create -> execute with token -> updates catalog & logs audit', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      // 1. Prepare
      final prep = await AiActionService.prepareAction(
        toolName: 'prepare_menu_item_create',
        arguments: {
          'name': 'Kesar Pista Kulfi',
          'category': 'Desserts',
          'price': 120.0,
          'is_veg': true,
        },
        staff: ownerStaff,
        ref: container,
      );

      expect(prep.success, isTrue);
      final token = prep.confirmationToken!.token;

      // 2. Execute with token
      final exec = await AiActionService.executeConfirmedAction(
        confirmationToken: token,
        staff: ownerStaff,
        ref: container,
      );

      expect(exec.success, isTrue);
      expect(exec.summary, contains('Kesar Pista Kulfi'));

      // 3. Verify in catalog
      final menu = container.read(menuProvider);
      expect(menu.any((m) => m.name == 'Kesar Pista Kulfi'), isTrue);

      // 4. Verify audit log entry
      expect(AiActionService.auditLogs.isNotEmpty, isTrue);
      expect(AiActionService.auditLogs.first.toolName, equals('prepare_menu_item_create'));
      expect(AiActionService.auditLogs.first.success, isTrue);
    });

    test('Replay Protection: Consuming token a second time is rejected', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final prep = await AiActionService.prepareAction(
        toolName: 'prepare_customer_create',
        arguments: {
          'name': 'Vikram Rathore',
          'phone': '9876543210',
        },
        staff: cashierStaff,
        ref: container,
      );

      final token = prep.confirmationToken!.token;

      // First execution succeeds
      final firstExec = await AiActionService.executeConfirmedAction(
        confirmationToken: token,
        staff: cashierStaff,
        ref: container,
      );
      expect(firstExec.success, isTrue);

      // Second execution must be rejected
      final secondExec = await AiActionService.executeConfirmedAction(
        confirmationToken: token,
        staff: cashierStaff,
        ref: container,
      );
      expect(secondExec.success, isFalse);
      expect(secondExec.summary, contains('invalid or has already been used'));
    });

    test('Cross-Staff Protection: Non-owner staff cannot consume another staff\'s token', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final prep = await AiActionService.prepareAction(
        toolName: 'prepare_table_status_change',
        arguments: {
          'table_number': 'T01',
          'action': 'occupy',
          'guests': 2,
        },
        staff: waiterStaff,
        ref: container,
      );

      final token = prep.confirmationToken!.token;

      // Cashier attempts to consume Waiter's token -> rejected
      final hijackedExec = await AiActionService.executeConfirmedAction(
        confirmationToken: token,
        staff: cashierStaff,
        ref: container,
      );

      expect(hijackedExec.success, isFalse);
      expect(hijackedExec.summary, contains('Security Error: This action was prepared by another staff member'));
    });
  });
}
