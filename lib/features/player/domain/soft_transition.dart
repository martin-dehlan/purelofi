/// How loud a track should be at [position] for a soft transition (#139),
/// from 0 to 1.
///
/// The last [fadeOut] of a track goes down to silence, so the next one does
/// not cut in on a full chord. A track that arrived that way — the one
/// before it ran out — comes in over [fadeIn]. A track the listener picked
/// or skipped to starts at once: they asked for it, they should hear it.
///
/// Nothing fades when transitions are off, when the track loops (repeat
/// one: the end is not an end), or while its length is not known yet.
double softTransitionLevel({
  required Duration position,
  required Duration? duration,
  required bool enabled,
  required bool loops,
  required bool fadesIn,
  Duration fadeIn = softFadeIn,
  Duration fadeOut = softFadeOut,
}) {
  if (!enabled) return 1;

  double level = 1;
  if (fadesIn) level = _fraction(position, fadeIn);
  if (!loops && duration != null && duration > Duration.zero) {
    final double out = _fraction(duration - position, fadeOut);
    if (out < level) level = out;
  }

  return level;
}

/// How long the start of a track takes to come in.
const Duration softFadeIn = Duration(seconds: 2);

/// How long the end of a track takes to go out.
const Duration softFadeOut = Duration(seconds: 4);

double _fraction(Duration part, Duration whole) {
  if (whole <= Duration.zero) return 1;
  final double value = part.inMicroseconds / whole.inMicroseconds;

  return value.clamp(0, 1).toDouble();
}
