import 'dart:async';

import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../domain/audio_player.service.dart';
import '../domain/scene.entity.dart';
import '../domain/volume_fader.dart';
import '../domain/volume_layer.dart';
import '../domain/wake_alarm.dart';
import 'player.controller.dart';
import 'player.provider.dart';
import 'scene.controller.dart';

part 'wake_alarm.controller.g.dart';

/// The state the room page shows: the alarm, and whether the system let it
/// be set.
class WakeAlarmState {
  const WakeAlarmState({required this.alarm, this.next, this.refused = false});

  final WakeAlarm alarm;

  /// When it rings next, while it is on and set.
  final DateTime? next;

  /// On, but the system refused exact alarms: the listener has to allow
  /// them in the settings.
  final bool refused;
}

/// The wake-up alarm (#146). Keeps the setting, sets the next ring with the
/// platform, and when it rings, plays the chosen room with the music coming
/// in slowly. Built at the root, so a ring that opened the app is answered.
@Riverpod(keepAlive: true)
class WakeAlarmController extends _$WakeAlarmController {
  VolumeFader? _fader;

  @override
  Future<WakeAlarmState> build() async {
    final WakeScheduler scheduler = ref.read(wakeSchedulerProvider);
    final StreamSubscription<void> rings = scheduler.rang.listen(
      (_) => unawaited(wake()),
    );
    ref.onDispose(() {
      unawaited(rings.cancel());
      _fader?.cancel();
    });

    final WakeAlarm alarm = await ref.read(wakeAlarmStoreProvider).load();
    // Set again on every launch: a reboot clears the system's alarms.
    return _apply(alarm);
  }

  AudioPlayerService get _audio => ref.read(audioPlayerServiceProvider);

  Future<void> set(WakeAlarm alarm) async {
    state = AsyncData<WakeAlarmState>(await _apply(alarm));
    try {
      await ref.read(wakeAlarmStoreProvider).save(alarm);
    } on Object {
      // Set again next time.
    }
  }

  Future<WakeAlarmState> _apply(WakeAlarm alarm) async {
    final WakeScheduler scheduler = ref.read(wakeSchedulerProvider);
    if (!alarm.enabled || !scheduler.isSupported) {
      await scheduler.cancel();
      return WakeAlarmState(alarm: alarm);
    }
    final DateTime next = nextWake(alarm, DateTime.now());
    final bool set = await scheduler.schedule(next);

    return WakeAlarmState(alarm: alarm, next: set ? next : null, refused: !set);
  }

  /// The alarm rang: the room, the music from silence, and the next ring.
  Future<void> wake() async {
    final WakeAlarm alarm =
        state.value?.alarm ?? await ref.read(wakeAlarmStoreProvider).load();

    final String? sceneId = alarm.sceneId;
    if (sceneId != null) {
      final List<SceneEntity> scenes = await ref.read(
        sceneListControllerProvider.future,
      );
      final SceneEntity? scene = scenes
          .where((SceneEntity s) => s.id == sceneId)
          .firstOrNull;
      if (scene != null) {
        ref.read(activeSceneControllerProvider.notifier).switchTo(scene);
      }
    }

    final VolumeFader fader = _fader ??= VolumeFader(
      (double level) => _audio.setVolumeLayer(VolumeLayer.alarm, level),
    );
    fader.jumpTo(0);
    final PlayerController player = ref.read(playerControllerProvider.notifier);
    if (ref.read(playerControllerProvider).currentTrack == null) {
      await player.playNext();
    } else if (!ref.read(playerControllerProvider).isPlaying) {
      await player.togglePlayPause();
    }
    fader.fadeTo(1, alarm.fade);

    // A one-off alarm turns itself off; a repeating one sets the next day.
    await set(alarm.weekdays.isEmpty ? alarm.copyWith(enabled: false) : alarm);
  }
}
