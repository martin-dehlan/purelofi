import 'artist.entity.dart';
import 'scene.entity.dart';
import 'track.entity.dart';

/// Reads the player's content. Read-only in the MVP — Supabase is the source
/// of truth and the app never writes to it.
///
/// Implementations throw `AppError` and nothing else.
abstract class ContentRepository {
  /// Active scenes, ordered by `sort_order`.
  ///
  /// With [cachedOnly], what is on the device, without asking Supabase; so
  /// for the getters below.
  Future<List<SceneEntity>> getScenes({bool cachedOnly = false});

  /// Active tracks, each with its artist's name where it has one.
  Future<List<TrackEntity>> getTracks({bool cachedOnly = false});

  /// Active artists, by name.
  Future<List<ArtistEntity>> getArtists({bool cachedOnly = false});

  /// Fires when a fetch that was not waited for has landed in the cache
  /// after all. What the getters handed out before is out of date then;
  /// read again with `cachedOnly`, and the network is not asked twice.
  Stream<void> get updates;

  /// A single track, or `null` when no active track has that id.
  Future<TrackEntity?> getTrackById(String id);
}
