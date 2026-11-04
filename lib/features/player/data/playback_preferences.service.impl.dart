import 'package:shared_preferences/shared_preferences.dart';

import '../domain/playback_mode.dart';
import '../domain/playback_preferences.service.dart';

/// One value in the platform's preferences store. Anything unreadable falls
/// back to shuffle, which is how the app has always played.
class PlaybackPreferencesImpl implements PlaybackPreferences {
  PlaybackPreferencesImpl([SharedPreferencesAsync? preferences])
    : _preferences = preferences ?? SharedPreferencesAsync();

  static const String _modeKey = 'playback.mode';
  static const String _softTransitionsKey = 'playback.softTransitions';

  final SharedPreferencesAsync _preferences;

  @override
  Future<PlaybackMode> load() async {
    try {
      final String? name = await _preferences.getString(_modeKey);
      for (final PlaybackMode mode in PlaybackMode.values) {
        if (mode.name == name) return mode;
      }
    } on Object {
      // Falls through to the default.
    }
    return PlaybackMode.shuffle;
  }

  @override
  Future<void> save(PlaybackMode mode) =>
      _preferences.setString(_modeKey, mode.name);

  @override
  Future<bool> loadSoftTransitions() async {
    try {
      return await _preferences.getBool(_softTransitionsKey) ?? true;
    } on Object {
      return true;
    }
  }

  @override
  Future<void> saveSoftTransitions(bool enabled) =>
      _preferences.setBool(_softTransitionsKey, enabled);
}
