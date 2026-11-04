import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';

import '../domain/wake_alarm.dart';

/// The alarm through `MainActivity` on Android (#146): `AlarmManager`'s
/// alarm clock, which survives Doze and shows in the status bar. When it
/// rings the activity starts with a wake action and tells Dart.
class WakeSchedulerImpl implements WakeScheduler {
  WakeSchedulerImpl() {
    if (isSupported) {
      _channel.setMethodCallHandler((MethodCall call) async {
        if (call.method == 'rang') _rang.add(null);
      });
    }
  }

  static const MethodChannel _channel = MethodChannel('app.purelofi/wake');

  final StreamController<void> _rang = StreamController<void>.broadcast();

  @override
  bool get isSupported => Platform.isAndroid;

  @override
  Stream<void> get rang => _rang.stream;

  @override
  Future<bool> schedule(DateTime at) async {
    if (!isSupported) return false;
    try {
      return await _channel.invokeMethod<bool>('schedule', <String, Object>{
            'at': at.millisecondsSinceEpoch,
          }) ??
          false;
    } on Object {
      // No channel: the alarm stays off.
      return false;
    }
  }

  @override
  Future<void> cancel() async {
    if (!isSupported) return;
    try {
      await _channel.invokeMethod<void>('cancel');
    } on Object {
      // Nothing set, nothing to cancel.
    }
  }

  /// Asks the activity whether this launch was the alarm ringing.
  Future<void> checkLaunch() async {
    if (!isSupported) return;
    try {
      if (await _channel.invokeMethod<bool>('launchedByAlarm') ?? false) {
        _rang.add(null);
      }
    } on Object {
      // An older build without the channel.
    }
  }
}
