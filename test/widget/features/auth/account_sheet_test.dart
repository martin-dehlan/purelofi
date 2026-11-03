import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:purelofi/common/errors/app_error.dart';
import 'package:purelofi/features/auth/domain/account.entity.dart';
import 'package:purelofi/features/auth/presentation/widgets/account_sheet.widget.dart';
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
    Future<void> toEmail(WidgetTester tester) async {
      await open(tester, FakeAuthRepository());
      await tester.tap(find.text('Continue with email'));
      await tester.pumpAndSettle();
    }

    testWidgets('sends a code only for an address that looks right', (
      tester,
    ) async {
      await toEmail(tester);

      await tester.enterText(find.byType(TextField), 'not-an-address');
      await tester.pump();
      await tester.tap(find.text('Send code'));
      await tester.pump();
      expect(auth.calls, isEmpty);

      await tester.enterText(find.byType(TextField), ' me@example.com ');
      await tester.pump();
      await tester.tap(find.text('Send code'));
      await tester.pumpAndSettle();

      expect(auth.calls, <String>['send me@example.com']);
      expect(find.text('We sent a code to me@example.com.'), findsOneWidget);
    });

    testWidgets('the sixth digit signs in', (tester) async {
      await toEmail(tester);
      await tester.enterText(find.byType(TextField), 'me@example.com');
      await tester.pump();
      await tester.tap(find.text('Send code'));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), '123456');
      await tester.pumpAndSettle();

      expect(auth.calls.last, 'verify me@example.com 123456');
      expect(find.text('Signed in with email'), findsOneWidget);
    });

    testWidgets('a new code waits out the minute', (tester) async {
      await toEmail(tester);
      await tester.enterText(find.byType(TextField), 'me@example.com');
      await tester.pump();
      await tester.tap(find.text('Send code'));
      await tester.pumpAndSettle();

      expect(find.text('Resend in 60s'), findsOneWidget);

      await tester.pump(const Duration(seconds: 61));

      expect(find.text('Send a new code'), findsOneWidget);
    });

    testWidgets('a wrong code says so and stays', (tester) async {
      await toEmail(tester);
      await tester.enterText(find.byType(TextField), 'me@example.com');
      await tester.pump();
      await tester.tap(find.text('Send code'));
      await tester.pumpAndSettle();

      auth.failWith = const AppError.auth(
        message: 'That code did not work. Check it, or send a new one.',
      );
      await tester.enterText(find.byType(TextField), '000000');
      await tester.pumpAndSettle();

      expect(
        find.text('That code did not work. Check it, or send a new one.'),
        findsOneWidget,
      );
      expect(find.text('Sign in'), findsOneWidget);
      // Let the resend countdown finish so no timer outlives the test.
      await tester.pump(const Duration(seconds: 61));
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
