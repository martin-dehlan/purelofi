import 'package:freezed_annotation/freezed_annotation.dart';

part 'pro_plan.entity.freezed.dart';

/// How often Pro is billed.
enum PlanPeriod { monthly, yearly }

/// One way to buy Pro, as the store prices it today.
///
/// Prices are strings because the store formats them: currency, separators
/// and all, in the listener's locale. The app never does sums on them.
@freezed
abstract class ProPlan with _$ProPlan {
  const factory ProPlan({
    required PlanPeriod period,

    /// The full price per period, e.g. "€29.99".
    required String price,

    /// The yearly plan's price broken down per month, e.g. "€2.50".
    String? pricePerMonth,

    /// A free trial before the first payment, if the store offers one to
    /// this listener. Set in the stores; seven days on the yearly plan.
    int? trialDays,
  }) = _ProPlan;
}
