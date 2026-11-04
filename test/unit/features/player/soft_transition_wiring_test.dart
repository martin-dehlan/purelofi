import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:just_audio/just_audio.dart';
import 'package:mocktail/mocktail.dart';
import 'package:purelofi/features/player/data/audio_player.service.impl.dart';
import 'package:purelofi/features/player/domain/playback_mode.dart';
import 'package:purelofi/features/player/domain/track.entity.dart';
import 'package:purelofi/features/player/domain/volume_layer.dart';

class _MockPlayer extends Mock implements AudioPlayer {}

class _FakeSource extends Fake implements AudioSource {}

/// The audio service's volume (#137, #138, #139): the playhead, the end of a
/// track and the app's own layers, all reaching the one player.
void main() {
  late _MockPlayer player;
  late _MockPlayer chime;
  late StreamController<Duration> position;
  late StreamController<ProcessingState> processing;
  late AudioPlayerServiceImpl service;
  late List<double> volumes;

  setUpAll(() {
    registerFallbackValue(_FakeSource());
    registerFallbackValue(Duration.zero);
    registerFallbackValue(LoopMode.off);
  });

  setUp(() {
    player = _MockPlayer();
    chime = _MockPlayer();
    position = StreamController<Duration>.broadcast();
    processing = StreamController<ProcessingState>.broadcast();
    volumes = <double>[];

    when(
      () => player.playbackEventStream,
    ).thenAnswer((_) => const Stream<PlaybackEvent>.empty());
    when(
      () => player.processingStateStream,
    ).thenAnswer((_) => processing.stream);
    when(
      () => player.createPositionStream(
        steps: any(named: 'steps'),
        minPeriod: any(named: 'minPeriod'),
        maxPeriod: any(named: 'maxPeriod'),
      ),
    ).thenAnswer((_) => position.stream);
    when(() => player.duration).thenReturn(const Duration(minutes: 3));
    when(() => player.setAudioSource(any())).thenAnswer((_) async => null);
    when(player.play).thenAnswer((_) async {});
    when(() => player.setLoopMode(any())).thenAnswer((_) async {});
    when(() => player.playbackEvent).thenReturn(PlaybackEvent());
    when(() => player.playing).thenReturn(true);
    when(() => player.processingState).thenReturn(ProcessingState.ready);
    when(() => player.position).thenReturn(Duration.zero);
    when(() => player.bufferedPosition).thenReturn(Duration.zero);
    when(() => player.speed).thenReturn(1);
    when(() => player.setVolume(any())).thenAnswer((Invocation i) async {
      volumes.add(i.positionalArguments.first as double);
    });

    when(() => chime.setAsset(any())).thenAnswer((_) async => null);
    when(() => chime.setVolume(any())).thenAnswer((_) async {});
    when(chime.play).thenAnswer((_) async {});

    service = AudioPlayerServiceImpl(
      player: player,
      roomInTitle: false,
      chimePlayer: () => chime,
    );
    addTearDown(() async {
      await position.close();
      await processing.close();
    });
  });

  Future<void> settle() => Future<void>.delayed(Duration.zero);

  TrackEntity track(String id) => TrackEntity(
    id: id,
    title: id,
    audioUrl: 'https://example.com/$id.mp3',
    createdAt: DateTime(2026),
  );

  Future<void> at(Duration where) async {
    position.add(where);
    await settle();
  }

  test('the end of a track goes down to silence', () async {
    await service.playTrack(track('a'));

    await at(const Duration(minutes: 1));
    expect(volumes.last, 1);

    await at(const Duration(minutes: 2, seconds: 58));
    expect(volumes.last, closeTo(0.5, 0.001));

    await at(const Duration(minutes: 3));
    expect(volumes.last, 0);
  });

  test('the track after one that ran out comes in softly', () async {
    await service.playTrack(track('a'));
    processing.add(ProcessingState.completed);
    await settle();

    await service.playTrack(track('b'));
    expect(volumes.last, 0);

    await at(const Duration(seconds: 1));
    expect(volumes.last, closeTo(0.5, 0.001));

    await at(const Duration(seconds: 2));
    expect(volumes.last, 1);
  });

  test('a skip starts the next track at full volume', () async {
    await service.playTrack(track('a'));
    await at(const Duration(minutes: 2, seconds: 58));

    // In the middle of the fade, the listener picks another track.
    await service.playTrack(track('b'));
    expect(volumes.last, 1);

    await at(Duration.zero);
    expect(volumes.last, 1);
  });

  test('repeat one never fades: the end of the loop is not an end', () async {
    await service.setPlaybackMode(PlaybackMode.repeatOne);
    await service.playTrack(track('a'));

    await at(const Duration(minutes: 3));
    expect(volumes.where((double v) => v < 1), isEmpty);
  });

  test('turned off, tracks neither fade out nor in', () async {
    await service.setSoftTransitions(false);
    await service.playTrack(track('a'));
    await at(const Duration(minutes: 3));
    processing.add(ProcessingState.completed);
    await settle();
    await service.playTrack(track('b'));
    await at(Duration.zero);

    expect(volumes.where((double v) => v < 1), isEmpty);
  });

  test('the layers multiply, so none undoes another', () async {
    await service.playTrack(track('a'));
    await service.setVolumeLayer(VolumeLayer.focusBreak, 0.4);
    expect(volumes.last, closeTo(0.4, 0.001));

    await service.setVolumeLayer(VolumeLayer.sleepTimer, 0.5);
    expect(volumes.last, closeTo(0.2, 0.001));

    await service.setVolumeLayer(VolumeLayer.sleepTimer, 1);
    expect(volumes.last, closeTo(0.4, 0.001));
  });

  test('the chime plays on its own player, never on the music\'s', () async {
    await service.playChime();

    verify(() => chime.setAsset(AudioPlayerServiceImpl.chimeAsset)).called(1);
    verify(chime.play).called(1);
    verifyNever(() => player.setAsset(any()));
  });
}
