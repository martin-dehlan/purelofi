import 'package:freezed_annotation/freezed_annotation.dart';

part 'ambient_sound.entity.freezed.dart';

/// A loop a room can bring along: rain on the window, the fire, the train
/// (#136). Real recordings, never generated.
@freezed
abstract class AmbientSoundEntity with _$AmbientSoundEntity {
  const factory AmbientSoundEntity({
    required String id,
    required String slug,
    required String title,
    required String audioUrl,

    /// How loud the room starts it, 0 to 1, before the listener's own mix.
    @Default(0.5) double defaultLevel,
  }) = _AmbientSoundEntity;
}
