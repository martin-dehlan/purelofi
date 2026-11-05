import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../common/utils/responsive.dart';
import '../../../../common/widgets/every_second.widget.dart';
import '../../../../l10n/l10n.dart';
import '../../controller/focus_timer.controller.dart';
import '../../domain/focus_session.dart';
import 'sleep_timer_slider.widget.dart';

/// The focus timer (#137) on its card. Off, it offers the plans as two
/// tiles, one tap to start. Running, it counts down the half it is in, says
/// until when, and fills a bar as the half goes by.
class FocusTimerCard extends ConsumerWidget {
  const FocusTimerCard({super.key});

  /// "Focus until 14:25 · round 2" or "Break until 14:30".
  static String status(BuildContext context, FocusSession session) {
    final String until = SleepTimerSlider.timeOfDay(context, session.endsAt);

    return switch (session.phase) {
      FocusPhase.focus =>
        session.round == 1
            ? context.l10n.focusUntil(until)
            : context.l10n.focusUntilRound(until, session.round),
      FocusPhase.rest => context.l10n.breakUntil(until),
    };
  }

  /// What is left of the half, "18:24", rounded up so it never shows 0:00
  /// while the half still runs.
  static String remaining(FocusSession session, DateTime now) {
    final int seconds = (session.endsAt.difference(now).inMilliseconds / 1000)
        .ceil()
        .clamp(0, 24 * 60 * 60);

    return '${seconds ~/ 60}:${(seconds % 60).toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final FocusSession? session = ref.watch(focusTimerControllerProvider);

    return Padding(
      padding: EdgeInsets.all(context.spaceM),
      child: AnimatedSize(
        duration: const Duration(milliseconds: 200),
        alignment: Alignment.topCenter,
        child: session == null ? const _Plans() : _Running(session: session),
      ),
    );
  }
}

/// The plans, side by side, each a tile to start it with.
class _Plans extends ConsumerWidget {
  const _Plans();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ColorScheme cs = Theme.of(context).colorScheme;

    Widget tile(FocusPlan plan) {
      final String focus = '${plan.focus.inMinutes}';
      final String full = context.l10n.minutesShort(plan.label);
      // "25" large, " / 5 min" quieter beside it. A language that puts the
      // unit first keeps the whole label in one size.
      final List<InlineSpan> spans = full.startsWith(focus)
          ? <InlineSpan>[
              TextSpan(
                text: focus,
                style: TextStyle(
                  fontSize: context.fontXl,
                  fontWeight: FontWeight.w700,
                  color: cs.onSurface,
                ),
              ),
              TextSpan(text: full.substring(focus.length)),
            ]
          : <InlineSpan>[TextSpan(text: full)];

      return Expanded(
        child: Material(
          color: cs.surfaceContainerHighest,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(context.cardBorderRadius),
          ),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: () =>
                ref.read(focusTimerControllerProvider.notifier).start(plan),
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: context.spaceM),
              child: Text.rich(
                TextSpan(children: spans),
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: cs.onSurfaceVariant,
                  fontSize: context.fontS,
                  fontWeight: FontWeight.w600,
                  fontFeatures: const <FontFeature>[
                    FontFeature.tabularFigures(),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    }

    return Row(
      children: <Widget>[
        for (final (int i, FocusPlan plan) in FocusPlan.offered.indexed) ...[
          if (i > 0) SizedBox(width: context.spaceS),
          tile(plan),
        ],
      ],
    );
  }
}

/// A session that runs: the count, the line under it and the bar.
class _Running extends ConsumerWidget {
  const _Running({required this.session});

  final FocusSession session;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ColorScheme cs = Theme.of(context).colorScheme;
    final bool focusing = session.phase == FocusPhase.focus;
    final Duration length = session.plan.lengthOf(session.phase);

    return EverySecond(
      builder: (BuildContext context, DateTime now) {
        final double done =
            1 -
            (session.endsAt.difference(now).inMilliseconds /
                    length.inMilliseconds)
                .clamp(0.0, 1.0);

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        FocusTimerCard.remaining(session, now),
                        style: TextStyle(
                          color: focusing ? cs.onSurface : cs.onSurfaceVariant,
                          fontSize: context.fontXl,
                          fontWeight: FontWeight.w700,
                          fontFeatures: const <FontFeature>[
                            FontFeature.tabularFigures(),
                          ],
                        ),
                      ),
                      Text(
                        FocusTimerCard.status(context, session),
                        style: TextStyle(
                          color: cs.onSurfaceVariant,
                          fontSize: context.fontS,
                        ),
                      ),
                    ],
                  ),
                ),
                ActionChip(
                  label: Text(context.l10n.off),
                  onPressed: ref
                      .read(focusTimerControllerProvider.notifier)
                      .stop,
                  side: BorderSide.none,
                  shape: const StadiumBorder(),
                  visualDensity: VisualDensity.compact,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  backgroundColor: cs.surfaceContainerHighest,
                  labelStyle: TextStyle(
                    color: cs.onSurface,
                    fontSize: context.fontS,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            SizedBox(height: context.spaceM),
            // The half going by; a break fills in the quieter colour.
            LinearProgressIndicator(
              value: done,
              minHeight: context.spaceS,
              borderRadius: BorderRadius.circular(context.spaceS),
              color: focusing ? cs.primary : cs.onSurfaceVariant,
              backgroundColor: cs.surfaceContainerHighest,
            ),
          ],
        );
      },
    );
  }
}
