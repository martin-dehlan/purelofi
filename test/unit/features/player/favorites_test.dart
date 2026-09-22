import 'dart:math';

import 'package:drift/drift.dart' show DatabaseConnection;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:purelofi/common/database/app_database.dart';
import 'package:purelofi/common/database/daos/track.dao.dart';
import 'package:purelofi/features/player/controller/player.controller.dart';
import 'package:purelofi/features/player/data/favorites.repository.impl.dart';
import 'package:purelofi/features/player/domain/track.entity.dart';

import '../../../helpers/mock_repositories.dart';

/// A Random that walks through a fixed sequence, so a weighted draw can be
/// checked exactly rather than statistically.
class _Sequence implements Random {
  _Sequence(this._values);

  final List<int> _values;
  int _at = 0;

  @override
  int nextInt(int max) => _values[_at++ % _values.length] % max;

  @override
  bool nextBool() => false;

  @override
  double nextDouble() => 0;
}

void main() {
  group('FavoritesRepositoryImpl', () {
    late AppDatabase database;
    late TrackDao dao;
    late FavoritesRepositoryImpl repository;

    Future<void> cache(List<String> ids) =>
        dao.replaceTracks(<TrackTableCompanion>[
          for (final String id in ids)
            TrackTableCompanion.insert(
              id: id,
              title: id,
              audioUrl: 'https://example.com/$id.mp3',
              createdAt: DateTime.utc(2026),
              updatedAt: DateTime.utc(2026),
            ),
        ]);

    setUp(() {
      database = AppDatabase.forTesting(
        DatabaseConnection(NativeDatabase.memory()),
      );
      addTearDown(database.close);
      dao = TrackDao(database);
      repository = FavoritesRepositoryImpl(dao: dao);
    });

    test('a mark survives being read back', () async {
      await cache(<String>['a', 'b']);

      expect(await repository.toggle('a'), isTrue);

      expect(await repository.getFavoriteIds(), <String>{'a'});
    });

    test('toggling again takes it off', () async {
      await cache(<String>['a']);
      await repository.toggle('a');

      expect(await repository.toggle('a'), isFalse);
      expect(await repository.getFavoriteIds(), isEmpty);
    });

    test('marking a track nobody has cached does nothing', () async {
      expect(await repository.toggle('ghost'), isFalse);
      expect(await repository.getFavoriteIds(), isEmpty);
    });

    test('a track the server drops loses its mark with it', () async {
      // A favourite on something that can no longer be played is not worth
      // keeping, and the cache is what decides that.
      await cache(<String>['a', 'b']);
      await repository.toggle('a');

      await cache(<String>['b']);

      expect(await repository.getFavoriteIds(), isEmpty);
    });

    test('the stream reports a change without being asked again', () async {
      await cache(<String>['a']);

      final Future<Set<String>> next = repository.watchFavoriteIds().firstWhere(
        (Set<String> ids) => ids.isNotEmpty,
      );
      await repository.toggle('a');

      expect(await next, <String>{'a'});
    });
  });

  group('pickWeighted', () {
    final List<TrackEntity> tracks = <TrackEntity>[
      makeTrack('plain'),
      makeTrack('loved'),
    ];

    test('counts a favourite three times over', () {
      // Weights are 1 and 3, so the draw runs over 0..3: only the first roll
      // lands on the unmarked track.
      final List<String> drawn = <String>[
        for (int roll = 0; roll < 4; roll++)
          pickWeighted(
            tracks,
            favorites: <String>{'loved'},
            random: _Sequence(<int>[roll]),
          ).id,
      ];

      expect(drawn, <String>['plain', 'loved', 'loved', 'loved']);
    });

    test('an unmarked track is still reachable', () {
      // The point of the weighting: likelier, not certain. A shuffle that
      // only played favourites would be a playlist, not a stream.
      expect(
        pickWeighted(
          tracks,
          favorites: <String>{'loved'},
          random: _Sequence(<int>[0]),
        ).id,
        'plain',
      );
    });

    test('with nothing marked it is an even draw', () {
      final List<String> drawn = <String>[
        for (int roll = 0; roll < 2; roll++)
          pickWeighted(
            tracks,
            favorites: const <String>{},
            random: _Sequence(<int>[roll]),
          ).id,
      ];

      expect(drawn, <String>['plain', 'loved']);
    });

    test('a single track is always that track', () {
      expect(
        pickWeighted(
          <TrackEntity>[makeTrack('only')],
          favorites: <String>{'only'},
          random: _Sequence(<int>[0]),
        ).id,
        'only',
      );
    });
  });
}
