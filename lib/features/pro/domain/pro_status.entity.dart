import 'package:freezed_annotation/freezed_annotation.dart';

import 'pro_plan.entity.dart';

part 'pro_status.entity.freezed.dart';

/// Whether this listener has Pro right now.
@freezed
abstract class ProStatus with _$ProStatus {
  const factory ProStatus({
    @Default(false) bool isPro,
    PlanPeriod? plan,
    DateTime? expiresAt,
    @Default(false) bool willRenew,

    /// Where the store lets them change or cancel it.
    String? manageUrl,
  }) = _ProStatus;

  static const ProStatus free = ProStatus();
}
