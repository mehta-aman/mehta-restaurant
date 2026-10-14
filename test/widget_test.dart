import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mehta_restaurant/main.dart';

void main() {
  testWidgets('Mehta Restaurant smoke test - loads tables', (WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MehtaRestaurantApp(),
      ),
    );

    // Verify app title or tables load
    await tester.pumpAndSettle();
    expect(find.text('T01'), findsOneWidget);
  });
}
