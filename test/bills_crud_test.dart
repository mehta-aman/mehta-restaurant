import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mehta_restaurant/models/models.dart';
import 'package:mehta_restaurant/providers/restaurant_provider.dart';
import 'package:mehta_restaurant/features/bills/bills_screen.dart';
import 'package:mehta_restaurant/features/bills/bill_detail_dialog.dart';

void main() {
  group('Bills & Invoices CRUD and Void Logic Tests', () {
    test('InvoicesNotifier supports add, single delete, bulk delete, clear all, and void', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final inv1 = Invoice(
        id: 'inv_1',
        invoiceNumber: 'MR-000001',
        tableNumber: 'T01',
        customerName: 'Aman Mehta',
        customerPhone: '9876543210',
        items: [
          OrderItem(
            id: 'it_1',
            menuItemId: 'm1',
            name: 'Paneer Butter Masala',
            unitPrice: 280,
            quantity: 2,
          ),
        ],
        subtotal: 560,
        taxAmount: 28,
        grandTotal: 588,
        cashPaid: 588,
        upiPaid: 0,
        creditAmount: 0,
      );

      final inv2 = Invoice(
        id: 'inv_2',
        invoiceNumber: 'MR-000002',
        tableNumber: 'T04',
        customerName: 'Raj Sharma',
        customerPhone: '9829012345',
        items: [
          OrderItem(
            id: 'it_2',
            menuItemId: 'm2',
            name: 'Dal Makhani',
            unitPrice: 240,
            quantity: 1,
          ),
        ],
        subtotal: 240,
        taxAmount: 12,
        grandTotal: 252,
        cashPaid: 0,
        upiPaid: 0,
        creditAmount: 252,
      );

      final inv3 = Invoice(
        id: 'inv_3',
        invoiceNumber: 'MR-000003',
        tableNumber: 'T06',
        customerName: 'Gupta Family',
        items: const [],
        subtotal: 100,
        taxAmount: 5,
        grandTotal: 105,
        cashPaid: 105,
        upiPaid: 0,
        creditAmount: 0,
      );

      final notifier = container.read(invoicesProvider.notifier);

      // 1. Add invoices
      notifier.addInvoice(inv1);
      notifier.addInvoice(inv2);
      notifier.addInvoice(inv3);

      var invoices = container.read(invoicesProvider);
      expect(invoices.length, equals(3));

      // 2. Void invoice #2
      final voidRes = await notifier.voidInvoice('MR-000002', 'Customer dispute on portion size');
      expect(voidRes.success, isTrue);

      invoices = container.read(invoicesProvider);
      final voidedInv = invoices.firstWhere((i) => i.invoiceNumber == 'MR-000002');
      expect(voidedInv.isVoided, isTrue);
      expect(voidedInv.voidReason, equals('Customer dispute on portion size'));

      // 3. Delete single invoice
      final delRes = await notifier.deleteInvoice('inv_3');
      expect(delRes, isTrue);
      invoices = container.read(invoicesProvider);
      expect(invoices.length, equals(2));
      expect(invoices.any((i) => i.id == 'inv_3'), isFalse);

      // 4. Bulk delete invoices
      final bulkRes = await notifier.bulkDeleteInvoices(['inv_1', 'inv_2']);
      expect(bulkRes, isTrue);
      invoices = container.read(invoicesProvider);
      expect(invoices.isEmpty, isTrue);

      // 5. Clear all invoices
      notifier.addInvoice(inv1);
      expect(container.read(invoicesProvider).length, equals(1));
      await notifier.clearAllInvoices();
      expect(container.read(invoicesProvider).isEmpty, isTrue);
    });

    testWidgets('BillsScreen renders header, stat cards, invoices table, and opens detail dialog', (tester) async {
      final inv = Invoice(
        id: 'inv_test_100',
        invoiceNumber: 'MR-009999',
        tableNumber: 'T05',
        customerName: 'Vikram Seth',
        customerPhone: '9811122233',
        items: [
          OrderItem(
            id: 'it_100',
            menuItemId: 'm10',
            name: 'Butter Naan',
            unitPrice: 40,
            quantity: 4,
          ),
        ],
        subtotal: 160,
        taxAmount: 8,
        grandTotal: 168,
        cashPaid: 168,
        upiPaid: 0,
        creditAmount: 0,
      );

      final container = ProviderContainer(
        overrides: [
          invoicesProvider.overrideWith(() => _TestInvoicesNotifier([inv])),
        ],
      );
      addTearDown(container.dispose);

      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: BillsScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Check title and metrics
      expect(find.text('Bills & Invoices Management'), findsOneWidget);
      expect(find.text('Total Bills'), findsOneWidget);
      expect(find.text('MR-009999'), findsOneWidget);
      expect(find.text('Vikram Seth'), findsOneWidget);
      expect(find.text('T05'), findsWidgets);
      expect(find.text('PAID'), findsWidgets);

      // Click on row to open BillDetailDialog
      await tester.tap(find.text('MR-009999'));
      await tester.pumpAndSettle();

      // Check dialog content
      expect(find.byType(BillDetailDialog), findsOneWidget);
      expect(find.text('Butter Naan'), findsOneWidget);
      expect(find.text('x4'), findsOneWidget);
      expect(find.text('Reject Bill'), findsOneWidget);
      expect(find.text('Print Receipt'), findsOneWidget);
    });
  });
}

class _TestInvoicesNotifier extends InvoicesNotifier {
  final List<Invoice> initialInvoices;
  _TestInvoicesNotifier(this.initialInvoices);

  @override
  List<Invoice> build() => initialInvoices;
}
