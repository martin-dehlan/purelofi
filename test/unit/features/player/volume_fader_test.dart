import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:purelofi/features/player/domain/volume_fader.dart';

void main() {
  late List<double> applied;
  late VolumeFader fader;

  setUp(() {
    applied = <double>[];
    fader = VolumeFader((double level) async => applied.add(level));
  });

  test('fades in even steps and lands on the target', () {
    fakeAsync((FakeAsync async) {
      fader.fadeTo(0, const Duration(seconds: 1));

      async.elapse(const Duration(milliseconds: 500));
      expect(fader.level, closeTo(0.5, 0.001));
      expect(fader.isFading, isTrue);

      async.elapse(const Duration(milliseconds: 500));
      expect(applied.last, 0);
      expect(fader.isFading, isFalse);
      expect(applied, hasLength(10));
    });
  });

  test('a new fade carries on from where the last one stopped', () {
    fakeAsync((FakeAsync async) {
      fader.fadeTo(0, const Duration(seconds: 1));
      async.elapse(const Duration(milliseconds: 500));

      fader.fadeTo(1, const Duration(seconds: 1));
      async.elapse(const Duration(milliseconds: 500));

      expect(fader.level, closeTo(0.75, 0.001));
    });
  });

  test('a jump stops the fade and sets the level at once', () {
    fakeAsync((FakeAsync async) {
      fader.fadeTo(0, const Duration(seconds: 1));
      async.elapse(const Duration(milliseconds: 300));

      fader.jumpTo(1);
      async.elapse(const Duration(seconds: 2));

      expect(applied.last, 1);
      expect(fader.level, 1);
    });
  });

  test('a fade shorter than one step is a jump', () {
    fader.fadeTo(0.4, Duration.zero);
    expect(applied, <double>[0.4]);
  });
}
