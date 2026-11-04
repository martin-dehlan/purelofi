import 'dart:async';

import 'package:purelofi/common/errors/app_error.dart';
import 'package:purelofi/features/player/domain/ambient_loop.dart';
import 'package:purelofi/features/player/domain/audio_player.service.dart';
import 'package:purelofi/features/player/domain/media_library.dart';
import 'package:purelofi/features/player/domain/playback_mode.dart';
import 'package:purelofi/features/player/domain/track.entity.dart';
import 'package:purelofi/features/player/domain/volume_layer.dart';

/// A stand-in for the real player: `just_audio` and `audio_service` both talk
/// to platform channels, so unit tests drive this instead (see `docs/10`).
class FakeAudioPlayerService implements AudioPlayerService {
  final StreamController<bool> playingController =
      StreamController<bool>.broadcast();
  final StreamController<void> nextRequestController =
      StreamController<void>.broadcast();
  final StreamController<AppError> errorController =
      StreamController<AppError>.broadcast();
  final StreamController<Duration> positionController =
      StreamController<Duration>.broadcast();
  final StreamController<Duration?> durationController =
      StreamController<Duration?>.broadcast();
  final StreamController<PlaybackMode> modeRequestController =
      StreamController<PlaybackMode>.broadcast();

  /// Every mode the player was handed, latest last.
  final List<PlaybackMode> modes = <PlaybackMode>[];

  final List<TrackEntity> playedTracks = <TrackEntity>[];
  int playCalls = 0;
  int pauseCalls = 0;
  int stopCalls = 0;
  final List<Duration> seeks = <Duration>[];

  /// When set, [playTrack] reports this failure instead of playing.
  AppError? failureOnPlay;

  @override
  Stream<bool> get playingStream => playingController.stream;

  @override
  Stream<void> get nextRequests => nextRequestController.stream;

  @override
  Stream<PlaybackMode> get modeRequests => modeRequestController.stream;

  @override
  Future<void> setPlaybackMode(PlaybackMode mode) async => modes.add(mode);

  @override
  Stream<AppError> get errors => errorController.stream;

  @override
  Stream<Duration> get positionStream => positionController.stream;

  @override
  Stream<Duration?> get durationStream => durationController.stream;

  @override
  Future<void> seek(Duration position) async {
    seeks.add(position);
    positionController.add(position);
  }

  /// What the lock screen was last told to show.
  Uri? artUri;

  @override
  Future<void> setArtwork(Uri? uri, {String? room}) async {
    artUri = uri;
    this.room = room;
  }

  /// The scene name last handed over with the artwork.
  String? room;

  @override
  Future<void> playTrack(TrackEntity track) async {
    final AppError? failure = failureOnPlay;
    if (failure != null) {
      errorController.add(failure);
      return;
    }

    playedTracks.add(track);
    playingController.add(true);
  }

  @override
  Future<void> play() async {
    playCalls++;
    playingController.add(true);
  }

  @override
  Future<void> pause() async {
    pauseCalls++;
    playingController.add(false);
  }

  @override
  Future<void> stop() async {
    stopCalls++;
    playingController.add(false);
  }

  /// Every layer's current level; a layer never set is at 1.
  final Map<VolumeLayer, double> layers = <VolumeLayer, double>{};

  /// Every level each layer was set to, in order.
  final Map<VolumeLayer, List<double>> layerHistory =
      <VolumeLayer, List<double>>{};

  double layer(VolumeLayer layer) => layers[layer] ?? 1;

  @override
  Future<void> setVolumeLayer(VolumeLayer layer, double level) async {
    layers[layer] = level;
    (layerHistory[layer] ??= <double>[]).add(level);
  }

  bool? softTransitions;

  @override
  Future<void> setSoftTransitions(bool enabled) async =>
      softTransitions = enabled;

  int chimes = 0;

  /// What media browsers were handed.
  MediaLibrary? library;

  @override
  void setLibrary(MediaLibrary library) => this.library = library;

  /// The room's sounds last handed over.
  List<AmbientLoop> ambience = const <AmbientLoop>[];

  @override
  Future<void> setAmbience(List<AmbientLoop> loops) async => ambience = loops;

  @override
  Future<void> playChime() async => chimes++;

  /// Simulates the current track running out, or skip on the lock screen.
  void emitNextRequest() => nextRequestController.add(null);

  /// Simulates shuffle or repeat changed on the lock screen.
  void emitModeRequest(PlaybackMode mode) => modeRequestController.add(mode);

  Future<void> dispose() async {
    await playingController.close();
    await nextRequestController.close();
    await modeRequestController.close();
    await errorController.close();
  }
}
