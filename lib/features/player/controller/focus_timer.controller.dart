import 'dart:async';
import 'dart:ui';

import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../common/analytics/analytics.provider.dart';
import '../../../common/analytics/analytics.service.dart';
import '../../../l10n/app_localizations.dart';
import '../domain/audio_player.service.dart';
import '../domain/focus_notifier.service.dart';
import '../domain/focus_session.dart';
import '../domain/volume_fader.dart';
import '../domain/volume_layer.dart';
import 'language.controller.dart';
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

  FocusNotifier get _notifier => ref.read(focusNoticeProvider);

  VolumeFader get _volume => _fader ??= VolumeFader(
    (double level) => _audio.setVolumeLayer(VolumeLayer.focusBreak, level),
  );

  /// Starts a first focus stretch with [plan], replacing any session before.
  void start(FocusPlan plan) {
    _timer?.cancel();
    _volume.jumpTo(1);
    _enter(FocusSession.start(plan, DateTime.now()));
    // Asked now, when the listener sees why: the switches will notify.
    unawaited(_notifier.prepare());
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
    unawaited(_notifier.clear());
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
    unawaited(_notifier.announce(_notice(next)));
    _volume.fadeTo(next.phase == FocusPhase.rest ? restLevel : 1, stepLength);
    _enter(next);
  }

  /// "Break · 5 min" or "Back to focus · 25 min", in the app's language:
  /// the one picked in the settings, else the phone's.
  String _notice(FocusSession next) {
    final String code =
        ref.read(languageControllerProvider).value ??
        PlatformDispatcher.instance.locale.languageCode;
    AppLocalizations l10n;
    try {
      l10n = lookupAppLocalizations(Locale(code));
    } on Object {
      l10n = lookupAppLocalizations(const Locale('en'));
    }
    final int minutes = next.plan.lengthOf(next.phase).inMinutes;

    return next.phase == FocusPhase.rest
        ? l10n.focusBreakNotice(minutes)
        : l10n.focusBackNotice(minutes);
  }
}
