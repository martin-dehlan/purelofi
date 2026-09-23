import 'package:flutter/material.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:purelofi/common/utils/app_assets.dart';
import 'package:purelofi/common/widgets/pixel_icon.widget.dart';
import 'package:purelofi/features/player/controller/player.provider.dart';
import 'package:purelofi/features/player/domain/scene.entity.dart';
import 'package:purelofi/features/player/domain/track.entity.dart';
import 'package:purelofi/features/player/presentation/widgets/favorite_button.widget.dart';
import 'package:purelofi/features/player/presentation/widgets/favorites_sheet.widget.dart';

import '../../../helpers/fake_audio_player.service.dart';
import '../../../helpers/fake_favorites.repository.dart';
import '../../../helpers/mock_repositories.dart';
import '../../../helpers/pump_routed_app.dart';

void main() {
  late MockContentRepository mockRepo;
  late FakeAudioPlayerService fakeAudio;
  late FakeFavoritesRepository favorites;

  setUp(() {
    mockRepo = MockContentRepository();
    fakeAudio = FakeAudioPlayerService();
    addTearDown(fakeAudio.dispose);
    favorites = FakeFavoritesRepository();
    when(() => mockRepo.getTracks()).thenAnswer(
      (_) async => <TrackEntity>[makeTrack('a', title: 'Dusk Tape')],
    );
  });

  List<Override> overrides() => <Override>[
    contentRepositoryProvider.overrideWithValue(mockRepo),
    audioPlayerServiceProvider.overrideWithValue(fakeAudio),
    sceneVideoBuilderProvider.overrideWithValue(
      (SceneEntity scene) => const SizedBox.shrink(),
    ),
  ];

  /// Which of the two hearts is on screen.
  String heartAsset(WidgetTester tester) => tester
      .widget<PixelIcon>(
        find.descendant(
          of: find.byType(FavoriteButton),
          matching: find.byType(PixelIcon),
        ),
      )
      .asset;

  testWidgets('the heart fills when the track is marked', (tester) async {
    await tester.pumpRoutedApp(overrides: overrides(), favorites: favorites);
    await tester.pumpAndSettle();
    await tester.pump();

    expect(heartAsset(tester), AppAssets.favoriteIcon);

    await tester.tap(find.byType(FavoriteButton));
    await tester.pumpAndSettle();
    await tester.pump();

    expect(favorites.toggled, <String>['a']);
    expect(heartAsset(tester), AppAssets.favoriteOnIcon);
  });

  testWidgets('a track already marked opens filled', (tester) async {
    favorites = FakeFavoritesRepository(<String>{'a'});

    await tester.pumpRoutedApp(overrides: overrides(), favorites: favorites);
    await tester.pumpAndSettle();
    await tester.pump();

    expect(heartAsset(tester), AppAssets.favoriteOnIcon);
  });

  testWidgets('the transport still has exactly three buttons', (tester) async {
    // docs/09: the chrome stays out of the way. The heart went beside the
    // title precisely so this number would not grow.
    await tester.pumpRoutedApp(overrides: overrides(), favorites: favorites);
    await tester.pumpAndSettle();
    await tester.pump();

    expect(
      find.bySemanticsLabel(RegExp('Start over|Play|Pause|Next track')),
      findsNWidgets(3),
    );
  });

  group('the menu', () {
    testWidgets('lists the marked tracks and counts them', (tester) async {
      favorites = FakeFavoritesRepository(<String>{'a'});

      await tester.pumpRoutedApp(overrides: overrides(), favorites: favorites);
      await tester.pumpAndSettle();
      await tester.pump();

      await openMenu(tester);

      expect(find.text('Favorites (1)'), findsOneWidget);
    });

    testWidgets('says so when nothing is marked', (tester) async {
      await tester.pumpRoutedApp(overrides: overrides(), favorites: favorites);
      await tester.pumpAndSettle();
      await tester.pump();

      await openMenu(tester);
      expect(find.text('Favorites'), findsOneWidget);

      await tapMenuEntry(tester, 'Favorites');

      expect(find.byType(FavoritesSheet), findsOneWidget);
      expect(find.textContaining('Nothing marked yet'), findsOneWidget);
    });

    testWidgets('playing one from the list starts it', (tester) async {
      favorites = FakeFavoritesRepository(<String>{'a'});

      await tester.pumpRoutedApp(overrides: overrides(), favorites: favorites);
      await tester.pumpAndSettle();
      await tester.pump();
      final int before = fakeAudio.playedTracks.length;

      await openMenu(tester);
      await tapMenuEntry(tester, 'Favorites (1)');
      await tester.tap(find.text('Dusk Tape').last);
      await tester.pumpAndSettle();

      expect(fakeAudio.playedTracks.length, greaterThan(before));
      expect(fakeAudio.playedTracks.last.id, 'a');
      expect(
        find.byType(FavoritesSheet),
        findsNothing,
        reason: 'picking a track closes the list',
      );
    });
  });
}
