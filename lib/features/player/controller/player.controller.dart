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
import '../domain/player.state.dart';
import '../domain/scene.entity.dart';
import '../domain/track.entity.dart';
import 'playback_source.controller.dart';
import 'player.provider.dart';
import 'scene.controller.dart';
import 'track.controller.dart';

part 'player.controller.g.dart';

/// How much likelier a favourite is than anything else.
const int favoriteWeight = 3;

/// One of [tracks], with the ones in [favorites] counted [favoriteWeight]
/// times over.
///
/// Pure and injectable so the weighting can be tested without waiting for a
/// few hundred tracks to play.
TrackEntity pickWeighted(
  List<TrackEntity> tracks, {
  required Set<String> favorites,
  required Random random,
}) {
  int total = 0;
  for (final TrackEntity track in tracks) {
    total += favorites.contains(track.id) ? favoriteWeight : 1;
  }

  int roll = random.nextInt(total);
  for (final TrackEntity track in tracks) {
    roll -= favorites.contains(track.id) ? favoriteWeight : 1;
    if (roll < 0) return track;
  }

  return tracks.last;
}

/// Playback: what is playing, whether it is playing, and what plays next.
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
        ];

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

  /// Starts a random track. Called when the app opens and whenever a track
  /// ends — the stream never stops on its own.
  Future<void> playNext() async {
    final TrackSource source = ref.read(playbackSourceControllerProvider);
    final List<TrackEntity> tracks;
    try {
      // Awaiting the future means the first play works even if nothing has
      // loaded the track list yet.
      tracks = source == TrackSource.local
          ? await ref.read(libraryRepositoryProvider).getTracks()
          : await ref.read(trackListControllerProvider.future);
    } on Object catch (error, stackTrace) {
      state = state.copyWith(
        error: ErrorMapper.fromException(error, stackTrace),
        isPlaying: false,
      );
      return;
    }

    if (tracks.isEmpty) return;

    // A failure here must not stop the music: an unreadable favourites table
    // means an unweighted shuffle, not silence. Favourites are catalogue
    // marks, so the listener's own library shuffles evenly.
    Set<String> favorites = const <String>{};
    if (source == TrackSource.catalogue) {
      try {
        favorites = await ref
            .read(favoritesRepositoryProvider)
            .getFavoriteIds();
      } on Object {
        favorites = const <String>{};
      }
    }

    if (source == TrackSource.local) {
      final LibraryView view = await _libraryView();
      if (view.order == LibraryOrder.inOrder) {
        return playTrack(_step(sortTracks(tracks, view.sort), 1));
      }
    }

    await playTrack(_pickNext(tracks, favorites));
  }

  /// The previous-track button.
  ///
  /// For PureLofi's stream there is no history to go back through — it
  /// picks at random — so it starts the track again. The listener's own
  /// music has an order, so there it goes back: to the track above in the
  /// list, or in shuffle to the one that actually played before. A few
  /// seconds in, it starts the track again first, as every player does.
  Future<void> previous() async {
    final TrackEntity? current = state.currentTrack;
    if (current == null) return;

    if (current.source != TrackSource.local ||
        state.position > restartThreshold) {
      return restart();
    }

    final LibraryView view = await _libraryView();
    if (view.order == LibraryOrder.inOrder) {
      final List<TrackEntity> tracks;
      try {
        tracks = await ref.read(libraryRepositoryProvider).getTracks();
      } on Object {
        return restart();
      }
      if (tracks.isEmpty) return restart();
      return playTrack(_step(sortTracks(tracks, view.sort), -1), back: true);
    }

    if (_played.isEmpty) return restart();
    return playTrack(_played.removeLast(), back: true);
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

  /// The listener's own tracks in the order they actually played, for
  /// "previous" in shuffle. Bounded: nobody goes back fifty songs.
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

  /// Back to the start of the current track. There is no history to step
  /// through — the stream picks tracks at random — so this is what "previous"
  /// can honestly mean.
  Future<void> restart() async {
    if (state.currentTrack == null) return;

    await seek(Duration.zero);
  }

  /// Plays [track]. [back] is set when "previous" is the reason, so going
  /// back does not itself become a step to go back to.
  Future<void> playTrack(TrackEntity track, {bool back = false}) async {
    final TrackEntity? current = state.currentTrack;
    if (!back &&
        current != null &&
        current.source == TrackSource.local &&
        track.source == TrackSource.local &&
        current.id != track.id) {
      _played.add(current);
      if (_played.length > _historyLimit) _played.removeAt(0);
    }

    // Picking a track from the other list is choosing that side: the stream
    // carries on from wherever the listener's last choice came from.
    if (ref.read(playbackSourceControllerProvider) != track.source) {
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

    ref.read(playbackSourceControllerProvider.notifier).select(source);
    await playNext();
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

  /// A random track that is not the one already playing, so the stream never
  /// repeats itself back to back.
  ///
  /// A favourite counts [favoriteWeight] times, which makes it likelier
  /// without making it certain: a shuffle that only ever played the marked
  /// tracks would turn the catalogue into a playlist of three, and the point
  /// of the stream is that it keeps going somewhere.
  TrackEntity _pickNext(List<TrackEntity> tracks, Set<String> favorites) {
    final String? currentId = state.currentTrack?.id;
    final List<TrackEntity> candidates = tracks
        .where((TrackEntity track) => track.id != currentId)
        .toList();
    final List<TrackEntity> pool = candidates.isEmpty ? tracks : candidates;

    return pickWeighted(pool, favorites: favorites, random: _random);
  }

  final Random _random = Random();
}
