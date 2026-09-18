import 'dart:async';

import 'package:audio_service/audio_service.dart';
import 'package:just_audio/just_audio.dart';

import '../../../common/errors/app_error.dart';
import '../domain/audio_player.service.dart';
import '../domain/track.entity.dart';

/// `just_audio` playback wrapped in an `audio_service` handler.
///
/// Extending [BaseAudioHandler] is what gives the app background playback and
/// lock-screen controls: the platform talks to this object, not to the UI.
class AudioPlayerServiceImpl extends BaseAudioHandler
    with SeekHandler
    implements AudioPlayerService {
  AudioPlayerServiceImpl({AudioPlayer? player})
    : _player = player ?? AudioPlayer() {
    _subscriptions.addAll(<StreamSubscription<Object?>>[
      _player.playbackEventStream.listen(
        _broadcastState,
        onError: (Object error, StackTrace stackTrace) => _reportFailure(error),
      ),
      _player.processingStateStream.listen((ProcessingState processingState) {
        if (processingState == ProcessingState.completed) {
          _nextRequests.add(null);
        }
      }),
    ]);
  }

  final AudioPlayer _player;
  final StreamController<void> _nextRequests =
      StreamController<void>.broadcast();
  final StreamController<AppError> _errors =
      StreamController<AppError>.broadcast();
  final List<StreamSubscription<Object?>> _subscriptions =
      <StreamSubscription<Object?>>[];

  @override
  Stream<bool> get playingStream => _player.playingStream;

  @override
  Stream<void> get nextRequests => _nextRequests.stream;

  @override
  Stream<AppError> get errors => _errors.stream;

  @override
  Future<void> playTrack(TrackEntity track) async {
    mediaItem.add(
      MediaItem(
        id: track.id,
        title: track.title,
        artist: 'PureLofi',
        duration: track.durationSeconds == null
            ? null
            : Duration(seconds: track.durationSeconds!),
      ),
    );

    await _guard(() async {
      await _player.setAudioSource(AudioSource.uri(Uri.parse(track.audioUrl)));
      await _player.play();
    });
  }

  @override
  Future<void> play() => _guard(_player.play);

  @override
  Future<void> pause() => _guard(_player.pause);

  @override
  Future<void> stop() async {
    await _guard(_player.stop);
    await super.stop();
  }

  /// The lock-screen skip button. The controller decides what plays next.
  @override
  Future<void> skipToNext() async => _nextRequests.add(null);

  Future<void> dispose() async {
    for (final StreamSubscription<Object?> subscription in _subscriptions) {
      await subscription.cancel();
    }
    await _player.dispose();
    await _nextRequests.close();
    await _errors.close();
  }

  /// Mirrors `just_audio`'s state onto the notification and lock screen.
  void _broadcastState(PlaybackEvent event) {
    final bool playing = _player.playing;

    playbackState.add(
      playbackState.value.copyWith(
        controls: <MediaControl>[
          if (playing) MediaControl.pause else MediaControl.play,
          MediaControl.skipToNext,
        ],
        systemActions: const <MediaAction>{MediaAction.seek},
        androidCompactActionIndices: const <int>[0, 1],
        processingState: switch (_player.processingState) {
          ProcessingState.idle => AudioProcessingState.idle,
          ProcessingState.loading => AudioProcessingState.loading,
          ProcessingState.buffering => AudioProcessingState.buffering,
          ProcessingState.ready => AudioProcessingState.ready,
          ProcessingState.completed => AudioProcessingState.completed,
        },
        playing: playing,
        updatePosition: _player.position,
        bufferedPosition: _player.bufferedPosition,
        speed: _player.speed,
      ),
    );
  }

  Future<void> _guard(Future<void> Function() action) async {
    try {
      await action();
    } on Object catch (error) {
      _reportFailure(error);
    }
  }

  void _reportFailure(Object error) {
    final AppError failure = AppError.playback(message: _describe(error));
    if (!_errors.isClosed) _errors.add(failure);
  }

  /// Keeps the user-facing message short — no stack traces, no plugin noise.
  static String _describe(Object error) => switch (error) {
    PlayerException(:final String? message) => message ?? 'the stream failed',
    PlayerInterruptedException() => 'playback was interrupted',
    _ => 'this track could not be played',
  };
}
