import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../common/utils/responsive.dart';
import '../../controller/sleep_timer.controller.dart';

/// When the music should stop, one tap away: off, a few lengths, or the
/// end of this track. While it runs, the line under the chips says when.
class SleepTimerChips extends ConsumerWidget {
  const SleepTimerChips({super.key});

  static const List<int> minutes = <int>[15, 30, 45, 60];

  /// "23:40" or "11:40 PM", the way the phone tells the time.
  static String timeOfDay(BuildContext context, DateTime at) =>
      MaterialLocalizations.of(context).formatTimeOfDay(
        TimeOfDay.fromDateTime(at),
        alwaysUse24HourFormat: MediaQuery.alwaysUse24HourFormatOf(context),
      );

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ColorScheme cs = Theme.of(context).colorScheme;
    final SleepTimerController timer = ref.read(
      sleepTimerControllerProvider.notifier,
    );
    final DateTime? stopsAt = ref.watch(sleepTimerControllerProvider);

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
          // On its card, a step lighter than the card.
          backgroundColor: cs.surfaceContainerHighest,
          selectedColor: cs.onSurface,
          labelStyle: TextStyle(
            color: selected ? cs.surface : cs.onSurface,
            fontSize: context.fontS,
            fontWeight: FontWeight.w600,
          ),
        );

    final double gap = context.spaceS;

    // One row, swiped like the rooms above it, never wrapped into three.
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: EdgeInsets.all(context.spaceM),
          child: Row(
            children: <Widget>[
              for (final Widget c in <Widget>[
                chip('Off', timer.cancel, selected: stopsAt == null),
                for (final int length in minutes)
                  chip(
                    length == 60 ? '1 h' : '$length min',
                    () => timer.start(Duration(minutes: length)),
                  ),
                chip('End of track', timer.endOfTrack),
              ]) ...<Widget>[c, SizedBox(width: gap)],
            ],
          ),
        ),
        if (stopsAt != null)
          Padding(
            padding: EdgeInsets.fromLTRB(
              context.spaceM,
              0,
              context.spaceM,
              context.spaceM,
            ),
            child: Text(
              'Stops at ${timeOfDay(context, stopsAt)}',
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
