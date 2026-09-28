import 'dart:async';
import 'dart:io';

import 'package:drift/drift.dart' show DatabaseConnection, Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:purelofi/common/database/app_database.dart';
import 'package:purelofi/common/database/daos/local_track.dao.dart';
import 'package:purelofi/common/database/daos/track.dao.dart';

void main() {
  final DateTime now = DateTime.utc(2026, 9, 28);

  LocalTrackTableCompanion local(
    String id, {
    int minutesAgo = 0,
    int sizeBytes = 1000,
  }) => LocalTrackTableCompanion(
    id: Value<String>(id),
    title: Value<String>(id),
    fileName: Value<String>('$id.mp3'),
    sizeBytes: Value<int>(sizeBytes),
    createdAt: Value<DateTime>(now.subtract(Duration(minutes: minutesAgo))),
    updatedAt: Value<DateTime>(now),
  );

  group('LocalTrackDao', () {
    late AppDatabase database;
    late LocalTrackDao library;

    setUp(() {
      database = AppDatabase.forTesting(
        DatabaseConnection(NativeDatabase.memory()),
      );
      addTearDown(database.close);
      library = LocalTrackDao(database);
    });

    test('hands tracks back newest first', () async {
      await library.add(local('old', minutesAgo: 10));
      await library.add(local('new'));

      expect(
        (await library.getAll()).map((LocalTrackTableData t) => t.id),
        <String>['new', 'old'],
      );
    });

    test('a server sync leaves the library alone', () async {
      // The reason this is its own table: replaceTracks deletes every row
      // the server did not send, and the server never sends these.
      await library.add(local('mine'));

      await TrackDao(database).replaceTracks(<TrackTableCompanion>[]);

      expect(await library.getAll(), hasLength(1));
    });

    test('remove says whether there was anything to remove', () async {
      await library.add(local('a'));

      expect(await library.remove('a'), isTrue);
      expect(await library.remove('a'), isFalse);
      expect(await library.find('a'), isNull);
    });

    test('adds up what the library costs on disk', () async {
      expect(await library.totalBytes(), 0);

      await library.add(local('a', sizeBytes: 3000));
      await library.add(local('b', sizeBytes: 4500));

      expect(await library.totalBytes(), 7500);
    });

    test('watchAll reports an import without being asked again', () async {
      final StreamIterator<List<LocalTrackTableData>> updates =
          StreamIterator<List<LocalTrackTableData>>(library.watchAll());
      addTearDown(updates.cancel);

      // The empty library first, so the import cannot land before anyone is
      // listening.
      expect(await updates.moveNext(), isTrue);
      expect(updates.current, isEmpty);

      await library.add(local('a'));

      expect(await updates.moveNext(), isTrue);
      expect(updates.current, hasLength(1));
    });
  });

  group('migration', () {
    test(
      'an existing v2 database gains the library and keeps its rows',
      () async {
        final Directory dir = await Directory.systemTemp.createTemp(
          'purelofi_db',
        );
        addTearDown(() => dir.delete(recursive: true));
        final File file = File('${dir.path}/db.sqlite');

        // Build today's schema, then take it back to what 0.3.0 shipped:
        // no library, user_version 2.
        final AppDatabase current = AppDatabase.forTesting(
          DatabaseConnection(NativeDatabase(file)),
        );
        await TrackDao(current).replaceTracks(<TrackTableCompanion>[
          TrackTableCompanion(
            id: const Value<String>('t'),
            title: const Value<String>('t'),
            audioUrl: const Value<String>('https://example.com/t.mp3'),
            isFavorite: const Value<bool>(true),
            createdAt: Value<DateTime>(now),
            updatedAt: Value<DateTime>(now),
          ),
        ]);
        await current.customStatement('DROP TABLE local_tracks');
        await current.customStatement('PRAGMA user_version = 2');
        await current.close();

        final AppDatabase upgraded = AppDatabase.forTesting(
          DatabaseConnection(NativeDatabase(file)),
        );
        addTearDown(upgraded.close);

        // The library is there and usable…
        await LocalTrackDao(upgraded).add(local('mine'));
        expect(await LocalTrackDao(upgraded).getAll(), hasLength(1));

        // …and nothing the listener had before went missing on the way.
        final List<TrackTableData> tracks = await TrackDao(
          upgraded,
        ).getTracks();
        expect(tracks.single.isFavorite, isTrue);
      },
    );
  });
}
