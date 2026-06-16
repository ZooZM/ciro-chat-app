import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:ciro_chat_app/main.dart' as app;

/// 10-digit local number (EG format) for this run, e.g. 1500000001.
/// Pass via: flutter test integration_test/login_test.dart -d <device> \
///   --dart-define=TEST_PHONE_DIGITS=1500000001
const _phoneDigits = String.fromEnvironment(
  'TEST_PHONE_DIGITS',
  defaultValue: '1500000001',
);

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('register/login with phone +20$_phoneDigits and OTP 123456', (
    tester,
  ) async {
    app.main();
    await tester.pumpAndSettle(const Duration(seconds: 5));

    if (find.byType(BottomNavigationBar).evaluate().isEmpty) {
      final phoneField = find.byType(TextFormField);
      expect(
        phoneField,
        findsOneWidget,
        reason: 'expected the mobile number screen',
      );

      await tester.enterText(phoneField, _phoneDigits);
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(ElevatedButton, 'Send Code'));
      await tester.pumpAndSettle(const Duration(seconds: 30));

      final pinField = find.byType(EditableText);
      expect(
        pinField,
        findsWidgets,
        reason: 'expected the verify-code screen',
      );
      await tester.enterText(pinField.first, '123456');
      await tester.pump(const Duration(seconds: 1));

      final verifyBtn = find.widgetWithText(ElevatedButton, 'Verify');
      if (verifyBtn.evaluate().isNotEmpty) {
        await tester.tap(verifyBtn);
      }
      await tester.pumpAndSettle(const Duration(seconds: 30));
    }

    expect(find.byType(BottomNavigationBar), findsOneWidget);
  });
}
