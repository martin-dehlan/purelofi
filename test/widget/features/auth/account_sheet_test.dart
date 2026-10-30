import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:purelofi/common/errors/app_error.dart';
import 'package:purelofi/features/auth/domain/account.entity.dart';
import 'package:purelofi/features/auth/presentation/widgets/account_sheet.widget.dart';
import 'package:purelofi/features/auth/presentation/widgets/auth_button.widget.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

import '../../../helpers/fake_auth.repository.dart';
import '../../../helpers/pump_routed_app.dart';

void main() {
  late FakeAuthRepository auth;

  Future<void> open(WidgetTester tester, FakeAuthRepository repository) async {
    auth = repository;
    await tester.pumpProviderApp(
      child: const Scaffold(body: AccountSheet()),
      auth: repository,
    );
    await tester.pumpAndSettle();
  }

  group('signed out', () {
    testWidgets('offers the ways in, and says it is optional', (tester) async {
      await open(tester, FakeAuthRepository(apple: true));

      expect(find.text('Sign in'), findsOneWidget);
      expect(find.text('Optional. The music never needs it.'), findsOneWidget);
      expect(find.byType(SignInWithAppleButton), findsOneWidget);
      expect(find.text('Continue with Google'), findsOneWidget);
      expect(find.text('Continue with email'), findsOneWidget);
    });

    testWidgets('no Apple where there is no Apple sheet', (tester) async {
      await open(tester, FakeAuthRepository());

      expect(find.byType(SignInWithAppleButton), findsNothing);
      expect(find.text('Continue with Google'), findsOneWidget);
    });

    testWidgets('no Google where it is not set up', (tester) async {
      await open(tester, FakeAuthRepository(google: false));

      expect(find.text('Continue with Google'), findsNothing);
      expect(find.text('Continue with email'), findsOneWidget);
    });

    testWidgets('Google signs in and the sheet shows who', (tester) async {
      await open(tester, FakeAuthRepository());

      await tester.tap(find.text('Continue with Google'));
      await tester.pumpAndSettle();

      expect(auth.calls, <String>['google']);
      expect(find.text('listener@example.com'), findsOneWidget);
      expect(find.text('Signed in with Google'), findsOneWidget);
    });

    testWidgets('closing the native sheet shows no error', (tester) async {
      await open(tester, FakeAuthRepository()..cancel = true);

      await tester.tap(find.text('Continue with Google'));
      await tester.pumpAndSettle();

      expect(find.text('Sign in'), findsOneWidget);
      expect(find.textContaining('did not work'), findsNothing);
    });

    testWidgets('a failure is one plain sentence', (tester) async {
      await open(
        tester,
        FakeAuthRepository()
          ..failWith = const AppError.auth(
            message: 'Signing in did not work. Please try again.',
          ),
      );

      await tester.tap(find.text('Continue with Google'));
      await tester.pumpAndSettle();

      expect(
        find.text('Signing in did not work. Please try again.'),
        findsOneWidget,
      );
    });
  });

  group('email', () {
    final Finder email = find.widgetWithText(TextField, 'Email');
    final Finder password = find.widgetWithText(TextField, 'Password');
    final Finder code = find.widgetWithText(TextField, 'Code');

    Finder button(String label) => find.widgetWithText(AuthButton, label);

    Future<void> toEmail(
      WidgetTester tester, [
      FakeAuthRepository? repo,
    ]) async {
      await open(tester, repo ?? FakeAuthRepository());
      await tester.tap(find.text('Continue with email'));
      await tester.pumpAndSettle();
    }

    Future<void> fill(WidgetTester tester, Finder field, String text) async {
      await tester.enterText(field, text);
      await tester.pump();
    }

    testWidgets('signs in with an address and a password', (tester) async {
      await toEmail(tester);

      await fill(tester, email, 'not-an-address');
      await fill(tester, password, 'secret123');
      await tester.tap(button('Sign in'));
      await tester.pump();
      expect(auth.calls, isEmpty);

      await fill(tester, email, ' me@example.com ');
      await tester.tap(button('Sign in'));
      await tester.pumpAndSettle();

      expect(auth.calls, <String>['sign in me@example.com secret123']);
      expect(find.text('Signed in with email'), findsOneWidget);
    });

    testWidgets('a wrong password says so and stays', (tester) async {
      await toEmail(tester);
      await fill(tester, email, 'me@example.com');
      await fill(tester, password, 'wrong');

      auth.failWith = const AppError.auth(message: 'Wrong email or password.');
      await tester.tap(button('Sign in'));
      await tester.pumpAndSettle();

      expect(find.text('Wrong email or password.'), findsOneWidget);
      expect(button('Sign in'), findsOneWidget);
    });

    testWidgets('a new account needs the length, then the code', (
      tester,
    ) async {
      await toEmail(tester);
      await tester.tap(find.text('Create an account'));
      await tester.pumpAndSettle();

      await fill(tester, email, 'me@example.com');
      await fill(tester, password, 'short');
      expect(find.text('At least 8 characters'), findsOneWidget);
      await tester.tap(button('Create account'));
      await tester.pump();
      expect(auth.calls, isEmpty);

      await fill(tester, password, 'long enough');
      await tester.tap(button('Create account'));
      await tester.pumpAndSettle();

      expect(auth.calls, <String>['create me@example.com long enough']);
      expect(find.text('We sent a code to me@example.com.'), findsOneWidget);
      expect(find.text('Resend in 60s'), findsOneWidget);

      // The sixth digit is the submit.
      await fill(tester, code, '123456');
      await tester.pumpAndSettle();

      expect(auth.calls.last, 'confirm me@example.com 123456');
      expect(find.text('Signed in with email'), findsOneWidget);
    });

    testWidgets('an unconfirmed address goes on to the code', (tester) async {
      await toEmail(tester, FakeAuthRepository()..unconfirmed = true);
      await fill(tester, email, 'me@example.com');
      await fill(tester, password, 'secret123');
      await tester.tap(button('Sign in'));
      await tester.pumpAndSettle();

      expect(find.text('We sent a code to me@example.com.'), findsOneWidget);

      await tester.pump(const Duration(seconds: 61));
      await tester.tap(find.text('Send a new code'));
      await tester.pumpAndSettle();
      expect(auth.calls.last, 'resend me@example.com');

      // "Different email" goes back where the code was asked for.
      await tester.tap(find.text('Different email'));
      await tester.pumpAndSettle();
      expect(button('Sign in'), findsOneWidget);
      await tester.pump(const Duration(seconds: 61));
    });

    testWidgets('a forgotten password resets with a code', (tester) async {
      await toEmail(tester);
      await tester.tap(find.text('Forgot password?'));
      await tester.pumpAndSettle();

      expect(password, findsNothing);
      await fill(tester, email, 'me@example.com');
      await tester.tap(button('Send reset code'));
      await tester.pumpAndSettle();
      expect(auth.calls, <String>['forgot me@example.com']);

      await fill(tester, code, '654321');
      // A reset still needs the new password: the code alone does nothing.
      expect(auth.calls, hasLength(1));
      await fill(
        tester,
        find.widgetWithText(TextField, 'New password'),
        'new secret',
      );
      await tester.tap(button('Set password'));
      await tester.pumpAndSettle();

      expect(auth.calls.last, 'reset me@example.com 654321 new secret');
      expect(find.text('Signed in with email'), findsOneWidget);
    });
  });

  group('signed in', () {
    const Account account = Account(
      id: 'u1',
      method: SignInMethod.apple,
      name: 'Martin',
      email: 'martin@example.com',
    );

    testWidgets('says who, and how', (tester) async {
      await open(tester, FakeAuthRepository(signedIn: account));

      expect(find.text('Martin'), findsOneWidget);
      expect(find.text('martin@example.com'), findsOneWidget);
      expect(find.text('Signed in with Apple'), findsOneWidget);
    });

    testWidgets('signs out', (tester) async {
      await open(tester, FakeAuthRepository(signedIn: account));

      await tester.tap(find.text('Sign out'));
      await tester.pumpAndSettle();

      expect(auth.calls, <String>['sign out']);
      expect(find.text('Sign in'), findsOneWidget);
    });

    testWidgets('deleting asks first, and keeping it changes nothing', (
      tester,
    ) async {
      await open(tester, FakeAuthRepository(signedIn: account));

      await tester.tap(find.text('Delete account'));
      await tester.pumpAndSettle();
      expect(find.text('Delete your account?'), findsOneWidget);

      await tester.tap(find.text('Keep it'));
      await tester.pumpAndSettle();

      expect(auth.calls, isEmpty);
      expect(find.text('Martin'), findsOneWidget);
    });

    testWidgets('deleting, confirmed, deletes and signs out', (tester) async {
      await open(tester, FakeAuthRepository(signedIn: account));

      await tester.tap(find.text('Delete account'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();

      expect(auth.calls, <String>['delete']);
      expect(find.text('Sign in'), findsOneWidget);
    });
  });
}
