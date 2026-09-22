import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:purelofi/features/player/domain/scene_event.scheduler.dart';
import 'package:purelofi/features/player/domain/scene_layer.entity.dart';

/// A Random that hands out fixed values, so "random" timing is exact here.
class _FixedRandom implements Random {
  _FixedRandom(this.value);

  final int value;

  @override
  int nextInt(int max) => value % max;

  @override
  bool nextBool() => false;

  @override
  double nextDouble() => 0;
}

void main() {
  SceneLayerEntity event(
    String id, {
    int min = 40,
    int max = 90,
    int frameCount = 24,
    double fps = 12,
  }) => SceneLayerEntity(
    id: id,
    zIndex: 5,
    spriteUrl: 'https://example.com/$id.png',
    frameCount: frameCount,
    fps: fps,
    eventIntervalMinSeconds: min,
    eventIntervalMaxSeconds: max,
  );

  SceneLayerEntity loop(String id) => SceneLayerEntity(
    id: id,
    zIndex: 1,
    spriteUrl: 'https://example.com/$id.png',
    frameCount: 6,
    fps: 12,
  );

  group('resting', () {
    test('an event sits on its first frame before its turn', () {
      final SceneLayerEntity car = event('car');
      final SceneEventScheduler scheduler = SceneEventScheduler(
        layers: <SceneLayerEntity>[car],
        random: _FixedRandom(0),
      );

      scheduler.update(const Duration(seconds: 39));

      expect(scheduler.runningLayerId, isNull);
      expect(scheduler.frameFor(car, const Duration(seconds: 39)), 0);
    });

    test('a looping layer is none of its business', () {
      final SceneLayerEntity rain = loop('rain');
      final SceneEventScheduler scheduler = SceneEventScheduler(
        layers: <SceneLayerEntity>[rain],
        random: _FixedRandom(0),
      );

      scheduler.update(const Duration(seconds: 120));

      expect(scheduler.runningLayerId, isNull);
      expect(scheduler.frameFor(rain, const Duration(seconds: 120)), 0);
    });
  });

  group('firing', () {
    test('fires once its interval has passed', () {
      final SceneLayerEntity car = event('car');
      final SceneEventScheduler scheduler = SceneEventScheduler(
        layers: <SceneLayerEntity>[car],
        random: _FixedRandom(0),
      );

      scheduler.update(const Duration(seconds: 40));

      expect(scheduler.runningLayerId, 'car');
      expect(scheduler.frameFor(car, const Duration(seconds: 40)), 0);
    });

    test('plays through its frames while running', () {
      final SceneLayerEntity car = event('car');
      final SceneEventScheduler scheduler = SceneEventScheduler(
        layers: <SceneLayerEntity>[car],
        random: _FixedRandom(0),
      );
      scheduler.update(const Duration(seconds: 40));

      expect(scheduler.frameFor(car, const Duration(milliseconds: 40500)), 6);
      expect(scheduler.frameFor(car, const Duration(milliseconds: 41000)), 12);
    });

    test('never runs past its last frame', () {
      final SceneLayerEntity car = event('car', frameCount: 24, fps: 12);
      final SceneEventScheduler scheduler = SceneEventScheduler(
        layers: <SceneLayerEntity>[car],
        random: _FixedRandom(0),
      );
      scheduler.update(const Duration(seconds: 40));

      // 1.9s in, 12fps: frame 22 by the maths.
      expect(scheduler.frameFor(car, const Duration(milliseconds: 41900)), 22);
      // Past the end of the strip it holds the last frame instead of
      // running off into a range error.
      expect(scheduler.frameFor(car, const Duration(milliseconds: 42500)), 23);
    });

    test('rests again once the animation is over', () {
      final SceneLayerEntity car = event('car', frameCount: 24, fps: 12);
      final SceneEventScheduler scheduler = SceneEventScheduler(
        layers: <SceneLayerEntity>[car],
        random: _FixedRandom(0),
      );
      scheduler.update(const Duration(seconds: 40));
      expect(scheduler.runningLayerId, 'car');

      // 24 frames at 12fps is two seconds.
      scheduler.update(const Duration(seconds: 42));

      expect(scheduler.runningLayerId, isNull);
      expect(scheduler.frameFor(car, const Duration(seconds: 42)), 0);
    });

    test('waits a fresh interval before firing again', () {
      final SceneLayerEntity car = event('car', min: 40, max: 40);
      final SceneEventScheduler scheduler = SceneEventScheduler(
        layers: <SceneLayerEntity>[car],
        random: _FixedRandom(0),
      );
      scheduler.update(const Duration(seconds: 40));
      scheduler.update(const Duration(seconds: 42));
      expect(scheduler.runningLayerId, isNull);

      scheduler.update(const Duration(seconds: 81));
      expect(scheduler.runningLayerId, isNull, reason: 'interval not up yet');

      scheduler.update(const Duration(seconds: 82));
      expect(scheduler.runningLayerId, 'car');
    });
  });

  group('one at a time', () {
    test('a second event waits for the first to finish', () {
      final SceneLayerEntity car = event('car', min: 40, max: 40);
      final SceneLayerEntity cat = event('cat', min: 40, max: 40);
      final SceneEventScheduler scheduler = SceneEventScheduler(
        layers: <SceneLayerEntity>[car, cat],
        random: _FixedRandom(0),
      );

      // Both are due at the same moment; only one may run.
      scheduler.update(const Duration(seconds: 40));
      final String? first = scheduler.runningLayerId;
      expect(first, isNotNull);

      scheduler.update(const Duration(milliseconds: 41000));
      expect(
        scheduler.runningLayerId,
        first,
        reason: 'the other one must not cut in',
      );

      // The first finishes after two seconds, then the other may go.
      scheduler.update(const Duration(seconds: 42));
      expect(scheduler.runningLayerId, isNot(first));
    });

    test('the waiting one keeps resting on frame 0 meanwhile', () {
      final SceneLayerEntity car = event('car', min: 40, max: 40);
      final SceneLayerEntity cat = event('cat', min: 40, max: 40);
      final SceneEventScheduler scheduler = SceneEventScheduler(
        layers: <SceneLayerEntity>[car, cat],
        random: _FixedRandom(0),
      );
      scheduler.update(const Duration(seconds: 40));

      final SceneLayerEntity waiting = scheduler.runningLayerId == 'car'
          ? cat
          : car;
      expect(
        scheduler.frameFor(waiting, const Duration(milliseconds: 41000)),
        0,
      );
    });
  });

  group('intervals', () {
    test('stays inside the range it was given', () {
      for (int seed = 0; seed < 20; seed++) {
        final SceneLayerEntity car = event('car', min: 40, max: 90);
        final SceneEventScheduler scheduler = SceneEventScheduler(
          layers: <SceneLayerEntity>[car],
          random: _FixedRandom(seed),
        );

        scheduler.update(const Duration(seconds: 39));
        expect(
          scheduler.runningLayerId,
          isNull,
          reason: 'seed $seed too early',
        );

        scheduler.update(const Duration(seconds: 90));
        expect(
          scheduler.runningLayerId,
          'car',
          reason: 'seed $seed should have fired by the upper bound',
        );
      }
    });
  });

  group('tappable', () {
    SceneLayerEntity cat({
      int frameCount = 12,
      double fps = 10,
      int idleFrameCount = 0,
    }) => SceneLayerEntity(
      id: 'cat',
      zIndex: 16,
      spriteUrl: 'https://example.com/cat.png',
      frameCount: frameCount,
      fps: fps,
      tappable: true,
      idleFrameCount: idleFrameCount,
    );

    test('waits indefinitely until it is tapped', () {
      final SceneLayerEntity layer = cat();
      final SceneEventScheduler scheduler = SceneEventScheduler(
        layers: <SceneLayerEntity>[layer],
        random: _FixedRandom(0),
      );

      scheduler.update(const Duration(minutes: 30));

      expect(
        scheduler.runningLayerId,
        isNull,
        reason: 'no timer starts a tappable layer',
      );
      expect(scheduler.frameFor(layer, const Duration(minutes: 30)), 0);
    });

    test('a tap starts it and it plays through', () {
      final SceneLayerEntity layer = cat();
      final SceneEventScheduler scheduler = SceneEventScheduler(
        layers: <SceneLayerEntity>[layer],
        random: _FixedRandom(0),
      );

      expect(scheduler.trigger('cat', const Duration(seconds: 5)), isTrue);
      expect(scheduler.runningLayerId, 'cat');
      expect(scheduler.frameFor(layer, const Duration(milliseconds: 5500)), 5);
    });

    test('a second tap during the stretch is ignored', () {
      final SceneEventScheduler scheduler = SceneEventScheduler(
        layers: <SceneLayerEntity>[cat()],
        random: _FixedRandom(0),
      );
      scheduler.trigger('cat', const Duration(seconds: 5));

      expect(
        scheduler.trigger('cat', const Duration(milliseconds: 5300)),
        isFalse,
        reason: 'restarting mid-stretch would look like a glitch',
      );
    });

    test('rests again afterwards and can be tapped once more', () {
      final SceneLayerEntity layer = cat();
      final SceneEventScheduler scheduler = SceneEventScheduler(
        layers: <SceneLayerEntity>[layer],
        random: _FixedRandom(0),
      );
      scheduler.trigger('cat', const Duration(seconds: 5));

      // 12 frames at 10fps is 1.2 seconds.
      scheduler.update(const Duration(milliseconds: 6300));

      expect(scheduler.runningLayerId, isNull);
      expect(scheduler.frameFor(layer, const Duration(milliseconds: 6300)), 0);
      expect(scheduler.trigger('cat', const Duration(seconds: 9)), isTrue);
    });

    test('an unknown id does nothing', () {
      final SceneEventScheduler scheduler = SceneEventScheduler(
        layers: <SceneLayerEntity>[cat()],
        random: _FixedRandom(0),
      );

      expect(scheduler.trigger('dog', const Duration(seconds: 5)), isFalse);
      expect(scheduler.runningLayerId, isNull);
    });
  });

  group('idle loop and reaction', () {
    // Four idle frames, then a six-frame reaction.
    SceneLayerEntity sleeper() => const SceneLayerEntity(
      id: 'cat',
      zIndex: 16,
      spriteUrl: 'https://example.com/cat.png',
      frameCount: 10,
      fps: 10,
      tappable: true,
      idleFrameCount: 4,
    );

    test('loops the idle frames while it waits', () {
      final SceneLayerEntity layer = sleeper();
      final SceneEventScheduler scheduler = SceneEventScheduler(
        layers: <SceneLayerEntity>[layer],
        random: _FixedRandom(0),
      );

      expect(scheduler.frameFor(layer, Duration.zero), 0);
      expect(scheduler.frameFor(layer, const Duration(milliseconds: 200)), 2);
      expect(
        scheduler.frameFor(layer, const Duration(milliseconds: 400)),
        0,
        reason: 'the idle loop wraps at its own length, not the strip length',
      );
    });

    test('a tap jumps past the idle frames into the reaction', () {
      final SceneLayerEntity layer = sleeper();
      final SceneEventScheduler scheduler = SceneEventScheduler(
        layers: <SceneLayerEntity>[layer],
        random: _FixedRandom(0),
      );

      scheduler.trigger('cat', const Duration(seconds: 2));

      expect(scheduler.frameFor(layer, const Duration(seconds: 2)), 4);
      expect(scheduler.frameFor(layer, const Duration(milliseconds: 2300)), 7);
    });

    test('the reaction never runs past the last frame', () {
      final SceneLayerEntity layer = sleeper();
      final SceneEventScheduler scheduler = SceneEventScheduler(
        layers: <SceneLayerEntity>[layer],
        random: _FixedRandom(0),
      );
      scheduler.trigger('cat', const Duration(seconds: 2));

      expect(scheduler.frameFor(layer, const Duration(seconds: 5)), 9);
    });

    test('it goes back to breathing once the reaction is over', () {
      final SceneLayerEntity layer = sleeper();
      final SceneEventScheduler scheduler = SceneEventScheduler(
        layers: <SceneLayerEntity>[layer],
        random: _FixedRandom(0),
      );
      scheduler.trigger('cat', const Duration(seconds: 2));

      // Six reaction frames at 10fps is 0.6 seconds.
      scheduler.update(const Duration(milliseconds: 2700));

      expect(scheduler.runningLayerId, isNull);
      expect(
        scheduler.frameFor(layer, const Duration(milliseconds: 2700)),
        lessThan(4),
        reason: 'back inside the idle range',
      );
    });
  });
}
