import '../../../common/database/app_database.dart';
import '../../../common/database/daos/artist.dao.dart';
import '../../../common/database/daos/scene.dao.dart';
import '../../../common/database/daos/track.dao.dart';
import '../../../common/errors/app_error.dart';
import '../../../common/errors/error_mapper.dart';
import '../domain/artist.entity.dart';
import '../domain/content.repository.dart';
import '../domain/scene.entity.dart';
import '../domain/track.entity.dart';
import 'artist.model.dart';
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
    required ArtistDao artistDao,
    DateTime Function()? now,
    this.patience = const Duration(seconds: 15),
    this.patienceWithCache = const Duration(seconds: 3),
  }) : _api = api,
       _trackDao = trackDao,
       _sceneDao = sceneDao,
       _artistDao = artistDao,
       _now = now ?? DateTime.now;

  final ContentApi _api;
  final TrackDao _trackDao;
  final SceneDao _sceneDao;
  final ArtistDao _artistDao;
  final DateTime Function() _now;

  /// How long a fetch may take when there is nothing to fall back on. A
  /// server that never answers would otherwise leave the room loading
  /// forever: the client sets no deadline of its own.
  final Duration patience;

  /// How long a fetch may take when the last one is on disk. Short, because
  /// the room is already there to open; a fetch that runs over still lands
  /// in the cache for the next start, it just is not waited for.
  final Duration patienceWithCache;

  @override
  Future<List<SceneEntity>> getScenes() async {
    final bool cachedBefore = await _has(_sceneDao.getScenes);
    final AppError? failure = await _refresh(cached: cachedBefore, () async {
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
    final bool cachedBefore = await _has(_trackDao.getTracks);
    // The artists come along so every track can show who made it. Their
    // fetch failing costs the names, never the music.
    final (AppError? failure, _) = await (
      _refresh(cached: cachedBefore, () async {
        final List<TrackModel> models = await _api.fetchTracks();
        final DateTime now = _now();

        await _trackDao.replaceTracks(<TrackTableCompanion>[
          for (final TrackModel model in models)
            model.toEntity().toCompanion(now: now),
        ]);
      }),
      _refresh(cached: cachedBefore, _refreshArtists),
    ).wait;

    final List<TrackEntity> cached = await _read(() async {
      final Map<String, String> names = await _artistNames();
      return (await _trackDao.getTracks())
          .map(
            (TrackTableData row) => row.toEntity(artist: names[row.artistId]),
          )
          .toList();
    });

    if (cached.isEmpty && failure != null) throw failure;

    return cached;
  }

  @override
  Future<List<ArtistEntity>> getArtists() async {
    final bool cachedBefore = await _has(_artistDao.getArtists);
    final AppError? failure = await _refresh(
      cached: cachedBefore,
      _refreshArtists,
    );

    final List<ArtistEntity> cached = await _read(
      () async => (await _artistDao.getArtists())
          .map((ArtistTableData row) => row.toEntity())
          .toList(),
    );

    if (cached.isEmpty && failure != null) throw failure;

    return cached;
  }

  Future<void> _refreshArtists() async {
    final List<ArtistModel> models = await _api.fetchArtists();
    final DateTime now = _now();

    await _artistDao.replaceArtists(<ArtistTableCompanion>[
      for (final ArtistModel model in models)
        model.toEntity().toCompanion(now: now),
    ]);
  }

  /// Each cached artist's name by id. A broken table is no names.
  Future<Map<String, String>> _artistNames() async {
    try {
      return <String, String>{
        for (final ArtistTableData row in await _artistDao.getArtists())
          row.id: row.name,
      };
    } on Object {
      return const <String, String>{};
    }
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

    return row?.toEntity(artist: (await _artistNames())[row.artistId]);
  }

  /// Runs a fetch-and-cache, and hands back what went wrong instead of
  /// throwing — the caller decides whether the cache makes it survivable.
  Future<AppError?> _refresh(
    Future<void> Function() body, {
    bool cached = false,
  }) async {
    try {
      await body().timeout(cached ? patienceWithCache : patience);
      return null;
    } on Object catch (error, stackTrace) {
      return ErrorMapper.fromException(error, stackTrace);
    }
  }

  /// Whether the cache holds anything yet. A broken database counts as
  /// empty: the fetch then gets its full time.
  Future<bool> _has(Future<List<Object>> Function() read) async {
    try {
      return (await read()).isNotEmpty;
    } on Object {
      return false;
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
