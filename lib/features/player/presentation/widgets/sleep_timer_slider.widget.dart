import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../common/utils/responsive.dart';
import '../../controller/sleep_timer.controller.dart';
import '../../../../l10n/l10n.dart';

/// When the music should stop, dragged into place: all the way left is off,
/// every step five minutes more, up to two hours. The timer is set when the
/// thumb is let go, not on every step it passes. The end of this track
/// stays one tap away beside the length.
class SleepTimerSlider extends ConsumerStatefulWidget {
  const SleepTimerSlider({super.key});

  /// The longest timer, in minutes.
  static const int longest = 120;

  /// One step of the slider, in minutes.
  static const int step = 5;

  /// "Off", "45 min", "1 h" or "1 h 30".
  static String lengthLabel(AppLocalizations l10n, int minutes) {
    if (minutes <= 0) return l10n.off;
    if (minutes < 60) return l10n.minutesShort('$minutes');
    final int rest = minutes % 60;
    return rest == 0
        ? l10n.hoursShort('${minutes ~/ 60}')
        : l10n.hoursMinutesShort(
            '${minutes ~/ 60}',
            rest.toString().padLeft(2, '0'),
          );
  }

  /// "23:40" or "11:40 PM", the way the phone tells the time.
  static String timeOfDay(BuildContext context, DateTime at) =>
      MaterialLocalizations.of(context).formatTimeOfDay(
        TimeOfDay.fromDateTime(at),
        alwaysUse24HourFormat: MediaQuery.alwaysUse24HourFormatOf(context),
      );

  @override
  ConsumerState<SleepTimerSlider> createState() => _SleepTimerSliderState();
}

class _SleepTimerSliderState extends ConsumerState<SleepTimerSlider> {
  /// Where the thumb is while a finger holds it, in minutes.
  double? _dragging;

  void _onChanged(double value) {
    final double snapped =
        (value / SleepTimerSlider.step).round() * SleepTimerSlider.step * 1.0;
    if (snapped != _dragging) HapticFeedback.selectionClick();
    setState(() => _dragging = snapped);
  }

  void _onChangeEnd(double value) {
    final int minutes =
        (value / SleepTimerSlider.step).round() * SleepTimerSlider.step;
    final SleepTimerController timer = ref.read(
      sleepTimerControllerProvider.notifier,
    );
    if (minutes == 0) {
      timer.cancel();
    } else {
      timer.start(Duration(minutes: minutes));
    }
    setState(() => _dragging = null);
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme cs = Theme.of(context).colorScheme;
    final DateTime? stopsAt = ref.watch(sleepTimerControllerProvider);

    // What is left of a running timer, rounded up: a timer set for 30 that
    // has run a few seconds still reads 30, not 29.
    final int left = stopsAt == null
        ? 0
        : (stopsAt.difference(DateTime.now()).inSeconds / 60).ceil().clamp(
            0,
            SleepTimerSlider.longest,
          );
    final double? dragging = _dragging;
    final int shown = dragging?.round() ?? left;
    final double value = (dragging ?? left.toDouble()).clamp(
      0,
      SleepTimerSlider.longest.toDouble(),
    );
    // While dragging, the time it would stop; otherwise the time it will.
    final DateTime? at = dragging != null
        ? (shown > 0 ? DateTime.now().add(Duration(minutes: shown)) : null)
        : stopsAt;
    final bool off = shown == 0 && at == null;

    return Padding(
      padding: EdgeInsets.fromLTRB(
        context.spaceM,
        context.spaceM,
        context.spaceM,
        context.spaceS,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          // Side by side where they fit; on a narrow card at a large text
          // size the chip moves under the time rather than being cut short.
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: context.spaceS,
            runSpacing: context.spaceS,
            children: <Widget>[
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    at != null && shown == 0
                        ? context.l10n.underAMinute
                        : SleepTimerSlider.lengthLabel(context.l10n, shown),
                    style: TextStyle(
                      color: off ? cs.onSurfaceVariant : cs.onSurface,
                      fontSize: context.fontL,
                      fontWeight: FontWeight.w600,
                      fontFeatures: const <FontFeature>[
                        FontFeature.tabularFigures(),
                      ],
                    ),
                  ),
                  Text(
                    at == null
                        ? context.l10n.playsOn
                        : context.l10n.stopsAt(
                            SleepTimerSlider.timeOfDay(context, at),
                          ),
                    style: TextStyle(
                      color: cs.onSurfaceVariant,
                      fontSize: context.fontS,
                    ),
                  ),
                ],
              ),
              ActionChip(
                label: Text(context.l10n.endOfTrack),
                onPressed: ref
                    .read(sleepTimerControllerProvider.notifier)
                    .endOfTrack,
                side: BorderSide.none,
                shape: const StadiumBorder(),
                visualDensity: VisualDensity.compact,
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                // On its card, a step lighter than the card.
                backgroundColor: cs.surfaceContainerHighest,
                labelStyle: TextStyle(
                  color: cs.onSurface,
                  fontSize: context.fontS,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              trackHeight: context.spaceS,
              activeTrackColor: cs.primary,
              inactiveTrackColor: cs.surfaceContainerHighest,
              thumbColor: cs.primary,
              overlayColor: cs.primary.withValues(alpha: 0.12),
              tickMarkShape: SliderTickMarkShape.noTickMark,
              showValueIndicator: ShowValueIndicator.never,
              padding: EdgeInsets.symmetric(vertical: context.spaceM),
            ),
            child: Slider(
              value: value,
              max: SleepTimerSlider.longest.toDouble(),
              divisions: SleepTimerSlider.longest ~/ SleepTimerSlider.step,
              semanticFormatterCallback: (double v) =>
                  SleepTimerSlider.lengthLabel(context.l10n, v.round()),
              onChanged: _onChanged,
              onChangeEnd: _onChangeEnd,
            ),
          ),
        ],
      ),
    );
  }
}
