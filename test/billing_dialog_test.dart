import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mehta_restaurant/features/billing/billing_dialog.dart';
import 'package:mehta_restaurant/models/models.dart';

void main() {
  final testOrder = Order(
    id: 'ord_1',
    orderNumber: 'ORD-101',
    tableNumber: 'T01',
    items: [
      OrderItem(
        id: 'item_1',
        menuItemId: '1',
        name: 'Paneer Butter Masala',
        unitPrice: 250,
        quantity: 2,
      ),
    ],
    createdAt: DateTime.now(),
    customerName: 'Raj Sharma',
    customerPhone: '9876543210',
  );

  final sizes = [
    const Size(320, 568),
    const Size(360, 640),
    const Size(375, 667),
    const Size(390, 844),
    const Size(768, 1024),
    const Size(1280, 800),
  ];

  for (final size in sizes) {
    testWidgets('Test BillingDialog on size ${size.width}x${size.height}', (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: BillingDialog(order: testOrder),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Switch to Split Bill mode
      final splitBillTab = find.textContaining('Split');
      expect(splitBillTab, findsOneWidget);
      await tester.tap(splitBillTab);
      await tester.pumpAndSettle();

      // Switch back to Single Payer
      final singlePayerTab = find.text('Single Payer');
      expect(singlePayerTab, findsOneWidget);
      await tester.tap(singlePayerTab);
      await tester.pumpAndSettle();

      // Enter 2000 cash to trigger change due UI
      final cashField = find.widgetWithText(TextField, 'Cash Received (₹)');
      if (cashField.evaluate().isNotEmpty) {
        await tester.ensureVisible(cashField);
        await tester.enterText(cashField, '2000');
        await tester.pumpAndSettle();
        expect(find.textContaining('Return Change'), findsOneWidget);
      }
    });
  }
}
