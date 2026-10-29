import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:purelofi/features/player/controller/player.provider.dart';
import 'package:purelofi/features/player/data/sprite_loader.service.dart';
import 'package:purelofi/features/player/domain/scene.entity.dart';
import 'package:purelofi/features/player/domain/track.entity.dart';
import 'package:purelofi/features/player/presentation/screens/player.screen.dart';
import 'package:purelofi/features/player/presentation/widgets/player_controls.widget.dart';
import 'package:purelofi/features/player/presentation/widgets/startup_screen.widget.dart';

import '../../../helpers/fake_audio_player.service.dart';
import '../../../helpers/fake_sprite_loader.dart';
import '../../../helpers/mock_repositories.dart';
import '../../../helpers/pump_routed_app.dart';

void main() {
  late MockContentRepository mockRepo;
  late FakeAudioPlayerService fakeAudio;

  setUp(() {
    mockRepo = MockContentRepository();
    fakeAudio = FakeAudioPlayerService();
    addTearDown(fakeAudio.dispose);
    when(
      () => mockRepo.getScenes(),
    ).thenAnswer((_) async => <SceneEntity>[makeScene('scene-1')]);
    when(
      () => mockRepo.getTracks(),
    ).thenAnswer((_) async => <TrackEntity>[makeTrack('a')]);
  });

  List<Override> overrides() => <Override>[
    contentRepositoryProvider.overrideWithValue(mockRepo),
    audioPlayerServiceProvider.overrideWithValue(fakeAudio),
    sceneVideoBuilderProvider.overrideWithValue(
      (SceneEntity scene) => const SizedBox.shrink(),
    ),
  ];

  double controlsOpacity(WidgetTester tester) {
    final AnimatedOpacity opacity = tester.widget<AnimatedOpacity>(
      find.ancestor(
        of: find.byType(PlayerControls),
        matching: find.byType(AnimatedOpacity),
      ),
    );
    return opacity.opacity;
  }

  testWidgets('starts the stream once the tracks load', (tester) async {
    await tester.pumpProviderApp(
      child: const PlayerScreen(),
      overrides: overrides(),
    );
    await tester.pump();
    await tester.pump();

    expect(fakeAudio.playedTracks.single.id, 'a');
  });

  testWidgets('shows the controls when it opens', (tester) async {
    await tester.pumpProviderApp(
      child: const PlayerScreen(),
      overrides: overrides(),
    );
    await tester.pump();

    expect(controlsOpacity(tester), 1);
  });

  testWidgets('hides the controls after 4s of stillness', (tester) async {
    await tester.pumpProviderApp(
      child: const PlayerScreen(),
      overrides: overrides(),
    );
    await tester.pump();

    await tester.pump(const Duration(seconds: 4));
    await tester.pump();

    expect(controlsOpacity(tester), 0);
  });

  testWidgets('a tap brings them back', (tester) async {
    await tester.pumpProviderApp(
      child: const PlayerScreen(),
      overrides: overrides(),
    );
    await tester.pump();
    await tester.pump(const Duration(seconds: 4));
    await tester.pump();
    expect(controlsOpacity(tester), 0);

    await tester.tapAt(tester.getCenter(find.byType(PlayerScreen)));
    await tester.pump();

    expect(controlsOpacity(tester), 1);
  });

  testWidgets('a tap on hidden controls does not toggle playback', (
    tester,
  ) async {
    await tester.pumpProviderApp(
      child: const PlayerScreen(),
      overrides: overrides(),
    );
    await tester.pump();
    await tester.pump();
    final int playedBefore = fakeAudio.playedTracks.length;

    await tester.pump(const Duration(seconds: 4));
    await tester.pump();
    await tester.tapAt(tester.getCenter(find.byType(PlayerScreen)));
    await tester.pump();

    expect(fakeAudio.pauseCalls, 0);
    expect(fakeAudio.playedTracks, hasLength(playedBefore));
  });

  group('the start', () {
    late _GatedSpriteLoader sprites;

    setUp(() {
      when(() => mockRepo.getScenes()).thenAnswer(
        (_) async => <SceneEntity>[
          makeScene(
            'room',
          ).copyWith(layers: [makeLayer('wall'), makeLayer('cat')]),
        ],
      );
    });

    /// Opens the app with every strip held back. The loader is made here,
    /// inside the test: a future made in `setUp` lives in another zone and
    /// would only complete once the test is over.
    Future<void> start(WidgetTester tester) async {
      sprites = _GatedSpriteLoader();
      await sprites.prepare(tester);
      await tester.pumpProviderApp(
        child: const PlayerScreen(),
        overrides: <Override>[
          ...overrides(),
          spriteLoaderProvider.overrideWithValue(sprites),
        ],
      );
    }

    testWidgets('keeps the transport away until the room is drawn', (
      tester,
    ) async {
      await start(tester);
      await tester.pump();
      await tester.pump();

      expect(find.byType(StartupScreen), findsOneWidget);
      expect(controlsOpacity(tester), 0);

      await sprites.release(tester);
      await frames(tester);

      expect(find.byType(StartupScreen), findsNothing);
      expect(controlsOpacity(tester), 1);
    });

    testWidgets('a tap during the start brings up nothing', (tester) async {
      await start(tester);
      await tester.pump();
      await tester.tapAt(tester.getCenter(find.byType(PlayerScreen)));
      await tester.pump();

      expect(controlsOpacity(tester), 0);
      await sprites.release(tester);
      await frames(tester);
    });

    testWidgets('the room arrives with a fresh countdown', (tester) async {
      await start(tester);
      await tester.pump();
      // Longer than the idle timeout: the countdown ran out while loading.
      await tester.pump(const Duration(seconds: 6));

      await sprites.release(tester);
      await frames(tester);

      expect(controlsOpacity(tester), 1);
    });
  });
}

/// The room animates forever, so `pumpAndSettle` would never return; a few
/// frames are enough for released strips to be drawn.
Future<void> frames(WidgetTester tester) async {
  for (int i = 0; i < 6; i++) {
    await tester.pump(const Duration(milliseconds: 16));
  }
}

/// Holds every strip back until [release], so a test can look at the start
/// screen while the room is still on its way.
class _GatedSpriteLoader implements SpriteLoader {
  final Completer<ui.Image> _gate = Completer<ui.Image>();

  /// The strip handed out on [release]. Rendering one needs the real event
  /// loop, which a widget test only lends out through `runAsync` — so it is
  /// made before the app is pumped, not while it waits.
  late ui.Image strip;

  Future<void> prepare(WidgetTester tester) async {
    strip = (await tester.runAsync(FakeSpriteLoader.createStrip))!;
  }

  Future<void> release(WidgetTester tester) async {
    if (!_gate.isCompleted) _gate.complete(strip);
  }

  @override
  Future<ui.Image> load(String url) => _gate.future;

  @override
  void dispose() {}
}
