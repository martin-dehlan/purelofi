/// Why something else wants the audio output.
enum InterruptionKind {
  /// A navigation prompt or a notification: quieter, not silent.
  duck,

  /// A call, or another player taking over: stop.
  pause,
}

/// What playback should do about an interruption.
enum InterruptionAction { none, pause, resume, duck, restoreVolume }

/// Decides what an interruption means for playback.
///
/// Pure, because the interesting part is not talking to the platform but
/// knowing when *not* to act — and that is exactly what cannot be checked by
/// hand on a device without making twenty phone calls.
///
/// [pausedByInterruption] is the rule that matters most: if the listener
/// pressed pause and then took a call, the music must not come back on
/// afterwards. Starting a stranger's music in their pocket is worse than
/// leaving it off.
InterruptionAction actionForInterruption({
  required InterruptionKind kind,
  required bool beginning,
  required bool isPlaying,
  required bool pausedByInterruption,
}) {
  if (beginning) {
    if (!isPlaying) return InterruptionAction.none;

    return kind == InterruptionKind.duck
        ? InterruptionAction.duck
        : InterruptionAction.pause;
  }

  if (kind == InterruptionKind.duck) return InterruptionAction.restoreVolume;

  return pausedByInterruption
      ? InterruptionAction.resume
      : InterruptionAction.none;
}

/// How quiet playback goes while something else talks over it.
///
/// Not silence: the point of ducking is that the music is still there under
/// the announcement.
const double duckedVolume = 0.3;
