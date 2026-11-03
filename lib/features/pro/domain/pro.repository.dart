import 'pro_plan.entity.dart';
import 'pro_status.entity.dart';

/// How a purchase ended, short of an error.
enum PurchaseOutcome {
  purchased,

  /// The listener closed the store's sheet. Not an error, so nothing is
  /// shown for it.
  cancelled,

  /// The store is waiting on someone — a parent's approval, a slow payment
  /// method. Pro arrives through [ProRepository.status] once it clears.
  pending,
}

/// Buying and holding Pro (#16). Errors leave as `AppError`.
abstract class ProRepository {
  /// Whether Pro can be bought in this build at all. Without RevenueCat's
  /// keys it cannot, and the app then keeps every scene free rather than
  /// showing a paywall nobody can pay at.
  bool get isAvailable;

  /// Pro now, and every change after — a renewal, an expiry, a refund, a
  /// purchase on another device under the same account.
  Stream<ProStatus> get status;

  /// The plans on offer, as the store prices them.
  Future<List<ProPlan>> plans();

  Future<PurchaseOutcome> purchase(PlanPeriod period);

  /// Brings back Pro bought earlier with this store account. `true` when
  /// there was something to bring back.
  Future<bool> restore();

  /// Pro follows the account from now on, to every device it signs in on.
  Future<void> logIn(String userId);

  /// Back to Pro belonging to the store account on this device.
  Future<void> logOut();
}
