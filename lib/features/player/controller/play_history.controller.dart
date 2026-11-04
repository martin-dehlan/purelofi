import 'dart:async';

import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../library/controller/library.controller.dart';
import '../domain/play_event.entity.dart';
import '../domain/play_history.repository.dart';
import '../domain/play_tally.dart';
import '../domain/player.state.dart';
import '../domain/track.entity.dart';
import 'player.controller.dart';
import 'player.provider.dart';
import 'scene.controller.dart';
import 'track.controller.dart';

part 'play_history.controller.g.dart';

/// Writes the listening log as the music plays (#142).
///
/// Follows the player rather than being called by it: the player decides
/// what plays, this only notices what was heard. A play is written once it
/// counts (thirty seconds, or nearly all of a short track) and its listened
/// time kept up to date until the next track starts. Built once at the
/// root; a failing database never touches playback.
@Riverpod(keepAlive: true)
class PlayHistoryRecorder extends _$PlayHistoryRecorder {
  String? _trackId;
  TrackSource? _source;
  String? _sceneId;
  DateTime? _startedAt;
  PlayTally _tally = PlayTally();
  int? _rowId;
  int _savedSeconds = 0;

  /// How often the listened time of a running play is written.
  static const Duration saveEvery = Duration(seconds: 30);

  @override
  void build() {
    unawaited(_safely(() => _history.prune(now: DateTime.now())));

    ref.listen<PlayerState>(playerControllerProvider, (
      PlayerState? _,
      PlayerState player,
    ) {
      final TrackEntity? track = player.currentTrack;
      if (track?.id != _trackId) {
        unawaited(_finish());
        _begin(track);
      }
      if (track == null) return;

      _tally.observe(player.position, playing: player.isPlaying);
      unawaited(_save(player.duration));
      if (!player.isPlaying) unawaited(_flush());
    }, fireImmediately: true);

    ref.onDispose(() => unawaited(_finish()));
  }

  PlayHistoryRepository get _history => ref.read(playHistoryRepositoryProvider);

  void _begin(TrackEntity? track) {
    _trackId = track?.id;
    _source = track?.source;
    _sceneId = ref.read(activeSceneControllerProvider)?.id;
    _startedAt = DateTime.now();
    _tally = PlayTally();
    _rowId = null;
    _savedSeconds = 0;
  }

  /// Writes the play the moment it counts, then its time every [saveEvery].
  Future<void> _save(Duration? duration) async {
    final String? trackId = _trackId;
    final TrackSource? source = _source;
    final DateTime? startedAt = _startedAt;
    if (trackId == null || source == null || startedAt == null) return;

    final int heard = _tally.heard.inSeconds;
    if (_rowId == null) {
      if (!_tally.counts(duration)) return;
      // Claimed before the await, so two reports do not write two rows.
      _rowId = -1;
      _savedSeconds = heard;
      final int? id = await _safely(
        () => _history.record(
          trackId: trackId,
          source: source,
          sceneId: _sceneId,
          startedAt: startedAt,
          listenedSeconds: heard,
        ),
      );
      if (_trackId == trackId) _rowId = id;
      return;
    }

    if (heard - _savedSeconds >= saveEvery.inSeconds) await _flush();
  }

  /// Writes the listened time now: on pause, and when the track changes.
  Future<void> _flush() async {
    final int? id = _rowId;
    final int heard = _tally.heard.inSeconds;
    if (id == null || id < 0 || heard == _savedSeconds) return;

    _savedSeconds = heard;
    await _safely(() => _history.updateListened(id, heard));
  }

  Future<void> _finish() => _flush();

  /// The log is a nicety; a database that fails is never the listener's
  /// problem.
  static Future<T?> _safely<T>(Future<T> Function() body) async {
    try {
      return await body();
    } on Object {
      return null;
    }
  }
}

/// The newest plays, for "recently played".
@Riverpod(keepAlive: true)
Stream<List<PlayEventEntity>> recentPlays(Ref ref) =>
    ref.watch(playHistoryRepositoryProvider).watchNewest(limit: 200);

/// What "recently played" lists: each track once, newest first, only those
/// still there to play — a track pulled from the catalogue or a file the
/// listener removed drops out.
@riverpod
List<TrackEntity> recentlyPlayedTracks(Ref ref) {
  final List<PlayEventEntity> plays =
      ref.watch(recentPlaysProvider).value ?? const <PlayEventEntity>[];
  if (plays.isEmpty) return const <TrackEntity>[];

  final Map<String, TrackEntity> playable = <String, TrackEntity>{
    for (final TrackEntity t
        in ref.watch(trackListControllerProvider).value ??
            const <TrackEntity>[])
      t.id: t,
    for (final TrackEntity t
        in ref.watch(libraryControllerProvider).value ?? const <TrackEntity>[])
      t.id: t,
  };

  return <TrackEntity>[
    for (final String id in recentTrackIds(
      plays.map((PlayEventEntity p) => p.trackId).where(playable.containsKey),
    ))
      playable[id]!,
  ];
}
