import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:purelofi/common/analytics/analytics.provider.dart';
import 'package:purelofi/common/analytics/analytics.service.dart';
import 'package:purelofi/features/library/controller/library.provider.dart';
import 'package:purelofi/features/player/controller/playback_source.controller.dart';
import 'package:purelofi/features/player/controller/player.controller.dart';
import 'package:purelofi/features/player/controller/player.provider.dart';
import 'package:purelofi/features/player/domain/track.entity.dart';

import '../../../helpers/fake_audio_player.service.dart';
import '../../../helpers/fake_favorites.repository.dart';
import '../../../helpers/fake_library.repository.dart';
import '../../../helpers/mock_repositories.dart';
import '../../../helpers/recording_analytics.service.dart';

void main() {
  late FakeAudioPlayerService audio;
  late RecordingAnalyticsService analytics;

  ProviderContainer make({List<TrackEntity> library = const <TrackEntity>[]}) {
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
}
