/// The wake-up alarm (#146): when, on which days, in which room, and how
/// slowly the music comes in.
class WakeAlarm {
  const WakeAlarm({
    required this.hour,
    required this.minute,
    this.weekdays = const <int>{1, 2, 3, 4, 5},
    this.sceneId,
    this.fade = const Duration(seconds: 60),
    this.enabled = false,
  });

  final int hour;
  final int minute;

  /// `DateTime.monday` (1) to `DateTime.sunday` (7). Empty: once, the next
  /// time the clock reads [hour]:[minute].
  final Set<int> weekdays;

  /// The room to wake up in; `null` for the one the app opens in.
  final String? sceneId;

  final Duration fade;
  final bool enabled;

  WakeAlarm copyWith({
    int? hour,
    int? minute,
    Set<int>? weekdays,
    String? sceneId,
    Duration? fade,
    bool? enabled,
  }) => WakeAlarm(
    hour: hour ?? this.hour,
    minute: minute ?? this.minute,
    weekdays: weekdays ?? this.weekdays,
    sceneId: sceneId ?? this.sceneId,
    fade: fade ?? this.fade,
    enabled: enabled ?? this.enabled,
  );

  Map<String, Object?> toJson() => <String, Object?>{
    'hour': hour,
    'minute': minute,
    'weekdays': weekdays.toList()..sort(),
    'sceneId': sceneId,
    'fadeSeconds': fade.inSeconds,
    'enabled': enabled,
  };

  static WakeAlarm fromJson(Map<String, Object?> json) => WakeAlarm(
    hour: (json['hour'] as num?)?.toInt().clamp(0, 23) ?? 7,
    minute: (json['minute'] as num?)?.toInt().clamp(0, 59) ?? 0,
    weekdays: <int>{
      for (final Object? d
          in (json['weekdays'] as List<Object?>?) ?? <Object?>[])
        if (d is num && d >= 1 && d <= 7) d.toInt(),
    },
    sceneId: json['sceneId'] as String?,
    fade: Duration(seconds: (json['fadeSeconds'] as num?)?.toInt() ?? 60),
    enabled: json['enabled'] as bool? ?? false,
  );
}

/// The next moment [alarm] rings after [now], in local time.
///
/// Built from calendar fields, not by adding 24-hour days, so a clock
/// change in between moves nothing: 7:00 stays 7:00.
DateTime nextWake(WakeAlarm alarm, DateTime now) {
  for (int days = 0; days <= 7; days++) {
    final DateTime at = DateTime(
      now.year,
      now.month,
      now.day + days,
      alarm.hour,
      alarm.minute,
    );
    if (!at.isAfter(now)) continue;
    if (alarm.weekdays.isEmpty || alarm.weekdays.contains(at.weekday)) {
      return at;
    }
  }
  // Unreachable with a valid weekday; the same time tomorrow otherwise.
  return DateTime(now.year, now.month, now.day + 1, alarm.hour, alarm.minute);
}

/// Sets the alarm with the platform. On Android an alarm clock the system
/// shows; elsewhere none yet (#146: iOS waits for AlarmKit).
abstract class WakeScheduler {
  bool get isSupported;

  /// Returns whether the alarm is set: Android lets the listener refuse
  /// exact alarms.
  Future<bool> schedule(DateTime at);

  Future<void> cancel();

  /// Fires when the app was opened by the alarm ringing.
  Stream<void> get rang;
}

/// Where the alarm is kept (#146).
abstract class WakeAlarmStore {
  Future<WakeAlarm> load();

  Future<void> save(WakeAlarm alarm);
}
