import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../common/utils/responsive.dart';
import '../../../../common/widgets/app_icon.widget.dart';
import '../../controller/player.controller.dart';
import '../../domain/player.state.dart';
import '../../domain/track.entity.dart';
import 'now_playing_bars.widget.dart';
import 'track_cover.widget.dart';
import '../../../../l10n/l10n.dart';

/// The track playing, as a card at the foot of the library: the cover,
/// what it is, the bars that dance while it plays, and pause. Skipping
/// waits in the room: the bare next triangle beside pause reads as a second
/// play at this size. The library stays open while the music changes, so
/// the music needs a place in it. Tapping the card goes back to the room.
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

    // In line with the page above it, as one more card of it, with the
    // home indicator's strip as the gap below. A phone without one gets a
    // small margin instead.
    return SafeArea(
      top: false,
      minimum: EdgeInsets.only(bottom: context.spaceS),
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          context.horizontalPadding,
          context.spaceS,
          context.horizontalPadding,
          0,
        ),
        child: Material(
          color: cs.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(context.cardBorderRadius * 1.5),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: () => Navigator.of(context).pop(),
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                context.spaceS,
                context.spaceS,
                context.spaceM,
                context.spaceS,
              ),
              child: Row(
                children: <Widget>[
                  TrackCover(track: track, size: context.screenWidth * 0.12),
                  SizedBox(width: context.spaceM),
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
                            fontSize: context.fontM,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        // The bars from the list's cover, small, in front of
                        // who made it: they dance while the music plays and
                        // rest on pause. One button stays on the right.
                        Row(
                          children: <Widget>[
                            NowPlayingBars(
                              size: context.fontS * 1.1,
                              color: cs.primary,
                            ),
                            SizedBox(width: context.spaceXs),
                            Flexible(
                              child: Text(
                                track.artist ?? 'PureLofi',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: cs.onSurfaceVariant,
                                  fontSize: context.fontS,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  SizedBox(width: context.spaceS),
                  // The one thing to do here, in the accent like the other
                  // main buttons of the app.
                  Tooltip(
                    message: isPlaying ? context.l10n.pause : context.l10n.play,
                    child: Material(
                      color: cs.primary,
                      shape: const CircleBorder(),
                      clipBehavior: Clip.antiAlias,
                      child: InkWell(
                        onTap: () => unawaited(player.togglePlayPause()),
                        // A finger's size at the least (#153).
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(
                            minWidth: kMinInteractiveDimension,
                            minHeight: kMinInteractiveDimension,
                          ),
                          child: Center(
                            widthFactor: 1,
                            heightFactor: 1,
                            child: Padding(
                              padding: EdgeInsets.all(context.spaceS),
                              // Play and pause turn into each other.
                              child: AnimatedSwitcher(
                                duration: const Duration(milliseconds: 180),
                                transitionBuilder:
                                    (Widget child, Animation<double> t) =>
                                        ScaleTransition(
                                          scale: t,
                                          child: FadeTransition(
                                            opacity: t,
                                            child: child,
                                          ),
                                        ),
                                child: AppIcon(
                                  isPlaying ? AppGlyph.pause : AppGlyph.play,
                                  key: ValueKey<bool>(isPlaying),
                                  size: context.fontL,
                                  color: cs.onPrimary,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
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
