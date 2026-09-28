import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:purelofi/common/widgets/app_icon.widget.dart';
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
  AppGlyph heart(WidgetTester tester) => tester
      .widget<AppIcon>(
        find.descendant(
          of: find.byType(FavoriteButton),
          matching: find.byType(AppIcon),
        ),
      )
      .glyph;

  /// The button on its own: since #67 it is not shown in the player.
  Future<void> pumpHeart(WidgetTester tester) async {
    await tester.pumpProviderApp(
      child: const Scaffold(body: FavoriteButton(trackId: 'a', size: 20)),
      overrides: overrides(),
      favorites: favorites,
    );
    await tester.pumpAndSettle();
  }

  /// The favourites sheet has no way in from the menu any more; opened the
  /// way the menu used to.
  Future<void> openFavorites(WidgetTester tester) async {
    unawaited(showFavoritesSheet(tester.element(find.byType(Scaffold).first)));
    await tester.pumpAndSettle();
  }

  testWidgets('the heart fills when the track is marked', (tester) async {
    await pumpHeart(tester);

    expect(heart(tester), AppGlyph.heartOutline);

    await tester.tap(find.byType(FavoriteButton));
    await tester.pumpAndSettle();

    expect(favorites.toggled, <String>['a']);
    expect(heart(tester), AppGlyph.heart);
  });

  testWidgets('a track already marked opens filled', (tester) async {
    favorites = FakeFavoritesRepository(<String>{'a'});

    await pumpHeart(tester);

    expect(heart(tester), AppGlyph.heart);
  });

  group('out of the interface (#67)', () {
    testWidgets('the player shows no heart', (tester) async {
      await tester.pumpRoutedApp(overrides: overrides(), favorites: favorites);
      await tester.pumpAndSettle();
      await tester.pump();

      expect(find.byType(FavoriteButton), findsNothing);
    });

    testWidgets('the menu has no favourites entry', (tester) async {
      favorites = FakeFavoritesRepository(<String>{'a'});

      await tester.pumpRoutedApp(overrides: overrides(), favorites: favorites);
      await tester.pumpAndSettle();
      await tester.pump();
      await openMenu(tester);

      expect(find.textContaining('Favorites'), findsNothing);
    });

    testWidgets('the transport still has exactly three buttons', (
      tester,
    ) async {
      // docs/09: the chrome stays out of the way.
      await tester.pumpRoutedApp(overrides: overrides(), favorites: favorites);
      await tester.pumpAndSettle();
      await tester.pump();

      expect(
        find.bySemanticsLabel(RegExp('Start over|Play|Pause|Next track')),
        findsNWidgets(3),
      );
    });
  });

  group('the favourites sheet, kept for later', () {
    testWidgets('says so when nothing is marked', (tester) async {
      await tester.pumpRoutedApp(overrides: overrides(), favorites: favorites);
      await tester.pumpAndSettle();
      await tester.pump();

      await openFavorites(tester);

      expect(find.byType(FavoritesSheet), findsOneWidget);
      expect(find.textContaining('Nothing marked yet'), findsOneWidget);
    });

    testWidgets('playing one from the list starts it', (tester) async {
      favorites = FakeFavoritesRepository(<String>{'a'});

      await tester.pumpRoutedApp(overrides: overrides(), favorites: favorites);
      await tester.pumpAndSettle();
      await tester.pump();
      final int before = fakeAudio.playedTracks.length;

      await openFavorites(tester);
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
