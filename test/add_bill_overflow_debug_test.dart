import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mehta_restaurant/features/accounts/accounts_screen.dart';

void main() {
  final sizes = [
    const Size(320, 568), // iPhone SE 1st gen
    const Size(360, 640), // Standard Android
    const Size(375, 667), // iPhone 8/SE 2
    const Size(390, 844), // iPhone 12/13/14
    const Size(414, 896), // iPhone 11 XR
    const Size(768, 1024), // iPad portrait
    const Size(1024, 768), // iPad landscape
    const Size(1280, 800), // Desktop
  ];

  for (final size in sizes) {
    testWidgets('Test clicking Add Bill on size ${size.width}x${size.height}', (tester) async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
        tester.view.resetViewInsets();
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
      final addBillIconFinder = find.byTooltip('Add Bill');
      final addPendingFinder = find.text('Add Pending Bill / Debit');

      Finder? targetFinder;
      if (addBillFinder.evaluate().isNotEmpty) {
        targetFinder = addBillFinder;
      } else if (addBillIconFinder.evaluate().isNotEmpty) {
        targetFinder = addBillIconFinder;
      } else if (addPendingFinder.evaluate().isNotEmpty) {
        targetFinder = addPendingFinder;
      }

      expect(targetFinder, isNotNull);
      await tester.tap(targetFinder!);
      await tester.pumpAndSettle();

      // Dialog should be open
      expect(find.text('Add Pending Bill (Debit Entry)'), findsOneWidget);

      // Now simulate keyboard showing up (e.g. 250px height)
      tester.view.viewInsets = const FakeViewPadding(bottom: 250);
      await tester.pumpAndSettle();

      // Enter amount
      final amountField = find.widgetWithText(TextField, 'Bill Amount (₹) *');
      expect(amountField, findsOneWidget);
      await tester.enterText(amountField, '750');
      await tester.pumpAndSettle();

      // Reset insets
      tester.view.viewInsets = FakeViewPadding.zero;
      await tester.pumpAndSettle();

      // Tap Add Bill to Khata
      final submitBtn = find.text('Add Bill to Khata');
      expect(submitBtn, findsOneWidget);
      await tester.tap(submitBtn);
      await tester.pumpAndSettle();

      // Dialog should be closed, and snackbar shown
      expect(find.text('Add Pending Bill (Debit Entry)'), findsNothing);
      expect(find.textContaining('Pending bill of ₹750.00 added'), findsOneWidget);

      // If customer is selected and detail is visible, test the "Add Pending Bill / Debit" action button too
      final addPendingBtn = find.text('Add Pending Bill / Debit');
      if (addPendingBtn.evaluate().isNotEmpty) {
        await tester.tap(addPendingBtn);
        await tester.pumpAndSettle();
        expect(find.text('Add Pending Bill (Debit Entry)'), findsOneWidget);

        // Cancel dialog
        await tester.tap(find.text('Cancel'));
        await tester.pumpAndSettle();
        expect(find.text('Add Pending Bill (Debit Entry)'), findsNothing);
      }
    });
  }
}
