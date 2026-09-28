import 'dart:io';
import 'dart:typed_data';

import 'package:drift/drift.dart' show DatabaseConnection;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:purelofi/common/database/app_database.dart';
import 'package:purelofi/common/database/daos/local_track.dao.dart';
import 'package:purelofi/features/library/data/library.repository.impl.dart';
import 'package:purelofi/features/library/domain/import_report.dart';
import 'package:purelofi/features/library/domain/tag_reader.service.dart';
import 'package:purelofi/features/player/domain/track.entity.dart';

/// Tags by file extension of the copy, so a test says what a file "contains"
/// without real audio.
class FakeTagReader implements TagReader {
  FakeTagReader([this.tags = TrackTags.none]);

  TrackTags tags;

  @override
  TrackTags read(File file) => tags;
}

ImportSource source(String name, [List<int> bytes = const <int>[1, 2, 3]]) =>
    ImportSource(name: name, open: () => Stream<List<int>>.value(bytes));

void main() {
  late AppDatabase database;
  late Directory dir;
  late FakeTagReader tags;
  late LibraryRepositoryImpl library;
  int ids = 0;

  setUp(() async {
    database = AppDatabase.forTesting(
      DatabaseConnection(NativeDatabase.memory()),
    );
    addTearDown(database.close);
    dir = await Directory.systemTemp.createTemp('purelofi_library');
    addTearDown(() => dir.delete(recursive: true));
    tags = FakeTagReader();
    ids = 0;
    library = LibraryRepositoryImpl(
      dao: LocalTrackDao(database),
      directory: Directory('${dir.path}/library'),
      tags: tags,
      newId: () => 'id${ids++}',
      now: () => DateTime.utc(2026, 9, 28, 12, ids),
    );
  });

  /// Everything in the library directory, by name.
  List<String> filesOnDisk() =>
      Directory('${dir.path}/library')
          .listSync()
          .map((FileSystemEntity e) => e.uri.pathSegments.last)
          .toList()
        ..sort();

  test('copies the file in and plays it from there', () async {
    final ImportReport report = await library.import(<ImportSource>[
      source('Late Tape.mp3', <int>[9, 8, 7]),
    ]);

    expect(report.rejected, isEmpty);
    final TrackEntity track = report.imported.single;
    expect(track.source, TrackSource.local);
    expect(track.title, 'Late Tape', reason: 'no tags: the file name');
    expect(Uri.parse(track.audioUrl).scheme, 'file');
    expect(File.fromUri(Uri.parse(track.audioUrl)).readAsBytesSync(), <int>[
      9,
      8,
      7,
    ]);
    expect(filesOnDisk(), <String>['id0.mp3']);
  });

  test('the tags win over the file name', () async {
    tags.tags = const TrackTags(
      title: 'Slow Bass',
      artist: 'Somebody',
      duration: Duration(seconds: 168),
    );

    final TrackEntity track = (await library.import(<ImportSource>[
      source('track01.m4a'),
    ])).imported.single;

    expect(track.title, 'Slow Bass');
    expect(track.artist, 'Somebody');
    expect(track.durationSeconds, 168);
  });

  test('an embedded cover is kept beside the file', () async {
    tags.tags = TrackTags(
      cover: Uint8List.fromList(<int>[1, 1, 1]),
      coverMimeType: 'image/png',
    );

    final TrackEntity track = (await library.import(<ImportSource>[
      source('a.flac'),
    ])).imported.single;

    expect(track.coverPath, endsWith('id0.cover.png'));
    expect(File(track.coverPath!).existsSync(), isTrue);
  });

  test('a file it cannot play is turned away, the rest arrive', () async {
    final ImportReport report = await library.import(<ImportSource>[
      source('notes.pdf'),
      source('good.wav'),
    ]);

    expect(report.imported.map((TrackEntity t) => t.title), <String>['good']);
    expect(report.rejected.single.name, 'notes.pdf');
    expect(report.rejected.single.reason, contains('audio format'));
    expect(filesOnDisk(), <String>['id0.wav']);
  });

  test('a copy that fails half way leaves nothing behind', () async {
    final ImportReport report = await library.import(<ImportSource>[
      ImportSource(
        name: 'broken.mp3',
        open: () async* {
          yield <int>[1, 2];
          throw const FileSystemException('gone');
        },
      ),
    ]);

    expect(report.imported, isEmpty);
    expect(report.rejected.single.name, 'broken.mp3');
    expect(filesOnDisk(), isEmpty, reason: 'no .part, no half file');
    expect(await library.getTracks(), isEmpty);
  });

  test('deleting removes the row, the file and the cover', () async {
    tags.tags = TrackTags(
      cover: Uint8List.fromList(<int>[1]),
      coverMimeType: 'image/jpeg',
    );
    final TrackEntity track = (await library.import(<ImportSource>[
      source('a.mp3'),
    ])).imported.single;
    expect(filesOnDisk(), hasLength(2));

    await library.delete(track.id);

    expect(await library.getTracks(), isEmpty);
    expect(filesOnDisk(), isEmpty);
  });

  test('knows what the copies cost', () async {
    await library.import(<ImportSource>[
      source('a.mp3', List<int>.filled(1000, 0)),
      source('b.mp3', List<int>.filled(500, 0)),
    ]);

    expect(await library.sizeInBytes(), 1500);
  });

  test(
    'the stored path is relative, so a moved sandbox still finds it',
    () async {
      await library.import(<ImportSource>[source('a.mp3')]);

      final LocalTrackTableData row = (await LocalTrackDao(
        database,
      ).getAll()).single;
      expect(row.fileName, 'id0.mp3');
      expect(row.fileName, isNot(contains('/')));
    },
  );
}
