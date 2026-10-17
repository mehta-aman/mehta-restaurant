import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mehta_restaurant/models/models.dart';
import 'package:mehta_restaurant/providers/restaurant_provider.dart';
import 'package:mehta_restaurant/services/supabase_service.dart';
import 'package:mehta_restaurant/services/supabase_schema_source.dart';

void main() {
  group('Phase 2B Backend Architecture & Security Tests', () {
    test('SupabaseService operates in standalone Local Mode when uninitialized', () {
      expect(SupabaseService.isInitialized, isFalse);
    });

    test('SupabaseService.verifyStaffPin fails safely to offline mode when uninitialized', () async {
      final res = await SupabaseService.verifyStaffPin(pin: '1234');
      expect(res.success, isFalse);
      expect(res.locked, isFalse);
      expect(res.message, contains('offline'));
    });

    test('SupabaseService.recordKhataSettlement fails safely to offline mode when uninitialized', () async {
      final res = await SupabaseService.recordKhataSettlement(customerId: 'c1', amount: 500);
      expect(res.success, isFalse);
      expect(res.message, contains('offline'));
    });

    test('SupabaseService.voidInvoice fails safely to offline mode when uninitialized', () async {
      final res = await SupabaseService.voidInvoice(invoiceNumber: 'MR-001001', reason: 'Test void');
      expect(res.success, isFalse);
      expect(res.message, contains('offline'));
    });

    test('SupabaseService.saveInvoice fails safely to offline mode when uninitialized', () async {
      final invoice = Invoice(
        id: 'test-inv-1',
        invoiceNumber: 'MR-001001',
        tableNumber: 'T01',
        subtotal: 500,
        taxAmount: 25,
        grandTotal: 525,
        cashPaid: 525,
        upiPaid: 0,
        creditAmount: 0,
        items: const [],
        issuedAt: DateTime.now(),
      );
      final success = await SupabaseService.saveInvoice(invoice);
      expect(success, isFalse);
    });

    test('Staff profiles match approved 8 staff members with strict RBAC', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final staffList = container.read(staffListProvider);

      expect(staffList.length, equals(8));

      final owner = staffList.firstWhere((s) => s.role == StaffRole.owner);
      expect(owner.name, equals('Aman Mehta'));
      expect(owner.canEditMenu, isTrue);
      expect(owner.canManageSettings, isTrue);
      expect(owner.canManageAccounts, isTrue);

      final manager = staffList.firstWhere((s) => s.role == StaffRole.manager);
      expect(manager.canEditMenu, isTrue);
      expect(manager.canManageAccounts, isTrue);

      final cashier = staffList.firstWhere((s) => s.role == StaffRole.cashier);
      expect(cashier.canEditMenu, isFalse);
      expect(cashier.canManageAccounts, isTrue);
      expect(cashier.canBill, isTrue);

      final waiter = staffList.firstWhere((s) => s.role == StaffRole.waiter);
      expect(waiter.canEditMenu, isFalse);
      expect(waiter.canManageAccounts, isFalse);
      expect(waiter.canBill, isTrue);

      final kitchen = staffList.firstWhere((s) => s.role == StaffRole.kitchen);
      expect(kitchen.canEditMenu, isFalse);
      expect(kitchen.canManageAccounts, isFalse);
      expect(kitchen.canBill, isFalse);
    });

    test('Embedded authoritative SQL schema source contains required Phase 2B structures', () {
      expect(kSupabaseSchemaSql, contains('CREATE SEQUENCE IF NOT EXISTS invoice_number_seq START WITH 1001'));
      expect(kSupabaseSchemaSql, contains('finalize_invoice_transaction'));
      expect(kSupabaseSchemaSql, contains('record_khata_settlement'));
      expect(kSupabaseSchemaSql, contains('void_invoice_transaction'));
      expect(kSupabaseSchemaSql, contains('verify_staff_pin'));
      expect(kSupabaseSchemaSql, contains('auth_pin_lockouts'));
      expect(kSupabaseSchemaSql, contains('trg_enforce_menu_update'));
      expect(kSupabaseSchemaSql, contains('get_auth_role()'));
    });
  });
}
