import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../common/widgets/error_state.widget.dart';
import '../../../../common/widgets/loading_state.widget.dart';
import '../../controller/player.provider.dart';
import '../../controller/scene.controller.dart';
import '../../domain/scene.entity.dart';
import 'scene_video.widget.dart';

/// The fullscreen looping scene behind everything else.
///
/// Fills the screen edge to edge; the player chrome floats over it.
class SceneBackground extends ConsumerWidget {
  const SceneBackground({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<List<SceneEntity>> scenes = ref.watch(
      sceneListControllerProvider,
    );

    return SizedBox.expand(
      child: scenes.when(
        data: (_) => const _ActiveScene(),
        loading: LoadingState.new,
        error: (Object error, _) => ErrorState(
          error: error,
          onRetry: () => ref.invalidate(sceneListControllerProvider),
        ),
      ),
    );
  }
}

class _ActiveScene extends ConsumerWidget {
  const _ActiveScene();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final SceneEntity? scene = ref.watch(activeSceneControllerProvider);
    if (scene == null) {
      // The content loaded but no scene is active — nothing to show but the
      // surface behind the player chrome.
      return ColoredBox(color: Theme.of(context).colorScheme.surface);
    }

    final SceneVideoBuilder? builder = ref.watch(sceneVideoBuilderProvider);

    return builder?.call(scene) ??
        SceneVideoView(key: ValueKey<String>(scene.id), scene: scene);
  }
}
