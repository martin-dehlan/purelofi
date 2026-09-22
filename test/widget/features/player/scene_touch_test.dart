import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:purelofi/features/player/controller/scene_touch.controller.dart';

void main() {
  group('SceneTouchController', () {
    test('starts with nothing consumed', () {
      final ProviderContainer container = ProviderContainer();
      addTearDown(container.dispose);

      expect(container.read(sceneTouchControllerProvider), isFalse);
    });

    test('take reports the touch once and then clears it', () {
      final ProviderContainer container = ProviderContainer();
      addTearDown(container.dispose);

      container.read(sceneTouchControllerProvider.notifier).consume();

      expect(
        container.read(sceneTouchControllerProvider.notifier).take(),
        isTrue,
      );
      expect(
        container.read(sceneTouchControllerProvider.notifier).take(),
        isFalse,
        reason: 'a consumed touch must not swallow the next tap as well',
      );
    });
  });
}
