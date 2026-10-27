/// How the stream moves on, as one setting with three states: one button
/// that steps through them, in this order.
///
/// One mode for both PureLofi's music and the listener's own, so the button
/// never means something different depending on which side is playing.
enum PlaybackMode {
  /// A random track next, any but the one just played. Where the app starts.
  shuffle,

  /// The current track again and again, until the listener skips — and a
  /// skip goes on in order, since repeat is about this track, not the next.
  repeatOne,

  /// Down the list: PureLofi's tracks oldest first, the listener's in the
  /// sort they chose.
  inOrder;

  /// Whether the next track is drawn at random.
  bool get shuffles => this == shuffle;

  /// Whether the current track loops.
  bool get loops => this == repeatOne;

  /// What the button turns this into.
  PlaybackMode get following => values[(index + 1) % values.length];
}
