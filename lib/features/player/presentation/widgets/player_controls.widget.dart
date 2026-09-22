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
import 'favorite_button.widget.dart';
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
    // Watched narrowly: the position ticks several times a second, and
    // rebuilding the whole bar for it was showing up as stutter.
    final bool isPlaying = ref.watch(
      playerControllerProvider.select((PlayerState s) => s.isPlaying),
    );
    final TrackEntity? track = ref.watch(
      playerControllerProvider.select((PlayerState s) => s.currentTrack),
    );
    final AppError? error = ref.watch(
      playerControllerProvider.select((PlayerState s) => s.error),
    );
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
          _Progress(title: track?.title ?? '', seed: track?.id ?? 'purelofi'),
          if (error != null) ...<Widget>[
            SizedBox(height: context.spaceS),
            Text(
              error.userMessage,
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
                asset: isPlaying ? AppAssets.pauseIcon : AppAssets.playIcon,
                label: isPlaying ? 'Pause' : 'Play',
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

/// The clock and the waveform: the only parts that follow the position, so
/// the only parts that rebuild while a track runs.
class _Progress extends ConsumerWidget {
  const _Progress({required this.title, required this.seed});

  final String title;
  final String seed;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ColorScheme cs = Theme.of(context).colorScheme;
    final Duration position = ref.watch(
      playerControllerProvider.select((PlayerState s) => s.position),
    );
    final Duration? duration = ref.watch(
      playerControllerProvider.select((PlayerState s) => s.duration),
    );

    final double progress = duration == null || duration <= Duration.zero
        ? 0
        : (position.inMilliseconds / duration.inMilliseconds).clamp(0.0, 1.0);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Row(
          children: <Widget>[
            Text(
              PlayerControls._clock(position),
              style: TextStyle(
                color: cs.onSurfaceVariant,
                fontSize: context.fontS,
              ),
            ),
            SizedBox(width: context.spaceM),
            Expanded(
              child: Text(
                title,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: cs.onSurface, fontSize: context.fontM),
              ),
            ),
            if (seed.isNotEmpty)
              FavoriteButton(trackId: seed, size: context.screenWidth * 0.05),
          ],
        ),
        SizedBox(height: context.spaceS),
        Waveform(
          seed: seed,
          progress: progress,
          height: context.screenHeight * 0.06,
          onSeek: (double fraction) {
            if (duration == null) return;

            unawaited(
              ref
                  .read(playerControllerProvider.notifier)
                  .seek(duration * fraction),
            );
          },
        ),
      ],
    );
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
