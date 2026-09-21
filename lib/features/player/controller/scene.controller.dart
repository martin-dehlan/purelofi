import 'dart:async';

import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../common/analytics/analytics.provider.dart';

import '../dev/test_scene.dart';
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

    return ref.watch(contentRepositoryProvider).getScenes();
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

    return scenes.reduce(
      (SceneEntity a, SceneEntity b) => a.sortOrder <= b.sortOrder ? a : b,
    );
  }

  void switchTo(SceneEntity scene) {
    state = scene;
    unawaited(ref.read(analyticsServiceProvider).sceneSwitched(scene.id));
  }
}
