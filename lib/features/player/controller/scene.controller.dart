import 'dart:async';

import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../common/analytics/analytics.provider.dart';

import '../dev/test_scene.dart';
import '../../pro/controller/pro.controller.dart';
import '../domain/scene.entity.dart';
import 'player.provider.dart';

part 'scene.controller.g.dart';

/// Loads the active scenes from Supabase, ordered by `sort_order`.
///
/// Kept alive for the same reason as the track list: fetched once, read again
/// whenever the listener switches scenes.
@Riverpod(keepAlive: true)
class SceneListController extends _$SceneListController {
  @override
  Future<List<SceneEntity>> build() async {
    // Compile-time constant, so the development scene is tree-shaken out of
    // any build that does not ask for it.
    if (DevTestScene.enabled) return <SceneEntity>[await DevTestScene.load()];

    final List<SceneEntity> scenes = await ref
        .watch(contentRepositoryProvider)
        .getScenes();

    // Every cover onto the disk now, while the listener is still looking at
    // the room: by the time they open the scene list, the pictures are
    // already there instead of loading row by row under their titles.
    for (final SceneEntity scene in scenes) {
      final String? url = scene.thumbnailUrl;
      if (url != null) ref.read(sceneCoverProvider(url).future).ignore();
    }

    return scenes;
  }
}

/// The scene currently playing behind the player.
///
/// Defaults to the first scene by `sort_order` once the list loads, and is
/// `null` while the list is loading or empty. Switching scenes is a state
/// change, not a route (see `docs/08`).
@riverpod
class ActiveSceneController extends _$ActiveSceneController {
  @override
  SceneEntity? build() {
    // Riverpod 3 makes AsyncValue.value nullable; there is no valueOrNull.
    final List<SceneEntity>? scenes = ref
        .watch(sceneListControllerProvider)
        .value;
    if (scenes == null || scenes.isEmpty) return null;

    // Pro ran out — an expiry, a refund — while a Pro scene was showing:
    // back to the first room, which is always free. The music plays on.
    ref.listen<Set<String>>(lockedScenesProvider, (_, Set<String> locked) {
      final SceneEntity? showing = state;
      if (showing != null && locked.contains(showing.id)) {
        state = _first(scenes);
      }
    });

    return _first(scenes);
  }

  static SceneEntity _first(List<SceneEntity> scenes) => scenes.reduce(
    (SceneEntity a, SceneEntity b) => a.sortOrder <= b.sortOrder ? a : b,
  );

  /// Shows [scene], unless it is a Pro scene this listener cannot open yet
  /// (#16) — then nothing changes and it returns `false`, for the caller to
  /// offer Pro instead.
  ///
  /// [justBought] is the paywall saying the purchase went through: the new
  /// status is on its way through RevenueCat's stream, and the room the
  /// listener paid for should not have to wait for it.
  bool switchTo(SceneEntity scene, {bool justBought = false}) {
    if (!justBought && ref.read(lockedScenesProvider).contains(scene.id)) {
      return false;
    }

    state = scene;
    unawaited(ref.read(analyticsServiceProvider).sceneSwitched(scene.id));
    return true;
  }
}
