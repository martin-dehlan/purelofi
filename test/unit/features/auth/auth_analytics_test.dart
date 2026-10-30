import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:purelofi/common/analytics/analytics.provider.dart';
import 'package:purelofi/common/analytics/analytics.service.dart';
import 'package:purelofi/common/errors/app_error.dart';
import 'package:purelofi/features/auth/controller/auth.controller.dart';
import 'package:purelofi/features/auth/controller/auth.provider.dart';
import 'package:purelofi/features/auth/domain/account.entity.dart';

import '../../../helpers/fake_auth.repository.dart';
import '../../../helpers/recording_analytics.service.dart';

void main() {
  late RecordingAnalyticsService analytics;
  late ProviderContainer container;

  ProviderContainer start(FakeAuthRepository repository) {
    analytics = RecordingAnalyticsService();
    final ProviderContainer c = ProviderContainer(
      overrides: [
        authRepositoryProvider.overrideWithValue(repository),
        analyticsServiceProvider.overrideWithValue(analytics),
      ],
    );
    addTearDown(c.dispose);
    addTearDown(repository.dispose);
    c.listen(authControllerProvider, (_, _) {}, fireImmediately: true);
    return c;
  }

  Future<void> settle() => Future<void>.delayed(Duration.zero);

  AuthController controller() =>
      container.read(authControllerProvider.notifier);

  test('a sign-in identifies the listener and counts the funnel', () async {
    container = start(FakeAuthRepository());
    await settle();

    await controller().signInWithGoogle();
    await settle();

    expect(analytics.eventNames, <String>[
      AnalyticsEvents.signInStarted,
      AnalyticsEvents.signInCompleted,
    ]);
    expect(analytics.last(AnalyticsEvents.signInCompleted), <String, Object>{
      'method': 'google',
    });
    expect(analytics.identifiedAs, 'u1');
    expect(analytics.personProperties, <String, Object>{
      'sign_in_method': 'google',
    });
  });

  test(
    'a session from a previous run is the same person, not a sign-in',
    () async {
      container = start(
        FakeAuthRepository(
          signedIn: const Account(id: 'u9', method: SignInMethod.apple),
        ),
      );
      await settle();

      expect(analytics.identifiedAs, 'u9');
      expect(
        analytics.eventNames,
        isNot(contains(AnalyticsEvents.signInCompleted)),
      );
    },
  );

  test('a closed sheet is started, never failed nor completed', () async {
    container = start(FakeAuthRepository()..cancel = true);
    await settle();

    await controller().signInWithGoogle();
    await settle();

    expect(analytics.eventNames, <String>[AnalyticsEvents.signInStarted]);
    expect(analytics.identifiedAs, isNull);
  });

  test('a failure sends the kind, never the message', () async {
    container = start(
      FakeAuthRepository()
        ..failWith = const AppError.auth(message: 'me@example.com is wrong'),
    );
    await settle();

    await expectLater(
      controller().signInWithGoogle(),
      throwsA(isA<AppError>()),
    );

    expect(analytics.last(AnalyticsEvents.signInFailed), <String, Object>{
      'method': 'google',
      'reason': 'auth',
    });
  });

  test('email: the code sent, then the sign-in it completes', () async {
    container = start(FakeAuthRepository());
    await settle();

    await controller().sendEmailCode('me@example.com');
    await controller().verifyEmailCode(email: 'me@example.com', code: '123456');
    await settle();

    expect(analytics.eventNames, <String>[
      AnalyticsEvents.signInStarted,
      AnalyticsEvents.emailCodeSent,
      AnalyticsEvents.signInCompleted,
    ]);
    // No address anywhere.
    for (final (String, Map<String, Object>) e in analytics.events) {
      expect(e.$2.values, isNot(contains('me@example.com')));
    }
  });

  test('signing out resets, so the next listener is someone new', () async {
    container = start(
      FakeAuthRepository(
        signedIn: const Account(id: 'u9', method: SignInMethod.email),
      ),
    );
    await settle();

    await controller().signOut();
    await settle();

    expect(analytics.resets, 1);
    expect(analytics.identifiedAs, isNull);
    expect(analytics.eventNames, contains(AnalyticsEvents.signedOut));
  });

  test('deleting the account is counted, and resets too', () async {
    container = start(
      FakeAuthRepository(
        signedIn: const Account(id: 'u9', method: SignInMethod.email),
      ),
    );
    await settle();

    await controller().deleteAccount();
    await settle();

    expect(analytics.eventNames, contains(AnalyticsEvents.accountDeleted));
    expect(analytics.resets, 1);
  });
}
