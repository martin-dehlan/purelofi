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
      (SceneLayerEntity layer) => layer.isEvent,
    )) {
      _layers[layer.id] = layer;
      _nextFireAt[layer.id] = _pickNextFire(layer, from: Duration.zero);
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
        // again just because its slot passed while it was playing.
        _nextFireAt[running] = _pickNextFire(layer, from: elapsed);
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

  /// Which frame [layer] shows at [elapsed]: its first while it waits, and
  /// the animation while it plays.
  int frameFor(SceneLayerEntity layer, Duration elapsed) {
    if (!layer.isEvent || _runningId != layer.id) return 0;

    final int frame =
        ((elapsed - _runningSince).inMilliseconds * layer.fps / 1000).floor();

    return frame.clamp(0, layer.frameCount - 1);
  }

  /// How long one pass of the animation takes.
  Duration _durationOf(SceneLayerEntity layer) {
    if (layer.fps <= 0) return Duration.zero;

    return Duration(
      milliseconds: (layer.frameCount / layer.fps * 1000).round(),
    );
  }

  Duration _pickNextFire(SceneLayerEntity layer, {required Duration from}) {
    final int min = layer.eventIntervalMinSeconds ?? 60;
    final int max = layer.eventIntervalMaxSeconds ?? min;
    final int spread = (max - min).clamp(0, 24 * 60 * 60);

    return from + Duration(seconds: min + _random.nextInt(spread + 1));
  }
}
