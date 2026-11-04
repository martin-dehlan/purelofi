import 'dart:async';

import 'package:purelofi/features/player/domain/wake_alarm.dart';

/// The platform's alarm in memory (#146).
class FakeWakeScheduler implements WakeScheduler {
  FakeWakeScheduler({this.isSupported = false, this.allowed = true});

  @override
  final bool isSupported;

  /// Whether the system lets exact alarms be set.
  bool allowed;
  DateTime? scheduled;
  int cancels = 0;
  final StreamController<void> _rang = StreamController<void>.broadcast(
    sync: true,
  );

  @override
  Stream<void> get rang => _rang.stream;

  void ring() => _rang.add(null);

  @override
  Future<bool> schedule(DateTime at) async {
    if (!allowed) return false;
    scheduled = at;
    return true;
  }

  @override
  Future<void> cancel() async {
    scheduled = null;
    cancels++;
  }

  Future<void> dispose() => _rang.close();
}

class FakeWakeAlarmStore implements WakeAlarmStore {
  FakeWakeAlarmStore([this.alarm = const WakeAlarm(hour: 7, minute: 0)]);

  WakeAlarm alarm;

  @override
  Future<WakeAlarm> load() async => alarm;

  @override
  Future<void> save(WakeAlarm alarm) async => this.alarm = alarm;
}
