import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:purelofi/common/widgets/app_icon.widget.dart';
import 'package:purelofi/features/player/controller/player.provider.dart';
import 'package:purelofi/features/player/domain/artist.entity.dart';
import 'package:purelofi/features/player/domain/scene.entity.dart';
import 'package:purelofi/features/player/domain/track.entity.dart';
import 'package:purelofi/features/player/presentation/widgets/library_sheet.widget.dart';
import 'package:purelofi/features/pro/domain/pro_status.entity.dart';
import 'package:purelofi/features/pro/presentation/widgets/paywall_sheet.widget.dart';

import '../../../helpers/fake_audio_player.service.dart';
import '../../../helpers/fake_media_cache.dart';
import '../../../helpers/fake_pro.repository.dart';
import '../../../helpers/mock_repositories.dart';
import '../../../helpers/pump_routed_app.dart';

void main() {
  late MockContentRepository mockRepo;
  late FakeAudioPlayerService fakeAudio;
  late FakeMediaCache cache;

  final List<TrackEntity> tracks = <TrackEntity>[
    makeTrack(
      'a',
      title: 'Feeling You',
    ).copyWith(artistId: 'masso', artist: 'massomusicofficial'),
    makeTrack(
      'b',
      title: 'Fleeting Lofi',
    ).copyWith(artistId: 'masso', artist: 'massomusicofficial'),
  ];

  setUp(() {
    mockRepo = MockContentRepository();
    fakeAudio = FakeAudioPlayerService();
    cache = FakeMediaCache(file: File('/tmp/purelofi-test.mp3'));
    addTearDown(fakeAudio.dispose);
    when(() => mockRepo.getTracks()).thenAnswer((_) async => tracks);
    when(() => mockRepo.getArtists()).thenAnswer(
      (_) async => <ArtistEntity>[
        const ArtistEntity(id: 'masso', name: 'massomusicofficial'),
      ],
    );
    when(
      () => mockRepo.getScenes(),
    ).thenAnswer((_) async => <SceneEntity>[makeScene('scene-a')]);
  });

  List<Override> overrides() => <Override>[
    contentRepositoryProvider.overrideWithValue(mockRepo),
    audioPlayerServiceProvider.overrideWithValue(fakeAudio),
    mediaCacheProvider.overrideWithValue(cache),
    sceneVideoBuilderProvider.overrideWithValue(
      (SceneEntity scene) => const SizedBox.shrink(),
    ),
  ];

  Future<void> start(WidgetTester tester, FakeProRepository pro) async {
    tester.view.physicalSize = const Size(1179, 2556);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpRoutedApp(overrides: overrides(), pro: pro);
    await tester.pumpAndSettle();
  }

  Future<void> openTrackMenu(WidgetTester tester, String title) async {
    await openLibrary(tester);
    await tapPill(tester, 'Tracks');
    await tester.tap(find.byTooltip('More: $title'));
    await tester.pumpAndSettle();
  }

  FakeProRepository withPro() =>
      FakeProRepository(initial: const ProStatus(isPro: true));

  testWidgets('with Pro, a track downloads and is marked', (tester) async {
    await start(tester, withPro());
    await openTrackMenu(tester, 'Feeling You');

    await tester.tap(find.text('Download'));
    await tester.pumpAndSettle();

    expect(cache.downloads, <String>{tracks.first.audioUrl});
    expect(
      find.descendant(
        of: find.byType(LibrarySheet),
        matching: find.byWidgetPredicate(
          (Widget w) => w is AppIcon && w.glyph == AppGlyph.download,
        ),
      ),
      findsOneWidget,
    );

    await tester.tap(find.byTooltip('More: Feeling You'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Remove download'));
    await tester.pumpAndSettle();

    expect(cache.downloads, isEmpty);
  });

  testWidgets('without Pro, download asks for it', (tester) async {
    await start(tester, FakeProRepository());
    await openTrackMenu(tester, 'Feeling You');

    expect(find.text('With Pro'), findsOneWidget);
    await tester.tap(find.text('Download'));
    await tester.pumpAndSettle();

    expect(find.byType(PaywallSheet), findsOneWidget);
    expect(cache.downloads, isEmpty);
  });

  testWidgets('where Pro is not for sale, downloads are open', (tester) async {
    await start(tester, FakeProRepository(available: false));
    await openTrackMenu(tester, 'Feeling You');

    await tester.tap(find.text('Download'));
    await tester.pumpAndSettle();

    expect(cache.downloads, hasLength(1));
  });

  testWidgets('an artist\'s tracks download in one tap', (tester) async {
    await start(tester, withPro());
    await openLibrary(tester);
    await tapPill(tester, 'Artists');
    await tester.tap(find.widgetWithText(ListTile, 'massomusicofficial'));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Download all'));
    await tester.pumpAndSettle();

    expect(cache.downloads, <String>{
      for (final TrackEntity t in tracks) t.audioUrl,
    });
    expect(find.byTooltip('Remove downloads'), findsOneWidget);
  });

  testWidgets('settings count the downloads and can take them all back', (
    tester,
  ) async {
    cache.downloads.addAll(<String>[
      tracks.first.audioUrl,
      tracks.last.audioUrl,
    ]);
    await start(tester, withPro());
    await openMenu(tester);
    await tapMenuEntry(tester, 'Settings');

    expect(find.text('2 tracks, 8 MB'), findsOneWidget);

    await tester.ensureVisible(find.text('Remove all'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Remove all'));
    await tester.pumpAndSettle();

    expect(cache.downloads, isEmpty);
    expect(find.text('Nothing downloaded yet'), findsOneWidget);
  });
}
