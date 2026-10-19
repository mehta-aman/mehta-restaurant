import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mehta_restaurant/features/staff/staff_login_window.dart';
import 'package:mehta_restaurant/models/models.dart';
import 'package:mehta_restaurant/providers/restaurant_provider.dart';

void main() {
  group('StaffSessionNotifier Unit Tests', () {
    test('Can log in with valid PIN and updates currentStaffProvider', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      // Initially logged in (in test mode) or can log in
      final success = container.read(staffSessionProvider.notifier).loginWithPin('1234');
      expect(success, isTrue);

      final current = container.read(currentStaffProvider);
      expect(current.role, equals(StaffRole.owner));
      expect(current.name, equals('Aman Mehta'));

      // Switch to Kitchen Chef (PIN: 3333)
      final kitchenSuccess = container.read(staffSessionProvider.notifier).loginWithPin('3333');
      expect(kitchenSuccess, isTrue);

      final kitchenStaff = container.read(currentStaffProvider);
      expect(kitchenStaff.role, equals(StaffRole.kitchen));
      expect(kitchenStaff.name, contains('Kitchen Chef'));

      // Logout
      container.read(staffSessionProvider.notifier).logout();
      expect(container.read(staffSessionProvider), isNull);
    });

    test('Rejects invalid PIN without altering session', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      container.read(staffSessionProvider.notifier).logout();
      expect(container.read(staffSessionProvider), isNull);

      final fail = container.read(staffSessionProvider.notifier).loginWithPin('0000');
      expect(fail, isFalse);
      expect(container.read(staffSessionProvider), isNull);
    });
  });

  group('StaffLoginWindow Widget Tests', () {
    testWidgets('Renders StaffLoginWindow and displays staff profiles and keypad', (tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: StaffLoginWindow(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify Brand and Terminal Header
      expect(find.text('MEHTA RESTAURANT'), findsOneWidget);
      expect(find.text('Enter Staff PIN'), findsOneWidget);

      // Verify keypad digits exist
      expect(find.text('1'), findsWidgets);
      expect(find.text('2'), findsWidgets);
      expect(find.text('C'), findsOneWidget);
      expect(find.text('⌫'), findsOneWidget);
    });

    testWidgets('Tapping keypad digits and entering correct PIN logs in successfully', (tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      StaffMember? loggedInStaff;

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: StaffLoginWindow(
              onLoginSuccess: (staff) {
                loggedInStaff = staff;
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Enter Owner PIN: 1234
      // Tap '1'
      await tester.tap(find.widgetWithText(InkWell, '1').first);
      await tester.pump();
      // Tap '2'
      await tester.tap(find.widgetWithText(InkWell, '2').first);
      await tester.pump();
      // Tap '3'
      await tester.tap(find.widgetWithText(InkWell, '3').first);
      await tester.pump();
      // Tap '4'
      await tester.tap(find.widgetWithText(InkWell, '4').first);
      await tester.pumpAndSettle();

      expect(loggedInStaff, isNotNull);
      expect(loggedInStaff!.role, equals(StaffRole.owner));
      expect(loggedInStaff!.name, equals('Aman Mehta'));
    });

    testWidgets('Entering incorrect PIN shows error message', (tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      StaffMember? loggedInStaff;

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: StaffLoginWindow(
              onLoginSuccess: (staff) {
                loggedInStaff = staff;
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Enter Wrong PIN: 0000
      await tester.tap(find.widgetWithText(InkWell, '0').first);
      await tester.pump();
      await tester.tap(find.widgetWithText(InkWell, '0').first);
      await tester.pump();
      await tester.tap(find.widgetWithText(InkWell, '0').first);
      await tester.pump();
      await tester.tap(find.widgetWithText(InkWell, '0').first);
      await tester.pumpAndSettle();

      expect(loggedInStaff, isNull);
      expect(find.textContaining('Incorrect PIN'), findsOneWidget);
    });
  });
}
