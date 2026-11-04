import 'package:freezed_annotation/freezed_annotation.dart';

import 'track.entity.dart';

part 'play_event.entity.freezed.dart';

/// One time a track was listened to (#142).
@freezed
abstract class PlayEventEntity with _$PlayEventEntity {
  const factory PlayEventEntity({
    required int id,
    required String trackId,
    required TrackSource source,
    String? sceneId,
    required DateTime startedAt,
    required int listenedSeconds,
  }) = _PlayEventEntity;
}
