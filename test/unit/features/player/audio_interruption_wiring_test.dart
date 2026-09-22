import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:just_audio/just_audio.dart';
import 'package:mocktail/mocktail.dart';
import 'package:purelofi/features/player/data/audio_player.service.impl.dart';
import 'package:purelofi/features/player/domain/audio_interruption.dart';
import 'package:purelofi/features/player/domain/audio_interruption.source.dart';

class _MockPlayer extends Mock implements AudioPlayer {}

/// Interruptions we can hand out on demand, instead of making a phone call.
class _FakeSource implements AudioInterruptionSource {
  final StreamController<void> noisy = StreamController<void>.broadcast();
  final StreamController<InterruptionEvent> events =
      StreamController<InterruptionEvent>.broadcast();

  @override
  Stream<void> get becomingNoisy => noisy.stream;

  @override
  Stream<InterruptionEvent> get interruptions => events.stream;

  Future<void> dispose() async {
    await noisy.close();
    await events.close();
  }
}

void main() {
  late _MockPlayer player;
  late _FakeSource source;
  late AudioPlayerServiceImpl service;
  bool playing = true;

  setUp(() {
    player = _MockPlayer();
    source = _FakeSource();
    playing = true;

    when(
      () => player.playbackEventStream,
    ).thenAnswer((_) => const Stream<PlaybackEvent>.empty());
    when(
      () => player.processingStateStream,
    ).thenAnswer((_) => const Stream<ProcessingState>.empty());
    when(() => player.playing).thenAnswer((_) => playing);
    when(player.pause).thenAnswer((_) async => playing = false);
    when(player.play).thenAnswer((_) async => playing = true);
    when(() => player.setVolume(any())).thenAnswer((_) async {});

    service = AudioPlayerServiceImpl(player: player, interruptions: source);
    addTearDown(source.dispose);
  });

  /// Lets the stream listeners run.
  Future<void> settle() => Future<void>.delayed(Duration.zero);

  test('pulling the headphones out stops the music', () async {
    source.noisy.add(null);
    await settle();

    verify(player.pause).called(1);
  });

  test('it does not come back on by itself afterwards', () async {
    source.noisy.add(null);
    await settle();

    // Whatever the platform says next, an unplug is not something to undo.
    source.events.add((kind: InterruptionKind.pause, beginning: false));
    await settle();

    verifyNever(player.play);
  });

  test('a call pauses, and the music returns when it ends', () async {
    source.events.add((kind: InterruptionKind.pause, beginning: true));
    await settle();
    verify(player.pause).called(1);

    source.events.add((kind: InterruptionKind.pause, beginning: false));
    await settle();

    verify(player.play).called(1);
  });

  test('a pause the listener asked for survives a call', () async {
    // The regression this is here for: press pause, take a call, and the
    // music must not be playing in your pocket when it ends.
    await service.pause();
    playing = false;

    source.events.add((kind: InterruptionKind.pause, beginning: true));
    await settle();
    source.events.add((kind: InterruptionKind.pause, beginning: false));
    await settle();

    verifyNever(player.play);
  });

  test('a prompt ducks and hands the volume back', () async {
    source.events.add((kind: InterruptionKind.duck, beginning: true));
    await settle();
    verify(() => player.setVolume(duckedVolume)).called(1);

    source.events.add((kind: InterruptionKind.duck, beginning: false));
    await settle();

    verify(() => player.setVolume(1)).called(1);
  });
}
