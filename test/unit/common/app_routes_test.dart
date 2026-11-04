import 'package:flutter_test/flutter_test.dart';
import 'package:purelofi/common/routes/app_routes.dart';

void main() {
  test('a deep link with a track id opens that track', () {
    expect(
      AppRoutes.trackIdFrom('3F2504E0-4F89-41D3-9A0C-0305E82C3301'),
      '3f2504e0-4f89-41d3-9a0c-0305e82c3301',
    );
  });

  test('anything else in the id slot is dropped', () {
    for (final String? raw in <String?>[
      null,
      '',
      'not-a-uuid',
      "1' or '1'='1",
      '3f2504e0-4f89-41d3-9a0c-0305e82c3301,is_active.eq.false',
    ]) {
      expect(AppRoutes.trackIdFrom(raw), isNull, reason: raw);
    }
  });
}
