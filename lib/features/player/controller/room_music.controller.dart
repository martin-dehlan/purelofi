import 'dart:async';

import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../domain/mood.entity.dart';
import '../domain/playback_scope.dart';
import '../domain/scene.entity.dart';
import 'collections.controller.dart';
import 'player.controller.dart';
import 'player.provider.dart';
import 'scene.controller.dart';

part 'room_music.controller.g.dart';

/// "Music follows the room" (#143): off unless the listener turns it on.
///
/// Parked: not in the release. Nothing builds these providers and no setting
/// shows them, so a value saved by an earlier build does nothing.
@Riverpod(keepAlive: true)
class FollowRoomController extends _$FollowRoomController {
  @override
  Future<bool> build() async {
    try {
      return await ref.read(playbackPreferencesProvider).loadFollowRoom();
    } on Object {
      return false;
    }
  }

  Future<void> set(bool enabled) async {
    state = AsyncData<bool>(enabled);
    try {
      await ref.read(playbackPreferencesProvider).saveFollowRoom(enabled);
    } on Object {
      // A setting that fails to save is set again next time.
    }
  }
}

/// Plays the room's mood while the listener is in it, when they asked for
/// that (#143). The track playing finishes; the next one comes from the
/// mood. A mood or playlist the listener picked themselves always wins: a
/// room never replaces it. Built at the root.
@Riverpod(keepAlive: true)
class RoomMusic extends _$RoomMusic {
  @override
  void build() {
    ref.listen<SceneEntity?>(
      activeSceneControllerProvider,
      (_, _) => unawaited(_follow()),
      fireImmediately: true,
    );
    ref.listen<AsyncValue<bool>>(
      followRoomControllerProvider,
      (_, _) => unawaited(_follow()),
    );
    ref.listen<AsyncValue<List<MoodEntity>>>(
      moodsProvider,
      (_, _) => unawaited(_follow()),
    );
  }

  Future<void> _follow() async {
    final PlaybackScope? current = ref.read(playbackScopeControllerProvider);
    // The listener's own choice stands.
    if (current != null && !current.fromRoom) return;

    final bool on = ref.read(followRoomControllerProvider).value ?? false;
    final SceneEntity? scene = ref.read(activeSceneControllerProvider);
    final String? moodId = on ? scene?.moodId : null;
    final MoodEntity? mood = moodId == null
        ? null
        : (ref.read(moodsProvider).value ?? const <MoodEntity>[])
              .where((MoodEntity m) => m.id == moodId)
              .firstOrNull;

    final PlaybackScope? next = mood == null
        ? null
        : PlaybackScope(
            kind: ScopeKind.mood,
            id: mood.id,
            title: mood.title,
            fromRoom: true,
          );
    if (next == current) return;

    // Nothing playing yet: the first track will come from the plan anyway.
    if (ref.read(playerControllerProvider).currentTrack == null) {
      ref.read(playbackScopeControllerProvider.notifier).select(next);
      return;
    }
    await ref.read(playerControllerProvider.notifier).followScope(next);
  }
}
