import 'package:flutter/material.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:purelofi/features/player/controller/player.provider.dart';
import 'package:purelofi/features/player/domain/ambient_sound.entity.dart';
import 'package:purelofi/features/player/domain/scene.entity.dart';
import 'package:purelofi/features/player/domain/track.entity.dart';
import 'package:purelofi/features/player/domain/volume_layer.dart';
import 'package:purelofi/features/player/presentation/widgets/sound_mix.widget.dart';
import 'package:purelofi/features/pro/presentation/widgets/pro_pill.widget.dart';

import '../../../helpers/fake_audio_player.service.dart';
import '../../../helpers/fake_pro.repository.dart';
import '../../../helpers/mock_repositories.dart';
import '../../../helpers/pump_routed_app.dart';

/// The room page's "Sound" card (#136, #154).
void main() {
  late MockContentRepository mockRepo;
  late FakeAudioPlayerService fakeAudio;

  setUp(() {
    mockRepo = MockContentRepository();
    fakeAudio = FakeAudioPlayerService();
    addTearDown(fakeAudio.dispose);
    when(
      () => mockRepo.getTracks(),
    ).thenAnswer((_) async => <TrackEntity>[makeTrack('a')]);
    when(() => mockRepo.getScenes()).thenAnswer(
      (_) async => <SceneEntity>[
        makeScene('rainy').copyWith(
          ambients: const <AmbientSoundEntity>[
            AmbientSoundEntity(
              id: 'rain',
              slug: 'rain',
              title: 'Rain',
              audioUrl: 'https://example.com/rain.m4a',
            ),
          ],
        ),
      ],
    );
  });

  List<Override> overrides() => <Override>[
    contentRepositoryProvider.overrideWithValue(mockRepo),
    audioPlayerServiceProvider.overrideWithValue(fakeAudio),
    sceneVideoBuilderProvider.overrideWithValue(
      (SceneEntity scene) => const SizedBox.shrink(),
    ),
  ];

  Future<void> open(WidgetTester tester, {FakeProRepository? pro}) async {
    tester.view.physicalSize = const Size(1179, 2556);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpRoutedApp(overrides: overrides(), pro: pro);
    await tester.pumpAndSettle();
    await openMenu(tester);
    await tester.ensureVisible(find.byType(SoundMix));
    await tester.pumpAndSettle();
  }

  testWidgets('the music, the room\'s sounds and each sound get a slider', (
    tester,
  ) async {
    await open(tester);

    expect(
      find.descendant(of: find.byType(SoundMix), matching: find.byType(Slider)),
      findsNWidgets(3),
    );
    expect(find.text('Room sounds'), findsOneWidget);

    // Dragging the music slider to its start turns the music right down.
    final Finder music = find
        .descendant(of: find.byType(SoundMix), matching: find.byType(Slider))
        .first;
    await tester.drag(music, const Offset(-1000, 0));
    await tester.pumpAndSettle();
    expect(fakeAudio.layer(VolumeLayer.music), 0);
  });

  testWidgets('without Pro the fine mix is offered, not open', (tester) async {
    await open(tester, pro: FakeProRepository());

    final Slider rain = tester.widget<Slider>(
      find
          .descendant(of: find.byType(SoundMix), matching: find.byType(Slider))
          .last,
    );
    expect(rain.onChanged, isNull);
    expect(
      find.descendant(
        of: find.byType(SoundMix),
        matching: find.byType(ProPill),
      ),
      findsOneWidget,
    );
  });
}
