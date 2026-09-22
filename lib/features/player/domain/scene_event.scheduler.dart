import 'dart:math';

import 'scene_layer.entity.dart';

/// Decides when a rare event layer fires.
///
/// A car sweeping its headlights across the wall every minute or so is what
/// keeps a scene from settling into a pattern. Looping it would defeat the
/// point, so these layers rest on their first frame, play once when their
/// turn comes, and then wait again for a random stretch.
///
/// Pure Dart and driven by an injected clock, so the timing can be tested
/// without waiting minutes for it.
class SceneEventScheduler {
  SceneEventScheduler({
    required Iterable<SceneLayerEntity> layers,
    Random? random,
  }) : _random = random ?? Random() {
    for (final SceneLayerEntity layer in layers.where(
      (SceneLayerEntity layer) => layer.isTriggered,
    )) {
      _layers[layer.id] = layer;
      // Tappable layers wait for a finger; timed ones schedule themselves.
      if (layer.isEvent) {
        _nextFireAt[layer.id] = _pickNextFire(layer, from: Duration.zero);
      }
    }
  }

  final Random _random;
  final Map<String, SceneLayerEntity> _layers = <String, SceneLayerEntity>{};
  final Map<String, Duration> _nextFireAt = <String, Duration>{};

  String? _runningId;
  Duration _runningSince = Duration.zero;

  /// The event playing right now, if any.
  String? get runningLayerId => _runningId;

  /// Moves the schedule to [elapsed]: starts what is due, ends what is over.
  void update(Duration elapsed) {
    final String? running = _runningId;

    if (running != null) {
      final SceneLayerEntity layer = _layers[running]!;
      if (elapsed - _runningSince >= _durationOf(layer)) {
        _runningId = null;
        // Measured from the end, so a long event does not immediately fire
        // again just because its slot passed while it was playing. A tappable
        // layer simply waits for the next tap.
        if (layer.isEvent) {
          _nextFireAt[running] = _pickNextFire(layer, from: elapsed);
        }
      } else {
        // One event at a time — two at once reads as chaos, not life.
        return;
      }
    }

    for (final MapEntry<String, Duration> entry in _nextFireAt.entries) {
      if (elapsed >= entry.value) {
        _runningId = entry.key;
        _runningSince = elapsed;
        return;
      }
    }
  }

  /// Starts [layerId] now, unless something else is already playing.
  ///
  /// Returns whether it took: a second tap during a stretch is ignored rather
  /// than restarting it.
  bool trigger(String layerId, Duration elapsed) {
    if (_runningId != null) return false;
    if (!_layers.containsKey(layerId)) return false;

    _runningId = layerId;
    _runningSince = elapsed;

    return true;
  }

  /// Which frame [layer] shows at [elapsed].
  ///
  /// While it waits it loops its idle frames, if it has any; while it plays
  /// it runs through the reaction once and stops on its last frame.
  int frameFor(SceneLayerEntity layer, Duration elapsed) {
    if (!layer.isTriggered) return 0;

    if (_runningId != layer.id) {
      if (!layer.hasIdleLoop || layer.fps <= 0) return 0;

      final int frame = (elapsed.inMilliseconds * layer.fps / 1000).floor();

      return frame % layer.idleFrameCount;
    }

    final int into =
        ((elapsed - _runningSince).inMilliseconds * layer.fps / 1000).floor();

    return (layer.idleFrameCount + into).clamp(0, layer.frameCount - 1);
  }

  /// How long one pass of the reaction takes.
  ///
  /// Only the frames after the idle loop count: those are the reaction.
  Duration _durationOf(SceneLayerEntity layer) {
    if (layer.fps <= 0) return Duration.zero;

    return Duration(
      milliseconds: (layer.reactionFrameCount / layer.fps * 1000).round(),
    );
  }

  Duration _pickNextFire(SceneLayerEntity layer, {required Duration from}) {
    final int min = layer.eventIntervalMinSeconds ?? 60;
    final int max = layer.eventIntervalMaxSeconds ?? min;
    final int spread = (max - min).clamp(0, 24 * 60 * 60);

    return from + Duration(seconds: min + _random.nextInt(spread + 1));
  }
}
