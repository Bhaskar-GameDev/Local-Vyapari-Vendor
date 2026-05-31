import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:local_vyapari_vendor/ui/common/primary_button.dart';
import 'package:local_vyapari_vendor/ui/common/custom_text_field.dart';

// Widget tests for the shared presentational components. These intentionally
// avoid pumping the full app, which requires a live Firebase instance; instead
// they exercise the pure UI widgets used across the auth and shop-setup screens.

Widget _wrap(Widget child) => MaterialApp(home: Scaffold(body: child));

void main() {
  group('PrimaryButton', () {
    testWidgets('renders its label and fires onPressed when tapped',
        (tester) async {
      var tapped = 0;
      await tester.pumpWidget(_wrap(
        PrimaryButton(text: 'Sign In', onPressed: () => tapped++),
      ));

      expect(find.text('Sign In'), findsOneWidget);

      await tester.tap(find.byType(PrimaryButton));
      expect(tapped, 1);
    });

    testWidgets('shows a spinner and is disabled while loading',
        (tester) async {
      var tapped = 0;
      await tester.pumpWidget(_wrap(
        PrimaryButton(
          text: 'Sign In',
          isLoading: true,
          onPressed: () => tapped++,
        ),
      ));

      // Label is replaced by a progress indicator and taps do nothing.
      expect(find.text('Sign In'), findsNothing);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      final button = tester.widget<ElevatedButton>(find.byType(ElevatedButton));
      expect(button.onPressed, isNull);

      await tester.tap(find.byType(PrimaryButton));
      expect(tapped, 0);
    });
  });

  group('CustomTextField', () {
    testWidgets('renders its label and accepts input', (tester) async {
      final controller = TextEditingController();
      await tester.pumpWidget(_wrap(
        CustomTextField(label: 'Email Address', controller: controller),
      ));

      expect(find.text('Email Address'), findsOneWidget);

      await tester.enterText(find.byType(TextField), 'test@example.com');
      expect(controller.text, 'test@example.com');
    });

    testWidgets('password field toggles obscured state via the suffix icon',
        (tester) async {
      final controller = TextEditingController();
      await tester.pumpWidget(_wrap(
        CustomTextField(
          label: 'Password',
          controller: controller,
          obscureText: true,
        ),
      ));

      // Starts obscured: the "show" (visibility_off) icon is offered.
      expect(find.byIcon(Icons.visibility_off_outlined), findsOneWidget);

      await tester.tap(find.byType(IconButton));
      await tester.pump();

      // After toggling, the "hide" (visibility) icon is shown instead.
      expect(find.byIcon(Icons.visibility_outlined), findsOneWidget);
    });
  });
}
