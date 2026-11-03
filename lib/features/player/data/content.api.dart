import 'package:supabase_flutter/supabase_flutter.dart';

import 'artist.model.dart';
import 'scene.model.dart';
import 'track.model.dart';

/// Supabase queries for the player's content. Selects only; the MVP never
/// writes. Inactive rows are filtered out server-side.
class ContentApi {
  const ContentApi(this._client);

  static const String scenesTable = 'scenes';
  static const String tracksTable = 'tracks';
  static const String layersTable = 'scene_layers';
  static const String artistsTable = 'artists';

  final SupabaseClient _client;

  Future<List<SceneModel>> fetchScenes() async {
    // Layers come back embedded, so a scene and its stack are one request.
    final List<Map<String, dynamic>> rows = await _client
        .from(scenesTable)
        .select('*, $layersTable(*)')
        .eq('is_active', true)
        .order('sort_order');

    return rows.map(SceneModel.fromJson).toList();
  }

  Future<List<TrackModel>> fetchTracks() async {
    final List<Map<String, dynamic>> rows = await _client
        .from(tracksTable)
        .select()
        .eq('is_active', true)
        .order('created_at');

    return rows.map(TrackModel.fromJson).toList();
  }

  Future<List<ArtistModel>> fetchArtists() async {
    final List<Map<String, dynamic>> rows = await _client
        .from(artistsTable)
        .select()
        .eq('is_active', true)
        .order('name');

    return rows.map(ArtistModel.fromJson).toList();
  }

  Future<TrackModel?> fetchTrackById(String id) async {
    final Map<String, dynamic>? row = await _client
        .from(tracksTable)
        .select()
        .eq('id', id)
        .eq('is_active', true)
        .maybeSingle();

    return row == null ? null : TrackModel.fromJson(row);
  }
}
