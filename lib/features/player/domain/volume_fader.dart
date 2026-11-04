import 'dart:async';

/// Moves a level from where it is to a target, in small steps over time.
///
/// The sleep timer fades out with it (#138) and the focus timer steps the
/// music back for a break (#137). Steps are counted rather than timed by the
/// wall clock, so a fade takes as long under test as it does on a phone.
class VolumeFader {
  VolumeFader(this._apply, {this.step = const Duration(milliseconds: 100)});

  final Future<void> Function(double level) _apply;

  /// How often the level moves while fading.
  final Duration step;

  Timer? _ticker;
  double _level = 1;

  /// Where the level is now.
  double get level => _level;

  /// Whether a fade is under way.
  bool get isFading => _ticker != null;

  /// Fades to [target] over [over]. A fade already running stops where it
  /// is and this one carries on from there.
  void fadeTo(double target, Duration over) {
    cancel();
    final int steps = over.inMicroseconds ~/ step.inMicroseconds;
    if (steps <= 0) return jumpTo(target);

    final double from = _level;
    int done = 0;
    _ticker = Timer.periodic(step, (Timer timer) {
      done++;
      if (done >= steps) {
        timer.cancel();
        _ticker = null;
        _set(target);
        return;
      }
      _set(from + (target - from) * done / steps);
    });
  }

  /// Sets [target] at once, stopping any fade.
  void jumpTo(double target) {
    cancel();
    _set(target);
  }

  /// Stops a fade where it is.
  void cancel() {
    _ticker?.cancel();
    _ticker = null;
  }

  void _set(double level) {
    _level = level.clamp(0, 1).toDouble();
    unawaited(_apply(_level));
  }
}
