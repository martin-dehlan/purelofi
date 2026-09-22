import 'package:freezed_annotation/freezed_annotation.dart';

part 'scene_layer.entity.freezed.dart';

/// One sprite layer of a scene.
///
/// A layer is a horizontal strip of [frameCount] frames played at [fps].
/// Stacked by [zIndex], they make up the scene the listener sees.
@freezed
abstract class SceneLayerEntity with _$SceneLayerEntity {
  const factory SceneLayerEntity({
    required String id,
    required int zIndex,
    required String spriteUrl,
    @Default(1) int frameCount,
    @Default(0) double fps,
    @Default(0) int offsetX,
    @Default(0) int offsetY,

    /// How far this layer moves with the camera. 1.0 moves with it, 0.5 half
    /// as far — that difference is what reads as depth.
    @Default(1) double parallax,

    /// Repeats across the canvas instead of being placed once.
    @Default(false) bool tiles,

    /// Advances only while audio is playing: the tape reels stop with the
    /// music, the rain does not.
    @Default(false) bool onlyWhilePlaying,

    /// Not drawn at all while the audio is paused. This is how a scene
    /// lights up when playback starts.
    @Default(false) bool hideWhenPaused,

    /// Plays its reaction once when the listener taps it, then returns to
    /// its idle loop.
    @Default(false) bool tappable,

    /// How many frames at the start of the strip form the idle loop. The
    /// rest are the reaction. Zero means the layer simply rests on its first
    /// frame until tapped.
    @Default(0) int idleFrameCount,

    /// Plays its reaction once whenever a new track starts.
    @Default(false) bool onTrackChange,

    /// Set on both to make this a rare event instead of a loop.
    int? eventIntervalMinSeconds,
    int? eventIntervalMaxSeconds,
  }) = _SceneLayerEntity;

  const SceneLayerEntity._();

  /// Whether this layer animates at all.
  bool get isAnimated => frameCount > 1 && fps > 0;

  /// Whether this layer fires on an interval rather than looping.
  bool get isEvent =>
      eventIntervalMinSeconds != null && eventIntervalMaxSeconds != null;

  /// Whether this layer waits for something rather than animating on its own.
  bool get isTriggered => isEvent || tappable || onTrackChange;

  /// Whether this layer keeps moving while it waits to be touched.
  bool get hasIdleLoop => idleFrameCount > 1;

  /// How many frames the reaction runs for.
  int get reactionFrameCount => frameCount - idleFrameCount;
}
