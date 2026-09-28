import 'package:flutter_test/flutter_test.dart';
import 'package:purelofi/features/library/data/library_preferences.service.impl.dart';
import 'package:purelofi/features/library/domain/library_view.dart';
import 'package:purelofi/features/player/domain/track.entity.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

TrackEntity t(String id, {String? title, String? artist, int day = 1}) =>
    TrackEntity(
      id: id,
      title: title ?? id,
      artist: artist,
      audioUrl: 'file:///$id.mp3',
      createdAt: DateTime.utc(2026, 9, day),
      source: TrackSource.local,
    );

List<String> ids(List<TrackEntity> tracks) =>
    tracks.map((TrackEntity x) => x.id).toList();

void main() {
  group('sortTracks', () {
    final List<TrackEntity> tracks = <TrackEntity>[
      t('a', title: 'banana', artist: 'Zed', day: 1),
      t('b', title: 'Apple', day: 3),
      t('c', title: 'cherry', artist: 'amy', day: 2),
    ];

    test('recent puts the newest import first', () {
      expect(ids(sortTracks(tracks, LibrarySort.recent)), <String>[
        'b',
        'c',
        'a',
      ]);
    });

    test('title ignores case', () {
      expect(ids(sortTracks(tracks, LibrarySort.title)), <String>[
        'b',
        'a',
        'c',
      ]);
    });

    test('artist ignores case, and no artist goes last', () {
      expect(ids(sortTracks(tracks, LibrarySort.artist)), <String>[
        'c',
        'a',
        'b',
      ]);
    });
  });

  group('searchTracks', () {
    final List<TrackEntity> tracks = <TrackEntity>[
      t('a', title: 'Kitchen Demo', artist: 'A Friend'),
      t('b', title: 'Late Tape'),
    ];

    test('matches the title or the artist, ignoring case', () {
      expect(ids(searchTracks(tracks, 'KITCHEN')), <String>['a']);
      expect(ids(searchTracks(tracks, 'friend')), <String>['a']);
    });

    test('an empty query is everything', () {
      expect(ids(searchTracks(tracks, '  ')), <String>['a', 'b']);
    });
  });

  group('LibraryPreferencesImpl', () {
    setUp(() {
      SharedPreferencesAsyncPlatform.instance =
          InMemorySharedPreferencesAsync.empty();
    });

    test('remembers order and sort', () async {
      await LibraryPreferencesImpl().save(
        const LibraryView(
          order: LibraryOrder.inOrder,
          sort: LibrarySort.artist,
        ),
      );

      expect(
        await LibraryPreferencesImpl().load(),
        const LibraryView(
          order: LibraryOrder.inOrder,
          sort: LibrarySort.artist,
        ),
      );
    });

    test('a value it does not know falls back to the default', () async {
      await SharedPreferencesAsync().setString('library.order', 'sideways');

      expect(
        (await LibraryPreferencesImpl().load()).order,
        LibraryOrder.shuffle,
      );
    });
  });
}
