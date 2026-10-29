import 'dart:async';
import 'dart:io';

import 'package:audio_service/audio_service.dart';
import 'package:just_audio/just_audio.dart';

import '../../../common/cache/media_cache.service.dart';
import '../../../common/errors/app_error.dart';
import '../domain/audio_interruption.dart';
import '../domain/audio_interruption.source.dart';
import '../domain/audio_player.service.dart';
import '../domain/playback_mode.dart';
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
    bool? roomInTitle,
  }) : _player = player ?? AudioPlayer(),
       _cache = cache,
       _roomInTitle = roomInTitle ?? Platform.isAndroid {
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

  /// The scene's name, shown as the album.
  String? _room;

  /// The playing track's own title, before any room is added to it.
  String? _trackTitle;

  /// Whether the room also goes into the title, which it does on Android.
  ///
  /// MIUI keeps the cover it first drew for a title and never draws another
  /// for it — not on a new picture, a new album, a new media id or even a
  /// freshly posted notification (#77). The app always opens in the same
  /// room, so every track got that room's cover for good. As "Travel Lofi ·
  /// Rainy Room" the track in each room is a title of its own, and each one
  /// keeps the right picture, switching back included.
  final bool _roomInTitle;

  String _titleFor(String title) {
    final String? room = _room;

    return _roomInTitle && room != null ? '$title · $room' : title;
  }

  PlaybackMode _mode = PlaybackMode.shuffle;
  final StreamController<void> _nextRequests =
      StreamController<void>.broadcast();
  final StreamController<PlaybackMode> _modeRequests =
      StreamController<PlaybackMode>.broadcast();
  final StreamController<AppError> _errors =
      StreamController<AppError>.broadcast();
  final List<StreamSubscription<Object?>> _subscriptions =
      <StreamSubscription<Object?>>[];

  @override
  Stream<bool> get playingStream => _player.playingStream;

  @override
  Stream<void> get nextRequests => _nextRequests.stream;

  @override
  Stream<PlaybackMode> get modeRequests => _modeRequests.stream;

  @override
  Stream<AppError> get errors => _errors.stream;

  @override
  Stream<Duration> get positionStream => _player.positionStream;

  @override
  Stream<Duration?> get durationStream => _player.durationStream;

  @override
  Future<void> seek(Duration position) => _player.seek(position);

  @override
  Future<void> setArtwork(Uri? artUri, {String? room}) async {
    _artUri = artUri;
    _room = room;

    // A track is already playing: give it the new picture now rather than
    // waiting for the next one, or switching scenes leaves a lock screen
    // showing the room the listener just left.
    final MediaItem? current = mediaItem.valueOrNull;
    final String? title = _trackTitle;
    if (current != null && title != null) {
      mediaItem.add(
        current.copyWith(title: _titleFor(title), artUri: artUri, album: room),
      );
    }
  }

  @override
  Future<void> playTrack(TrackEntity track) async {
    _trackTitle = track.title;
    mediaItem.add(
      MediaItem(
        id: track.id,
        title: _titleFor(track.title),
        // A listener's own file is not ours to sign: their tags or nothing.
        artist: track.source == TrackSource.local ? track.artist : 'PureLofi',
        album: _room,
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
    // The listener's own music is already on disk, and it is the only copy:
    // it must never pass through the cache, which evicts (#66).
    final Uri uri = Uri.parse(url);
    if (uri.scheme == 'file') return AudioSource.file(uri.toFilePath());

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

  /// Repeat one is `just_audio`'s own loop: gapless, and a looping track
  /// never completes, so nothing asks for the next one. Skip still does.
  @override
  Future<void> setPlaybackMode(PlaybackMode mode) async {
    _mode = mode;
    await _guard(
      () => _player.setLoopMode(mode.loops ? LoopMode.one : LoopMode.off),
    );
    _broadcastState(_player.playbackEvent);
  }

  /// From a watch, a car or the iOS command centre, which think of shuffle
  /// and repeat as two switches. Turning one on is that mode; turning off
  /// the one that is on leaves the stream in order.
  @override
  Future<void> setShuffleMode(AudioServiceShuffleMode shuffleMode) async {
    if (shuffleMode != AudioServiceShuffleMode.none) {
      return _requestMode(PlaybackMode.shuffle);
    }
    if (_mode.shuffles) _requestMode(PlaybackMode.inOrder);
  }

  @override
  Future<void> setRepeatMode(AudioServiceRepeatMode repeatMode) async {
    if (repeatMode != AudioServiceRepeatMode.none) {
      return _requestMode(PlaybackMode.repeatOne);
    }
    if (_mode.loops) _requestMode(PlaybackMode.inOrder);
  }

  /// The notification's own mode button, which steps on like the app's.
  @override
  Future<dynamic> customAction(
    String name, [
    Map<String, dynamic>? extras,
  ]) async {
    if (name == _modeAction) _requestMode(_mode.following);
  }

  void _requestMode(PlaybackMode mode) {
    if (!_modeRequests.isClosed) _modeRequests.add(mode);
  }

  static const String _modeAction = 'mode';

  /// Android draws a custom control from a drawable and nothing else, so the
  /// icon is the state, as on the app's button.
  MediaControl get _modeControl => MediaControl.custom(
    androidIcon: switch (_mode) {
      PlaybackMode.shuffle => 'drawable/ic_media_shuffle',
      PlaybackMode.repeatOne => 'drawable/ic_media_repeat_one',
      PlaybackMode.inOrder => 'drawable/ic_media_in_order',
    },
    label: switch (_mode) {
      PlaybackMode.shuffle => 'Play order: Shuffle',
      PlaybackMode.repeatOne => 'Play order: Repeat track',
      PlaybackMode.inOrder => 'Play order: In order',
    },
    name: _modeAction,
  );

  Future<void> dispose() async {
    for (final StreamSubscription<Object?> subscription in _subscriptions) {
      await subscription.cancel();
    }
    await _player.dispose();
    await _nextRequests.close();
    await _modeRequests.close();
    await _errors.close();
  }

  /// Mirrors `just_audio`'s state onto the notification and lock screen.
  void _broadcastState(PlaybackEvent event) {
    final bool playing = _player.playing;

    playbackState.add(
      playbackState.value.copyWith(
        // In the app's order: play order, play, next. The compact
        // notification keeps to play and next.
        controls: <MediaControl>[
          _modeControl,
          if (playing) MediaControl.pause else MediaControl.play,
          MediaControl.skipToNext,
        ],
        systemActions: const <MediaAction>{
          MediaAction.seek,
          MediaAction.setShuffleMode,
          MediaAction.setRepeatMode,
        },
        androidCompactActionIndices: const <int>[1, 2],
        shuffleMode: _mode.shuffles
            ? AudioServiceShuffleMode.all
            : AudioServiceShuffleMode.none,
        repeatMode: _mode.loops
            ? AudioServiceRepeatMode.one
            : AudioServiceRepeatMode.none,
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
