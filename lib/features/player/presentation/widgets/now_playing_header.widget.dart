import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../common/utils/responsive.dart';
import '../../controller/player.controller.dart';
import '../../controller/scene.controller.dart';
import '../../domain/scene.entity.dart';
import '../../domain/track.entity.dart';
import 'track_cover.widget.dart';

/// The top of the menu: what is playing, and in which room.
///
/// The menu opens over the room it is about, so it starts by naming both.
/// Nothing playing yet, nothing shown.
class NowPlayingHeader extends ConsumerWidget {
  const NowPlayingHeader({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ColorScheme cs = Theme.of(context).colorScheme;
    final TrackEntity? track = ref.watch(
      playerControllerProvider.select((state) => state.currentTrack),
    );
    final SceneEntity? scene = ref.watch(activeSceneControllerProvider);
    if (track == null) return const SizedBox.shrink();

    return Padding(
      padding: EdgeInsets.fromLTRB(
        context.horizontalPadding,
        0,
        context.horizontalPadding,
        context.spaceM,
      ),
      child: Row(
        children: <Widget>[
          TrackCover(track: track, size: context.fontXxl * 1.6),
          SizedBox(width: context.spaceM),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  track.title,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: cs.onSurface,
                    fontSize: context.fontM,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (scene != null)
                  Text(
                    scene.title,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: cs.onSurfaceVariant,
                      fontSize: context.fontS,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
