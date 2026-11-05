import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../common/utils/responsive.dart';
import '../../../../common/widgets/every_second.widget.dart';
import '../../../../l10n/l10n.dart';
import '../../controller/focus_timer.controller.dart';
import '../../domain/focus_session.dart';
import 'focus_timer_card.widget.dart';

/// The focus timer on the scene (#137), top and centre: which half, and
/// what is left of it, large enough to read across a desk. It stays while
/// the controls step aside, since a glance at it is the point. Nothing at
/// all while the timer is off.
class FocusClock extends ConsumerWidget {
  const FocusClock({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final FocusSession? session = ref.watch(focusTimerControllerProvider);
    if (session == null) return const SizedBox.shrink();

    final ColorScheme cs = Theme.of(context).colorScheme;
    final bool focusing = session.phase == FocusPhase.focus;

    return IgnorePointer(
      child: EverySecond(
        builder: (BuildContext context, DateTime now) {
          final String left = FocusTimerCard.remaining(session, now);
          final String half = focusing
              ? context.l10n.focus
              : context.l10n.breakLabel;

          return Semantics(
            label: <String>[half, left].join(' '),
            excludeSemantics: true,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text(
                  half.toUpperCase(),
                  style: TextStyle(
                    color: cs.onSurface.withValues(alpha: 0.7),
                    fontSize: context.fontXs,
                    fontWeight: FontWeight.w700,
                    letterSpacing: context.fontXs * 0.15,
                  ),
                ),
                Text(
                  left,
                  style: TextStyle(
                    color: focusing
                        ? cs.onSurface
                        : cs.onSurface.withValues(alpha: 0.7),
                    fontSize: context.fontXxl,
                    fontWeight: FontWeight.w700,
                    height: 1.1,
                    fontFeatures: const <FontFeature>[
                      FontFeature.tabularFigures(),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
