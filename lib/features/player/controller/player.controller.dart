import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../common/analytics/analytics.provider.dart';
import '../../../common/errors/app_error.dart';
import '../../../common/errors/error_mapper.dart';
import '../../library/controller/library.controller.dart';
import '../../library/controller/library.provider.dart';
import '../../library/domain/library_view.dart';
import '../domain/audio_player.service.dart';
import '../domain/playback_mode.dart';
import '../domain/player.state.dart';
import '../domain/scene.entity.dart';
import '../domain/track.entity.dart';
import '../domain/up_next.dart';
import 'playback_mode.controller.dart';
import 'playback_source.controller.dart';
import 'player.provider.dart';
import 'scene.controller.dart';
import 'track.controller.dart';

export '../domain/up_next.dart' show favoriteWeight, pickWeighted;

part 'player.controller.g.dart';

/// Playback: what is playing, whether it is playing, and what plays next.
///
/// What plays next is the listener's queue first, then [PlayerState.upNext]:
/// the stream's own plan, drawn a few tracks ahead so it can be shown, and
/// redrawn when shuffle, the side or the sort changes.
///
/// The audio itself lives in [AudioPlayerService]; this controller only
/// decides which track to hand it.
@riverpod
class PlayerController extends _$PlayerController {
  @override
  PlayerState build() {
    final AudioPlayerService audio = ref.watch(audioPlayerServiceProvider);

    final List<StreamSubscription<Object?>> subscriptions =
        <StreamSubscription<Object?>>[
          audio.playingStream.listen((bool playing) {
            state = state.copyWith(isPlaying: playing);
          }),
          // Fired when a track ends and when skip is pressed on the lock
          // screen — both mean "play something else".
          audio.nextRequests.listen((_) => unawaited(playNext())),
          audio.errors.listen((AppError error) {
            state = state.copyWith(error: error, isPlaying: false);
          }),
          audio.positionStream.listen((Duration position) {
            state = state.copyWith(position: position);
          }),
          audio.durationStream.listen((Duration? duration) {
            state = state.copyWith(duration: duration);
          }),
          // Shuffle or repeat changed on the lock screen: the same as the
          // buttons in the app.
          audio.modeRequests.listen(
            (PlaybackMode mode) => unawaited(
              ref.read(playbackModeControllerProvider.notifier).set(mode),
            ),
          ),
        ];

    // The audio service loops on repeat and shows both settings on the lock
    // screen, so it follows the mode from the moment it is loaded. When
    // shuffling starts or stops, the plan was drawn the other way: draw it
    // again.
    bool? shuffle;
    ref.listen<AsyncValue<PlaybackMode>>(playbackModeControllerProvider, (
      AsyncValue<PlaybackMode>? _,
      AsyncValue<PlaybackMode> mode,
    ) {
      final PlaybackMode? value = mode.value;
      if (value == null) return;

      unawaited(audio.setPlaybackMode(value));
      if (shuffle != null && shuffle != value.shuffles) unawaited(replan());
      shuffle = value.shuffles;
    }, fireImmediately: true);

    // The lock screen shows the room, and follows it when the listener
    // switches scenes.
    ref.listen<SceneEntity?>(
      activeSceneControllerProvider,
      (SceneEntity? _, SceneEntity? scene) =>
          unawaited(_showArtwork(scene?.thumbnailUrl)),
      fireImmediately: true,
    );

    ref.onDispose(() {
      for (final StreamSubscription<Object?> subscription in subscriptions) {
        unawaited(subscription.cancel());
      }
    });

    return const PlayerState();
  }

  /// Starts the next track: the first in the queue, else the first the
  /// stream planned. Called when the app opens and whenever a track ends —
  /// the stream never stops on its own.
  Future<void> playNext() => _advance();

  /// [useQueue] is off when the listener switched sides: they asked for that
  /// side's music now, not for what they had lined up.
  Future<void> _advance({bool useQueue = true}) async {
    if (useQueue && state.queue.isNotEmpty) {
      final TrackEntity next = state.queue.first;
      state = state.copyWith(queue: state.queue.sublist(1));
      await _play(next);
      return _plan();
    }

    if (state.upNext.isEmpty) await _plan(surfaceErrors: true);
    if (state.upNext.isEmpty) return;

    final TrackEntity next = state.upNext.first;
    state = state.copyWith(upNext: state.upNext.sublist(1));
    await _play(next);
    await _plan();
  }

  /// The previous-track button.
  ///
  /// In order it goes to the track above in the list; in shuffle, to the one
  /// that actually played before, and the one it leaves goes back to the
  /// front of what comes next. A few seconds in, it starts the track again
  /// first, as every player does — and with nothing to go back to, that is
  /// all it does.
  Future<void> previous() async {
    final TrackEntity? current = state.currentTrack;
    if (current == null) return;

    if (state.position > restartThreshold) return restart();

    final PlaybackMode mode = await _playbackMode();
    if (!mode.shuffles) {
      final List<TrackEntity> tracks;
      try {
        tracks = await _tracksFor(current.source);
      } on Object {
        return restart();
      }
      if (tracks.isEmpty) return restart();
      await _play(
        _step(await _ordered(tracks, current.source), -1),
        back: true,
      );
      return _plan();
    }

    if (_played.isEmpty) return restart();
    final TrackEntity before = _played.removeLast();
    state = state.copyWith(upNext: <TrackEntity>[current, ...state.upNext]);
    await _play(before, back: true);
  }

  /// Plays [track] after everything lined up for later, in the order added.
  void addToQueue(TrackEntity track) =>
      state = state.copyWith(queue: <TrackEntity>[...state.queue, track]);

  /// Plays [track] as soon as the current one ends, ahead of the queue.
  void queueNext(TrackEntity track) =>
      state = state.copyWith(queue: <TrackEntity>[track, ...state.queue]);

  void removeFromQueue(int index) {
    if (index < 0 || index >= state.queue.length) return;
    state = state.copyWith(
      queue: <TrackEntity>[...state.queue]..removeAt(index),
    );
  }

  void clearQueue() => state = state.copyWith(queue: const <TrackEntity>[]);

  /// Jumps to the [index]th queued track. What was queued before it is
  /// skipped with it, as in every player.
  Future<void> skipToQueued(int index) async {
    if (index < 0 || index >= state.queue.length) return;

    final TrackEntity track = state.queue[index];
    state = state.copyWith(queue: state.queue.sublist(index + 1));
    await _play(track);
    await _plan();
  }

  /// Jumps to the [index]th track the stream planned, skipping the ones
  /// before it. The queue stays as it is.
  Future<void> skipToUpNext(int index) async {
    if (index < 0 || index >= state.upNext.length) return;

    final TrackEntity track = state.upNext[index];
    state = state.copyWith(upNext: state.upNext.sublist(index + 1));
    await _play(track);
    await _plan();
  }

  /// Drops [id] from everything that might play it later. For a file the
  /// listener removed: the player must never reach for one that is gone.
  void forget(String id) {
    bool keep(TrackEntity t) => t.id != id;
    _played.removeWhere((TrackEntity t) => !keep(t));
    state = state.copyWith(
      queue: state.queue.where(keep).toList(),
      upNext: state.upNext.where(keep).toList(),
    );
  }

  /// Draws the stream's plan again from scratch: shuffle or the sort changed,
  /// and the old one was drawn the other way.
  Future<void> replan() async {
    state = state.copyWith(upNext: const <TrackEntity>[]);
    await _plan();
  }

  /// Tops [PlayerState.upNext] up from the side that is playing: in order,
  /// the tracks after the current one; in shuffle, what was already drawn
  /// and new draws after it.
  ///
  /// A failure to load the tracks leaves the plan as it was. [surfaceErrors]
  /// is for when nothing at all could play without them.
  Future<void> _plan({bool surfaceErrors = false}) async {
    final TrackSource source = ref.read(playbackSourceControllerProvider);
    final List<TrackEntity> tracks;
    try {
      tracks = await _tracksFor(source);
    } on Object catch (error, stackTrace) {
      if (surfaceErrors) {
        state = state.copyWith(
          error: ErrorMapper.fromException(error, stackTrace),
          isPlaying: false,
        );
      }
      return;
    }

    final String? currentId = state.currentTrack?.id;
    final PlaybackMode mode = await _playbackMode();
    if (!mode.shuffles) {
      state = state.copyWith(
        upNext: upNextInOrder(
          await _ordered(tracks, source),
          currentId: currentId,
        ),
      );
      return;
    }

    state = state.copyWith(
      upNext: upNextShuffled(
        tracks,
        currentId: currentId,
        favorites: await _favoritesFor(source),
        random: _random,
        planned: state.upNext,
      ),
    );
  }

  /// A failure here must not stop the music: an unreadable favourites table
  /// means an unweighted shuffle, not silence. Favourites are catalogue
  /// marks, so the listener's own library shuffles evenly.
  Future<Set<String>> _favoritesFor(TrackSource source) async {
    if (source != TrackSource.catalogue) return const <String>{};
    try {
      return await ref.read(favoritesRepositoryProvider).getFavoriteIds();
    } on Object {
      return const <String>{};
    }
  }

  /// Every track on [source]'s side. Awaiting the future means the first
  /// play works even if nothing has loaded the track list yet.
  Future<List<TrackEntity>> _tracksFor(TrackSource source) =>
      source == TrackSource.local
      ? ref.read(libraryRepositoryProvider).getTracks()
      : ref.read(trackListControllerProvider.future);

  /// [tracks] in the order "in order" plays them: the listener's own in the
  /// sort they chose for the list, PureLofi's oldest first, the order they
  /// were recorded in.
  Future<List<TrackEntity>> _ordered(
    List<TrackEntity> tracks,
    TrackSource source,
  ) async {
    if (source == TrackSource.local) {
      return sortTracks(tracks, (await _libraryView()).sort);
    }

    return List<TrackEntity>.of(tracks)..sort((TrackEntity a, TrackEntity b) {
      final int byAge = a.createdAt.compareTo(b.createdAt);
      return byAge != 0 ? byAge : a.id.compareTo(b.id);
    });
  }

  Future<PlaybackMode> _playbackMode() async {
    try {
      return await ref.read(playbackModeControllerProvider.future);
    } on Object {
      return PlaybackMode.shuffle;
    }
  }

  /// How far into a track "previous" means "from the top" rather than "the
  /// one before".
  static const Duration restartThreshold = Duration(seconds: 3);

  /// The track [by] places from the current one in [sorted], round the ends.
  /// Anything not in the list — the first local track after a switch — starts
  /// at the top.
  TrackEntity _step(List<TrackEntity> sorted, int by) {
    final int at = sorted.indexWhere(
      (TrackEntity t) => t.id == state.currentTrack?.id,
    );
    if (at < 0) return sorted.first;

    return sorted[(at + by) % sorted.length];
  }

  Future<LibraryView> _libraryView() async {
    try {
      return await ref.read(libraryViewControllerProvider.future);
    } on Object {
      return const LibraryView();
    }
  }

  /// The tracks in the order they actually played, for "previous" in
  /// shuffle. One side at a time — switching starts it afresh — and bounded:
  /// nobody goes back fifty songs.
  final List<TrackEntity> _played = <TrackEntity>[];
  static const int _historyLimit = 50;

  /// Hands the lock screen a picture of the room.
  ///
  /// Through the file cache rather than as a URL: `audio_service` takes a
  /// `file://` URI straight to the platform, while a remote one goes through
  /// a downloader of its own. Ours already has the file — and a cover that
  /// only appears when there is a network would be missing exactly when the
  /// offline cache is doing its job.
  Future<void> _showArtwork(String? url) async {
    final AudioPlayerService audio = ref.read(audioPlayerServiceProvider);
    if (url == null || url.isEmpty) return audio.setArtwork(null);

    final File? file = await ref.read(mediaCacheProvider)?.store(url);

    // No cache, or the download failed: hand over the URL and let the
    // platform try. A missing cover is not worth an error.
    return audio.setArtwork(
      file == null ? Uri.tryParse(url) : Uri.file(file.path),
    );
  }

  /// Jumps to [position] in the current track.
  Future<void> seek(Duration position) async {
    if (state.currentTrack == null) return;

    state = state.copyWith(position: position);
    await ref.read(audioPlayerServiceProvider).seek(position);
  }

  /// Back to the start of the current track.
  Future<void> restart() async {
    if (state.currentTrack == null) return;

    await seek(Duration.zero);
  }

  /// Plays [track] because the listener picked it from a list. In order the
  /// stream carries on from it; in shuffle the draws already made stand.
  Future<void> playTrack(TrackEntity track) async {
    final List<TrackEntity> upNext = state.upNext;
    if (upNext.isNotEmpty && upNext.first.id == track.id) {
      state = state.copyWith(upNext: upNext.sublist(1));
    }
    await _play(track);
    await _plan();
  }

  /// Hands [track] to the audio. [back] is set when "previous" is the
  /// reason, so going back does not itself become a step to go back to.
  Future<void> _play(TrackEntity track, {bool back = false}) async {
    final TrackEntity? current = state.currentTrack;
    if (!back &&
        current != null &&
        current.source == track.source &&
        current.id != track.id) {
      _played.add(current);
      if (_played.length > _historyLimit) _played.removeAt(0);
    }

    // Picking a track from the other list is choosing that side: the stream
    // carries on from wherever the listener's last choice came from.
    // The plan was drawn from the side just left.
    if (ref.read(playbackSourceControllerProvider) != track.source) {
      _played.clear();
      state = state.copyWith(upNext: const <TrackEntity>[]);
      ref.read(playbackSourceControllerProvider.notifier).select(track.source);
    }

    state = state.copyWith(
      currentTrack: track,
      position: Duration.zero,
      duration: track.durationSeconds == null
          ? null
          : Duration(seconds: track.durationSeconds!),
      error: null,
    );
    unawaited(
      track.source == TrackSource.local
          ? ref.read(analyticsServiceProvider).localTrackPlayed()
          : ref.read(analyticsServiceProvider).trackPlayed(track.id),
    );
    await ref.read(audioPlayerServiceProvider).playTrack(track);
  }

  /// Switches the stream between PureLofi's music and the listener's own,
  /// and starts something from the new side straight away: a switch that
  /// kept playing the old source until the track ended would feel broken.
  Future<void> useSource(TrackSource source) async {
    if (ref.read(playbackSourceControllerProvider) == source) return;

    _played.clear();
    state = state.copyWith(upNext: const <TrackEntity>[]);
    ref.read(playbackSourceControllerProvider.notifier).select(source);
    await _advance(useQueue: false);
  }

  Future<void> togglePlayPause() async {
    final AudioPlayerService audio = ref.read(audioPlayerServiceProvider);

    if (state.currentTrack == null) {
      await playNext();
      return;
    }

    if (state.isPlaying) {
      await audio.pause();
    } else {
      await audio.play();
    }
  }

  final Random _random = Random();
}
