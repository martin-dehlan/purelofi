import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:purelofi/features/player/data/sprite_loader.service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const String missing = 'assets/nothing/is/here.png';

  test('a failed sprite is not remembered, so a retry really tries again', () {
    final NetworkSpriteLoader loader = NetworkSpriteLoader();
    addTearDown(loader.dispose);

    final Future<ui.Image> first = loader.load(missing);

    return expectLater(first, throwsA(anything)).then((_) {
      final Future<ui.Image> second = loader.load(missing);

      expect(
        identical(first, second),
        isFalse,
        reason:
            'the second call must go back to the network, not hand back '
            'the remembered failure',
      );

      return expectLater(second, throwsA(anything));
    });
  });

  test('a sprite asked for twice at once is only fetched once', () {
    final NetworkSpriteLoader loader = NetworkSpriteLoader();
    addTearDown(loader.dispose);

    final Future<ui.Image> first = loader.load(missing);
    final Future<ui.Image> second = loader.load(missing);

    expect(identical(first, second), isTrue);

    return Future.wait<void>(<Future<void>>[
      expectLater(first, throwsA(anything)),
      expectLater(second, throwsA(anything)),
    ]);
  });
}
