import 'package:flutter/material.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:purelofi/features/player/controller/player.provider.dart';
import 'package:purelofi/features/player/domain/artist.entity.dart';
import 'package:purelofi/features/player/domain/scene.entity.dart';
import 'package:purelofi/features/player/domain/track.entity.dart';
import 'package:purelofi/features/player/presentation/widgets/follow_button.widget.dart';

import '../../../helpers/fake_audio_player.service.dart';
import '../../../helpers/mock_repositories.dart';
import '../../../helpers/pump_routed_app.dart';

/// Following an artist from their page (#147).
void main() {
  testWidgets('follow, then following, then follow again', (tester) async {
    final MockContentRepository mockRepo = MockContentRepository();
    final FakeAudioPlayerService fakeAudio = FakeAudioPlayerService();
    addTearDown(fakeAudio.dispose);
    when(() => mockRepo.getTracks()).thenAnswer(
      (_) async => <TrackEntity>[
        makeTrack('a', title: 'Dusk Tape').copyWith(artistId: 'ada'),
      ],
    );
    when(() => mockRepo.getArtists()).thenAnswer(
      (_) async => const <ArtistEntity>[
        ArtistEntity(id: 'ada', name: 'Ada Tapes'),
      ],
    );
    when(
      () => mockRepo.getScenes(),
    ).thenAnswer((_) async => <SceneEntity>[makeScene('scene-a')]);
    tester.view.physicalSize = const Size(1179, 2556);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    await tester.pumpRoutedApp(
      overrides: <Override>[
        contentRepositoryProvider.overrideWithValue(mockRepo),
        audioPlayerServiceProvider.overrideWithValue(fakeAudio),
        sceneVideoBuilderProvider.overrideWithValue(
          (SceneEntity scene) => const SizedBox.shrink(),
        ),
      ],
    );
    await tester.pumpAndSettle();
    await openLibrary(tester);
    await tapPill(tester, 'Artists');
    await tester.tap(find.widgetWithText(ListTile, 'Ada Tapes'));
    await tester.pumpAndSettle();

    final Finder button = find.byType(FollowButton);
    expect(
      find.descendant(of: button, matching: find.text('Follow')),
      findsOneWidget,
    );

    await tester.tap(button);
    await tester.pumpAndSettle();
    expect(
      find.descendant(of: button, matching: find.text('Following')),
      findsOneWidget,
    );

    await tester.tap(button);
    await tester.pumpAndSettle();
    expect(
      find.descendant(of: button, matching: find.text('Follow')),
      findsOneWidget,
    );
  });
}
