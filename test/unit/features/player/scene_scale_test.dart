import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:purelofi/features/player/presentation/widgets/scene_layers.widget.dart';

void main() {
  group('sceneScaleFor', () {
    test('always returns a whole number that covers the viewport', () {
      // An iPhone 17 viewport against the standard 320x568 canvas.
      const Size viewport = Size(402, 874);

      final int scale = sceneScaleFor(
        viewport: viewport,
        canvasWidth: 320,
        canvasHeight: 568,
      );

      expect(scale, 2);
      expect(320 * scale, greaterThanOrEqualTo(viewport.width));
      expect(568 * scale, greaterThanOrEqualTo(viewport.height));
    });

    test('covers on both axes, not just the looser one', () {
      // Wide and short: width needs 4x, height only 1x.
      final int scale = sceneScaleFor(
        viewport: const Size(1200, 400),
        canvasWidth: 320,
        canvasHeight: 568,
      );

      expect(scale, 4);
    });

    test('never scales below 1', () {
      expect(
        sceneScaleFor(
          viewport: const Size(10, 10),
          canvasWidth: 320,
          canvasHeight: 568,
        ),
        1,
      );
    });

    test('survives a nonsense canvas instead of dividing by zero', () {
      expect(
        sceneScaleFor(
          viewport: const Size(402, 874),
          canvasWidth: 0,
          canvasHeight: 0,
        ),
        1,
      );
    });

    test('an exact fit does not round up to an empty border', () {
      expect(
        sceneScaleFor(
          viewport: const Size(640, 1136),
          canvasWidth: 320,
          canvasHeight: 568,
        ),
        2,
      );
    });
  });

  group('frameIndexAt', () {
    test('advances one frame per 1/fps and wraps at the end', () {
      int at(int ms) => frameIndexAt(
        clock: Duration(milliseconds: ms),
        fps: 10,
        frameCount: 6,
      );

      expect(at(0), 0);
      expect(at(99), 0);
      expect(at(100), 1);
      expect(at(550), 5);
      expect(at(600), 0, reason: 'wraps back to the first frame');
      expect(at(650), 0, reason: 'still inside the first frame of the loop');
      expect(at(700), 1);
    });

    test('a still layer stays on frame 0', () {
      expect(
        frameIndexAt(clock: const Duration(seconds: 9), fps: 0, frameCount: 1),
        0,
      );
    });

    test('a frame count of 1 never advances, whatever the fps', () {
      expect(
        frameIndexAt(clock: const Duration(seconds: 9), fps: 24, frameCount: 1),
        0,
      );
    });

    test('a frozen clock holds its frame', () {
      const Duration paused = Duration(milliseconds: 250);

      expect(frameIndexAt(clock: paused, fps: 8, frameCount: 4), 2);
      expect(frameIndexAt(clock: paused, fps: 8, frameCount: 4), 2);
    });
  });
}
