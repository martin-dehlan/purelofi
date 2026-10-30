import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:purelofi/common/analytics/analytics.provider.dart';
import 'package:purelofi/common/analytics/analytics.service.dart';
import 'package:purelofi/common/errors/app_error.dart';
import 'package:purelofi/features/auth/controller/auth.provider.dart';
import 'package:purelofi/features/player/controller/player.provider.dart';
import 'package:purelofi/features/player/controller/scene.controller.dart';
import 'package:purelofi/features/player/domain/scene.entity.dart';
import 'package:purelofi/features/pro/controller/pro.controller.dart';
import 'package:purelofi/features/pro/controller/pro.provider.dart';
import 'package:purelofi/features/pro/domain/pro.repository.dart';
import 'package:purelofi/features/pro/domain/pro_plan.entity.dart';
import 'package:purelofi/features/pro/domain/pro_status.entity.dart';

import '../../../helpers/fake_auth.repository.dart';
import '../../../helpers/fake_pro.repository.dart';
import '../../../helpers/mock_repositories.dart';
import '../../../helpers/recording_analytics.service.dart';

void main() {
  late FakeAuthRepository auth;
  late FakeProRepository pro;
  late RecordingAnalyticsService analytics;
  late MockContentRepository content;

  final List<SceneEntity> scenes = <SceneEntity>[
    makeScene('autumn').copyWith(sortOrder: 1),
    makeScene('rainy').copyWith(sortOrder: 2),
    makeScene('snow').copyWith(sortOrder: 3),
  ];

  ProviderContainer start({FakeProRepository? withPro}) {
    auth = FakeAuthRepository();
    pro = withPro ?? FakeProRepository();
    analytics = RecordingAnalyticsService();
    content = MockContentRepository();
    when(() => content.getScenes()).thenAnswer((_) async => scenes);
    final ProviderContainer c = ProviderContainer(
      overrides: [
        authRepositoryProvider.overrideWithValue(auth),
        proRepositoryProvider.overrideWithValue(pro),
        analyticsServiceProvider.overrideWithValue(analytics),
        contentRepositoryProvider.overrideWithValue(content),
      ],
    );
    addTearDown(c.dispose);
    addTearDown(auth.dispose);
    addTearDown(pro.dispose);
    c.listen(proControllerProvider, (_, _) {}, fireImmediately: true);
    c.listen(activeSceneControllerProvider, (_, _) {}, fireImmediately: true);
    return c;
  }

  Future<void> settle() async {
    for (int i = 0; i < 5; i++) {
      await Future<void>.delayed(Duration.zero);
    }
  }

  const ProPlan yearly = ProPlan(
    period: PlanPeriod.yearly,
    price: '€29.99',
    trialDays: 7,
  );

  group('Pro follows the account', () {
    test('a sign-in hands RevenueCat the user id', () async {
      start();
      await settle();

      await auth.signInWithGoogle();
      await settle();

      expect(pro.calls, contains('logIn u1'));
    });

    test('a sign-out hands Pro back to the device', () async {
      start();
      await settle();
      await auth.signInWithGoogle();
      await settle();

      await auth.signOut();
      await settle();

      expect(pro.calls.last, 'logOut');
    });
  });

  group('locked scenes', () {
    test(
      'without Pro, the third scene is locked and cannot be shown',
      () async {
        final ProviderContainer c = start();
        await c.read(sceneListControllerProvider.future);
        await settle();

        expect(c.read(lockedScenesProvider), <String>{'snow'});
        final bool shown = c
            .read(activeSceneControllerProvider.notifier)
            .switchTo(scenes[2]);
        expect(shown, isFalse);
        expect(c.read(activeSceneControllerProvider)?.id, 'autumn');
      },
    );

    test('with Pro, it opens', () async {
      final ProviderContainer c = start(
        withPro: FakeProRepository(initial: const ProStatus(isPro: true)),
      );
      await c.read(sceneListControllerProvider.future);
      await settle();

      expect(c.read(lockedScenesProvider), isEmpty);
      expect(
        c.read(activeSceneControllerProvider.notifier).switchTo(scenes[2]),
        isTrue,
      );
    });

    test(
      'when Pro runs out mid-scene, the room falls back to a free one',
      () async {
        final ProviderContainer c = start(
          withPro: FakeProRepository(initial: const ProStatus(isPro: true)),
        );
        await c.read(sceneListControllerProvider.future);
        await settle();
        c.read(activeSceneControllerProvider.notifier).switchTo(scenes[2]);

        pro.emit(ProStatus.free);
        await settle();

        expect(c.read(activeSceneControllerProvider)?.id, 'autumn');
      },
    );

    test('where Pro is not for sale, every scene is open', () async {
      final ProviderContainer c = start(
        withPro: FakeProRepository(available: false),
      );
      await c.read(sceneListControllerProvider.future);
      await settle();

      expect(c.read(lockedScenesProvider), isEmpty);
    });
  });

  group('the funnel', () {
    test(
      'a purchase is started and completed, with the plan and the trial',
      () async {
        final ProviderContainer c = start();
        await settle();

        final PurchaseOutcome outcome = await c
            .read(proControllerProvider.notifier)
            .purchase(yearly);

        expect(outcome, PurchaseOutcome.purchased);
        expect(analytics.eventNames, <String>[
          AnalyticsEvents.purchaseStarted,
          AnalyticsEvents.purchaseCompleted,
        ]);
        expect(
          analytics.last(AnalyticsEvents.purchaseCompleted),
          <String, Object>{'plan': 'yearly', 'trial': true},
        );
      },
    );

    test('a cancelled purchase is counted as cancelled', () async {
      final ProviderContainer c = start(
        withPro: FakeProRepository()..outcome = PurchaseOutcome.cancelled,
      );
      await settle();

      await c.read(proControllerProvider.notifier).purchase(yearly);

      expect(analytics.eventNames.last, AnalyticsEvents.purchaseCancelled);
    });

    test('a failure is counted, then thrown for the sheet', () async {
      final ProviderContainer c = start(
        withPro: FakeProRepository()
          ..failWith = const AppError.purchase(message: 'nope'),
      );
      await settle();

      await expectLater(
        c.read(proControllerProvider.notifier).purchase(yearly),
        throwsA(isA<PurchaseError>()),
      );
      expect(analytics.last(AnalyticsEvents.purchaseFailed), <String, Object>{
        'plan': 'yearly',
        'trial': true,
        'reason': 'store',
      });
    });

    test('a restore says whether it found anything', () async {
      final ProviderContainer c = start(
        withPro: FakeProRepository()..restoreFinds = true,
      );
      await settle();

      expect(await c.read(proControllerProvider.notifier).restore(), isTrue);
      expect(analytics.eventNames, <String>[
        AnalyticsEvents.restoreTapped,
        AnalyticsEvents.restoreCompleted,
      ]);
      expect(analytics.last(AnalyticsEvents.restoreCompleted), <String, Object>{
        'found': true,
      });
    });

    test('the paywall view carries its source and the scene', () async {
      final ProviderContainer c = start();
      await settle();

      c
          .read(proControllerProvider.notifier)
          .paywallViewed('scene_switcher', sceneId: 'snow');
      await settle();

      expect(analytics.last(AnalyticsEvents.paywallViewed), <String, Object>{
        'source': 'scene_switcher',
        'scene_id': 'snow',
      });
    });
  });
}
