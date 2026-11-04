/// The listener's mix, kept on the device (#136, #154): the music's level,
/// the room sounds' level, whether they play at all, and each sound's own
/// level per room.
abstract class MixPreferences {
  Future<MixSettings> load();

  Future<void> save(MixSettings settings);
}

/// What [MixPreferences] keeps.
class MixSettings {
  const MixSettings({
    this.musicLevel = 1,
    this.ambienceLevel = 1,
    this.ambienceOn = true,
    this.soundLevels = const <String, double>{},
  });

  final double musicLevel;
  final double ambienceLevel;
  final bool ambienceOn;

  /// Keyed by [soundKey]: one room's rain need not be another's.
  final Map<String, double> soundLevels;

  static String soundKey(String sceneId, String soundId) => '$sceneId/$soundId';

  MixSettings copyWith({
    double? musicLevel,
    double? ambienceLevel,
    bool? ambienceOn,
    Map<String, double>? soundLevels,
  }) => MixSettings(
    musicLevel: musicLevel ?? this.musicLevel,
    ambienceLevel: ambienceLevel ?? this.ambienceLevel,
    ambienceOn: ambienceOn ?? this.ambienceOn,
    soundLevels: soundLevels ?? this.soundLevels,
  );
}
