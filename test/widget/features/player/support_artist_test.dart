import 'package:flutter/material.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:purelofi/features/player/controller/player.provider.dart';
import 'package:purelofi/features/player/data/artist.model.dart';
import 'package:purelofi/features/player/domain/artist.entity.dart';
import 'package:purelofi/features/player/domain/artist_link.dart';
import 'package:purelofi/features/player/domain/scene.entity.dart';
import 'package:purelofi/features/player/domain/track.entity.dart';
import 'package:purelofi/features/player/presentation/widgets/support_artist_button.widget.dart';

import '../../../helpers/fake_audio_player.service.dart';
import '../../../helpers/mock_repositories.dart';
import '../../../helpers/pump_routed_app.dart';

/// Supporting an artist directly (#152).
void main() {
  test('the button says where it goes', () {
    expect(supportPlatform('https://adatapes.bandcamp.com'), 'Bandcamp');
    expect(supportPlatform('https://ko-fi.com/adatapes'), 'Ko-fi');
    expect(supportPlatform('https://www.patreon.com/adatapes'), 'Patreon');
    expect(supportPlatform('https://paypal.me/adatapes'), 'PayPal');
    expect(supportPlatform('https://adatapes.com/tip'), isNull);
  });

  test('a support link that is not a web link is dropped', () {
    const ArtistModel model = ArtistModel(
      id: 'ada',
      name: 'Ada',
      supportUrl: 'intent://pay#Intent;end',
    );

    expect(model.toEntity().supportUrl, isNull);
  });

  group('on the artist\'s page and the track\'s menu', () {
    late MockContentRepository mockRepo;
    late FakeAudioPlayerService fakeAudio;

    setUp(() {
      mockRepo = MockContentRepository();
      fakeAudio = FakeAudioPlayerService();
      addTearDown(fakeAudio.dispose);
      when(() => mockRepo.getTracks()).thenAnswer(
        (_) async => <TrackEntity>[
          makeTrack(
            'a',
            title: 'Dusk Tape',
          ).copyWith(artistId: 'ada', artist: 'Ada Tapes'),
        ],
      );
      when(() => mockRepo.getArtists()).thenAnswer(
        (_) async => const <ArtistEntity>[
          ArtistEntity(
            id: 'ada',
            name: 'Ada Tapes',
            supportUrl: 'https://adatapes.bandcamp.com',
          ),
        ],
      );
      when(
        () => mockRepo.getScenes(),
      ).thenAnswer((_) async => <SceneEntity>[makeScene('scene-a')]);
    });

    List<Override> overrides() => <Override>[
      contentRepositoryProvider.overrideWithValue(mockRepo),
      audioPlayerServiceProvider.overrideWithValue(fakeAudio),
      sceneVideoBuilderProvider.overrideWithValue(
        (SceneEntity scene) => const SizedBox.shrink(),
      ),
    ];

    Future<void> start(WidgetTester tester) async {
      tester.view.physicalSize = const Size(1179, 2556);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      await tester.pumpRoutedApp(overrides: overrides());
      await tester.pumpAndSettle();
      await openLibrary(tester);
    }

    testWidgets('the page offers it, and says where it goes', (tester) async {
      await start(tester);
      await tapPill(tester, 'Artists');
      await tester.tap(find.widgetWithText(ListTile, 'Ada Tapes'));
      await tester.pumpAndSettle();

      expect(find.byType(SupportArtistButton), findsOneWidget);
      expect(find.text('Support Ada Tapes'), findsOneWidget);
      expect(
        find.text('Opens Bandcamp. It goes straight to the artist.'),
        findsOneWidget,
      );
    });

    testWidgets('a track of theirs offers it in its menu', (tester) async {
      await start(tester);
      await tapPill(tester, 'Tracks');
      await tester.tap(find.byTooltip('More: Dusk Tape'));
      await tester.pumpAndSettle();

      expect(find.text('Support this artist'), findsOneWidget);
      expect(find.text('Opens Bandcamp'), findsOneWidget);
    });
  });
}
