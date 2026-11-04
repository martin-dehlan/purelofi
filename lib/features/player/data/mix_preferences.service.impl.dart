import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../domain/mix_preferences.service.dart';

/// The mix in the platform's preferences store, as one JSON value. Anything
/// unreadable is the default mix: everything at full, the room's sounds on.
class MixPreferencesImpl implements MixPreferences {
  MixPreferencesImpl([SharedPreferencesAsync? preferences])
    : _preferences = preferences ?? SharedPreferencesAsync();

  static const String _key = 'mix';

  final SharedPreferencesAsync _preferences;

  @override
  Future<MixSettings> load() async {
    try {
      final String? json = await _preferences.getString(_key);
      if (json == null) return const MixSettings();
      final Object? data = jsonDecode(json);
      if (data is! Map<String, dynamic>) return const MixSettings();

      double level(Object? value, double fallback) =>
          value is num ? value.toDouble().clamp(0.0, 1.0) : fallback;

      return MixSettings(
        musicLevel: level(data['music'], 1),
        ambienceLevel: level(data['ambience'], 1),
        ambienceOn: data['ambienceOn'] as bool? ?? true,
        soundLevels: <String, double>{
          if (data['sounds'] case final Map<String, dynamic> sounds)
            for (final MapEntry<String, dynamic> e in sounds.entries)
              if (e.value is num) e.key: level(e.value, 0.5),
        },
      );
    } on Object {
      return const MixSettings();
    }
  }

  @override
  Future<void> save(MixSettings settings) => _preferences.setString(
    _key,
    jsonEncode(<String, Object>{
      'music': settings.musicLevel,
      'ambience': settings.ambienceLevel,
      'ambienceOn': settings.ambienceOn,
      'sounds': settings.soundLevels,
    }),
  );
}
