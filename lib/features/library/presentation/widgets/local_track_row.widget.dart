import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../common/utils/responsive.dart';
import '../../../player/controller/player.controller.dart';
import '../../../player/domain/track.entity.dart';
import '../../../player/presentation/widgets/track_tile.widget.dart';
import '../../controller/library.controller.dart';
import 'remove_track_dialog.dart';

/// One of the listener's own tracks: tap to play, swipe to remove (#66).
/// Removing is in its `⋯` too, for anyone who never thinks to swipe.
class LocalTrackRow extends ConsumerWidget {
  const LocalTrackRow({required this.track, super.key});

  final TrackEntity track;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ColorScheme cs = Theme.of(context).colorScheme;

    return Dismissible(
      key: ValueKey<String>('local-${track.id}'),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: EdgeInsets.symmetric(horizontal: context.spaceM),
        color: cs.errorContainer,
        child: Text(
          'Remove',
          style: TextStyle(color: cs.onErrorContainer, fontSize: context.fontS),
        ),
      ),
      confirmDismiss: (_) => confirmRemoveTrack(context, track),
      onDismissed: (_) => unawaited(
        ref.read(libraryControllerProvider.notifier).remove(track.id),
      ),
      child: TrackTile(
        track: track,
        onTap: () {
          Navigator.of(context).pop();
          unawaited(
            ref.read(playerControllerProvider.notifier).playTrack(track),
          );
        },
      ),
    );
  }
}
