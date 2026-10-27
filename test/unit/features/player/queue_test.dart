import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:purelofi/common/analytics/analytics.provider.dart';
import 'package:purelofi/features/player/controller/playback_mode.controller.dart';
import 'package:purelofi/features/player/controller/player.controller.dart';
import 'package:purelofi/features/player/controller/player.provider.dart';
import 'package:purelofi/features/player/domain/playback_mode.dart';
import 'package:purelofi/features/player/domain/player.state.dart';
import 'package:purelofi/features/player/domain/track.entity.dart';
import 'package:purelofi/features/player/domain/up_next.dart';

import '../../../helpers/fake_audio_player.service.dart';
import '../../../helpers/fake_favorites.repository.dart';
import '../../../helpers/fake_playback_preferences.dart';
import '../../../helpers/mock_repositories.dart';
import '../../../helpers/recording_analytics.service.dart';

void main() {
  List<String> ids(Iterable<TrackEntity> tracks) =>
      tracks.map((TrackEntity t) => t.id).toList();

  final List<TrackEntity> abc = <TrackEntity>[
    for (final (String id, int day) in <(String, int)>[
      ('a', 1),
      ('b', 2),
      ('c', 3),
    ])
      makeTrack(id).copyWith(createdAt: DateTime.utc(2026, 1, day)),
  ];

  group('upNextInOrder', () {
    test('starts at the top with nothing playing', () {
      expect(ids(upNextInOrder(abc, currentId: null)), <String>['a', 'b', 'c']);
    });

    test('goes on from the current track, round the end', () {
      expect(ids(upNextInOrder(abc, currentId: 'b')), <String>['c', 'a']);
    });

    test('never lists more than asked for', () {
      expect(upNextInOrder(abc, currentId: null, count: 2), hasLength(2));
    });

    test('the only track comes round again', () {
      expect(ids(upNextInOrder(abc.sublist(0, 1), currentId: 'a')), <String>[
        'a',
      ]);
    });
  });

  group('upNextShuffled', () {
    final List<TrackEntity> twelve = <TrackEntity>[
      for (int i = 0; i < 12; i++) makeTrack('t$i'),
    ];

    test('fills the plan with no title twice and no repeat running', () {
      final List<TrackEntity> plan = upNextShuffled(
        twelve,
        currentId: 't0',
        favorites: const <String>{},
        random: Random(7),
      );

      expect(plan, hasLength(upNextLength));
      expect(plan.first.id, isNot('t0'));
      expect(ids(plan).toSet(), hasLength(plan.length));
    });

    test('stays two short of the catalogue, so it is still random', () {
      final Set<String> firsts = <String>{
        for (int seed = 0; seed < 40; seed++)
          upNextShuffled(
            abc,
            currentId: 'a',
            favorites: const <String>{},
            random: Random(seed),
          ).single.id,
      };

      expect(firsts, <String>{'b', 'c'});
    });

    test('a catalogue of one plans that track once', () {
      expect(
        ids(
          upNextShuffled(
            abc.sublist(0, 1),
            currentId: 'a',
            favorites: const <String>{},
            random: Random(1),
          ),
        ),
        <String>['a'],
      );
    });

    test('keeps what was drawn, minus anything that has gone', () {
      final List<TrackEntity> plan = upNextShuffled(
        twelve,
        currentId: 't0',
        favorites: const <String>{},
        random: Random(1),
        planned: <TrackEntity>[makeTrack('gone'), twelve[2], twelve[1]],
      );

      expect(ids(plan.take(2)), <String>['t2', 't1']);
    });
  });

  group('the queue', () {
    late FakeAudioPlayerService audio;

    ProviderContainer make({PlaybackMode mode = PlaybackMode.shuffle}) {
      final MockContentRepository content = MockContentRepository();
      when(() => content.getTracks()).thenAnswer((_) async => abc);
      final FakeFavoritesRepository favorites = FakeFavoritesRepository();
      addTearDown(favorites.dispose);

      final ProviderContainer container = ProviderContainer(
        overrides: [
          contentRepositoryProvider.overrideWithValue(content),
          audioPlayerServiceProvider.overrideWithValue(audio),
          favoritesRepositoryProvider.overrideWithValue(favorites),
          playbackPreferencesProvider.overrideWithValue(
            FakePlaybackPreferences(mode),
          ),
          analyticsServiceProvider.overrideWithValue(
            RecordingAnalyticsService(),
          ),
        ],
        retry: (_, _) => null,
      );
      addTearDown(container.dispose);
      container.listen(playerControllerProvider, (_, _) {});
      return container;
    }

    List<String> played() => ids(audio.playedTracks);

    setUp(() {
      audio = FakeAudioPlayerService();
      addTearDown(audio.dispose);
    });

    test('plays before the stream\'s own plan, in the order added', () async {
      final ProviderContainer c = make(mode: PlaybackMode.inOrder);
      final PlayerController player = c.read(playerControllerProvider.notifier);
      await player.playNext();

      player
        ..addToQueue(abc[2])
        ..addToQueue(abc[0]);
      await player.playNext();
      await player.playNext();
      await player.playNext();

      expect(played(), <String>['a', 'c', 'a', 'b']);
    });

    test('play next goes ahead of what is already queued', () async {
      final PlayerController player = make().read(
        playerControllerProvider.notifier,
      );
      await player.playNext();

      player
        ..addToQueue(abc[1])
        ..queueNext(abc[2]);

      await player.playNext();
      expect(played().last, 'c');
    });

    test('jumping into the queue skips what was before it', () async {
      final ProviderContainer c = make();
      final PlayerController player = c.read(playerControllerProvider.notifier);
      await player.playNext();
      player
        ..addToQueue(abc[0])
        ..addToQueue(abc[1])
        ..addToQueue(abc[2]);

      await player.skipToQueued(1);

      expect(played().last, 'b');
      expect(ids(c.read(playerControllerProvider).queue), <String>['c']);
    });

    test('jumping into the plan skips what was before it', () async {
      final ProviderContainer c = make(mode: PlaybackMode.inOrder);
      final PlayerController player = c.read(playerControllerProvider.notifier);
      await player.playNext();
      expect(ids(c.read(playerControllerProvider).upNext), <String>['b', 'c']);

      await player.skipToUpNext(1);

      expect(played().last, 'c');
      expect(ids(c.read(playerControllerProvider).upNext), <String>['a', 'b']);
    });

    test('the plan is drawn ahead and shown while a track plays', () async {
      final ProviderContainer c = make();
      await c.read(playerControllerProvider.notifier).playNext();

      final PlayerState state = c.read(playerControllerProvider);
      expect(state.upNext, hasLength(1), reason: 'three tracks, two short');
      expect(state.upNext.first.id, isNot(state.currentTrack!.id));
    });

    test('a forgotten track leaves the queue and the plan', () async {
      final ProviderContainer c = make();
      final PlayerController player = c.read(playerControllerProvider.notifier);
      await player.playNext();
      player.addToQueue(abc[1]);

      player.forget('b');

      final PlayerState state = c.read(playerControllerProvider);
      expect(state.queue, isEmpty);
      expect(ids(state.upNext), isNot(contains('b')));
    });

    test('turning shuffle off draws the plan again, in order', () async {
      final ProviderContainer c = make();
      await c.read(playerControllerProvider.notifier).playNext();
      final String current = c.read(playerControllerProvider).currentTrack!.id;

      await c
          .read(playbackModeControllerProvider.notifier)
          .set(PlaybackMode.inOrder);
      await Future<void>.delayed(Duration.zero);

      expect(
        ids(c.read(playerControllerProvider).upNext),
        ids(upNextInOrder(abc, currentId: current)),
      );
    });
  });
}
