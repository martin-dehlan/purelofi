import 'dart:async';

import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../common/analytics/analytics.provider.dart';
import '../../../common/analytics/analytics.service.dart';
import '../domain/audio_player.service.dart';
import '../domain/focus_session.dart';
import '../domain/volume_fader.dart';
import '../domain/volume_layer.dart';
import 'player.provider.dart';

part 'focus_timer.controller.g.dart';

/// The focus timer (#137): stretches of work and short breaks, round after
/// round, until the listener turns it off. `null` while it is off.
///
/// The music keeps playing throughout. A chime marks each switch, and
/// during a break the music steps back to [restLevel], so the switch is
/// heard even with the phone face down. Like the sleep timer it holds a
/// moment, not a countdown, and lives as long as the app does — the audio
/// service keeps the app alive while the music plays, screen off or not.
@Riverpod(keepAlive: true)
class FocusTimerController extends _$FocusTimerController {
  Timer? _timer;
  VolumeFader? _fader;

  /// How loud the music is during a break.
  static const double restLevel = 0.4;

  /// How long the music takes to step back or come forward again.
  static const Duration stepLength = Duration(seconds: 3);

  @override
  FocusSession? build() {
    ref.onDispose(() {
      _timer?.cancel();
      _fader?.cancel();
    });
    return null;
  }

  AudioPlayerService get _audio => ref.read(audioPlayerServiceProvider);

  VolumeFader get _volume => _fader ??= VolumeFader(
    (double level) => _audio.setVolumeLayer(VolumeLayer.focusBreak, level),
  );

  /// Starts a first focus stretch with [plan], replacing any session before.
  void start(FocusPlan plan) {
    _timer?.cancel();
    _volume.jumpTo(1);
    _enter(FocusSession.start(plan, DateTime.now()));
    unawaited(
      ref.read(analyticsServiceProvider).capture(
        AnalyticsEvents.focusStarted,
        <String, Object>{
          'focus_minutes': plan.focus.inMinutes,
          'rest_minutes': plan.rest.inMinutes,
        },
      ),
    );
  }

  /// Turns the timer off; the music is at full volume again at once.
  void stop() {
    _timer?.cancel();
    _timer = null;
    if (_fader != null) _volume.jumpTo(1);
    state = null;
  }

  void _enter(FocusSession session) {
    state = session;
    _timer = Timer(session.endsAt.difference(DateTime.now()), _switch);
  }

  void _switch() {
    final FocusSession? session = state;
    if (session == null) return;

    final FocusSession next = session.next(DateTime.now());
    unawaited(_audio.playChime());
    _volume.fadeTo(next.phase == FocusPhase.rest ? restLevel : 1, stepLength);
    _enter(next);
  }
}
