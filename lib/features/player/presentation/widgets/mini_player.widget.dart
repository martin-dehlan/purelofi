import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../common/utils/responsive.dart';
import '../../../../common/widgets/app_icon.widget.dart';
import '../../controller/player.controller.dart';
import '../../domain/player.state.dart';
import '../../domain/track.entity.dart';
import 'track_cover.widget.dart';

/// The track playing, as a slim bar at the foot of the library: what it is
/// and pause. Skipping waits in the room: the bare next triangle beside
/// pause reads as a second play at this size. The library stays open while the music changes, so the
/// music needs a place in it. Tapping the bar goes back to the room.
///
/// Nothing while nothing plays.
class MiniPlayer extends ConsumerWidget {
  const MiniPlayer({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ColorScheme cs = Theme.of(context).colorScheme;
    final TrackEntity? track = ref.watch(
      playerControllerProvider.select((PlayerState s) => s.currentTrack),
    );
    final bool isPlaying = ref.watch(
      playerControllerProvider.select((PlayerState s) => s.isPlaying),
    );
    if (track == null) return const SizedBox.shrink();
    final PlayerController player = ref.read(playerControllerProvider.notifier);

    // The home indicator's strip is gap enough below it; a phone without
    // one gets a small margin instead.
    return SafeArea(
      top: false,
      minimum: EdgeInsets.only(bottom: context.spaceS),
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          context.spaceS,
          context.spaceXs,
          context.spaceS,
          0,
        ),
        child: Material(
          color: cs.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(context.cardBorderRadius),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: () => Navigator.of(context).pop(),
            child: Padding(
              padding: EdgeInsets.all(context.spaceS),
              child: Row(
                children: <Widget>[
                  TrackCover(track: track, size: context.screenWidth * 0.11),
                  SizedBox(width: context.spaceS),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        Text(
                          track.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: cs.onSurface,
                            fontSize: context.fontS,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          track.artist ?? 'PureLofi',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: cs.onSurfaceVariant,
                            fontSize: context.fontXs,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: isPlaying ? 'Pause' : 'Play',
                    onPressed: () => unawaited(player.togglePlayPause()),
                    icon: AppIcon(
                      isPlaying ? AppGlyph.pause : AppGlyph.play,
                      size: context.fontXl,
                      color: cs.onSurface,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
