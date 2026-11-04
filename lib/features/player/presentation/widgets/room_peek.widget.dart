import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../common/utils/app_fonts.dart';
import '../../../../common/utils/responsive.dart';
import '../../../../common/widgets/app_icon.widget.dart';
import '../../controller/scene.controller.dart';
import '../../domain/scene.entity.dart';

/// The top of the room page: the scene, still playing, showing through.
///
/// It is the way back. A tap on it, like a swipe down on the page, takes
/// the listener back into the room, the way one looks up from a notebook
/// to the window. Its label names the room so the way back says where.
class RoomPeek extends ConsumerWidget {
  const RoomPeek({required this.height, super.key});

  final double height;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ColorScheme cs = Theme.of(context).colorScheme;
    final SceneEntity? scene = ref.watch(activeSceneControllerProvider);

    return Semantics(
      button: true,
      label: 'Back to the room',
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => Navigator.of(context).maybePop(),
        child: SizedBox(
          height: height,
          child: Align(
            alignment: Alignment.bottomCenter,
            child: Padding(
              padding: EdgeInsets.only(bottom: context.spaceS),
              child: DecoratedBox(
                decoration: ShapeDecoration(
                  color: cs.surface.withValues(alpha: 0.7),
                  shape: const StadiumBorder(),
                ),
                child: Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: context.spaceM,
                    vertical: context.spaceXs * 1.5,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      AppIcon(
                        AppGlyph.dropDown,
                        size: context.fontM,
                        color: cs.onSurface,
                      ),
                      SizedBox(width: context.spaceXs),
                      Text(
                        scene?.title ?? 'Back',
                        style: TextStyle(
                          color: cs.onSurface,
                          fontFamily: AppFonts.wordmark,
                          fontSize: context.fontS,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
