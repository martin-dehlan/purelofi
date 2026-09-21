import 'package:flutter/material.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:purelofi/features/player/controller/player.provider.dart';
import 'package:purelofi/features/player/domain/scene.entity.dart';
import 'package:purelofi/features/player/domain/scene_layer.entity.dart';
import 'package:purelofi/features/player/domain/track.entity.dart';
import 'package:purelofi/features/player/presentation/widgets/scene_background.widget.dart';
import 'package:purelofi/features/player/presentation/widgets/scene_layers.widget.dart';
import 'package:purelofi/features/player/presentation/widgets/scene_video.widget.dart';

import '../../../helpers/fake_audio_player.service.dart';
import '../../../helpers/fake_sprite_loader.dart';
import '../../../helpers/mock_repositories.dart';
import '../../../helpers/pump_routed_app.dart';

/// The renderer animates forever, so `pumpAndSettle` would never return.
/// A handful of frames is enough for the sprites to arrive and the first
/// paint to happen.
Future<void> settle(WidgetTester tester) async {
  for (int i = 0; i < 6; i++) {
    await tester.pump(const Duration(milliseconds: 16));
  }
}

void main() {
  late MockContentRepository mockRepo;
  late FakeAudioPlayerService fakeAudio;
  late FakeSpriteLoader fakeSprites;

  SceneEntity layeredScene() => makeScene('scene-a').copyWith(
    layers: <SceneLayerEntity>[
      makeLayer('back', zIndex: 0),
      makeLayer('rain', zIndex: 1, frameCount: 6, fps: 12, tiles: true),
      makeLayer('reels', zIndex: 2, frameCount: 8, fps: 10, onlyWhilePlaying: true),
    ],
  );

  setUp(() {
    mockRepo = MockContentRepository();
    fakeAudio = FakeAudioPlayerService();
    fakeSprites = FakeSpriteLoader();
    addTearDown(fakeAudio.dispose);
    when(
      () => mockRepo.getTracks(),
    ).thenAnswer((_) async => <TrackEntity>[makeTrack('a')]);
  });

  List<Override> overrides() => <Override>[
    contentRepositoryProvider.overrideWithValue(mockRepo),
    audioPlayerServiceProvider.overrideWithValue(fakeAudio),
    spriteLoaderProvider.overrideWithValue(fakeSprites),
  ];

  testWidgets('draws a layered scene instead of playing a video', (
    tester,
  ) async {
    when(
      () => mockRepo.getScenes(),
    ).thenAnswer((_) async => <SceneEntity>[layeredScene()]);

    await tester.pumpProviderApp(
      child: const SceneBackground(),
      overrides: overrides(),
    );
    await settle(tester);

    expect(find.byType(SceneLayersView), findsOneWidget);
    expect(find.byType(SceneVideoView), findsNothing);
  });

  testWidgets('loads every layer sprite exactly once', (tester) async {
    when(
      () => mockRepo.getScenes(),
    ).thenAnswer((_) async => <SceneEntity>[layeredScene()]);

    await tester.pumpProviderApp(
      child: const SceneBackground(),
      overrides: overrides(),
    );
    await settle(tester);

    expect(fakeSprites.requestedUrls, hasLength(3));
    expect(fakeSprites.requestedUrls.toSet(), hasLength(3));
  });

  testWidgets('a scene without layers still plays its video', (tester) async {
    when(
      () => mockRepo.getScenes(),
    ).thenAnswer((_) async => <SceneEntity>[makeScene('scene-a')]);

    await tester.pumpProviderApp(
      child: const SceneBackground(),
      overrides: <Override>[
        ...overrides(),
        sceneVideoBuilderProvider.overrideWithValue(
          (SceneEntity scene) => Text('video ${scene.id}'),
        ),
      ],
    );
    await settle(tester);

    expect(find.text('video scene-a'), findsOneWidget);
    expect(find.byType(SceneLayersView), findsNothing);
  });

  testWidgets('a sprite that fails to load costs its layer, not the scene', (
    tester,
  ) async {
    fakeSprites = FakeSpriteLoader(
      failingUrls: <String>{'https://example.com/rain.png'},
    );
    when(
      () => mockRepo.getScenes(),
    ).thenAnswer((_) async => <SceneEntity>[layeredScene()]);

    await tester.pumpProviderApp(
      child: const SceneBackground(),
      overrides: overrides(),
    );
    await settle(tester);

    expect(find.byType(SceneLayersView), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('keeps repainting while it is on screen', (tester) async {
    when(
      () => mockRepo.getScenes(),
    ).thenAnswer((_) async => <SceneEntity>[layeredScene()]);

    await tester.pumpProviderApp(
      child: const SceneBackground(),
      overrides: overrides(),
    );
    await settle(tester);

    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 100));

    expect(tester.takeException(), isNull);
    expect(find.byType(CustomPaint), findsWidgets);
  });

  testWidgets('disposes its ticker when the scene leaves the tree', (
    tester,
  ) async {
    when(
      () => mockRepo.getScenes(),
    ).thenAnswer((_) async => <SceneEntity>[layeredScene()]);

    await tester.pumpProviderApp(
      child: const SceneBackground(),
      overrides: overrides(),
    );
    await settle(tester);

    // A leaked ticker makes the test framework complain on teardown.
    await tester.pumpProviderApp(
      child: const SizedBox.shrink(),
      overrides: overrides(),
    );
    await settle(tester);

    expect(find.byType(SceneLayersView), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
