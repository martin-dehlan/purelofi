import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../common/utils/responsive.dart';
import '../../../../common/widgets/app_icon.widget.dart';
import '../../../../common/widgets/empty_state.widget.dart';
import '../../../../common/widgets/error_state.widget.dart';
import '../../../../common/widgets/skeleton.widget.dart';
import '../../../pro/controller/pro.controller.dart';
import '../../../pro/presentation/widgets/paywall_sheet.widget.dart';
import '../../controller/player.provider.dart';
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
          loading: _SceneListSkeleton.new,
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

/// Rows in the shape of the list, while the scenes are on their way.
class _SceneListSkeleton extends StatelessWidget {
  const _SceneListSkeleton();

  /// About as many rooms as there are; a guess, but a close one beats a
  /// spinner in a sheet that is about to fill.
  static const int rows = 4;

  @override
  Widget build(BuildContext context) {
    final BorderRadius line = BorderRadius.circular(context.screenWidth * 0.01);

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: context.horizontalPadding),
      child: Semantics(
        label: 'Loading scenes',
        child: ExcludeSemantics(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              for (int i = 0; i < rows; i++)
                Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: context.spaceS,
                    vertical: context.spaceS,
                  ),
                  child: Row(
                    children: <Widget>[
                      Skeleton(
                        width: _SceneThumbnail.sizeFor(context),
                        height: _SceneThumbnail.sizeFor(context),
                        borderRadius: _SceneThumbnail.radiusFor(context),
                      ),
                      SizedBox(width: context.spaceM),
                      Skeleton(
                        // Titles differ in length; so do the bars.
                        width: context.screenWidth * (0.42 - 0.06 * (i % 3)),
                        height: context.fontM,
                        borderRadius: line,
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
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
    // A Pro room stays in the list, so a listener sees what Pro has; it
    // opens the paywall instead of the room (#16).
    final bool locked = ref.watch(lockedScenesProvider).contains(scene.id);

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
          color: isActive
              ? cs.primary
              : (locked ? cs.onSurfaceVariant : cs.onSurface),
          fontSize: context.fontM,
        ),
      ),
      trailing: locked
          ? Semantics(
              label: 'Pro',
              child: AppIcon(
                AppGlyph.lock,
                size: context.fontM,
                color: cs.onSurfaceVariant,
              ),
            )
          : null,
      selected: isActive,
      onTap: () {
        final NavigatorState navigator = Navigator.of(context);
        final BuildContext root = navigator.context;
        navigator.pop();
        if (ref.read(activeSceneControllerProvider.notifier).switchTo(scene)) {
          return;
        }
        ref.read(proControllerProvider.notifier).proSceneTapped(scene.id);
        unawaited(
          showPaywallSheet(root, source: 'scene_switcher', scene: scene),
        );
      },
    );
  }
}

/// A scene's cover, from the disk when it is there.
///
/// The covers are fetched as soon as the scene list is (see
/// `SceneListController`), so by the time the sheet opens they are usually
/// on the device and draw with the titles. Until one is, its skeleton holds
/// the place, and the picture fades in over it rather than popping.
class _SceneThumbnail extends ConsumerWidget {
  const _SceneThumbnail({required this.scene});

  final SceneEntity scene;

  static double sizeFor(BuildContext context) => context.screenWidth * 0.12;

  static BorderRadius radiusFor(BuildContext context) =>
      BorderRadius.circular(context.screenWidth * 0.01);

  /// How long a picture takes to come up over its skeleton.
  static const Duration fadeIn = Duration(milliseconds: 220);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ColorScheme cs = Theme.of(context).colorScheme;
    final String? url = scene.thumbnailUrl;
    final double size = sizeFor(context);
    final BorderRadius radius = radiusFor(context);
    final Widget blank = ColoredBox(color: cs.surfaceContainerHighest);
    final Widget skeleton = Skeleton(
      width: size,
      height: size,
      borderRadius: radius,
    );

    // Decoded at the size it is drawn, not as the 960 px square it is: a
    // fraction of the work, so it is ready in the same frame as the title.
    final int decodeWidth = (size * MediaQuery.devicePixelRatioOf(context))
        .round();

    Widget picture(ImageProvider<Object> image) => Image(
      image: ResizeImage(image, width: decodeWidth),
      fit: BoxFit.cover,
      filterQuality: FilterQuality.none,
      frameBuilder:
          (
            BuildContext context,
            Widget child,
            int? frame,
            bool wasSynchronouslyLoaded,
          ) {
            if (wasSynchronouslyLoaded) return child;

            return Stack(
              fit: StackFit.expand,
              children: <Widget>[
                skeleton,
                AnimatedOpacity(
                  opacity: frame == null ? 0 : 1,
                  duration: fadeIn,
                  curve: Curves.easeOut,
                  child: child,
                ),
              ],
            );
          },
      errorBuilder: (_, _, _) => blank,
    );

    final Widget content;
    if (url == null) {
      content = blank;
    } else {
      content = ref
          .watch(sceneCoverProvider(url))
          .when(
            data: (File? file) => file == null
                // No cache, or the download failed: the network may still
                // have it.
                ? picture(NetworkImage(url))
                : picture(FileImage(file)),
            loading: () => skeleton,
            error: (_, _) => picture(NetworkImage(url)),
          );
    }

    return ClipRRect(
      borderRadius: radius,
      child: SizedBox.square(dimension: size, child: content),
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
