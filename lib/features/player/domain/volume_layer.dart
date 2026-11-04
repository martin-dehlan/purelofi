/// The reasons the app turns the music down, each with a level of its own.
///
/// The audio service multiplies them, together with its own ducking and the
/// soft transitions between tracks (#139), so one never undoes another: the
/// sleep timer fading out during a focus break ends at silence, not at the
/// break's level.
enum VolumeLayer {
  /// The sleep timer's fade before it pauses (#138).
  sleepTimer,

  /// The focus timer's break, when the music steps back (#137).
  focusBreak,
}
