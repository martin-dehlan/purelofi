import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../domain/wake_alarm.dart';

/// The alarm in the platform's preferences store (#146).
class WakeAlarmStoreImpl implements WakeAlarmStore {
  WakeAlarmStoreImpl([SharedPreferencesAsync? preferences])
    : _preferences = preferences ?? SharedPreferencesAsync();

  static const String _key = 'wake.alarm';
  final SharedPreferencesAsync _preferences;

  @override
  Future<WakeAlarm> load() async {
    try {
      final String? json = await _preferences.getString(_key);
      if (json != null) {
        return WakeAlarm.fromJson(jsonDecode(json) as Map<String, Object?>);
      }
    } on Object {
      // Falls through to the default.
    }
    return const WakeAlarm(hour: 7, minute: 0);
  }

  @override
  Future<void> save(WakeAlarm alarm) =>
      _preferences.setString(_key, jsonEncode(alarm.toJson()));
}
