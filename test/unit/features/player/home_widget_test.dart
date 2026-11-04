import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:purelofi/features/player/controller/home_widget.controller.dart';
import 'package:purelofi/features/player/controller/player.controller.dart';
import 'package:purelofi/features/player/controller/player.provider.dart';
import 'package:purelofi/features/player/controller/scene.controller.dart';
import 'package:purelofi/features/player/domain/home_widget.service.dart';
import 'package:purelofi/features/player/domain/scene.entity.dart';
import 'package:purelofi/features/player/domain/track.entity.dart';

import '../../../helpers/fake_audio_player.service.dart';
import '../../../helpers/fake_favorites.repository.dart';
import '../../../helpers/fake_home_widget.dart';
import '../../../helpers/mock_repositories.dart';

void main() {
  late MockContentRepository content;
  late FakeAudioPlayerService audio;
  late FakeFavoritesRepository favorites;
  late FakeHomeWidgetService widgets;

  Future<ProviderContainer> start() async {
    content = MockContentRepository();
    audio = FakeAudioPlayerService();
    favorites = FakeFavoritesRepository();
    widgets = FakeHomeWidgetService();
    when(() => content.getScenes()).thenAnswer(
      (_) async => <SceneEntity>[
        makeScene('rainy', title: 'Rainy Room'),
        makeScene('roof', title: 'Rooftop').copyWith(sortOrder: 1),
      ],
    );
    when(() => content.getTracks()).thenAnswer(
      (_) async => <TrackEntity>[makeTrack('a', title: 'Dusk Tape')],
    );
    final ProviderContainer container = ProviderContainer(
      overrides: [
        contentRepositoryProvider.overrideWithValue(content),
        audioPlayerServiceProvider.overrideWithValue(audio),
        favoritesRepositoryProvider.overrideWithValue(favorites),
        homeWidgetServiceProvider.overrideWithValue(widgets),
      ],
      retry: (_, _) => null,
    );
    addTearDown(() {
      container.dispose();
      audio.dispose();
      favorites.dispose();
    });
    container
      ..listen(playerControllerProvider, (_, _) {})
      ..listen(homeWidgetSyncProvider, (_, _) {})
      ..listen(activeSceneControllerProvider, (_, _) {});
    await container.read(sceneListControllerProvider.future);
    container.read(activeSceneControllerProvider);
    await pumpEventQueue();
    return container;
  }

  test('the widget shows the room the app opens in', () async {
    await start();

    expect(widgets.shown.last.room, 'Rainy Room');
    expect(widgets.shown.last.isPlaying, isFalse);
  });

  test('a track starting, and the room changing, reach the widget', () async {
    final ProviderContainer c = await start();

    await c.read(playerControllerProvider.notifier).playNext();
    await pumpEventQueue();
    final WidgetSnapshot playing = widgets.shown.last;
    expect(playing.track, 'Dusk Tape');
    expect(playing.isPlaying, isTrue);

    c
        .read(activeSceneControllerProvider.notifier)
        .switchTo(makeScene('roof', title: 'Rooftop').copyWith(sortOrder: 1));
    await pumpEventQueue();
    expect(widgets.shown.last.room, 'Rooftop');
  });

  test('the position ticking along is not the widget\'s business', () async {
    final ProviderContainer c = await start();
    await c.read(playerControllerProvider.notifier).playNext();
    await pumpEventQueue();
    final int before = widgets.shown.length;

    for (int s = 1; s < 5; s++) {
      audio.positionController.add(Duration(seconds: s));
    }
    await pumpEventQueue();

    expect(widgets.shown.length, before);
  });
}
