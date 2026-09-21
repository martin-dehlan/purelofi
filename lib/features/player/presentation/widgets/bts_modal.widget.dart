import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../common/analytics/analytics.provider.dart';
import '../../../../common/utils/responsive.dart';
import '../../controller/player.controller.dart';
import '../../controller/player.provider.dart';
import '../../domain/track.entity.dart';
import 'bts_video.widget.dart';

/// The "this is real, not AI" proof: phone footage of the track being played.
class BtsModal extends ConsumerWidget {
  const BtsModal({required this.track, super.key});

  final TrackEntity track;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ColorScheme cs = Theme.of(context).colorScheme;
    final String? videoUrl = track.btsVideoUrl;

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: context.horizontalPadding,
          vertical: context.spaceL,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              track.title,
              style: TextStyle(color: cs.onSurface, fontSize: context.fontL),
            ),
            SizedBox(height: context.spaceS),
            Text(
              'Played on a real guitar, recorded on a phone.',
              style: TextStyle(
                color: cs.onSurfaceVariant,
                fontSize: context.fontS,
              ),
            ),
            SizedBox(height: context.spaceL),
            if (videoUrl == null)
              Text(
                'No behind-the-scenes clip for this track yet.',
                style: TextStyle(
                  color: cs.onSurfaceVariant,
                  fontSize: context.fontM,
                ),
              )
            else
              ref.watch(btsVideoBuilderProvider)?.call(videoUrl) ??
                  BtsVideoView(videoUrl: videoUrl),
          ],
        ),
      ),
    );
  }
}

/// Opens the behind-the-scenes clip for [track].
///
/// The music pauses while the footage plays — the point is hearing the track
/// being played — and picks up again when the sheet is dismissed.
Future<void> showBtsModal(
  BuildContext context,
  WidgetRef ref,
  TrackEntity track,
) async {
  final PlayerController player = ref.read(playerControllerProvider.notifier);
  final bool wasPlaying = ref.read(playerControllerProvider).isPlaying;

  unawaited(ref.read(analyticsServiceProvider).btsOpened(track.id));

  if (wasPlaying) await player.togglePlayPause();

  if (!context.mounted) return;
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Theme.of(context).colorScheme.surface,
    builder: (_) => BtsModal(track: track),
  );

  if (wasPlaying) await player.togglePlayPause();
}
