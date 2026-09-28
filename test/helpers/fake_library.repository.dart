import 'dart:async';

import 'package:purelofi/features/library/domain/import_report.dart';
import 'package:purelofi/features/library/domain/library.repository.dart';
import 'package:purelofi/features/player/domain/track.entity.dart';

/// The listener's library in memory, so no test opens a database or a disk.
class FakeLibraryRepository implements LibraryRepository {
  FakeLibraryRepository([List<TrackEntity> tracks = const <TrackEntity>[]])
    : _tracks = List<TrackEntity>.of(tracks);

  final List<TrackEntity> _tracks;
  final StreamController<List<TrackEntity>> _changes =
      StreamController<List<TrackEntity>>.broadcast();

  /// What the next import reports as turned away, by file name.
  final Set<String> refuse = <String>{};
  final List<String> deleted = <String>[];

  @override
  Stream<List<TrackEntity>> watchTracks() async* {
    yield List<TrackEntity>.unmodifiable(_tracks);
    yield* _changes.stream;
  }

  @override
  Future<List<TrackEntity>> getTracks() async =>
      List<TrackEntity>.unmodifiable(_tracks);

  @override
  Future<ImportReport> import(List<ImportSource> sources) async {
    final List<TrackEntity> imported = <TrackEntity>[];
    final List<RejectedImport> rejected = <RejectedImport>[];
    for (final ImportSource source in sources) {
      if (refuse.contains(source.name)) {
        rejected.add(RejectedImport(name: source.name, reason: 'Refused.'));
        continue;
      }
      imported.add(makeLocalTrack(source.name, title: source.name));
    }
    _tracks.insertAll(0, imported);
    _changes.add(List<TrackEntity>.unmodifiable(_tracks));
    return ImportReport(imported: imported, rejected: rejected);
  }

  @override
  Future<void> delete(String id) async {
    deleted.add(id);
    _tracks.removeWhere((TrackEntity t) => t.id == id);
    _changes.add(List<TrackEntity>.unmodifiable(_tracks));
  }

  @override
  Future<int> sizeInBytes() async => _tracks.length * 1000;

  Future<void> dispose() => _changes.close();
}

/// One of the listener's own tracks.
TrackEntity makeLocalTrack(
  String id, {
  String title = 'Kitchen Demo',
  String? artist,
}) => TrackEntity(
  id: id,
  title: title,
  artist: artist,
  audioUrl: Uri.file('/library/$id.mp3').toString(),
  createdAt: DateTime.utc(2026, 9, 28),
  source: TrackSource.local,
);
