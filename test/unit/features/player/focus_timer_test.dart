import 'package:fake_async/fake_async.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:purelofi/common/analytics/analytics.provider.dart';
import 'package:purelofi/common/analytics/analytics.service.dart';
import 'package:purelofi/features/player/controller/focus_timer.controller.dart';
import 'package:purelofi/features/player/controller/player.provider.dart';
import 'package:purelofi/features/player/domain/focus_session.dart';
import 'package:purelofi/features/player/domain/volume_layer.dart';

import '../../../helpers/fake_audio_player.service.dart';
import '../../../helpers/fake_display_preferences.dart';
import '../../../helpers/fake_focus_notifier.dart';
import '../../../helpers/recording_analytics.service.dart';

void main() {
  late FakeAudioPlayerService fakeAudio;
  late RecordingAnalyticsService analytics;
  late FakeFocusNotifier notifier;

  ProviderContainer container() {
    fakeAudio = FakeAudioPlayerService();
    analytics = RecordingAnalyticsService();
    notifier = FakeFocusNotifier();
    final ProviderContainer container = ProviderContainer(
      overrides: [
        audioPlayerServiceProvider.overrideWithValue(fakeAudio),
        analyticsServiceProvider.overrideWithValue(analytics),
        focusNoticeProvider.overrideWithValue(notifier),
        displayPreferencesProvider.overrideWithValue(FakeDisplayPreferences()),
      ],
    );
    addTearDown(() {
      container.dispose();
      fakeAudio.dispose();
    });
    container.listen(focusTimerControllerProvider, (_, _) {});
    return container;
  }

  test('starts with a focus stretch, the music at full volume', () {
    fakeAsync((FakeAsync async) {
      final ProviderContainer c = container();
      c.read(focusTimerControllerProvider.notifier).start(FocusPlan.classic);

      final FocusSession? session = c.read(focusTimerControllerProvider);
      expect(session?.phase, FocusPhase.focus);
      expect(fakeAudio.layer(VolumeLayer.focusBreak), 1);
      expect(fakeAudio.chimes, 0);
      expect(analytics.last(AnalyticsEvents.focusStarted), <String, Object>{
        'focus_minutes': 25,
        'rest_minutes': 5,
      });
    });
  });

  test('at the end of a stretch: a chime, a break, the music steps back', () {
    fakeAsync((FakeAsync async) {
      final ProviderContainer c = container();
      c.read(focusTimerControllerProvider.notifier).start(FocusPlan.classic);

      async.elapse(const Duration(minutes: 25));
      expect(fakeAudio.chimes, 1);
      expect(c.read(focusTimerControllerProvider)?.phase, FocusPhase.rest);

      async.elapse(FocusTimerController.stepLength);
      expect(
        fakeAudio.layer(VolumeLayer.focusBreak),
        closeTo(FocusTimerController.restLevel, 0.001),
      );
    });
  });

  test('after the break: another chime, round two, full volume again', () {
    fakeAsync((FakeAsync async) {
      final ProviderContainer c = container();
      c.read(focusTimerControllerProvider.notifier).start(FocusPlan.classic);

      async.elapse(const Duration(minutes: 30));
      async.elapse(FocusTimerController.stepLength);

      final FocusSession? session = c.read(focusTimerControllerProvider);
      expect(fakeAudio.chimes, 2);
      expect(session?.phase, FocusPhase.focus);
      expect(session?.round, 2);
      expect(fakeAudio.layer(VolumeLayer.focusBreak), closeTo(1, 0.001));
    });
  });

  test('turned off in a break, the music is back at once and stays', () {
    fakeAsync((FakeAsync async) {
      final ProviderContainer c = container();
      final FocusTimerController timer = c.read(
        focusTimerControllerProvider.notifier,
      )..start(FocusPlan.classic);

      async.elapse(const Duration(minutes: 26));
      expect(fakeAudio.layer(VolumeLayer.focusBreak), lessThan(1));

      timer.stop();
      expect(fakeAudio.layer(VolumeLayer.focusBreak), 1);
      expect(c.read(focusTimerControllerProvider), isNull);

      async.elapse(const Duration(hours: 2));
      expect(fakeAudio.chimes, 1);
      expect(fakeAudio.layer(VolumeLayer.focusBreak), 1);
    });
  });

  test('picking another plan starts over from a focus stretch', () {
    fakeAsync((FakeAsync async) {
      final ProviderContainer c = container();
      final FocusTimerController timer = c.read(
        focusTimerControllerProvider.notifier,
      )..start(FocusPlan.classic);
      async.elapse(const Duration(minutes: 26));

      timer.start(FocusPlan.deep);

      final FocusSession? session = c.read(focusTimerControllerProvider);
      expect(session?.plan, FocusPlan.deep);
      expect(session?.phase, FocusPhase.focus);
      expect(fakeAudio.layer(VolumeLayer.focusBreak), 1);
    });
  });

  test('each switch buzzes and says what comes now; off clears it', () {
    fakeAsync((FakeAsync async) {
      final ProviderContainer c = container();
      c.read(focusTimerControllerProvider.notifier).start(FocusPlan.classic);
      async.flushMicrotasks();
      expect(notifier.prepared, 1);

      async.elapse(FocusPlan.classic.focus);
      expect(notifier.announced, <String>['Break · 5 min']);

      async.elapse(FocusPlan.classic.rest);
      expect(notifier.announced.last, 'Back to focus · 25 min');

      c.read(focusTimerControllerProvider.notifier).stop();
      async.flushMicrotasks();
      expect(notifier.cleared, 1);
    });
  });
}
