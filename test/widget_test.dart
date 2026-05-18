import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:local_vyapari_vendor/main.dart';

void main() {
  testWidgets('App smoke test', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(
      const ProviderScope(
        child: LocalVyapariVendorApp(),
      ),
    );

    // Verify that the splash screen shows 'Local Vyapari'
    expect(find.text('Local Vyapari'), findsOneWidget);
  });
}
