import 'package:drift/drift.dart' show Value;

import '../../../common/database/app_database.dart';
import '../../../common/database/daos/play_event.dao.dart';
import '../domain/play_event.entity.dart';
import '../domain/play_history.repository.dart';
import '../domain/track.entity.dart';

/// The listening log in Drift (#142).
class PlayHistoryRepositoryImpl implements PlayHistoryRepository {
  PlayHistoryRepositoryImpl(this._dao);

  final PlayEventDao _dao;

  /// What the log keeps: three months, and never more than this many rows.
  static const Duration keepFor = Duration(days: 90);
  static const int keepRows = 5000;

  @override
  Future<int> record({
    required String trackId,
    required TrackSource source,
    String? sceneId,
    required DateTime startedAt,
    required int listenedSeconds,
  }) => _dao.add(
    PlayEventTableCompanion.insert(
      trackId: trackId,
      source: source.name,
      sceneId: Value<String?>(sceneId),
      startedAt: startedAt,
      listenedSeconds: listenedSeconds,
    ),
  );

  @override
  Future<void> updateListened(int id, int seconds) =>
      _dao.setListened(id, seconds);

  @override
  Stream<List<PlayEventEntity>> watchNewest({int limit = 200}) => _dao
      .watchNewest(limit)
      .map((List<PlayEventTableData> rows) => rows.map(_toEntity).toList());

  @override
  Future<List<PlayEventEntity>> between(DateTime from, DateTime to) async =>
      (await _dao.between(from, to)).map(_toEntity).toList();

  @override
  Future<void> prune({required DateTime now}) =>
      _dao.prune(before: now.subtract(keepFor), keep: keepRows);

  @override
  Future<void> clear() => _dao.clear();

  static PlayEventEntity _toEntity(PlayEventTableData row) => PlayEventEntity(
    id: row.id,
    trackId: row.trackId,
    source: row.source == TrackSource.local.name
        ? TrackSource.local
        : TrackSource.catalogue,
    sceneId: row.sceneId,
    startedAt: row.startedAt,
    listenedSeconds: row.listenedSeconds,
  );
}
