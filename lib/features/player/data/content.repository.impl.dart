import '../../../common/errors/error_mapper.dart';
import '../domain/content.repository.dart';
import '../domain/scene.entity.dart';
import '../domain/track.entity.dart';
import 'content.api.dart';
import 'scene.model.dart';
import 'track.model.dart';

/// Thin Supabase reader: fetch rows, map to entities, translate failures.
///
/// Phase 2 adds the local-first Drift flow here (see `docs/01`, `docs/04`).
class ContentRepositoryImpl implements ContentRepository {
  const ContentRepositoryImpl({required ContentApi api}) : _api = api;

  final ContentApi _api;

  @override
  Future<List<SceneEntity>> getScenes() async {
    try {
      final List<SceneModel> models = await _api.fetchScenes();
      return models.map((SceneModel model) => model.toEntity()).toList();
    } on Object catch (error, stackTrace) {
      throw ErrorMapper.fromException(error, stackTrace);
    }
  }

  @override
  Future<List<TrackEntity>> getTracks() async {
    try {
      final List<TrackModel> models = await _api.fetchTracks();
      return models.map((TrackModel model) => model.toEntity()).toList();
    } on Object catch (error, stackTrace) {
      throw ErrorMapper.fromException(error, stackTrace);
    }
  }

  @override
  Future<TrackEntity?> getTrackById(String id) async {
    try {
      final TrackModel? model = await _api.fetchTrackById(id);
      return model?.toEntity();
    } on Object catch (error, stackTrace) {
      throw ErrorMapper.fromException(error, stackTrace);
    }
  }
}
