import 'package:flutter/material.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:purelofi/common/widgets/app_icon.widget.dart';
import 'package:purelofi/features/player/controller/player.provider.dart';
import 'package:purelofi/features/player/domain/scene.entity.dart';
import 'package:purelofi/features/player/domain/track.entity.dart';
import 'package:purelofi/features/player/presentation/widgets/favorite_button.widget.dart';

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

  /// The button on its own.
  Future<void> pumpHeart(WidgetTester tester) async {
    await tester.pumpProviderApp(
      child: const Scaffold(body: FavoriteButton(trackId: 'a', size: 20)),
      overrides: overrides(),
      favorites: favorites,
    );
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

  group('in the player', () {
    Future<void> start(WidgetTester tester) async {
      await tester.pumpRoutedApp(overrides: overrides(), favorites: favorites);
      await tester.pumpAndSettle();
      await tester.pump();
    }

    testWidgets('sits beside the title of PureLofi\'s track', (tester) async {
      await start(tester);

      expect(find.byType(FavoriteButton), findsOneWidget);
      expect(find.bySemanticsLabel('Add to favorites'), findsOneWidget);
    });

    testWidgets('a mark there puts the track under Favorites', (tester) async {
      await start(tester);

      await tester.tap(find.byType(FavoriteButton));
      await tester.pumpAndSettle();
      await openLibrary(tester);
      await tapPill(tester, 'Favorites');

      expect(find.widgetWithText(ListTile, 'Dusk Tape'), findsOneWidget);
    });

    testWidgets('the transport row is five buttons and no heart', (
      tester,
    ) async {
      // docs/09: the chrome stays out of the way.
      await start(tester);

      expect(
        find.bySemanticsLabel(
          RegExp(
            '^(Play order|Previous track|Play|Pause|Next track|Library)\$',
          ),
        ),
        findsNWidgets(5),
      );
    });
  });
}
