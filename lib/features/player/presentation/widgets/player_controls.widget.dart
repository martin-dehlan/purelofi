import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../common/errors/app_error.dart';
import '../../../../common/utils/app_assets.dart';
import '../../../../common/utils/responsive.dart';
import '../../../../common/widgets/pixel_icon.widget.dart';
import '../../controller/player.controller.dart';
import '../../controller/track.controller.dart';
import '../../domain/player.state.dart';
import '../../domain/track.entity.dart';
import 'waveform.widget.dart';

/// The bar along the bottom: the track, its waveform, and the transport.
///
/// The waveform is both the progress indicator and the scrubber, so there is
/// no separate slider competing with it.
class PlayerControls extends ConsumerWidget {
  const PlayerControls({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ColorScheme cs = Theme.of(context).colorScheme;
    final PlayerState state = ref.watch(playerControllerProvider);
    final AsyncValue<List<TrackEntity>> tracks = ref.watch(
      trackListControllerProvider,
    );

    // A transport that cannot play anything is worse than none: it looks
    // broken. Say what is actually going on instead.
    final bool hasNoTracks = tracks.hasValue && tracks.value!.isEmpty;
    if (hasNoTracks) {
      return Padding(
        padding: EdgeInsets.all(context.spaceL),
        child: Text(
          'No tracks yet.',
          textAlign: TextAlign.center,
          style: TextStyle(color: cs.onSurfaceVariant, fontSize: context.fontM),
        ),
      );
    }

    final TrackEntity? track = state.currentTrack;

    return Padding(
      padding: EdgeInsets.fromLTRB(
        context.horizontalPadding,
        context.spaceM,
        context.horizontalPadding,
        context.spaceXl,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            children: <Widget>[
              Text(
                _clock(state.position),
                style: TextStyle(
                  color: cs.onSurfaceVariant,
                  fontSize: context.fontS,
                ),
              ),
              SizedBox(width: context.spaceM),
              Expanded(
                child: Text(
                  track?.title ?? '',
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: cs.onSurface,
                    fontSize: context.fontM,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: context.spaceS),
          Waveform(
            seed: track?.id ?? 'purelofi',
            progress: state.progress,
            height: context.screenHeight * 0.06,
            onSeek: (double fraction) {
              final Duration? total = state.duration;
              if (total == null) return;

              unawaited(
                ref
                    .read(playerControllerProvider.notifier)
                    .seek(total * fraction),
              );
            },
          ),
          if (state.error != null) ...<Widget>[
            SizedBox(height: context.spaceS),
            Text(
              state.error!.userMessage,
              textAlign: TextAlign.center,
              style: TextStyle(color: cs.error, fontSize: context.fontS),
            ),
          ],
          SizedBox(height: context.spaceM),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              _TransportButton(
                asset: AppAssets.prevIcon,
                label: 'Start over',
                size: context.screenWidth * 0.07,
                onTap: ref.read(playerControllerProvider.notifier).restart,
              ),
              SizedBox(width: context.spaceXl),
              _TransportButton(
                asset: state.isPlaying
                    ? AppAssets.pauseIcon
                    : AppAssets.playIcon,
                label: state.isPlaying ? 'Pause' : 'Play',
                size: context.screenWidth * 0.13,
                onTap: ref
                    .read(playerControllerProvider.notifier)
                    .togglePlayPause,
              ),
              SizedBox(width: context.spaceXl),
              _TransportButton(
                asset: AppAssets.nextIcon,
                label: 'Next track',
                size: context.screenWidth * 0.07,
                onTap: ref.read(playerControllerProvider.notifier).playNext,
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// m:ss — hours would be dishonest for a three-minute track.
  static String _clock(Duration position) {
    final int minutes = position.inMinutes;
    final int seconds = position.inSeconds % 60;

    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }
}

class _TransportButton extends StatelessWidget {
  const _TransportButton({
    required this.asset,
    required this.label,
    required this.size,
    required this.onTap,
  });

  final String asset;
  final String label;
  final double size;
  final Future<void> Function() onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => unawaited(onTap()),
        child: Padding(
          padding: EdgeInsets.all(context.spaceS),
          child: PixelIcon(asset: asset, size: size),
        ),
      ),
    );
  }
}
