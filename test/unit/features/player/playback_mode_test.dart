import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:purelofi/common/analytics/analytics.provider.dart';
import 'package:purelofi/features/player/controller/playback_mode.controller.dart';
import 'package:purelofi/features/player/controller/player.controller.dart';
import 'package:purelofi/features/player/controller/player.provider.dart';
import 'package:purelofi/features/player/data/playback_preferences.service.impl.dart';
import 'package:purelofi/features/player/domain/playback_mode.dart';
import 'package:purelofi/features/player/domain/track.entity.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

import '../../../helpers/fake_audio_player.service.dart';
import '../../../helpers/fake_favorites.repository.dart';
import '../../../helpers/fake_playback_preferences.dart';
import '../../../helpers/mock_repositories.dart';
import '../../../helpers/recording_analytics.service.dart';

void main() {
  late FakeAudioPlayerService audio;
  late FakePlaybackPreferences preferences;

  // Handed over newest first, as the repository might: "in order" has to
  // sort them itself.
  final List<TrackEntity> catalogue = <TrackEntity>[
    for (final (String id, int day) in <(String, int)>[
      ('c', 3),
      ('a', 1),
      ('b', 2),
    ])
      makeTrack(id).copyWith(createdAt: DateTime.utc(2026, 1, day)),
  ];

  ProviderContainer make({PlaybackMode mode = PlaybackMode.shuffle}) {
    final MockContentRepository content = MockContentRepository();
    when(() => content.getTracks()).thenAnswer((_) async => catalogue);
    final FakeFavoritesRepository favorites = FakeFavoritesRepository();
    addTearDown(favorites.dispose);
    preferences = FakePlaybackPreferences(mode);

    final ProviderContainer container = ProviderContainer(
      overrides: [
        contentRepositoryProvider.overrideWithValue(content),
        audioPlayerServiceProvider.overrideWithValue(audio),
        favoritesRepositoryProvider.overrideWithValue(favorites),
        playbackPreferencesProvider.overrideWithValue(preferences),
        analyticsServiceProvider.overrideWithValue(RecordingAnalyticsService()),
      ],
      retry: (_, _) => null,
    );
    addTearDown(container.dispose);
    container.listen(playerControllerProvider, (_, _) {});
    return container;
  }

  /// Lets the provider listeners run.
  Future<void> pump() => Future<void>.delayed(Duration.zero);

  List<String> played() =>
      audio.playedTracks.map((TrackEntity t) => t.id).toList();

  setUp(() {
    audio = FakeAudioPlayerService();
    addTearDown(audio.dispose);
  });

  group('the mode', () {
    test('reaches the audio service as soon as it is loaded', () async {
      final ProviderContainer c = make(mode: PlaybackMode.repeatOne);

      await c.read(playbackModeControllerProvider.future);
      await pump();

      expect(audio.modes.last, PlaybackMode.repeatOne);
    });

    test('a toggle is remembered and handed on', () async {
      final ProviderContainer c = make();
      await c.read(playbackModeControllerProvider.future);

      await c.read(playbackModeControllerProvider.notifier).cycle();
      await pump();

      expect(preferences.stored, PlaybackMode.repeatOne);
      expect(audio.modes.last.loops, isTrue);
    });

    test('a change on the lock screen is the same as one in the app', () async {
      final ProviderContainer c = make();
      await c.read(playbackModeControllerProvider.future);
      await pump();

      audio.emitModeRequest(PlaybackMode.inOrder);
      await pump();

      expect(
        c.read(playbackModeControllerProvider).value,
        PlaybackMode.inOrder,
      );
      expect(preferences.stored.shuffles, isFalse);
      expect(audio.modes.last.shuffles, isFalse);
    });

    test('skipping keeps repeat on for the next track', () async {
      final ProviderContainer c = make(mode: PlaybackMode.repeatOne);
      final PlayerController player = c.read(playerControllerProvider.notifier);

      await player.playNext();
      await player.playNext();

      expect(c.read(playbackModeControllerProvider).value?.loops, isTrue);
    });
  });

  group('PureLofi\'s music with shuffle off', () {
    const PlaybackMode inOrder = PlaybackMode.inOrder;

    test('plays oldest first and round again', () async {
      final PlayerController player = make(
        mode: inOrder,
      ).read(playerControllerProvider.notifier);

      for (int i = 0; i < 4; i++) {
        await player.playNext();
      }

      expect(played(), <String>['a', 'b', 'c', 'a']);
    });

    test('previous is the track before', () async {
      final PlayerController player = make(
        mode: inOrder,
      ).read(playerControllerProvider.notifier);

      await player.playNext();
      await player.playNext();
      await player.previous();

      expect(played(), <String>['a', 'b', 'a']);
    });
  });

  test('in shuffle, previous goes back to what actually played', () async {
    final PlayerController player = make().read(
      playerControllerProvider.notifier,
    );

    await player.playNext();
    await player.playNext();
    final List<String> before = played();
    await player.previous();

    expect(played().last, before.first);
  });

  group('PlaybackPreferencesImpl', () {
    setUp(() {
      SharedPreferencesAsyncPlatform.instance =
          InMemorySharedPreferencesAsync.empty();
    });

    test('starts the way the app always has: shuffled, no repeat', () async {
      expect(await PlaybackPreferencesImpl().load(), PlaybackMode.shuffle);
    });

    test('remembers both', () async {
      const PlaybackMode mode = PlaybackMode.repeatOne;
      await PlaybackPreferencesImpl().save(mode);

      expect(await PlaybackPreferencesImpl().load(), mode);
    });

    test('a value of the wrong type falls back to the default', () async {
      await SharedPreferencesAsync().setString('playback.mode', 'sideways');

      expect((await PlaybackPreferencesImpl().load()).shuffles, isTrue);
    });
  });
}
