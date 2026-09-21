import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:purelofi/features/player/domain/scene_layer.entity.dart';
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

  group('sceneScaleFor on a real screen', () {
    // iPhone 17: 402x874 logical at 3x.
    const Size viewport = Size(402, 874);

    test('counts device pixels, not logical points', () {
      final int scale = sceneScaleFor(
        viewport: viewport,
        canvasWidth: 320,
        canvasHeight: 568,
        devicePixelRatio: 3,
      );

      expect(scale, 5);
      expect(
        320 * scale,
        greaterThanOrEqualTo(viewport.width * 3),
        reason: 'must still cover the screen',
      );
    });

    test('crops far less than the logical-point scale would', () {
      double cropFraction(int scale, double dpr) {
        final double drawn = 320 * scale / dpr;
        return (drawn - viewport.width) / drawn;
      }

      final int logical = sceneScaleFor(
        viewport: viewport,
        canvasWidth: 320,
        canvasHeight: 568,
      );
      final int device = sceneScaleFor(
        viewport: viewport,
        canvasWidth: 320,
        canvasHeight: 568,
        devicePixelRatio: 3,
      );

      expect(cropFraction(logical, 1), greaterThan(0.35));
      expect(cropFraction(device, 3), lessThan(0.26));
    });

    test('a canvas shaped like the screen barely crops at all', () {
      final int scale = sceneScaleFor(
        viewport: viewport,
        canvasWidth: 320,
        canvasHeight: 696,
        devicePixelRatio: 3,
      );

      expect(scale, 4);
      expect(
        (320 * scale / 3 - viewport.width) / (320 * scale / 3),
        lessThan(0.08),
      );
      expect(
        (696 * scale / 3 - viewport.height) / (696 * scale / 3),
        lessThan(0.08),
      );
    });

    test('a nonsense ratio falls back to 1 instead of dividing by zero', () {
      expect(
        sceneScaleFor(
          viewport: viewport,
          canvasWidth: 320,
          canvasHeight: 568,
          devicePixelRatio: 0,
        ),
        1,
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

  group('layerIsVisible', () {
    SceneLayerEntity layer({bool hideWhenPaused = false}) => SceneLayerEntity(
      id: 'l',
      zIndex: 1,
      spriteUrl: 'https://example.com/l.png',
      hideWhenPaused: hideWhenPaused,
    );

    test('an ordinary layer is drawn either way', () {
      expect(layerIsVisible(layer(), isPlaying: true), isTrue);
      expect(layerIsVisible(layer(), isPlaying: false), isTrue);
    });

    test('a layer tied to the music disappears when it stops', () {
      final SceneLayerEntity lamp = layer(hideWhenPaused: true);

      expect(layerIsVisible(lamp, isPlaying: true), isTrue);
      expect(
        layerIsVisible(lamp, isPlaying: false),
        isFalse,
        reason: 'the lamp goes out when the music does',
      );
    });
  });
}
