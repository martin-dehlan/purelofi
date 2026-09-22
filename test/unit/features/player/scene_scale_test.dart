import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:purelofi/features/player/domain/scene_event.scheduler.dart';
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

    test('an ordinary layer is drawn fully, whatever the lamp does', () {
      expect(layerOpacity(layer(), fade: 0), 1);
      expect(layerOpacity(layer(), fade: 0.5), 1);
    });

    test('a layer tied to the music follows the fade', () {
      final SceneLayerEntity lamp = layer(hideWhenPaused: true);

      expect(layerOpacity(lamp, fade: 0), 0);
      expect(layerOpacity(lamp, fade: 0.4), 0.4);
      expect(layerOpacity(lamp, fade: 1), 1);
    });
  });

  group('stepFade', () {
    const Duration full = Duration(seconds: 2);

    test('climbs towards lit while the music plays', () {
      final double after = stepFade(
        0,
        isPlaying: true,
        delta: const Duration(milliseconds: 500),
        duration: full,
      );

      expect(after, closeTo(0.25, 0.001));
    });

    test('takes the full duration to come up', () {
      double fade = 0;
      for (int i = 0; i < 8; i++) {
        fade = stepFade(
          fade,
          isPlaying: true,
          delta: const Duration(milliseconds: 250),
          duration: full,
        );
      }

      expect(fade, 1);
    });

    test('falls back towards dark when the music stops', () {
      final double after = stepFade(
        1,
        isPlaying: false,
        delta: const Duration(milliseconds: 500),
        duration: full,
      );

      expect(after, closeTo(0.75, 0.001));
    });

    test('never overshoots either end', () {
      expect(
        stepFade(
          0.9,
          isPlaying: true,
          delta: const Duration(seconds: 5),
          duration: full,
        ),
        1,
      );
      expect(
        stepFade(
          0.1,
          isPlaying: false,
          delta: const Duration(seconds: 5),
          duration: full,
        ),
        0,
      );
    });

    test('a zero duration snaps, rather than dividing by zero', () {
      expect(
        stepFade(
          0,
          isPlaying: true,
          delta: const Duration(milliseconds: 16),
          duration: Duration.zero,
        ),
        1,
      );
    });
  });

  group('frameForLayer', () {
    SceneLayerEntity layer({
      bool onTrackChange = false,
      bool onlyWhilePlaying = false,
      int idleFrameCount = 0,
    }) => SceneLayerEntity(
      id: 'led',
      zIndex: 17,
      spriteUrl: 'led.png',
      frameCount: 32,
      fps: 6,
      onTrackChange: onTrackChange,
      onlyWhilePlaying: onlyWhilePlaying,
      idleFrameCount: idleFrameCount,
    );

    SceneEventScheduler schedulerFor(SceneLayerEntity one) =>
        SceneEventScheduler(layers: <SceneLayerEntity>[one]);

    test('a plain layer follows the clock straight through its strip', () {
      final SceneLayerEntity plain = layer();

      expect(
        frameForLayer(
          plain,
          events: schedulerFor(plain),
          elapsed: const Duration(milliseconds: 5000),
          playingElapsed: Duration.zero,
        ),
        30,
      );
    });

    test('a layer tied to the music follows the second clock', () {
      final SceneLayerEntity tied = layer(onlyWhilePlaying: true);

      expect(
        frameForLayer(
          tied,
          events: schedulerFor(tied),
          elapsed: const Duration(seconds: 30),
          playingElapsed: const Duration(milliseconds: 1000),
        ),
        6,
      );
    });

    test('a layer waiting for a track change never reaches its reaction', () {
      // The regression this is here for: routed through the plain clock, the
      // radio played its 8 reaction frames every 32 frames all by itself.
      final SceneLayerEntity led = layer(
        onTrackChange: true,
        idleFrameCount: 24,
      );
      final SceneEventScheduler events = schedulerFor(led);

      for (int second = 0; second < 120; second++) {
        final Duration now = Duration(seconds: second);
        events.update(now);

        expect(
          frameForLayer(led, events: events, elapsed: now, playingElapsed: now),
          lessThan(24),
          reason: 'frame 24 and up are the reaction, and nothing triggered it',
        );
      }
    });

    test('and plays it once when the track does change', () {
      final SceneLayerEntity led = layer(
        onTrackChange: true,
        idleFrameCount: 24,
      );
      final SceneEventScheduler events = schedulerFor(led);

      const Duration start = Duration(seconds: 10);
      expect(events.trigger(led.id, start), isTrue);

      expect(
        frameForLayer(
          led,
          events: events,
          elapsed: start,
          playingElapsed: start,
        ),
        24,
      );
      expect(
        frameForLayer(
          led,
          events: events,
          elapsed: start + const Duration(milliseconds: 500),
          playingElapsed: start,
        ),
        27,
      );

      // The reaction is 8 frames at 6fps, so it is over well before this.
      events.update(start + const Duration(seconds: 3));
      expect(
        frameForLayer(
          led,
          events: events,
          elapsed: start + const Duration(seconds: 3),
          playingElapsed: start,
        ),
        lessThan(24),
      );
    });
  });

  group('visibleCanvasRect and layerFits', () {
    SceneLayerEntity cat({bool hideWhenClipped = false}) => SceneLayerEntity(
      id: 'cat',
      zIndex: 16,
      spriteUrl: 'cat.png',
      offsetX: 62,
      offsetY: 500,
      hideWhenClipped: hideWhenClipped,
    );

    const Size frame = Size(48, 36);

    /// What a phone really shows of a 320x568 canvas.
    Rect shown(double width, double height, double dpr) => visibleCanvasRect(
      viewport: Size(width, height),
      canvasWidth: 320,
      canvasHeight: 568,
      devicePixelRatio: dpr,
    );

    test('a 9:16 phone loses the most, because 2.35x rounds up to 3x', () {
      // iPhone SE 3. The canvas is the same shape as the screen, which is
      // exactly why it goes wrong: there is nothing to round down to.
      final Rect visible = shown(375, 667, 2);

      expect(visible.top, closeTo(61.7, 0.5));
      expect(visible.bottom, closeTo(506.3, 0.5));
      expect(visible.left, closeTo(35, 0.5));
    });

    test('a tall phone loses width instead', () {
      final Rect visible = shown(411, 923, 2.625);

      expect(visible.left, closeTo(52, 0.5));
      expect(visible.right, closeTo(268, 0.5));
      expect(visible.bottom, closeTo(526, 0.5));
    });

    test('an ordinary layer is drawn even where it is cropped', () {
      // The room and the sky are meant to run past the edges.
      expect(
        layerFits(
          cat(),
          bounds: layerBounds(cat(), frameSize: frame),
          visible: shown(375, 667, 2),
        ),
        isTrue,
      );
    });

    test('a layer that asks to be whole stays away when it is not', () {
      // The cat sits at y 500..536. An SE shows down to 506, so the mattress
      // under it is gone and it would read as falling off the bed.
      final SceneLayerEntity layer = cat(hideWhenClipped: true);

      expect(
        layerFits(
          layer,
          bounds: layerBounds(layer, frameSize: frame),
          visible: shown(375, 667, 2),
        ),
        isFalse,
      );
      expect(
        layerFits(
          layer,
          bounds: layerBounds(layer, frameSize: frame),
          visible: shown(411, 923, 2.625),
        ),
        isFalse,
        reason: 'a Pixel cuts the bottom ten rows',
      );
    });

    test('and is drawn where all of it fits', () {
      // iPhone 17 shows down to y 546, past the cat's 536.
      final SceneLayerEntity layer = cat(hideWhenClipped: true);

      expect(
        layerFits(
          layer,
          bounds: layerBounds(layer, frameSize: frame),
          visible: shown(402, 874, 3),
        ),
        isTrue,
      );
    });
  });
}
