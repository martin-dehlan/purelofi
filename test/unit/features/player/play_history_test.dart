import 'package:fake_async/fake_async.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:purelofi/features/library/controller/library.provider.dart';
import 'package:purelofi/features/player/controller/play_history.controller.dart';
import 'package:purelofi/features/player/controller/player.controller.dart';
import 'package:purelofi/features/player/controller/player.provider.dart';
import 'package:purelofi/features/player/domain/play_event.entity.dart';
import 'package:purelofi/features/player/domain/track.entity.dart';

import '../../../helpers/fake_audio_player.service.dart';
import '../../../helpers/fake_favorites.repository.dart';
import '../../../helpers/fake_library.repository.dart';
import '../../../helpers/fake_play_history.repository.dart';
import '../../../helpers/mock_repositories.dart';

void main() {
  late MockContentRepository mockRepo;
  late FakeAudioPlayerService fakeAudio;
  late FakePlayHistoryRepository history;

  setUp(() {
    mockRepo = MockContentRepository();
    fakeAudio = FakeAudioPlayerService();
    when(
      () => mockRepo.getTracks(),
    ).thenAnswer((_) async => <TrackEntity>[makeTrack('a'), makeTrack('b')]);
  });

  ProviderContainer recording(
    FakeAsync async, [
    List<PlayEventEntity> earlier = const <PlayEventEntity>[],
  ]) {
    history = FakePlayHistoryRepository(List<PlayEventEntity>.of(earlier));
    final FakeFavoritesRepository favorites = FakeFavoritesRepository();
    final FakeLibraryRepository library = FakeLibraryRepository();
    final ProviderContainer container = ProviderContainer(
      overrides: [
        contentRepositoryProvider.overrideWithValue(mockRepo),
        audioPlayerServiceProvider.overrideWithValue(fakeAudio),
        favoritesRepositoryProvider.overrideWithValue(favorites),
        libraryRepositoryProvider.overrideWithValue(library),
        playHistoryRepositoryProvider.overrideWithValue(history),
      ],
      retry: (_, _) => null,
    );
    addTearDown(() {
      container.dispose();
      favorites.dispose();
      library.dispose();
      fakeAudio.dispose();
      history.dispose();
    });
    container
      ..listen(playHistoryRecorderProvider, (_, _) {})
      ..listen(recentlyPlayedTracksProvider, (_, _) {});
    container.read(playerControllerProvider.notifier).playTrack(makeTrack('a'));
    async.flushMicrotasks();
    fakeAudio.durationController.add(const Duration(minutes: 3));
    async.flushMicrotasks();
    return container;
  }

  /// The playhead moving through [seconds] of the track, from [from].
  void listen(FakeAsync async, int seconds, {int from = 0}) {
    for (int ms = from * 1000; ms <= (from + seconds) * 1000; ms += 500) {
      fakeAudio.positionController.add(Duration(milliseconds: ms));
      async.flushMicrotasks();
    }
  }

  test('a track heard for 30 seconds is written to the log', () {
    fakeAsync((FakeAsync async) {
      recording(async);

      listen(async, 29);
      expect(history.events, isEmpty);

      listen(async, 2, from: 29);
      expect(history.events.single.trackId, 'a');
      expect(history.events.single.source, TrackSource.catalogue);
    });
  });

  test('a skip after a few seconds is not a play', () {
    fakeAsync((FakeAsync async) {
      final ProviderContainer container = recording(async);
      listen(async, 3);

      container.read(playerControllerProvider.notifier).playNext();
      async.flushMicrotasks();

      expect(history.events, isEmpty);
    });
  });

  test('the listened time is brought up to date when the track changes', () {
    fakeAsync((FakeAsync async) {
      final ProviderContainer container = recording(async);
      listen(async, 45);

      container
          .read(playerControllerProvider.notifier)
          .playTrack(makeTrack('b'));
      async.flushMicrotasks();

      final PlayEventEntity play = history.events.single;
      expect(play.listenedSeconds, 45);
    });
  });

  test('recently played lists each track once, newest first', () {
    fakeAsync((FakeAsync async) {
      final DateTime now = DateTime(2026, 11, 4);
      int id = 0;
      final ProviderContainer container = recording(async, <PlayEventEntity>[
        for (final (String track, int minutesAgo) in <(String, int)>[
          ('a', 30),
          ('b', 20),
          ('a', 10),
          ('gone', 5),
        ])
          PlayEventEntity(
            id: ++id,
            trackId: track,
            source: TrackSource.catalogue,
            startedAt: now.subtract(Duration(minutes: minutesAgo)),
            listenedSeconds: 60,
          ),
      ]);
      async.flushMicrotasks();

      // "gone" is no longer in the catalogue, so it drops out.
      expect(
        container
            .read(recentlyPlayedTracksProvider)
            .map((TrackEntity t) => t.id),
        <String>['a', 'b'],
      );
    });
  });
}
