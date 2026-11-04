import 'package:freezed_annotation/freezed_annotation.dart';

part 'focus_session.freezed.dart';

/// The two halves of a focus cycle (#137).
enum FocusPhase {
  /// Working: the music plays as it always does.
  focus,

  /// A break: the music steps back so the switch is heard.
  rest;

  /// What comes after this half.
  FocusPhase get following => this == focus ? rest : focus;
}

/// How long each half of a cycle lasts.
@freezed
abstract class FocusPlan with _$FocusPlan {
  const factory FocusPlan({required Duration focus, required Duration rest}) =
      _FocusPlan;

  const FocusPlan._();

  /// The classic Pomodoro: 25 minutes on, 5 off.
  static const FocusPlan classic = FocusPlan(
    focus: Duration(minutes: 25),
    rest: Duration(minutes: 5),
  );

  /// For longer stretches of deep work: 50 on, 10 off.
  static const FocusPlan deep = FocusPlan(
    focus: Duration(minutes: 50),
    rest: Duration(minutes: 10),
  );

  /// The plans the room page offers, in order.
  static const List<FocusPlan> offered = <FocusPlan>[classic, deep];

  Duration lengthOf(FocusPhase phase) => switch (phase) {
    FocusPhase.focus => focus,
    FocusPhase.rest => rest,
  };

  /// "25 / 5", as on the chip.
  String get label => '${focus.inMinutes} / ${rest.inMinutes}';
}

/// A focus timer that is running: which half, until when, which round.
///
/// A moment rather than a countdown, like the sleep timer: "Focus until
/// 14:25" needs no ticking.
@freezed
abstract class FocusSession with _$FocusSession {
  const factory FocusSession({
    required FocusPlan plan,
    required FocusPhase phase,
    required DateTime endsAt,

    /// Which focus stretch this is, from 1. A break belongs to the round
    /// before it.
    @Default(1) int round,
  }) = _FocusSession;

  const FocusSession._();

  /// The session just begun with [plan] at [now].
  factory FocusSession.start(FocusPlan plan, DateTime now) => FocusSession(
    plan: plan,
    phase: FocusPhase.focus,
    endsAt: now.add(plan.focus),
  );

  /// The half that follows this one, starting at [now].
  FocusSession next(DateTime now) {
    final FocusPhase phase = this.phase.following;

    return copyWith(
      phase: phase,
      endsAt: now.add(plan.lengthOf(phase)),
      round: phase == FocusPhase.focus ? round + 1 : round,
    );
  }
}
