import 'package:flutter_test/flutter_test.dart';
import 'package:purelofi/features/player/domain/focus_session.dart';

void main() {
  final DateTime nine = DateTime(2026, 11, 4, 9);

  test('a session starts with a focus stretch of the plan\'s length', () {
    final FocusSession session = FocusSession.start(FocusPlan.classic, nine);

    expect(session.phase, FocusPhase.focus);
    expect(session.endsAt, nine.add(const Duration(minutes: 25)));
    expect(session.round, 1);
  });

  test('focus gives way to a break, a break to the next round', () {
    final FocusSession focus = FocusSession.start(FocusPlan.classic, nine);
    final DateTime later = focus.endsAt;

    final FocusSession rest = focus.next(later);
    expect(rest.phase, FocusPhase.rest);
    expect(rest.endsAt, later.add(const Duration(minutes: 5)));
    expect(rest.round, 1);

    final FocusSession again = rest.next(rest.endsAt);
    expect(again.phase, FocusPhase.focus);
    expect(again.round, 2);
  });

  test('the chips read as minutes on and off', () {
    expect(FocusPlan.classic.label, '25 / 5');
    expect(FocusPlan.deep.label, '50 / 10');
  });
}
