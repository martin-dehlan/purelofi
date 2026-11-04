import 'package:fake_async/fake_async.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:purelofi/features/player/controller/mix.controller.dart';
import 'package:purelofi/features/player/controller/player.provider.dart';
import 'package:purelofi/features/player/controller/scene.controller.dart';
import 'package:purelofi/features/player/data/ambient_sound.model.dart';
import 'package:purelofi/features/player/data/content_cache.mapper.dart';
import 'package:purelofi/features/player/domain/ambient_loop.dart';
import 'package:purelofi/features/player/domain/ambient_sound.entity.dart';
import 'package:purelofi/features/player/domain/mix_preferences.service.dart';
import 'package:purelofi/features/player/domain/scene.entity.dart';
import 'package:purelofi/features/player/domain/track.entity.dart';
import 'package:purelofi/features/player/domain/volume_layer.dart';
import 'package:purelofi/features/pro/controller/pro.provider.dart';

import '../../../helpers/fake_audio_player.service.dart';
import '../../../helpers/fake_favorites.repository.dart';
import '../../../helpers/fake_mix_preferences.dart';
import '../../../helpers/fake_pro.repository.dart';
import '../../../helpers/mock_repositories.dart';

void main() {
  const AmbientSoundEntity rain = AmbientSoundEntity(
    id: 'rain',
    slug: 'rain',
    title: 'Rain',
    audioUrl: 'https://example.com/rain.m4a',
    defaultLevel: 0.6,
  );
  const AmbientSoundEntity fire = AmbientSoundEntity(
    id: 'fire',
    slug: 'fire',
    title: 'Fire',
    audioUrl: 'https://example.com/fire.m4a',
    defaultLevel: 0.3,
  );

  group('AmbientSoundModel', () {
    test('reads the embedded sounds, sorted, a hidden one dropped', () {
      final List<AmbientSoundEntity> sounds = AmbientSoundModel.listFrom(
        <Object?>[
          <String, dynamic>{
            'default_level': 0.3,
            'ambient_sounds': <String, dynamic>{
              'id': 'fire',
              'slug': 'fire',
              'title': 'Fire',
              'audio_url': 'https://example.com/fire.m4a',
              'sort_order': 2,
            },
          },
          // Row-level security hid this sound: PostgREST sends null.
          <String, dynamic>{'default_level': 0.5, 'ambient_sounds': null},
          <String, dynamic>{
            'default_level': 0.6,
            'ambient_sounds': <String, dynamic>{
              'id': 'rain',
              'slug': 'rain',
              'title': 'Rain',
              'audio_url': 'https://example.com/rain.m4a',
              'sort_order': 1,
            },
          },
        ],
      );

      expect(sounds, <AmbientSoundEntity>[rain, fire]);
    });

    test('nothing embedded is no sounds', () {
      expect(AmbientSoundModel.listFrom(null), isEmpty);
    });

    test('the cache keeps them', () {
      final SceneEntity scene = makeScene(
        'room',
      ).copyWith(ambients: <AmbientSoundEntity>[rain, fire]);
      final row = scene.toCompanion(now: DateTime(2026));

      expect(row.ambients.value, contains('rain.m4a'));
      expect(
        AmbientSoundModel.fromCache(AmbientSoundModel.toCache(scene.ambients)),
        <AmbientSoundEntity>[rain, fire],
      );
    });
  });

  group('MixController', () {
    late MockContentRepository content;
    late FakeAudioPlayerService audio;
    late FakeFavoritesRepository favorites;
    late FakeMixPreferences preferences;
    late FakeProRepository pro;

    final SceneEntity rainy = makeScene(
      'rainy',
    ).copyWith(ambients: <AmbientSoundEntity>[rain, fire]);
    final SceneEntity quiet = makeScene('quiet', title: 'Quiet');

    ProviderContainer start(
      FakeAsync async, {
      MixSettings stored = const MixSettings(),
    }) {
      content = MockContentRepository();
      audio = FakeAudioPlayerService();
      favorites = FakeFavoritesRepository();
      preferences = FakeMixPreferences(stored);
      pro = FakeProRepository(available: false);
      when(
        () => content.getScenes(),
      ).thenAnswer((_) async => <SceneEntity>[rainy, quiet]);
      when(
        () => content.getTracks(),
      ).thenAnswer((_) async => <TrackEntity>[makeTrack('a')]);
      final ProviderContainer container = ProviderContainer(
        overrides: [
          contentRepositoryProvider.overrideWithValue(content),
          audioPlayerServiceProvider.overrideWithValue(audio),
          favoritesRepositoryProvider.overrideWithValue(favorites),
          mixPreferencesProvider.overrideWithValue(preferences),
          proRepositoryProvider.overrideWithValue(pro),
        ],
        retry: (_, _) => null,
      );
      addTearDown(() {
        container.dispose();
        audio.dispose();
        favorites.dispose();
        pro.dispose();
      });
      container.listen(mixControllerProvider, (_, _) {});
      container.listen(activeSceneControllerProvider, (_, _) {});
      async.flushMicrotasks();
      container.read(sceneListControllerProvider);
      async.flushMicrotasks();
      // The room the app opens in, as the scene behind the player reads it.
      container.read(activeSceneControllerProvider);
      async.flushMicrotasks();
      return container;
    }

    test(
      'the room the app opens in brings its sounds at its levels, under the music',
      () {
        fakeAsync((FakeAsync async) {
          start(async);

          expect(audio.ambience, <AmbientLoop>[
            AmbientLoop(id: 'rain', url: rain.audioUrl, level: 0.6),
            AmbientLoop(id: 'fire', url: fire.audioUrl, level: 0.3),
          ]);
          expect(audio.layer(VolumeLayer.music), 1);
          expect(audio.layer(VolumeLayer.ambience), 0.5);
        });
      },
    );

    test('a quiet room has none, and switching back brings them again', () {
      fakeAsync((FakeAsync async) {
        final ProviderContainer container = start(async);

        container.read(activeSceneControllerProvider.notifier).switchTo(quiet);
        async.flushMicrotasks();
        expect(audio.ambience, isEmpty);

        container.read(activeSceneControllerProvider.notifier).switchTo(rainy);
        async.flushMicrotasks();
        expect(audio.ambience, hasLength(2));
      });
    });

    test('the listener\'s levels win over the room\'s, and are saved', () {
      fakeAsync((FakeAsync async) {
        final ProviderContainer container = start(async);
        final MixController mix = container.read(
          mixControllerProvider.notifier,
        );

        mix.setSoundLevel('rainy', 'rain', 0.9);
        mix.setMusicLevel(0.5);

        expect(audio.ambience.first.level, 0.9);
        expect(audio.layer(VolumeLayer.music), 0.5);
        expect(preferences.saves, 0);

        async.elapse(MixController.saveAfter);
        expect(preferences.saves, 1);
        expect(preferences.stored.musicLevel, 0.5);
      });
    });

    test('turned off, the room is silent; a sound at zero is not played', () {
      fakeAsync((FakeAsync async) {
        final ProviderContainer container = start(
          async,
          stored: MixSettings(
            soundLevels: <String, double>{
              MixSettings.soundKey('rainy', 'fire'): 0,
            },
          ),
        );
        expect(audio.ambience.map((AmbientLoop l) => l.id), <String>['rain']);

        container.read(mixControllerProvider.notifier).setAmbienceOn(false);
        expect(audio.ambience, isEmpty);
      });
    });
  });
}
