import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../common/utils/responsive.dart';
import '../../../../l10n/l10n.dart';
import '../../controller/player.provider.dart';
import '../../controller/wake_alarm.controller.dart';
import '../../domain/wake_alarm.dart';
import 'sleep_timer_chips.widget.dart';

/// "Wake up" on the room page (#146): on or off, the time, the days. Only
/// where the platform can set an alarm — Android for now.
class WakeAlarmCard extends ConsumerWidget {
  const WakeAlarmCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!ref.watch(wakeSchedulerProvider).isSupported) {
      return const SizedBox.shrink();
    }
    final ColorScheme cs = Theme.of(context).colorScheme;
    final MaterialLocalizations ml = MaterialLocalizations.of(context);
    final WakeAlarmState? state = ref.watch(wakeAlarmControllerProvider).value;
    if (state == null) return const SizedBox.shrink();
    final WakeAlarm alarm = state.alarm;
    final WakeAlarmController controller = ref.read(
      wakeAlarmControllerProvider.notifier,
    );
    final String time = SleepTimerChips.timeOfDay(
      context,
      DateTime(2000, 1, 1, alarm.hour, alarm.minute),
    );

    Future<void> pickTime() async {
      final TimeOfDay? picked = await showTimePicker(
        context: context,
        initialTime: TimeOfDay(hour: alarm.hour, minute: alarm.minute),
      );
      if (picked == null) return;
      await controller.set(
        alarm.copyWith(hour: picked.hour, minute: picked.minute, enabled: true),
      );
    }

    // Monday first, in the phone's language: DateTime.weekday 1..7.
    final List<String> narrow = ml.narrowWeekdays;
    String dayName(int weekday) => narrow[weekday % 7];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        SwitchListTile(
          contentPadding: EdgeInsets.symmetric(horizontal: context.spaceM),
          title: Text(
            time,
            style: TextStyle(
              fontSize: context.fontL,
              fontWeight: FontWeight.w600,
            ),
          ),
          subtitle: Text(
            state.refused
                ? context.l10n.allowAlarms
                : alarm.enabled
                ? context.l10n.wakeMusicFadesIn
                : context.l10n.off,
            style: TextStyle(
              color: state.refused ? cs.error : cs.onSurfaceVariant,
              fontSize: context.fontS,
            ),
          ),
          value: alarm.enabled,
          onChanged: (bool on) =>
              unawaited(controller.set(alarm.copyWith(enabled: on))),
          secondary: IconButton(
            tooltip: context.l10n.changeTime,
            onPressed: () => unawaited(pickTime()),
            icon: Icon(Icons.schedule, color: cs.onSurface),
          ),
        ),
        Padding(
          padding: EdgeInsets.fromLTRB(
            context.spaceM,
            0,
            context.spaceM,
            context.spaceM,
          ),
          child: Wrap(
            spacing: context.spaceXs,
            children: <Widget>[
              for (int day = 1; day <= 7; day++)
                FilterChip(
                  label: Text(dayName(day)),
                  selected: alarm.weekdays.contains(day),
                  showCheckmark: false,
                  onSelected: (bool on) => unawaited(
                    controller.set(
                      alarm.copyWith(
                        weekdays: on
                            ? <int>{...alarm.weekdays, day}
                            : (<int>{...alarm.weekdays}..remove(day)),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}
