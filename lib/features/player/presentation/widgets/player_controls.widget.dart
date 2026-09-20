import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../common/errors/app_error.dart';
import '../../../../common/utils/app_assets.dart';
import '../../../../common/utils/responsive.dart';
import '../../../../common/widgets/pixel_icon.widget.dart';
import '../../controller/player.controller.dart';
import '../../domain/player.state.dart';

/// The player chrome that floats over the scene: what is playing, and one
/// pixel button to start or stop it.
class PlayerControls extends ConsumerWidget {
  const PlayerControls({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ColorScheme cs = Theme.of(context).colorScheme;
    final PlayerState state = ref.watch(playerControllerProvider);

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
        _PlayPauseButton(isPlaying: state.isPlaying),
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
