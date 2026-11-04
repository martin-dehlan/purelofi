import 'dart:convert';

import 'package:drift/drift.dart' show Value;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../common/database/app_database.dart';
import '../../../common/database/daos/mood.dao.dart';
import '../domain/mood.entity.dart';

/// Moods from Supabase (#141), with the last copy in Drift for offline: the
/// server when it answers, the copy when it does not.
class MoodRepositoryImpl implements MoodRepository {
  MoodRepositoryImpl({required SupabaseClient client, required MoodDao dao})
    : _client = client,
      _dao = dao;

  final SupabaseClient _client;
  final MoodDao _dao;

  @override
  Future<List<MoodEntity>> getMoods() async {
    try {
      final List<Map<String, dynamic>> rows = await _client
          .from('moods')
          .select(
            'id, slug, title, cover_url, sort_order, mood_tracks(track_id, position)',
          )
          .eq('is_active', true)
          .order('sort_order');
      final List<MoodEntity> moods = rows.map(fromRow).toList();
      await _dao.replaceAll(<MoodTableCompanion>[
        for (int i = 0; i < moods.length; i++)
          MoodTableCompanion(
            id: Value<String>(moods[i].id),
            slug: Value<String>(moods[i].slug),
            title: Value<String>(moods[i].title),
            coverUrl: Value<String?>(moods[i].coverUrl),
            sortOrder: Value<int>(i),
            trackIds: Value<String>(jsonEncode(moods[i].trackIds)),
          ),
      ]);
      return moods;
    } on Object {
      final List<MoodTableData> cached = await _dao.getAll();
      if (cached.isEmpty) rethrow;
      return <MoodEntity>[
        for (final MoodTableData row in cached)
          MoodEntity(
            id: row.id,
            slug: row.slug,
            title: row.title,
            coverUrl: row.coverUrl,
            trackIds: <String>[
              for (final Object? id
                  in jsonDecode(row.trackIds) as List<Object?>)
                if (id is String) id,
            ],
          ),
      ];
    }
  }

  /// One row with its `mood_tracks` embedded, the tracks in position order.
  static MoodEntity fromRow(Map<String, dynamic> row) {
    final List<Map<String, dynamic>> tracks =
        <Map<String, dynamic>>[
          for (final Object? t
              in (row['mood_tracks'] as List<Object?>?) ?? <Object?>[])
            if (t is Map<String, dynamic>) t,
        ]..sort(
          (Map<String, dynamic> a, Map<String, dynamic> b) =>
              ((a['position'] as num?) ?? 0).compareTo(
                (b['position'] as num?) ?? 0,
              ),
        );

    return MoodEntity(
      id: row['id'] as String,
      slug: row['slug'] as String,
      title: row['title'] as String,
      coverUrl: row['cover_url'] as String?,
      trackIds: <String>[
        for (final Map<String, dynamic> t in tracks) t['track_id'] as String,
      ],
    );
  }
}
