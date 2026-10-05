import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../common/utils/responsive.dart';
import '../../../../common/widgets/empty_state.widget.dart';
import '../../../../common/widgets/error_state.widget.dart';
import '../../../../common/widgets/loading_state.widget.dart';
import '../../controller/scene.controller.dart';
import '../../domain/scene.entity.dart';

/// The list of scenes to choose from, in `sort_order`.
///
/// Picking one swaps the video behind the player. The music keeps playing —
/// scenes and tracks are independent.
class SceneSwitcherSheet extends ConsumerWidget {
  const SceneSwitcherSheet({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<List<SceneEntity>> scenes = ref.watch(
      sceneListControllerProvider,
    );

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(bottom: context.spaceL),
        child: scenes.when(
          data: (List<SceneEntity> scenes) => _SceneList(scenes: scenes),
          loading: LoadingState.new,
          error: (Object error, _) => ErrorState(
            error: error,
            onRetry: () => ref.invalidate(sceneListControllerProvider),
          ),
        ),
      ),
    );
  }
}

class _SceneList extends ConsumerWidget {
  const _SceneList({required this.scenes});

  final List<SceneEntity> scenes;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final SceneEntity? active = ref.watch(activeSceneControllerProvider);

    if (scenes.isEmpty) {
      return Padding(
        padding: EdgeInsets.symmetric(vertical: context.spaceXl),
        child: const EmptyState(message: 'No scenes to switch to yet.'),
      );
    }

    return ListView.builder(
      shrinkWrap: true,
      padding: EdgeInsets.symmetric(horizontal: context.horizontalPadding),
      itemCount: scenes.length,
      itemBuilder: (BuildContext context, int index) {
        final SceneEntity scene = scenes[index];

        return _SceneTile(scene: scene, isActive: scene.id == active?.id);
      },
    );
  }
}

class _SceneTile extends ConsumerWidget {
  const _SceneTile({required this.scene, required this.isActive});

  final SceneEntity scene;
  final bool isActive;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ColorScheme cs = Theme.of(context).colorScheme;

    // The same tile as a track in the menu: the room you are in is filled
    // with the selected tone.
    return ListTile(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(context.cardBorderRadius),
      ),
      contentPadding: EdgeInsets.symmetric(horizontal: context.spaceS),
      horizontalTitleGap: context.spaceM,
      leading: _SceneThumbnail(scene: scene),
      title: Text(
        scene.title,
        style: TextStyle(
          color: isActive ? cs.primary : cs.onSurface,
          fontSize: context.fontM,
        ),
      ),
      selected: isActive,
      onTap: () {
        ref.read(activeSceneControllerProvider.notifier).switchTo(scene);
        Navigator.of(context).pop();
      },
    );
  }
}

class _SceneThumbnail extends StatelessWidget {
  const _SceneThumbnail({required this.scene});

  final SceneEntity scene;

  @override
  Widget build(BuildContext context) {
    final ColorScheme cs = Theme.of(context).colorScheme;
    final String? url = scene.thumbnailUrl;
    final double size = context.screenWidth * 0.12;

    final BorderRadius radius = BorderRadius.circular(
      context.screenWidth * 0.01,
    );

    if (url == null) {
      return ClipRRect(
        borderRadius: radius,
        child: SizedBox.square(
          dimension: size,
          child: ColoredBox(color: cs.surfaceContainerHighest),
        ),
      );
    }

    return ClipRRect(
      borderRadius: radius,
      child: SizedBox.square(
        dimension: size,
        child: Image.network(
          url,
          fit: BoxFit.cover,
          filterQuality: FilterQuality.none,
          errorBuilder: (_, _, _) =>
              ColoredBox(color: cs.surfaceContainerHighest),
        ),
      ),
    );
  }
}

/// Opens the scene list as a bottom sheet.
Future<void> showSceneSwitcherSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    builder: (_) => const SceneSwitcherSheet(),
  );
}
