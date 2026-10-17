import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mehta_restaurant/features/accounts/accounts_screen.dart';
import 'package:mehta_restaurant/models/models.dart';
import 'package:mehta_restaurant/providers/restaurant_provider.dart';

void main() {
  testWidgets('Test Add Bill button in AccountsScreen desktop', (tester) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          home: AccountsScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Look for Add Bill button
    final addBillFinder = find.text('+ Add Bill');
    expect(addBillFinder, findsOneWidget);

    // Tap Add Bill
    await tester.tap(addBillFinder);
    await tester.pumpAndSettle();

    // Verify dialog opened
    expect(find.text('Add Pending Bill (Debit Entry)'), findsOneWidget);

    // Enter amount
    final amountField = find.widgetWithText(TextField, 'Bill Amount (₹) *');
    expect(amountField, findsOneWidget);
    await tester.enterText(amountField, '500');
    await tester.pumpAndSettle();

    // Tap 'Add Bill to Khata'
    final submitButton = find.text('Add Bill to Khata');
    expect(submitButton, findsOneWidget);
    await tester.tap(submitButton);
    await tester.pumpAndSettle();

    // Check if bill was added
    final entries = container.read(ledgerProvider);
    final hasNewBill = entries.any((e) => e.amount == 500 && e.type == LedgerType.debit);
    expect(hasNewBill, isTrue);
  });
}
