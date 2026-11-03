import 'artist.entity.dart';
import 'scene.entity.dart';
import 'track.entity.dart';

/// Reads the player's content. Read-only in the MVP — Supabase is the source
/// of truth and the app never writes to it.
///
/// Implementations throw `AppError` and nothing else.
abstract class ContentRepository {
  /// Active scenes, ordered by `sort_order`.
  Future<List<SceneEntity>> getScenes();

  /// Active tracks, each with its artist's name where it has one.
  Future<List<TrackEntity>> getTracks();

  /// Active artists, by name.
  Future<List<ArtistEntity>> getArtists();

  /// A single track, or `null` when no active track has that id.
  Future<TrackEntity?> getTrackById(String id);
}
