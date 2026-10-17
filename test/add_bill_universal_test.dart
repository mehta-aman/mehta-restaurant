import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mehta_restaurant/features/accounts/accounts_screen.dart';
import 'package:mehta_restaurant/models/models.dart';
import 'package:mehta_restaurant/providers/restaurant_provider.dart';

void main() {
  testWidgets('Test Add Bill from AppBar when no customer is selected (universal dropdown)', (tester) async {
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

    // Verify Add Bill button in AppBar is present even before selecting a customer
    final addBillButton = find.text('+ Add Bill');
    expect(addBillButton, findsOneWidget);

    await tester.tap(addBillButton);
    await tester.pumpAndSettle();

    // Dialog should show with dropdown customer selector
    expect(find.text('Add Pending Bill (Debit Entry)'), findsOneWidget);
    expect(find.text('Select Customer Account *'), findsOneWidget);

    // Enter bill amount
    final amountField = find.widgetWithText(TextField, 'Bill Amount (₹) *');
    expect(amountField, findsOneWidget);
    await tester.enterText(amountField, '1200');
    await tester.pumpAndSettle();

    // Submit bill
    final submitButton = find.text('Add Bill to Khata');
    expect(submitButton, findsOneWidget);
    await tester.tap(submitButton);
    await tester.pumpAndSettle();

    // Verify bill was recorded in ledger
    final entries = container.read(ledgerProvider);
    final hasNewBill = entries.any((e) => e.amount == 1200 && e.type == LedgerType.debit);
    expect(hasNewBill, isTrue);
  });

  testWidgets('Test Add Bill from mobile AppBar icon button', (tester) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    tester.view.physicalSize = const Size(390, 844);
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

    // Verify mobile Add Bill icon button is present in AppBar
    final addBillIcon = find.byTooltip('Add Bill');
    expect(addBillIcon, findsOneWidget);

    await tester.tap(addBillIcon);
    await tester.pumpAndSettle();

    // Dialog should open
    expect(find.text('Add Pending Bill (Debit Entry)'), findsOneWidget);

    // Enter amount
    final amountField = find.widgetWithText(TextField, 'Bill Amount (₹) *');
    await tester.enterText(amountField, '850');
    await tester.pumpAndSettle();

    // Submit
    final submitButton = find.text('Add Bill to Khata');
    await tester.tap(submitButton);
    await tester.pumpAndSettle();

    // Verify bill exists
    final entries = container.read(ledgerProvider);
    expect(entries.any((e) => e.amount == 850 && e.type == LedgerType.debit), isTrue);
  });
}
