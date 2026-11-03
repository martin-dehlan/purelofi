import 'dart:async';

import 'package:purelofi/common/errors/app_error.dart';
import 'package:purelofi/features/pro/domain/pro.repository.dart';
import 'package:purelofi/features/pro/domain/pro_plan.entity.dart';
import 'package:purelofi/features/pro/domain/pro_status.entity.dart';

/// Pro in memory: no RevenueCat, no store sheet.
///
/// A purchase that goes through puts Pro on [status], the way RevenueCat's
/// listener does.
class FakeProRepository implements ProRepository {
  FakeProRepository({
    this.available = true,
    ProStatus initial = ProStatus.free,
    List<ProPlan>? plans,
  }) : _now = initial,
       _plans = plans ?? defaultPlans;

  static const List<ProPlan> defaultPlans = <ProPlan>[
    ProPlan(
      period: PlanPeriod.yearly,
      price: '€29.99',
      pricePerMonth: '€2.50',
      trialDays: 7,
    ),
    ProPlan(period: PlanPeriod.monthly, price: '€3.99'),
  ];

  final bool available;
  final List<ProPlan> _plans;
  ProStatus _now;
  final StreamController<ProStatus> _changes =
      StreamController<ProStatus>.broadcast();

  /// How the next purchase ends.
  PurchaseOutcome outcome = PurchaseOutcome.purchased;

  /// Thrown by the next purchase or restore, then cleared.
  AppError? failWith;

  /// What a restore finds.
  bool restoreFinds = false;

  final List<String> calls = <String>[];

  /// Pro changes from outside the app: a renewal, an expiry, a refund.
  void emit(ProStatus status) {
    _now = status;
    _changes.add(status);
  }

  @override
  bool get isAvailable => available;

  @override
  Stream<ProStatus> get status async* {
    yield _now;
    yield* _changes.stream;
  }

  @override
  Future<List<ProPlan>> plans() async => _plans;

  @override
  Future<PurchaseOutcome> purchase(PlanPeriod period) async {
    calls.add('purchase ${period.name}');
    final AppError? failure = failWith;
    failWith = null;
    if (failure != null) throw failure;
    if (outcome == PurchaseOutcome.purchased) {
      emit(ProStatus(isPro: true, plan: period, willRenew: true));
    }
    return outcome;
  }

  @override
  Future<bool> restore() async {
    calls.add('restore');
    if (restoreFinds) emit(const ProStatus(isPro: true));
    return restoreFinds;
  }

  @override
  Future<void> logIn(String userId) async => calls.add('logIn $userId');

  @override
  Future<void> logOut() async => calls.add('logOut');

  Future<void> dispose() => _changes.close();
}
