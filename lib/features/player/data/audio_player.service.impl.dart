import 'dart:async';
import 'dart:io';

import 'package:audio_service/audio_service.dart';
import 'package:just_audio/just_audio.dart';

import '../../../common/cache/media_cache.service.dart';
import '../../../common/errors/app_error.dart';
import '../domain/audio_interruption.dart';
import '../domain/audio_interruption.source.dart';
import '../domain/audio_player.service.dart';
import '../domain/track.entity.dart';

/// `just_audio` playback wrapped in an `audio_service` handler.
///
/// Extending [BaseAudioHandler] is what gives the app background playback and
/// lock-screen controls: the platform talks to this object, not to the UI.
class AudioPlayerServiceImpl extends BaseAudioHandler
    with SeekHandler
    implements AudioPlayerService {
  AudioPlayerServiceImpl({
    AudioPlayer? player,
    MediaCache? cache,
    AudioInterruptionSource? interruptions,
  }) : _player = player ?? AudioPlayer(),
       _cache = cache {
    if (interruptions != null) _listenForInterruptions(interruptions);

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
  final MediaCache? _cache;

  /// Whether the pause on the books is ours or the listener's. Only ours is
  /// ever undone automatically.
  bool _pausedByInterruption = false;

  Uri? _artUri;
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
  Stream<Duration> get positionStream => _player.positionStream;

  @override
  Stream<Duration?> get durationStream => _player.durationStream;

  @override
  Future<void> seek(Duration position) => _player.seek(position);

  @override
  Future<void> setArtwork(Uri? artUri) async {
    _artUri = artUri;

    // A track is already playing: give it the new picture now rather than
    // waiting for the next one, or switching scenes leaves a lock screen
    // showing the room the listener just left.
    final MediaItem? current = mediaItem.valueOrNull;
    if (current != null) mediaItem.add(current.copyWith(artUri: artUri));
  }

  @override
  Future<void> playTrack(TrackEntity track) async {
    mediaItem.add(
      MediaItem(
        id: track.id,
        title: track.title,
        artist: 'PureLofi',
        artUri: _artUri,
        duration: track.durationSeconds == null
            ? null
            : Duration(seconds: track.durationSeconds!),
      ),
    );

    await _guard(() async {
      await _player.setAudioSource(await _sourceFor(track.audioUrl));
      await _player.play();
    });
  }

  /// The file on disk when there is one, the stream otherwise.
  ///
  /// A track is downloaded the first time it plays, in the background, so it
  /// is there the next time — which is the whole point of the cache. The
  /// download is deliberately not awaited: playback should start now, not
  /// when the last byte lands.
  Future<AudioSource> _sourceFor(String url) async {
    final MediaCache? cache = _cache;
    if (cache == null) return AudioSource.uri(Uri.parse(url));

    final File? cached = await cache.fileFor(url);
    if (cached != null) return AudioSource.file(cached.path);

    unawaited(cache.store(url));

    return AudioSource.uri(Uri.parse(url));
  }

  @override
  Future<void> play() {
    _pausedByInterruption = false;

    return _guard(_player.play);
  }

  @override
  Future<void> pause() {
    // A pause the listener asked for. Nothing may undo it but them.
    _pausedByInterruption = false;

    return _guard(_player.pause);
  }

  void _listenForInterruptions(AudioInterruptionSource source) {
    _subscriptions.addAll(<StreamSubscription<Object?>>[
      // Headphones out. Pause, and never resume on its own: the speaker is
      // not where this was meant to be heard.
      source.becomingNoisy.listen((_) {
        if (_player.playing) unawaited(pause());
      }),
      source.interruptions.listen((InterruptionEvent event) {
        final InterruptionAction action = actionForInterruption(
          kind: event.kind,
          beginning: event.beginning,
          isPlaying: _player.playing,
          pausedByInterruption: _pausedByInterruption,
        );

        switch (action) {
          case InterruptionAction.none:
            break;
          case InterruptionAction.duck:
            unawaited(_guard(() => _player.setVolume(duckedVolume)));
          case InterruptionAction.restoreVolume:
            unawaited(_guard(() => _player.setVolume(1)));
          case InterruptionAction.pause:
            _pausedByInterruption = true;
            unawaited(_guard(_player.pause));
          case InterruptionAction.resume:
            _pausedByInterruption = false;
            unawaited(_guard(_player.play));
        }
      }),
    ]);
  }

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
