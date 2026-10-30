import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:purelofi/common/utils/app_version.dart';

void main() {
  test('the menu shows the version pubspec.yaml ships', () {
    final String pubspec = File('pubspec.yaml').readAsStringSync();
    final RegExpMatch? match = RegExp(
      r'^version:\s*([^+\s]+)',
      multiLine: true,
    ).firstMatch(pubspec);

    expect(match, isNotNull);
    expect(appVersion, match!.group(1));
  });
}
