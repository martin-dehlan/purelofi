/// The reasons the app turns the music down, each with a level of its own.
///
/// The audio service multiplies them, together with its own ducking and the
/// soft transitions between tracks (#139), so one never undoes another: the
/// sleep timer fading out during a focus break ends at silence, not at the
/// break's level.
enum VolumeLayer {
  /// The sleep timer's fade before it pauses (#138).
  sleepTimer,

  /// The focus timer's break, when the music steps back (#137). The room's
  /// sounds stay where they are: a break is a moment to hear the rain.
  focusBreak,

  /// The listener's own level for the music (#154).
  music,

  /// The listener's own level for the room's sounds (#136, #154).
  ambience,

  /// The wake-up alarm bringing the music in from silence (#146).
  alarm,
}

/// The layers that turn the room's sounds down too. The music's own level
/// and the focus break are the music's alone.
const Set<VolumeLayer> ambienceLayers = <VolumeLayer>{
  VolumeLayer.sleepTimer,
  VolumeLayer.ambience,
  VolumeLayer.alarm,
};

/// The layers that turn the music down.
const Set<VolumeLayer> musicLayers = <VolumeLayer>{
  VolumeLayer.sleepTimer,
  VolumeLayer.focusBreak,
  VolumeLayer.music,
  VolumeLayer.alarm,
};
