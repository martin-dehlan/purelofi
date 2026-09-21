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
import 'bts_button.widget.dart';
import 'scene_switcher.widget.dart';

/// The player chrome that floats over the scene: what is playing, and one
/// pixel button to start or stop it.
class PlayerControls extends ConsumerWidget {
  const PlayerControls({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ColorScheme cs = Theme.of(context).colorScheme;
    final PlayerState state = ref.watch(playerControllerProvider);
    final AsyncValue<List<TrackEntity>> tracks = ref.watch(
      trackListControllerProvider,
    );

    // A play button that cannot play anything is worse than no button: it
    // looks broken. Say what is actually going on instead.
    final bool hasNoTracks = tracks.hasValue && tracks.value!.isEmpty;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        if (state.currentTrack != null)
          Text(
            state.currentTrack!.title,
            textAlign: TextAlign.center,
            style: TextStyle(color: cs.onSurface, fontSize: context.fontL),
          ),
        SizedBox(height: context.spaceL),
        if (hasNoTracks)
          Text(
            'No tracks yet.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: cs.onSurfaceVariant,
              fontSize: context.fontM,
            ),
          )
        else
          _PlayPauseButton(isPlaying: state.isPlaying),
        SizedBox(height: context.spaceL),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const SceneSwitcher(),
            SizedBox(width: context.spaceXl),
            const BtsButton(),
          ],
        ),
        if (state.error != null) ...<Widget>[
          SizedBox(height: context.spaceL),
          Text(
            state.error!.userMessage,
            textAlign: TextAlign.center,
            style: TextStyle(color: cs.error, fontSize: context.fontS),
          ),
        ],
      ],
    );
  }
}

class _PlayPauseButton extends ConsumerWidget {
  const _PlayPauseButton({required this.isPlaying});

  final bool isPlaying;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Semantics(
      button: true,
      label: isPlaying ? 'Pause' : 'Play',
      child: GestureDetector(
        onTap: ref.read(playerControllerProvider.notifier).togglePlayPause,
        child: PixelIcon(
          asset: isPlaying ? AppAssets.pauseIcon : AppAssets.playIcon,
          size: context.screenWidth * 0.18,
        ),
      ),
    );
  }
}
