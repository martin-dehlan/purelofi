import 'package:flutter/material.dart';

import '../../../../common/utils/responsive.dart';
import '../../domain/pro_plan.entity.dart';

/// One plan to pick, as a card: the period, the store's price, and the free
/// trial when there is one. The chosen one is outlined in the accent.
class PlanOption extends StatelessWidget {
  const PlanOption({
    required this.plan,
    required this.selected,
    required this.onTap,
    super.key,
  });

  final ProPlan plan;
  final bool selected;
  final VoidCallback? onTap;

  static String titleFor(PlanPeriod period) => switch (period) {
    PlanPeriod.yearly => 'Yearly',
    PlanPeriod.monthly => 'Monthly',
  };

  static String perFor(PlanPeriod period) => switch (period) {
    PlanPeriod.yearly => 'a year',
    PlanPeriod.monthly => 'a month',
  };

  @override
  Widget build(BuildContext context) {
    final ColorScheme cs = Theme.of(context).colorScheme;
    final int? trial = plan.trialDays;
    final String? perMonth = plan.pricePerMonth;
    final BorderRadius radius = BorderRadius.circular(context.cardBorderRadius);

    return Semantics(
      selected: selected,
      button: true,
      child: Material(
        color: selected ? cs.surfaceContainerHighest : cs.surfaceContainerHigh,
        shape: RoundedRectangleBorder(
          borderRadius: radius,
          side: BorderSide(
            color: selected ? cs.primary : cs.outlineVariant,
            width: selected ? 2 : 1,
          ),
        ),
        child: InkWell(
          borderRadius: radius,
          onTap: onTap,
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: context.spaceM,
              vertical: context.spaceM,
            ),
            child: Row(
              children: <Widget>[
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        titleFor(plan.period),
                        style: TextStyle(
                          color: cs.onSurface,
                          fontSize: context.fontM,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      SizedBox(height: context.spaceXs),
                      Text(
                        perMonth == null
                            ? '${plan.price} ${perFor(plan.period)}'
                            : '${plan.price} ${perFor(plan.period)} · '
                                  '$perMonth a month',
                        style: TextStyle(
                          color: cs.onSurfaceVariant,
                          fontSize: context.fontS,
                        ),
                      ),
                    ],
                  ),
                ),
                if (trial != null)
                  Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: context.spaceS,
                      vertical: context.spaceXs,
                    ),
                    decoration: ShapeDecoration(
                      shape: const StadiumBorder(),
                      color: cs.primary,
                    ),
                    child: Text(
                      '$trial days free',
                      style: TextStyle(
                        color: cs.onPrimary,
                        fontSize: context.fontXs,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
