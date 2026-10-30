import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

import '../../../common/errors/app_error.dart';
import '../domain/pro.repository.dart';
import '../domain/pro_plan.entity.dart';
import '../domain/pro_status.entity.dart';

/// Pro through RevenueCat: one SDK for the App Store and Google Play, with
/// receipts, renewals and refunds checked on RevenueCat's side.
///
/// What the dashboard is expected to hold (#16): entitlement `pro`, and the
/// current offering with a monthly and an annual package.
class RevenueCatProRepository implements ProRepository {
  RevenueCatProRepository({required String apiKey}) : _apiKey = apiKey;

  static const String entitlement = 'pro';

  final String _apiKey;
  Future<void>? _ready;
  final StreamController<ProStatus> _status =
      StreamController<ProStatus>.broadcast();

  /// The store key for this platform, or `null` when this build has none —
  /// in which case Pro is not offered at all.
  static String? keyFor({String? apple, String? google}) =>
      Platform.isIOS ? apple : (Platform.isAndroid ? google : null);

  /// Configured once, on first use. RevenueCat starts anonymous; [logIn]
  /// moves Pro onto an account.
  Future<void> _configure() => _ready ??= () async {
    await Purchases.configure(PurchasesConfiguration(_apiKey));
    Purchases.addCustomerInfoUpdateListener(
      (CustomerInfo info) => _status.add(statusFrom(info)),
    );
  }();

  @override
  bool get isAvailable => true;

  @override
  Stream<ProStatus> get status async* {
    await _configure();
    yield statusFrom(await _guard(Purchases.getCustomerInfo));
    yield* _status.stream;
  }

  @override
  Future<List<ProPlan>> plans() async {
    await _configure();
    final Offerings offerings = await _guard(Purchases.getOfferings);
    final Offering? offering = offerings.current;
    if (offering == null) return const <ProPlan>[];

    return <ProPlan>[
      if (offering.annual case final Package annual)
        planFrom(annual.storeProduct, PlanPeriod.yearly),
      if (offering.monthly case final Package monthly)
        planFrom(monthly.storeProduct, PlanPeriod.monthly),
    ];
  }

  @override
  Future<PurchaseOutcome> purchase(PlanPeriod period) async {
    await _configure();
    final Offering? offering = (await _guard(Purchases.getOfferings)).current;
    final Package? package = switch (period) {
      PlanPeriod.yearly => offering?.annual,
      PlanPeriod.monthly => offering?.monthly,
    };
    if (package == null) {
      throw const AppError.purchase(
        message: 'That plan is not available right now.',
      );
    }

    try {
      final PurchaseResult result = await Purchases.purchase(
        PurchaseParams.package(package),
      );
      _status.add(statusFrom(result.customerInfo));
      return PurchaseOutcome.purchased;
    } on PlatformException catch (error) {
      return switch (PurchasesErrorHelper.getErrorCode(error)) {
        PurchasesErrorCode.purchaseCancelledError => PurchaseOutcome.cancelled,
        PurchasesErrorCode.paymentPendingError => PurchaseOutcome.pending,
        final PurchasesErrorCode code => throw _mapped(code),
      };
    }
  }

  @override
  Future<bool> restore() async {
    await _configure();
    final CustomerInfo info = await _guard(Purchases.restorePurchases);
    final ProStatus status = statusFrom(info);
    _status.add(status);
    return status.isPro;
  }

  @override
  Future<void> logIn(String userId) async {
    await _configure();
    final LogInResult result = await _guard(() => Purchases.logIn(userId));
    _status.add(statusFrom(result.customerInfo));
  }

  @override
  Future<void> logOut() async {
    await _configure();
    // RevenueCat refuses to log out a user that is already anonymous; that
    // is the state we want anyway.
    if (await Purchases.isAnonymous) return;
    _status.add(statusFrom(await _guard(Purchases.logOut)));
  }

  /// The `pro` entitlement, read the same way wherever customer info comes
  /// from.
  static ProStatus statusFrom(CustomerInfo info) {
    final EntitlementInfo? pro = info.entitlements.active[entitlement];
    if (pro == null) return ProStatus(manageUrl: info.managementURL);

    return ProStatus(
      isPro: true,
      plan: periodFrom(pro.productIdentifier),
      expiresAt: pro.expirationDate == null
          ? null
          : DateTime.tryParse(pro.expirationDate!),
      willRenew: pro.willRenew,
      manageUrl: info.managementURL,
    );
  }

  /// Which plan a store product is, by its id (`pro_yearly`, `pro:yearly`…).
  static PlanPeriod? periodFrom(String productId) {
    final String id = productId.toLowerCase();
    if (id.contains('year') || id.contains('annual')) return PlanPeriod.yearly;
    if (id.contains('month')) return PlanPeriod.monthly;
    return null;
  }

  static ProPlan planFrom(StoreProduct product, PlanPeriod period) => ProPlan(
    period: period,
    price: product.priceString,
    pricePerMonth: period == PlanPeriod.yearly
        ? product.pricePerMonthString
        : null,
    trialDays: trialDaysFrom(product),
  );

  /// A free first period, however the store describes it: Apple as an
  /// introductory price of zero, Google as a free phase on the offer.
  static int? trialDaysFrom(StoreProduct product) {
    final IntroductoryPrice? intro = product.introductoryPrice;
    if (intro != null && intro.price == 0) {
      return daysIn(intro.periodUnit, intro.periodNumberOfUnits);
    }

    final Period? free = product.defaultOption?.freePhase?.billingPeriod;
    if (free != null) return daysIn(free.unit, free.value);

    return null;
  }

  static int daysIn(PeriodUnit unit, int count) => switch (unit) {
    PeriodUnit.day => count,
    PeriodUnit.week => count * 7,
    PeriodUnit.month => count * 30,
    PeriodUnit.year => count * 365,
    PeriodUnit.unknown => count,
  };

  static Future<T> _guard<T>(Future<T> Function() call) async {
    try {
      return await call();
    } on PlatformException catch (error) {
      throw _mapped(PurchasesErrorHelper.getErrorCode(error));
    }
  }

  static AppError _mapped(PurchasesErrorCode code) => switch (code) {
    PurchasesErrorCode.networkError ||
    PurchasesErrorCode.offlineConnectionError => const AppError.network(),
    PurchasesErrorCode.purchaseNotAllowedError => const AppError.purchase(
      message: 'Purchases are turned off on this device.',
    ),
    PurchasesErrorCode.productAlreadyPurchasedError => const AppError.purchase(
      message: 'You already have Pro. Try "Restore purchases".',
    ),
    PurchasesErrorCode.storeProblemError => const AppError.purchase(
      message: 'The store had a problem. Please try again in a moment.',
    ),
    _ => const AppError.purchase(
      message: 'The purchase did not go through. Please try again.',
    ),
  };
}

/// Pro in a build that has no RevenueCat keys: not for sale, so nothing is
/// locked (#16). The app behaves exactly as it did before Pro existed.
class UnavailableProRepository implements ProRepository {
  const UnavailableProRepository();

  @override
  bool get isAvailable => false;

  @override
  Stream<ProStatus> get status => Stream<ProStatus>.value(ProStatus.free);

  @override
  Future<List<ProPlan>> plans() async => const <ProPlan>[];

  @override
  Future<PurchaseOutcome> purchase(PlanPeriod period) =>
      throw const AppError.purchase(message: 'Pro is not available yet.');

  @override
  Future<bool> restore() async => false;

  @override
  Future<void> logIn(String userId) async {}

  @override
  Future<void> logOut() async {}
}
