/// How much of one track has really been heard (#142).
///
/// Fed the playhead as it moves. Small steps forward are listening; a jump
/// — a seek, a restart, the playhead of the next track arriving early — is
/// not, so it is left out rather than counted.
class PlayTally {
  Duration _heard = Duration.zero;
  Duration? _last;

  /// The longest step between two playhead reports that still counts as
  /// listening. Reports arrive several times a second while playing.
  static const Duration maxStep = Duration(seconds: 2);

  /// How long a track has to be heard before it counts as played, unless
  /// it is shorter than that: then all of it but the last second.
  static const Duration countsAfter = Duration(seconds: 30);

  Duration get heard => _heard;

  /// The playhead is at [position] and the music is [playing].
  void observe(Duration position, {required bool playing}) {
    final Duration? last = _last;
    _last = position;
    if (!playing || last == null) return;

    final Duration step = position - last;
    if (step > Duration.zero && step <= maxStep) _heard += step;
  }

  /// Whether what was heard of a track [duration] long makes it a play.
  bool counts(Duration? duration) {
    Duration needed = countsAfter;
    if (duration != null &&
        duration < countsAfter + const Duration(seconds: 1)) {
      needed = duration - const Duration(seconds: 1);
      if (needed <= Duration.zero) needed = duration;
    }

    return _heard >= needed;
  }
}

/// The ids of [newestFirst] plays, each once, at most [limit] of them —
/// what "recently played" lists.
List<String> recentTrackIds(Iterable<String> newestFirst, {int limit = 50}) {
  final List<String> ids = <String>[];
  final Set<String> seen = <String>{};
  for (final String id in newestFirst) {
    if (!seen.add(id)) continue;
    ids.add(id);
    if (ids.length == limit) break;
  }

  return ids;
}
