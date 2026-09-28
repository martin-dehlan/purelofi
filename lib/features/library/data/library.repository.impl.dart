import 'dart:io';

import 'package:drift/drift.dart' show Value;
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

import '../../../common/database/app_database.dart';
import '../../../common/database/daos/local_track.dao.dart';
import '../../../common/errors/error_mapper.dart';
import '../../player/domain/track.entity.dart';
import '../domain/import_report.dart';
import '../domain/library.repository.dart';
import '../domain/tag_reader.service.dart';

/// The library on disk, with Drift as its index.
///
/// The files live in their own directory beside the media cache and never in
/// it: the cache evicts, and these are the only copy the app has (docs/04).
class LibraryRepositoryImpl implements LibraryRepository {
  LibraryRepositoryImpl({
    required LocalTrackDao dao,
    required Directory directory,
    required TagReader tags,
    String Function()? newId,
    DateTime Function()? now,
  }) : _dao = dao,
       _directory = directory,
       _tags = tags,
       _newId = newId ?? const Uuid().v4,
       _now = now ?? DateTime.now;

  /// What `just_audio` plays on both platforms. Anything else is turned away
  /// at the door, by name, rather than failing later mid-shuffle.
  static const Set<String> supportedExtensions = <String>{
    'mp3',
    'm4a',
    'aac',
    'wav',
    'flac',
  };

  final LocalTrackDao _dao;
  final Directory _directory;
  final TagReader _tags;
  final String Function() _newId;
  final DateTime Function() _now;

  static Future<Directory> defaultDirectory() async {
    final Directory support = await getApplicationSupportDirectory();

    return Directory('${support.path}/library');
  }

  @override
  Stream<List<TrackEntity>> watchTracks() => _dao.watchAll().map(
    (List<LocalTrackTableData> rows) => rows.map(_toEntity).toList(),
  );

  @override
  Future<List<TrackEntity>> getTracks() async {
    try {
      return (await _dao.getAll()).map(_toEntity).toList();
    } on Object catch (error, stackTrace) {
      throw ErrorMapper.fromException(error, stackTrace);
    }
  }

  @override
  Future<ImportReport> import(List<ImportSource> sources) async {
    await _directory.create(recursive: true);

    final List<TrackEntity> imported = <TrackEntity>[];
    final List<RejectedImport> rejected = <RejectedImport>[];

    for (final ImportSource source in sources) {
      final String extension = _extensionOf(source.name);
      if (!supportedExtensions.contains(extension)) {
        rejected.add(
          RejectedImport(
            name: source.name,
            reason: 'Not an audio format PureLofi can play.',
          ),
        );
        continue;
      }

      try {
        imported.add(await _importOne(source, extension));
      } on Object {
        rejected.add(
          RejectedImport(name: source.name, reason: 'Could not be copied.'),
        );
      }
    }

    return ImportReport(imported: imported, rejected: rejected);
  }

  Future<TrackEntity> _importOne(ImportSource source, String extension) async {
    final String id = _newId();
    final String fileName = '$id.$extension';
    final File file = _file(fileName);
    // Write beside, then rename: a copy the app died halfway through must
    // never be taken for a whole one.
    final File partial = File('${file.path}.part');
    File? cover;

    try {
      final IOSink sink = partial.openWrite();
      await sink.addStream(source.open());
      await sink.close();
      await partial.rename(file.path);

      final TrackTags tags = _tags.read(file);
      String? coverFileName;
      if (tags.cover != null) {
        coverFileName = '$id.cover.${_imageExtension(tags.coverMimeType)}';
        cover = _file(coverFileName);
        await cover.writeAsBytes(tags.cover!, flush: true);
      }

      final DateTime now = _now();
      final LocalTrackTableCompanion row = LocalTrackTableCompanion(
        id: Value<String>(id),
        title: Value<String>(tags.title ?? _titleFromName(source.name)),
        artist: Value<String?>(tags.artist),
        fileName: Value<String>(fileName),
        coverFileName: Value<String?>(coverFileName),
        durationSeconds: Value<int?>(tags.duration?.inSeconds),
        sizeBytes: Value<int>(await file.length()),
        createdAt: Value<DateTime>(now),
        updatedAt: Value<DateTime>(now),
      );
      await _dao.add(row);

      return _toEntity((await _dao.find(id))!);
    } on Object {
      // Leave nothing behind for a track that is not in the index.
      for (final File leftover in <File>[partial, file, ?cover]) {
        if (leftover.existsSync()) await leftover.delete();
      }
      rethrow;
    }
  }

  @override
  Future<void> delete(String id) async {
    try {
      final LocalTrackTableData? row = await _dao.find(id);
      if (row == null) return;

      await _dao.remove(id);
      for (final String? name in <String?>[row.fileName, row.coverFileName]) {
        if (name == null) continue;
        final File file = _file(name);
        if (file.existsSync()) await file.delete();
      }
    } on Object catch (error, stackTrace) {
      throw ErrorMapper.fromException(error, stackTrace);
    }
  }

  @override
  Future<int> sizeInBytes() => _dao.totalBytes();

  TrackEntity _toEntity(LocalTrackTableData row) => TrackEntity(
    id: row.id,
    title: row.title,
    artist: row.artist,
    audioUrl: Uri.file(_file(row.fileName).path).toString(),
    coverPath: row.coverFileName == null
        ? null
        : _file(row.coverFileName!).path,
    durationSeconds: row.durationSeconds,
    createdAt: row.createdAt,
    source: TrackSource.local,
  );

  /// Resolved against today's directory every time: the stored name is
  /// relative precisely because the absolute path moves.
  File _file(String name) => File('${_directory.path}/$name');

  static String _extensionOf(String name) {
    final int dot = name.lastIndexOf('.');
    return dot < 0 ? '' : name.substring(dot + 1).toLowerCase();
  }

  static String _titleFromName(String name) {
    final int dot = name.lastIndexOf('.');
    final String base = (dot <= 0 ? name : name.substring(0, dot)).trim();
    return base.isEmpty ? name : base;
  }

  static String _imageExtension(String? mimeType) =>
      mimeType == 'image/png' ? 'png' : 'jpg';
}
