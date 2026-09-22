import 'dart:io';

import 'package:drift/drift.dart' show DatabaseConnection;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:purelofi/common/cache/media_cache.service.dart';
import 'package:purelofi/common/database/app_database.dart';
import 'package:purelofi/common/database/daos/cached_file.dao.dart';

void main() {
  late AppDatabase database;
  late CachedFileDao dao;
  late Directory directory;
  late List<String> requested;
  DateTime clock = DateTime.utc(2026, 9, 22, 12);

  /// Serves [size] bytes for anything, and records what was asked for.
  MockClient serving({int size = 1024, int status = 200}) =>
      MockClient((http.Request request) async {
        requested.add(request.url.toString());

        return http.Response.bytes(List<int>.filled(size, 7), status);
      });

  FileMediaCache cacheWith({
    required http.Client client,
    int maxBytes = FileMediaCache.defaultMaxBytes,
  }) => FileMediaCache(
    dao: dao,
    directory: directory,
    client: client,
    maxBytes: maxBytes,
    now: () => clock,
  );

  setUp(() {
    database = AppDatabase.forTesting(
      DatabaseConnection(NativeDatabase.memory()),
    );
    addTearDown(database.close);
    dao = CachedFileDao(database);
    directory = Directory.systemTemp.createTempSync('purelofi_cache_test');
    addTearDown(() => directory.deleteSync(recursive: true));
    requested = <String>[];
    clock = DateTime.utc(2026, 9, 22, 12);
  });

  group('store', () {
    test('downloads once and serves the file afterwards', () async {
      final FileMediaCache cache = cacheWith(client: serving(size: 500));

      final File? first = await cache.store('https://x/track.mp3');
      expect(first, isNotNull);
      expect(first!.readAsBytesSync(), hasLength(500));

      final File? again = await cache.store('https://x/track.mp3');

      expect(again?.path, first.path);
      expect(requested, hasLength(1), reason: 'the second call is a hit');
      expect(await cache.sizeInBytes(), 500);
    });

    test('two callers asking at once fetch it once', () async {
      final FileMediaCache cache = cacheWith(client: serving());

      await Future.wait(<Future<File?>>[
        cache.store('https://x/strip.png'),
        cache.store('https://x/strip.png'),
      ]);

      expect(requested, hasLength(1));
    });

    test('keeps the extension, so a player can tell what it got', () async {
      final FileMediaCache cache = cacheWith(client: serving());

      final File? file = await cache.store('https://x/a/track.mp3');

      expect(file!.path, endsWith('.mp3'));
    });

    test('a failed download is a miss, not an error', () async {
      final FileMediaCache cache = cacheWith(client: serving(status: 404));

      expect(await cache.store('https://x/gone.mp3'), isNull);
      expect(await cache.sizeInBytes(), 0);
    });

    test('a refused connection is a miss too', () async {
      final FileMediaCache cache = cacheWith(
        client: MockClient((_) async => throw const SocketException('down')),
      );

      expect(await cache.store('https://x/track.mp3'), isNull);
      expect(await cache.sizeInBytes(), 0);
    });

    test('leaves no half-written file behind', () async {
      final FileMediaCache cache = cacheWith(client: serving());
      await cache.store('https://x/track.mp3');

      expect(
        directory.listSync().where(
          (FileSystemEntity e) => e.path.endsWith('.part'),
        ),
        isEmpty,
      );
    });
  });

  group('fileFor', () {
    test('is a miss before anything was stored', () async {
      final FileMediaCache cache = cacheWith(client: serving());

      expect(await cache.fileFor('https://x/track.mp3'), isNull);
    });

    test('forgets a file the system deleted under it', () async {
      final FileMediaCache cache = cacheWith(client: serving());
      final File? file = await cache.store('https://x/track.mp3');
      file!.deleteSync();

      expect(await cache.fileFor('https://x/track.mp3'), isNull);
      expect(
        await cache.sizeInBytes(),
        0,
        reason: 'the index must not outlive the file',
      );
    });

    test('a hit counts as a use', () async {
      final FileMediaCache cache = cacheWith(client: serving());
      await cache.store('https://x/track.mp3');

      clock = clock.add(const Duration(days: 1));
      await cache.fileFor('https://x/track.mp3');

      // Drift stores the instant, not the time zone, so compare instants.
      final CachedFileTableData? row = await dao.find('https://x/track.mp3');
      expect(row?.lastUsedAt.isAtSameMomentAs(clock), isTrue);
    });
  });

  group('evict', () {
    test('throws away the least recently used until it fits', () async {
      // Three files of 400 bytes against a 1000 byte cap: one has to go.
      final FileMediaCache cache = cacheWith(
        client: serving(size: 400),
        maxBytes: 1000,
      );

      await cache.store('https://x/one.mp3');
      clock = clock.add(const Duration(minutes: 1));
      await cache.store('https://x/two.mp3');
      clock = clock.add(const Duration(minutes: 1));

      // Playing the oldest again moves it out of the firing line.
      await cache.fileFor('https://x/one.mp3');
      clock = clock.add(const Duration(minutes: 1));

      await cache.store('https://x/three.mp3');

      expect(await cache.sizeInBytes(), 800);
      expect(await cache.fileFor('https://x/two.mp3'), isNull);
      expect(await cache.fileFor('https://x/one.mp3'), isNotNull);
      expect(await cache.fileFor('https://x/three.mp3'), isNotNull);
    });

    test('deletes the file, not just the row', () async {
      final FileMediaCache cache = cacheWith(
        client: serving(size: 400),
        maxBytes: 500,
      );

      await cache.store('https://x/one.mp3');
      clock = clock.add(const Duration(minutes: 1));
      await cache.store('https://x/two.mp3');

      expect(
        directory.listSync(),
        hasLength(1),
        reason: 'an evicted row that leaves its file is a disk leak',
      );
    });

    test('does nothing while there is room', () async {
      final FileMediaCache cache = cacheWith(
        client: serving(size: 100),
        maxBytes: 1000,
      );

      await cache.store('https://x/one.mp3');
      await cache.store('https://x/two.mp3');
      await cache.evict();

      expect(await cache.sizeInBytes(), 200);
    });
  });
}
