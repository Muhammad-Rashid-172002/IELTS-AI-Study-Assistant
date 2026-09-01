import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fyproject/screens/pages/registration/email_verification_screen.dart';

void main() {
  group('email verification recovery helpers', () {
    test('uses a sixty-second resend cooldown', () {
      expect(emailVerificationResendCooldown, const Duration(seconds: 60));
    });

    test('builds a support email with the registered email pre-filled', () {
      final uri = buildEmailVerificationSupportUri('learner@example.com');

      expect(uri.scheme, 'mailto');
      expect(uri.path, emailVerificationSupportEmail);
      expect(
        uri.queryParameters['subject'],
        'IELTS AI Master - Email Verification Help',
      );
      expect(
        uri.queryParameters['body'],
        contains('Registered email: learner@example.com'),
      );
    });

    test('uses safe messages for network and rate-limit failures', () {
      expect(
        emailVerificationAuthErrorMessage(
          FirebaseAuthException(code: 'network-request-failed'),
        ),
        contains('No internet connection'),
      );
      expect(
        emailVerificationAuthErrorMessage(
          FirebaseAuthException(code: 'too-many-requests'),
        ),
        contains('Please wait'),
      );
    });
  });

  testWidgets('recovery actions remain usable on a compact phone', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: EmailVerificationRecoveryView(
          email: 'a.very.long.learner.email.address@example.com',
          initialEmailSent: true,
          secondsUntilResend: 42,
          isChecking: false,
          isSending: false,
          isChangingEmail: false,
          isOpeningSupport: false,
          onCheckVerification: () {},
          onResend: () {},
          onChangeEmail: () {},
          onContactSupport: () {},
        ),
      ),
    );

    expect(find.text('Verify Your Email'), findsOneWidget);
    expect(find.text("I've Verified My Email"), findsOneWidget);
    expect(find.text('Resend available in 42s'), findsOneWidget);
    expect(find.text('Change Email Address'), findsOneWidget);
    expect(find.text('Need Help? Contact Support'), findsOneWidget);
    expect(find.textContaining('Spam/Junk folder'), findsOneWidget);
    final resendButton = tester.widget<OutlinedButton>(
      find.widgetWithText(OutlinedButton, 'Resend available in 42s'),
    );
    expect(resendButton.onPressed, isNull);
    expect(tester.takeException(), isNull);

    await tester.scrollUntilVisible(
      find.text('Need Help? Contact Support'),
      120,
      scrollable: find.byType(Scrollable).first,
    );
    expect(tester.takeException(), isNull);
  });
}
