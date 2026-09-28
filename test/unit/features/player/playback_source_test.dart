import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:purelofi/common/analytics/analytics.provider.dart';
import 'package:purelofi/common/analytics/analytics.service.dart';
import 'package:purelofi/features/library/controller/library.provider.dart';
import 'package:purelofi/features/library/domain/library_view.dart';
import 'package:purelofi/features/player/controller/playback_source.controller.dart';
import 'package:purelofi/features/player/controller/player.controller.dart';
import 'package:purelofi/features/player/controller/player.provider.dart';
import 'package:purelofi/features/player/domain/track.entity.dart';

import '../../../helpers/fake_audio_player.service.dart';
import '../../../helpers/fake_favorites.repository.dart';
import '../../../helpers/fake_library.repository.dart';
import '../../../helpers/fake_library_preferences.dart';
import '../../../helpers/mock_repositories.dart';
import '../../../helpers/recording_analytics.service.dart';

void main() {
  late FakeAudioPlayerService audio;
  late RecordingAnalyticsService analytics;

  ProviderContainer make({
    List<TrackEntity> library = const <TrackEntity>[],
    LibraryView view = const LibraryView(),
  }) {
    final MockContentRepository content = MockContentRepository();
    when(
      () => content.getTracks(),
    ).thenAnswer((_) async => <TrackEntity>[makeTrack('ours')]);
    final FakeFavoritesRepository favorites = FakeFavoritesRepository();
    final FakeLibraryRepository mine = FakeLibraryRepository(library);
    addTearDown(favorites.dispose);
    addTearDown(mine.dispose);

    final ProviderContainer container = ProviderContainer(
      overrides: [
        contentRepositoryProvider.overrideWithValue(content),
        audioPlayerServiceProvider.overrideWithValue(audio),
        favoritesRepositoryProvider.overrideWithValue(favorites),
        libraryRepositoryProvider.overrideWithValue(mine),
        libraryPreferencesProvider.overrideWithValue(
          FakeLibraryPreferences(view),
        ),
        analyticsServiceProvider.overrideWithValue(analytics),
      ],
      retry: (_, _) => null,
    );
    addTearDown(container.dispose);
    container.listen(playerControllerProvider, (_, _) {});
    return container;
  }

  setUp(() {
    audio = FakeAudioPlayerService();
    addTearDown(audio.dispose);
    analytics = RecordingAnalyticsService();
  });

  test('the app starts on PureLofi\'s own music', () async {
    final ProviderContainer c = make(
      library: <TrackEntity>[makeLocalTrack('mine')],
    );

    expect(c.read(playbackSourceControllerProvider), TrackSource.catalogue);

    await c.read(playerControllerProvider.notifier).playNext();
    expect(audio.playedTracks.last.id, 'ours');
  });

  test('switching to the library plays one of its tracks at once', () async {
    final ProviderContainer c = make(
      library: <TrackEntity>[makeLocalTrack('mine')],
    );

    await c
        .read(playerControllerProvider.notifier)
        .useSource(TrackSource.local);

    expect(c.read(playbackSourceControllerProvider), TrackSource.local);
    expect(audio.playedTracks.last.id, 'mine');
  });

  test('and the stream stays in the library after that', () async {
    final ProviderContainer c = make(
      library: <TrackEntity>[makeLocalTrack('one'), makeLocalTrack('two')],
    );
    final PlayerController player = c.read(playerControllerProvider.notifier);

    await player.useSource(TrackSource.local);
    await player.playNext();
    await player.playNext();

    expect(
      audio.playedTracks.map((TrackEntity t) => t.source),
      everyElement(TrackSource.local),
    );
  });

  test('a local track is reported without an id or a title', () async {
    final ProviderContainer c = make(
      library: <TrackEntity>[makeLocalTrack('mine', title: 'Secret Demo')],
    );

    await c
        .read(playerControllerProvider.notifier)
        .useSource(TrackSource.local);

    final (String, Map<String, Object>) event = analytics.events.last;
    expect(event.$1, AnalyticsEvents.trackPlayed);
    expect(event.$2, <String, Object>{'source': 'local'});
  });

  test('an empty library plays nothing rather than failing', () async {
    final ProviderContainer c = make();

    await c
        .read(playerControllerProvider.notifier)
        .useSource(TrackSource.local);

    expect(audio.playedTracks, isEmpty);
    expect(c.read(playerControllerProvider).error, isNull);
  });

  group('moving through the library', () {
    // Titles sort a, b, c; imports are newest first, so recent is c, b, a.
    final List<TrackEntity> three = <TrackEntity>[
      makeLocalTrack('a', title: 'Alpha'),
      makeLocalTrack('b', title: 'Bravo'),
      makeLocalTrack('c', title: 'Charlie'),
    ];
    const LibraryView inOrderByTitle = LibraryView(
      order: LibraryOrder.inOrder,
      sort: LibrarySort.title,
    );

    List<String> played() =>
        audio.playedTracks.map((TrackEntity x) => x.id).toList();

    test('in order goes down the list and round again', () async {
      final ProviderContainer c = make(library: three, view: inOrderByTitle);
      final PlayerController player = c.read(playerControllerProvider.notifier);

      await player.useSource(TrackSource.local);
      await player.playNext();
      await player.playNext();
      await player.playNext();

      expect(played(), <String>['a', 'b', 'c', 'a']);
    });

    test('previous in order is the track above', () async {
      final ProviderContainer c = make(library: three, view: inOrderByTitle);
      final PlayerController player = c.read(playerControllerProvider.notifier);

      await player.useSource(TrackSource.local);
      await player.playNext();
      await player.previous();

      expect(played(), <String>['a', 'b', 'a']);
    });

    test('previous in shuffle is the one that actually played', () async {
      final ProviderContainer c = make(library: three);
      final PlayerController player = c.read(playerControllerProvider.notifier);

      await player.useSource(TrackSource.local);
      await player.playNext();
      await player.playNext();
      final List<String> before = played();

      await player.previous();
      await player.previous();

      expect(played().sublist(3), <String>[before[1], before[0]]);
    });

    test('a few seconds in, previous starts the track again', () async {
      final ProviderContainer c = make(library: three, view: inOrderByTitle);
      final PlayerController player = c.read(playerControllerProvider.notifier);

      await player.useSource(TrackSource.local);
      await player.playNext();
      await player.seek(const Duration(seconds: 10));
      await player.previous();

      expect(played(), <String>['a', 'b'], reason: 'nothing new played');
      expect(c.read(playerControllerProvider).position, Duration.zero);
    });

    test('PureLofi\'s stream still only starts over', () async {
      final ProviderContainer c = make(library: three);
      final PlayerController player = c.read(playerControllerProvider.notifier);

      await player.playNext();
      await player.previous();

      expect(played(), <String>['ours']);
    });
  });
}
