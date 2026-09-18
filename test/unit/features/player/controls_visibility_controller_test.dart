import 'package:fake_async/fake_async.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:purelofi/features/player/controller/controls_visibility.controller.dart';

void main() {
  ProviderContainer makeContainer() {
    final ProviderContainer container = ProviderContainer();
    addTearDown(container.dispose);
    container.listen(controlsVisibilityControllerProvider, (_, _) {});
    return container;
  }

  test('controls start visible', () {
    final ProviderContainer container = makeContainer();

    expect(container.read(controlsVisibilityControllerProvider), isTrue);
  });

  test('controls hide after 4s of stillness', () {
    fakeAsync((FakeAsync async) {
      final ProviderContainer container = makeContainer();
      container.read(controlsVisibilityControllerProvider);

      async.elapse(const Duration(seconds: 3, milliseconds: 999));
      expect(container.read(controlsVisibilityControllerProvider), isTrue);

      async.elapse(const Duration(milliseconds: 1));
      expect(container.read(controlsVisibilityControllerProvider), isFalse);
    });
  });

  test('reveal shows them again and restarts the countdown', () {
    fakeAsync((FakeAsync async) {
      final ProviderContainer container = makeContainer();
      container.read(controlsVisibilityControllerProvider);
      async.elapse(const Duration(seconds: 5));
      expect(container.read(controlsVisibilityControllerProvider), isFalse);

      container.read(controlsVisibilityControllerProvider.notifier).reveal();
      expect(container.read(controlsVisibilityControllerProvider), isTrue);

      async.elapse(const Duration(seconds: 3));
      expect(container.read(controlsVisibilityControllerProvider), isTrue);

      async.elapse(const Duration(seconds: 1));
      expect(container.read(controlsVisibilityControllerProvider), isFalse);
    });
  });

  test('a tap during the countdown resets it rather than shortening it', () {
    fakeAsync((FakeAsync async) {
      final ProviderContainer container = makeContainer();
      container.read(controlsVisibilityControllerProvider);

      async.elapse(const Duration(seconds: 3));
      container.read(controlsVisibilityControllerProvider.notifier).reveal();
      async.elapse(const Duration(seconds: 3));

      expect(container.read(controlsVisibilityControllerProvider), isTrue);
    });
  });

  test('the timer does not outlive the controller', () {
    fakeAsync((FakeAsync async) {
      final ProviderContainer container = ProviderContainer();
      container.listen(controlsVisibilityControllerProvider, (_, _) {});
      container.read(controlsVisibilityControllerProvider);

      container.dispose();
      async.elapse(const Duration(seconds: 10));

      expect(async.pendingTimers, isEmpty);
    });
  });
}
