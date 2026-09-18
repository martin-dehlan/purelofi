import 'package:supabase_flutter/supabase_flutter.dart';

import 'scene.model.dart';
import 'track.model.dart';

/// Supabase queries for the player's content. Selects only; the MVP never
/// writes. Inactive rows are filtered out server-side.
class ContentApi {
  const ContentApi(this._client);

  static const String scenesTable = 'scenes';
  static const String tracksTable = 'tracks';

  final SupabaseClient _client;

  Future<List<SceneModel>> fetchScenes() async {
    final List<Map<String, dynamic>> rows = await _client
        .from(scenesTable)
        .select()
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
