import '../../../common/database/app_database.dart';
import '../../../common/database/daos/scene.dao.dart';
import '../../../common/database/daos/track.dao.dart';
import '../../../common/errors/app_error.dart';
import '../../../common/errors/error_mapper.dart';
import '../domain/content.repository.dart';
import '../domain/scene.entity.dart';
import '../domain/track.entity.dart';
import 'content.api.dart';
import 'content_cache.mapper.dart';
import 'scene.model.dart';
import 'track.model.dart';

/// Local-first content: fetch from Supabase, write to the cache, serve from
/// the cache (`docs/04`).
///
/// Supabase stays the source of truth — the cache is never written to except
/// by a successful fetch. What the cache buys is a room that still opens on
/// a train: when the network fails and something was cached, the failure is
/// swallowed and the cached content is served. When nothing was cached there
/// is nothing to show, so the error is raised and the UI says so.
class ContentRepositoryImpl implements ContentRepository {
  const ContentRepositoryImpl({
    required ContentApi api,
    required TrackDao trackDao,
    required SceneDao sceneDao,
    DateTime Function()? now,
  }) : _api = api,
       _trackDao = trackDao,
       _sceneDao = sceneDao,
       _now = now ?? DateTime.now;

  final ContentApi _api;
  final TrackDao _trackDao;
  final SceneDao _sceneDao;
  final DateTime Function() _now;

  @override
  Future<List<SceneEntity>> getScenes() async {
    final AppError? failure = await _refresh(() async {
      final List<SceneModel> models = await _api.fetchScenes();
      final List<SceneEntity> scenes = models
          .map((SceneModel model) => model.toEntity())
          .toList();

      final DateTime now = _now();
      await _sceneDao.replaceScenes(
        <SceneTableCompanion>[
          for (final SceneEntity scene in scenes) scene.toCompanion(now: now),
        ],
        <SceneLayerTableCompanion>[
          for (final SceneEntity scene in scenes)
            ...scene.toLayerCompanions(now: now),
        ],
      );
    });

    final List<SceneEntity> cached = await _read(
      () async => (await _sceneDao.getScenes())
          .map((CachedScene row) => row.toEntity())
          .toList(),
    );

    if (cached.isEmpty && failure != null) throw failure;

    return cached;
  }

  @override
  Future<List<TrackEntity>> getTracks() async {
    final AppError? failure = await _refresh(() async {
      final List<TrackModel> models = await _api.fetchTracks();
      final DateTime now = _now();

      await _trackDao.replaceTracks(<TrackTableCompanion>[
        for (final TrackModel model in models)
          model.toEntity().toCompanion(now: now),
      ]);
    });

    final List<TrackEntity> cached = await _read(
      () async => (await _trackDao.getTracks())
          .map((TrackTableData row) => row.toEntity())
          .toList(),
    );

    if (cached.isEmpty && failure != null) throw failure;

    return cached;
  }

  @override
  Future<TrackEntity?> getTrackById(String id) async {
    final AppError? failure = await _refresh(() async {
      final TrackModel? model = await _api.fetchTrackById(id);
      if (model == null) return;

      await _trackDao.replaceTracks(<TrackTableCompanion>[
        ...(await _trackDao.getTracks()).map(
          (TrackTableData row) =>
              row.toEntity().toCompanion(now: row.updatedAt),
        ),
        model.toEntity().toCompanion(now: _now()),
      ]);
    });

    final TrackTableData? row = await _read(() => _trackDao.getTrackById(id));

    if (row == null && failure != null) throw failure;

    return row?.toEntity();
  }

  /// Runs a fetch-and-cache, and hands back what went wrong instead of
  /// throwing — the caller decides whether the cache makes it survivable.
  Future<AppError?> _refresh(Future<void> Function() body) async {
    try {
      await body();
      return null;
    } on Object catch (error, stackTrace) {
      return ErrorMapper.fromException(error, stackTrace);
    }
  }

  /// A cache read. A broken local database is not something the listener can
  /// act on, so it is mapped like any other failure rather than crashing.
  Future<T> _read<T>(Future<T> Function() body) async {
    try {
      return await body();
    } on Object catch (error, stackTrace) {
      throw ErrorMapper.fromException(error, stackTrace);
    }
  }
}
