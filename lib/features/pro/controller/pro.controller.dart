import 'dart:async';

import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../common/analytics/analytics.provider.dart';
import '../../../common/analytics/analytics.service.dart';
import '../../../common/errors/app_error.dart';
import '../../auth/controller/auth.controller.dart';
import '../../auth/domain/account.entity.dart';
import '../../player/controller/scene.controller.dart';
import '../../player/domain/scene.entity.dart';
import '../domain/free_scenes.dart';
import '../domain/pro.repository.dart';
import '../domain/pro_plan.entity.dart';
import '../domain/pro_status.entity.dart';
import 'pro.provider.dart';

part 'pro.controller.g.dart';

/// Whether this listener has Pro (#16), and the ways to get it.
///
/// Pro follows the account when there is one: a sign-in hands RevenueCat
/// the Supabase user id, a sign-out hands Pro back to the store account on
/// the device. Buying never needs an account.
@Riverpod(keepAlive: true)
class ProController extends _$ProController {
  @override
  Stream<ProStatus> build() {
    final ProRepository pro = ref.watch(proRepositoryProvider);

    ref.listen<AsyncValue<Account?>>(authControllerProvider, (
      AsyncValue<Account?>? previous,
      AsyncValue<Account?> next,
    ) {
      final String? was = previous?.value?.id;
      final String? now = next.value?.id;
      if (now == was) return;
      // Moving Pro between accounts is housekeeping: a failure here must not
      // surface as a sign-in error. RevenueCat retries on the next change.
      if (now != null) {
        unawaited(pro.logIn(now).catchError((Object _) {}));
      } else if (was != null) {
        unawaited(pro.logOut().catchError((Object _) {}));
      }
    }, fireImmediately: true);

    return pro.status;
  }

  ProRepository get _pro => ref.read(proRepositoryProvider);

  AnalyticsService get _analytics => ref.read(analyticsServiceProvider);

  bool get isAvailable => _pro.isAvailable;

  Future<List<ProPlan>> plans() => _pro.plans();

  /// The paywall opened. [source] is where from (`scene_switcher`, `menu`).
  void paywallViewed(String source, {String? sceneId}) => unawaited(
    _analytics.capture(AnalyticsEvents.paywallViewed, <String, Object>{
      'source': source,
      'scene_id': ?sceneId,
    }),
  );

  /// A locked scene was tapped — which rooms sell Pro.
  void proSceneTapped(String sceneId) => unawaited(
    _analytics.capture(AnalyticsEvents.proSceneTapped, <String, Object>{
      'scene_id': sceneId,
    }),
  );

  void planSelected(ProPlan plan) => unawaited(
    _analytics.capture(AnalyticsEvents.planSelected, <String, Object>{
      'plan': plan.period.name,
    }),
  );

  Future<PurchaseOutcome> purchase(ProPlan plan) async {
    final Map<String, Object> props = <String, Object>{
      'plan': plan.period.name,
      'trial': plan.trialDays != null,
    };
    unawaited(_analytics.capture(AnalyticsEvents.purchaseStarted, props));

    try {
      final PurchaseOutcome outcome = await _pro.purchase(plan.period);
      unawaited(
        _analytics.capture(switch (outcome) {
          PurchaseOutcome.purchased => AnalyticsEvents.purchaseCompleted,
          PurchaseOutcome.cancelled => AnalyticsEvents.purchaseCancelled,
          PurchaseOutcome.pending => AnalyticsEvents.purchasePending,
        }, props),
      );
      return outcome;
    } on AppError catch (error) {
      unawaited(
        _analytics.capture(AnalyticsEvents.purchaseFailed, <String, Object>{
          ...props,
          'reason': error is NetworkError ? 'network' : 'store',
        }),
      );
      rethrow;
    }
  }

  Future<bool> restore() async {
    unawaited(_analytics.capture(AnalyticsEvents.restoreTapped));
    final bool found = await _pro.restore();
    unawaited(
      _analytics.capture(AnalyticsEvents.restoreCompleted, <String, Object>{
        'found': found,
      }),
    );
    return found;
  }
}

/// The scenes this listener cannot open yet (#16): every scene past the
/// first two, unless they have Pro or Pro is not for sale in this build.
///
/// Until Pro's status is known the extra scenes count as locked — the
/// common case, and the default scene is always one of the free two.
@riverpod
Set<String> lockedScenes(Ref ref) {
  final List<SceneEntity> scenes =
      ref.watch(sceneListControllerProvider).value ?? const <SceneEntity>[];
  final bool isPro = ref.watch(proControllerProvider).value?.isPro ?? false;

  return lockedSceneIds(
    scenes,
    isPro: isPro,
    proAvailable: ref.watch(proRepositoryProvider).isAvailable,
  );
}
