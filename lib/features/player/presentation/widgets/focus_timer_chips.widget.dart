import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../common/utils/responsive.dart';
import '../../controller/focus_timer.controller.dart';
import '../../domain/focus_session.dart';
import 'sleep_timer_chips.widget.dart';
import '../../../../l10n/l10n.dart';

/// The focus timer (#137), one tap away: off, or a plan. While it runs, the
/// line under the chips says which half it is in and until when.
class FocusTimerChips extends ConsumerWidget {
  const FocusTimerChips({super.key});

  /// "Focus until 14:25 · round 2" or "Break until 14:30".
  static String status(BuildContext context, FocusSession session) {
    final String until = SleepTimerChips.timeOfDay(context, session.endsAt);

    return switch (session.phase) {
      FocusPhase.focus =>
        session.round == 1
            ? context.l10n.focusUntil(until)
            : context.l10n.focusUntilRound(until, session.round),
      FocusPhase.rest => context.l10n.breakUntil(until),
    };
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ColorScheme cs = Theme.of(context).colorScheme;
    final FocusTimerController timer = ref.read(
      focusTimerControllerProvider.notifier,
    );
    final FocusSession? session = ref.watch(focusTimerControllerProvider);

    Widget chip(String label, VoidCallback onTap, {bool selected = false}) =>
        ChoiceChip(
          label: Text(label),
          selected: selected,
          showCheckmark: false,
          onSelected: (_) => onTap(),
          side: BorderSide.none,
          shape: const StadiumBorder(),
          visualDensity: VisualDensity.compact,
          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          backgroundColor: cs.surfaceContainerHighest,
          selectedColor: cs.onSurface,
          labelStyle: TextStyle(
            color: selected ? cs.surface : cs.onSurface,
            fontSize: context.fontS,
            fontWeight: FontWeight.w600,
          ),
        );

    final double gap = context.spaceS;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: EdgeInsets.all(context.spaceM),
          child: Row(
            children: <Widget>[
              for (final Widget c in <Widget>[
                chip(context.l10n.off, timer.stop, selected: session == null),
                for (final FocusPlan plan in FocusPlan.offered)
                  chip(
                    context.l10n.minutesShort(plan.label),
                    () => timer.start(plan),
                    selected: session?.plan == plan,
                  ),
              ]) ...<Widget>[c, SizedBox(width: gap)],
            ],
          ),
        ),
        if (session != null)
          Padding(
            padding: EdgeInsets.fromLTRB(
              context.spaceM,
              0,
              context.spaceM,
              context.spaceM,
            ),
            child: Text(
              status(context, session),
              style: TextStyle(
                color: cs.onSurfaceVariant,
                fontSize: context.fontS,
              ),
            ),
          ),
      ],
    );
  }
}
