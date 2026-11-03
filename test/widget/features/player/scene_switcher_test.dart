import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:purelofi/common/cache/media_cache.service.dart';
import 'package:purelofi/common/errors/app_error.dart';
import 'package:purelofi/common/widgets/error_state.widget.dart';
import 'package:purelofi/common/widgets/skeleton.widget.dart';
import 'package:purelofi/features/player/controller/player.provider.dart';
import 'package:purelofi/features/player/domain/scene.entity.dart';
import 'package:purelofi/features/player/domain/track.entity.dart';
import 'package:purelofi/features/player/presentation/screens/player.screen.dart';
import 'package:purelofi/features/player/presentation/widgets/scene_switcher_sheet.widget.dart';

import '../../../helpers/fake_audio_player.service.dart';
import '../../../helpers/mock_repositories.dart';
import '../../../helpers/pump_routed_app.dart';

void main() {
  late MockContentRepository mockRepo;
  late FakeAudioPlayerService fakeAudio;

  final List<SceneEntity> scenes = <SceneEntity>[
    makeScene('scene-a', title: 'Rainy Room').copyWith(sortOrder: 1),
    makeScene('scene-b', title: 'Night Bus').copyWith(sortOrder: 2),
  ];

  setUp(() {
    mockRepo = MockContentRepository();
    fakeAudio = FakeAudioPlayerService();
    addTearDown(fakeAudio.dispose);
    when(() => mockRepo.getScenes()).thenAnswer((_) async => scenes);
    when(
      () => mockRepo.getTracks(),
    ).thenAnswer((_) async => <TrackEntity>[makeTrack('a')]);
  });

  List<Override> overrides() => <Override>[
    contentRepositoryProvider.overrideWithValue(mockRepo),
    audioPlayerServiceProvider.overrideWithValue(fakeAudio),
    sceneVideoBuilderProvider.overrideWithValue(
      (SceneEntity scene) => Text('scene ${scene.id}'),
    ),
  ];

  Future<void> openSwitcher(WidgetTester tester) async {
    await tester.pumpProviderApp(
      child: const PlayerScreen(),
      overrides: overrides(),
    );
    await tester.pumpAndSettle();
    await openMenu(tester);
    await tapMenuEntry(tester, 'Change scene');
  }

  testWidgets('shows rows in the shape of the list while it loads', (
    tester,
  ) async {
    final Completer<List<SceneEntity>> pending = Completer<List<SceneEntity>>();
    when(() => mockRepo.getScenes()).thenAnswer((_) => pending.future);

    await tester.pumpProviderApp(
      child: const Scaffold(body: SceneSwitcherSheet()),
      overrides: overrides(),
    );
    await tester.pump();

    // A thumbnail and a title bar for each of the four rows.
    expect(find.byType(Skeleton), findsNWidgets(8));
    expect(find.bySemanticsLabel('Loading scenes'), findsOneWidget);

    pending.complete(scenes);
    await tester.pumpAndSettle();

    expect(find.byType(Skeleton), findsNothing);
    expect(find.text('Rainy Room'), findsOneWidget);
  });

  testWidgets('a cover still on its way holds its place with a skeleton', (
    tester,
  ) async {
    final _GatedCache cache = _GatedCache();
    when(() => mockRepo.getScenes()).thenAnswer(
      (_) async => <SceneEntity>[
        makeScene('scene-a', thumbnailUrl: 'https://example.com/a.png'),
      ],
    );

    await tester.pumpProviderApp(
      child: const Scaffold(body: SceneSwitcherSheet()),
      overrides: <Override>[
        ...overrides(),
        mediaCacheProvider.overrideWithValue(cache),
      ],
    );
    await tester.pump();

    // The title is there; its picture is a skeleton, not a gap.
    expect(find.text('Rainy Room'), findsOneWidget);
    expect(find.byType(Skeleton), findsOneWidget);

    final File cover = File('${Directory.systemTemp.path}/cover.png');
    cache.release(cover);
    await tester.pump();

    // From the disk, never the network.
    final Image image = tester.widget<Image>(find.byType(Image));
    expect((image.image as ResizeImage).imageProvider, FileImage(cover));
  });

  testWidgets('lists the active scenes in sort_order', (tester) async {
    await openSwitcher(tester);

    expect(find.byType(SceneSwitcherSheet), findsOneWidget);
    final Offset rainy = tester.getTopLeft(find.text('Rainy Room'));
    final Offset night = tester.getTopLeft(find.text('Night Bus'));
    expect(rainy.dy, lessThan(night.dy));
  });

  testWidgets('picking a scene switches the background and closes the sheet', (
    tester,
  ) async {
    await openSwitcher(tester);
    expect(find.text('scene scene-a'), findsOneWidget);

    await tester.tap(find.text('Night Bus'));
    await tester.pumpAndSettle();

    expect(find.byType(SceneSwitcherSheet), findsNothing);
    expect(find.text('scene scene-b'), findsOneWidget);
  });

  testWidgets('switching scenes leaves the audio alone', (tester) async {
    await openSwitcher(tester);
    final int playedBefore = fakeAudio.playedTracks.length;

    await tester.tap(find.text('Night Bus'));
    await tester.pumpAndSettle();

    expect(fakeAudio.playedTracks, hasLength(playedBefore));
    expect(fakeAudio.pauseCalls, 0);
    expect(fakeAudio.stopCalls, 0);
  });

  testWidgets('shows an error state when the scenes cannot be loaded', (
    tester,
  ) async {
    when(() => mockRepo.getScenes()).thenThrow(const AppError.network());

    await tester.pumpProviderApp(
      child: const SceneSwitcherSheet(),
      overrides: overrides(),
    );
    await tester.pumpAndSettle();

    expect(find.byType(ErrorState), findsOneWidget);
  });

  testWidgets('marks the scene that is already playing', (tester) async {
    await openSwitcher(tester);

    final ListTile active = tester.widget<ListTile>(
      find.ancestor(
        of: find.text('Rainy Room'),
        matching: find.byType(ListTile),
      ),
    );
    expect(active.selected, isTrue);
  });
}

/// A cache whose downloads wait for [release].
class _GatedCache implements MediaCache {
  final Completer<File?> _gate = Completer<File?>();

  void release(File? file) => _gate.complete(file);

  @override
  Future<File?> fileFor(String url) => _gate.future;

  @override
  Future<File?> store(String url) => _gate.future;

  @override
  Future<int> sizeInBytes() async => 0;

  @override
  Future<void> evict() async {}
}
