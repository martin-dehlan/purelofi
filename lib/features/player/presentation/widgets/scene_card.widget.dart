import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../common/utils/responsive.dart';
import '../../../../common/widgets/app_icon.widget.dart';
import '../../../pro/controller/pro.controller.dart';
import '../../../pro/presentation/widgets/paywall_sheet.widget.dart';
import '../../controller/new_content.controller.dart';
import '../../controller/scene.controller.dart';
import '../../domain/scene.entity.dart';
import 'new_dot.widget.dart';
import 'scene_thumbnail.widget.dart';

/// One room to step into: its cover with its name under it.
///
/// The room you are in is framed in the accent. A Pro room stays in the
/// row, so a listener sees what Pro has, with a lock on it; it opens the
/// paywall instead of the room (#16). Picking one swaps the scene behind
/// the page and leaves the music alone.
class SceneCard extends ConsumerWidget {
  const SceneCard({
    required this.scene,
    required this.isActive,
    required this.size,
    super.key,
  });

  final SceneEntity scene;
  final bool isActive;

  /// The cover's width and height.
  final double size;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ColorScheme cs = Theme.of(context).colorScheme;
    final bool locked = ref.watch(lockedScenesProvider).contains(scene.id);
    final bool isNew = ref.watch(newScenesProvider).contains(scene.id);
    final double frame = size * 0.035;
    final BorderRadius radius = SceneThumbnail.radiusFor(size);

    void pick() {
      final BuildContext root = Navigator.of(context).context;
      if (ref.read(activeSceneControllerProvider.notifier).switchTo(scene)) {
        return;
      }
      ref.read(proControllerProvider.notifier).proSceneTapped(scene.id);
      unawaited(showPaywallSheet(root, source: 'scene_switcher', scene: scene));
    }

    return Semantics(
      button: true,
      selected: isActive,
      label: <String>[
        scene.title,
        if (locked) 'Pro',
        if (isNew) 'new',
      ].join(', '),
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: pick,
        child: SizedBox(
          width: size,
          child: Column(
            // The title centred under its cover.
            crossAxisAlignment: CrossAxisAlignment.center,
            children: <Widget>[
              Container(
                padding: EdgeInsets.all(frame),
                decoration: BoxDecoration(
                  borderRadius: radius,
                  border: Border.all(
                    color: isActive
                        ? cs.primary
                        : cs.primary.withValues(alpha: 0),
                    width: frame,
                  ),
                ),
                child: Stack(
                  children: <Widget>[
                    Opacity(
                      opacity: locked ? 0.55 : 1,
                      child: SceneThumbnail(
                        scene: scene,
                        size: size - frame * 4,
                      ),
                    ),
                    // Added since the listener last looked (#148).
                    if (isNew)
                      Positioned(
                        right: context.spaceXs,
                        top: context.spaceXs,
                        child: const NewDot(),
                      ),
                    if (locked)
                      Positioned(
                        right: context.spaceXs,
                        bottom: context.spaceXs,
                        child: Container(
                          padding: EdgeInsets.all(context.spaceXs),
                          decoration: BoxDecoration(
                            color: cs.surface,
                            shape: BoxShape.circle,
                          ),
                          child: AppIcon(
                            AppGlyph.lock,
                            size: context.fontS,
                            color: cs.onSurface,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              SizedBox(height: context.spaceXs),
              Text(
                scene.title,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: isActive
                      ? cs.primary
                      : (locked ? cs.onSurfaceVariant : cs.onSurface),
                  fontSize: context.fontS,
                  fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
