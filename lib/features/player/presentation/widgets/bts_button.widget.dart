import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../common/utils/app_assets.dart';
import '../../../../common/utils/responsive.dart';
import '../../../../common/widgets/pixel_icon.widget.dart';
import '../../controller/player.controller.dart';
import '../../domain/track.entity.dart';
import 'bts_modal.widget.dart';

/// Opens the behind-the-scenes clip for whatever is playing.
class BtsButton extends ConsumerWidget {
  const BtsButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final TrackEntity? track = ref.watch(
      playerControllerProvider.select((state) => state.currentTrack),
    );
    // No track, or a track nobody filmed: a camera that opens nothing reads
    // as a broken button.
    final String? clip = track?.btsVideoUrl;
    if (track == null || clip == null || clip.isEmpty) {
      return const SizedBox.shrink();
    }

    return Semantics(
      button: true,
      label: 'Behind the scenes',
      child: GestureDetector(
        onTap: () => showBtsModal(context, ref, track),
        child: PixelIcon(
          asset: AppAssets.cameraIcon,
          size: context.screenWidth * 0.09,
        ),
      ),
    );
  }
}
