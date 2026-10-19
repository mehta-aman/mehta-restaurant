import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mehta_restaurant/models/models.dart';
import 'package:mehta_restaurant/providers/restaurant_provider.dart';
import 'package:mehta_restaurant/services/ai/ai_read_operations_service.dart';

void main() {
  group('Phase 3: AI Read Operations Service Tests', () {
    late ProviderContainer container;

    setUp(() {
      container = ProviderContainer();
    });

    tearDown(() {
      container.dispose();
    });

    test('search_menu finds items by query and veg filter', () async {
      const owner = StaffMember(id: 's1', name: 'Aman Mehta', role: StaffRole.owner, pin: '1234');

      final res = await AiReadOperationsService.executeReadTool(
        toolName: 'search_menu',
        arguments: {'query': 'Paneer', 'is_veg': true},
        staff: owner,
        ref: container,
      );

      expect(res.success, isTrue);
      expect(res.data['count'], greaterThan(0));
      expect(res.summary, contains('Paneer'));
    });

    test('list_categories returns all menu categories and item counts', () async {
      const owner = StaffMember(id: 's1', name: 'Aman Mehta', role: StaffRole.owner, pin: '1234');

      final res = await AiReadOperationsService.executeReadTool(
        toolName: 'list_categories',
        arguments: {},
        staff: owner,
        ref: container,
      );

      expect(res.success, isTrue);
      expect(res.summary, contains('Main Course'));
      expect(res.data['categories'], isNotEmpty);
    });

    test('get_table_status returns accurate floor metrics', () async {
      const waiter = StaffMember(id: 's4', name: 'Ramesh', role: StaffRole.waiter, pin: '1001');

      final res = await AiReadOperationsService.executeReadTool(
        toolName: 'get_table_status',
        arguments: {},
        staff: waiter,
        ref: container,
      );

      expect(res.success, isTrue);
      expect(res.data['total'], equals(10));
      expect(res.summary, contains('Dining Floor Status'));
    });

    test('get_sales_report calculates net sales and tender breakdown accurately', () async {
      const owner = StaffMember(id: 's1', name: 'Aman Mehta', role: StaffRole.owner, pin: '1234');

      // Seed 2 invoices (1 valid, 1 voided)
      container.read(invoicesProvider.notifier).addInvoice(
        Invoice(
          id: 'inv-1',
          invoiceNumber: 'MR-001001',
          tableNumber: 'T01',
          subtotal: 500,
          taxAmount: 25,
          grandTotal: 525,
          cashPaid: 300,
          upiPaid: 225,
          creditAmount: 0,
          items: const [],
          issuedAt: DateTime.now(),
        ),
      );

      container.read(invoicesProvider.notifier).addInvoice(
        Invoice(
          id: 'inv-2',
          invoiceNumber: 'MR-001002',
          tableNumber: 'T02',
          subtotal: 400,
          taxAmount: 20,
          grandTotal: 420,
          cashPaid: 420,
          upiPaid: 0,
          creditAmount: 0,
          items: const [],
          isVoided: true,
          voidReason: 'Test void bill',
          issuedAt: DateTime.now(),
        ),
      );

      final res = await AiReadOperationsService.executeReadTool(
        toolName: 'get_sales_report',
        arguments: {'period': 'today'},
        staff: owner,
        ref: container,
      );

      expect(res.success, isTrue);
      expect(res.data['net_sales'], equals(525.0)); // excludes voided 420.0
      expect(res.data['cash_collected'], equals(300.0));
      expect(res.data['upi_collected'], equals(225.0));
      expect(res.data['voided_count'], equals(1));
    });

    test('get_sales_report is strictly DENIED to Waiter and Kitchen roles', () async {
      const waiter = StaffMember(id: 's4', name: 'Ramesh', role: StaffRole.waiter, pin: '1001');

      final res = await AiReadOperationsService.executeReadTool(
        toolName: 'get_sales_report',
        arguments: {'period': 'today'},
        staff: waiter,
        ref: container,
      );

      expect(res.success, isFalse);
      expect(res.summary, contains('Access Denied'));
      expect(res.errorMessage, contains('WAITER'));
    });

    test('get_customer_balances is strictly DENIED to Kitchen Chef', () async {
      const chef = StaffMember(id: 's7', name: 'Kitchen Chef', role: StaffRole.kitchen, pin: '3333');

      final res = await AiReadOperationsService.executeReadTool(
        toolName: 'get_customer_balances',
        arguments: {},
        staff: chef,
        ref: container,
      );

      expect(res.success, isFalse);
      expect(res.summary, contains('Access Denied'));
    });

    test('get_restaurant_settings returns non-sensitive restaurant profile', () async {
      const waiter = StaffMember(id: 's4', name: 'Ramesh', role: StaffRole.waiter, pin: '1001');

      final res = await AiReadOperationsService.executeReadTool(
        toolName: 'get_restaurant_settings',
        arguments: {},
        staff: waiter,
        ref: container,
      );

      expect(res.success, isTrue);
      expect(res.summary, contains('Restaurant Profile'));
      expect(res.data['restaurant_name'], isNotNull);
    });
  });
}
