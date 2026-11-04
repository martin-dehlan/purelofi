import '../domain/ambient_sound.entity.dart';

/// A row of `scene_ambients` with its `ambient_sounds` embedded, as
/// PostgREST returns it inside a scene (#136).
///
/// Hand-written rather than generated: the shape is two levels deep and a
/// sound hidden by row-level security comes back as `null`, which simply
/// drops the row.
abstract final class AmbientSoundModel {
  static List<AmbientSoundEntity> listFrom(Object? json) {
    if (json is! List) return const <AmbientSoundEntity>[];

    final List<(int, AmbientSoundEntity)> sounds =
        <(int, AmbientSoundEntity)>[
          for (final Object? row in json)
            if (row is Map<String, dynamic>)
              if (row['ambient_sounds'] case final Map<String, dynamic> sound)
                (
                  (sound['sort_order'] as num?)?.toInt() ?? 0,
                  AmbientSoundEntity(
                    id: sound['id'] as String,
                    slug: sound['slug'] as String,
                    title: sound['title'] as String,
                    audioUrl: sound['audio_url'] as String,
                    defaultLevel:
                        ((row['default_level'] as num?)?.toDouble() ?? 0.5)
                            .clamp(0.0, 1.0),
                  ),
                ),
        ]..sort(
          ((int, AmbientSoundEntity) a, (int, AmbientSoundEntity) b) =>
              a.$1.compareTo(b.$1),
        );

    return <AmbientSoundEntity>[
      for (final (int, AmbientSoundEntity) s in sounds) s.$2,
    ];
  }

  /// For the cache: the sounds as JSON text in one column of `scenes`.
  static List<Map<String, Object>> toCache(List<AmbientSoundEntity> sounds) =>
      <Map<String, Object>>[
        for (final AmbientSoundEntity s in sounds)
          <String, Object>{
            'id': s.id,
            'slug': s.slug,
            'title': s.title,
            'audio_url': s.audioUrl,
            'default_level': s.defaultLevel,
          },
      ];

  static List<AmbientSoundEntity> fromCache(Object? json) {
    if (json is! List) return const <AmbientSoundEntity>[];

    return <AmbientSoundEntity>[
      for (final Object? row in json)
        if (row is Map<String, dynamic>)
          AmbientSoundEntity(
            id: row['id'] as String,
            slug: row['slug'] as String,
            title: row['title'] as String,
            audioUrl: row['audio_url'] as String,
            defaultLevel: (row['default_level'] as num?)?.toDouble() ?? 0.5,
          ),
    ];
  }
}
