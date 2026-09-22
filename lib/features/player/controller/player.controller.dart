import 'dart:async';
import 'dart:math';

import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../common/analytics/analytics.provider.dart';
import '../../../common/errors/app_error.dart';
import '../../../common/errors/error_mapper.dart';
import '../domain/audio_player.service.dart';
import '../domain/player.state.dart';
import '../domain/track.entity.dart';
import 'player.provider.dart';
import 'track.controller.dart';

part 'player.controller.g.dart';

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
    final List<TrackEntity> tracks;
    try {
      // Awaiting the future means the first play works even if nothing has
      // loaded the track list yet.
      tracks = await ref.read(trackListControllerProvider.future);
    } on Object catch (error, stackTrace) {
      state = state.copyWith(
        error: ErrorMapper.fromException(error, stackTrace),
        isPlaying: false,
      );
      return;
    }

    if (tracks.isEmpty) return;

    await playTrack(_pickNext(tracks));
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

  Future<void> playTrack(TrackEntity track) async {
    state = state.copyWith(
      currentTrack: track,
      position: Duration.zero,
      duration: track.durationSeconds == null
          ? null
          : Duration(seconds: track.durationSeconds!),
      error: null,
    );
    unawaited(ref.read(analyticsServiceProvider).trackPlayed(track.id));
    await ref.read(audioPlayerServiceProvider).playTrack(track);
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
  TrackEntity _pickNext(List<TrackEntity> tracks) {
    final String? currentId = state.currentTrack?.id;
    final List<TrackEntity> candidates = tracks
        .where((TrackEntity track) => track.id != currentId)
        .toList();
    final List<TrackEntity> pool = candidates.isEmpty ? tracks : candidates;

    return pool[_random.nextInt(pool.length)];
  }

  final Random _random = Random();
}
