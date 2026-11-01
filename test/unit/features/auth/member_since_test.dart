import 'package:flutter_test/flutter_test.dart';
import 'package:purelofi/features/auth/domain/member_since.dart';

void main() {
  test('names the month and the year, not the day', () {
    expect(
      memberSinceLabel(DateTime(2026, 11, 1, 12)),
      'Member since November 2026',
    );
  });

  test('January is the first month, December the last', () {
    expect(
      memberSinceLabel(DateTime(2027, 1, 15)),
      'Member since January 2027',
    );
    expect(
      memberSinceLabel(DateTime(2026, 12, 31, 12)),
      'Member since December 2026',
    );
  });
}
