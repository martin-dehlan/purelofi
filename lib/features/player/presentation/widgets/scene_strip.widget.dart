import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../common/utils/responsive.dart';
import '../../../../common/widgets/empty_state.widget.dart';
import '../../../../common/widgets/error_state.widget.dart';
import '../../../../common/widgets/skeleton.widget.dart';
import '../../controller/scene.controller.dart';
import '../../domain/scene.entity.dart';
import 'scene_card.widget.dart';
import 'scene_thumbnail.widget.dart';

/// The rooms, side by side in `sort_order`, to swipe through and step into.
///
/// Their pictures are the prettiest thing in the app, so they are shown,
/// not listed by name. While they load, cards in their shape hold the row.
class SceneStrip extends ConsumerWidget {
  const SceneStrip({super.key});

  /// About as many rooms as fit on a phone's width.
  static const int placeholders = 4;

  static double cardSizeFor(BuildContext context) => context.screenWidth * 0.27;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<List<SceneEntity>> scenes = ref.watch(
      sceneListControllerProvider,
    );
    final SceneEntity? active = ref.watch(activeSceneControllerProvider);
    final double card = cardSizeFor(context);
    final double gap = context.spaceS;

    Widget row(int count, Widget Function(int index) item) => SizedBox(
      // The cover and a line of title under it.
      height: card + context.spaceXs + context.fontS * 1.6 + 2 * context.spaceM,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        // Inside its card: the covers scroll to the card's edge.
        padding: EdgeInsets.all(context.spaceM),
        itemCount: count,
        separatorBuilder: (_, _) => SizedBox(width: gap),
        itemBuilder: (BuildContext context, int index) => item(index),
      ),
    );

    return scenes.when(
      data: (List<SceneEntity> scenes) {
        if (scenes.isEmpty) {
          return Padding(
            padding: EdgeInsets.symmetric(vertical: context.spaceL),
            child: const EmptyState(message: 'No scenes to switch to yet.'),
          );
        }
        return row(
          scenes.length,
          (int index) => SceneCard(
            scene: scenes[index],
            isActive: scenes[index].id == active?.id,
            size: card,
          ),
        );
      },
      loading: () => Semantics(
        label: 'Loading scenes',
        child: ExcludeSemantics(
          child: row(
            placeholders,
            (_) => Align(
              alignment: Alignment.topCenter,
              child: Skeleton(
                width: card,
                height: card,
                borderRadius: SceneThumbnail.radiusFor(card),
              ),
            ),
          ),
        ),
      ),
      error: (Object error, _) => ErrorState(
        error: error,
        onRetry: () => ref.invalidate(sceneListControllerProvider),
      ),
    );
  }
}
