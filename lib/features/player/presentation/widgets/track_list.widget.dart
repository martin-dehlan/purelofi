import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../common/utils/app_fonts.dart';
import '../../../../common/utils/clock.dart';
import '../../../../common/utils/responsive.dart';
import '../../../../common/widgets/app_icon.widget.dart';
import '../../controller/player.controller.dart';
import '../../controller/track.controller.dart';
import '../../domain/track.entity.dart';
import 'bts_modal.widget.dart';

/// Every track, and a way straight into one of them (#67).
///
/// The stream still shuffles on its own when a track ends; this is for when
/// the listener wants a particular one now.
class TrackList extends ConsumerWidget {
  const TrackList({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ColorScheme cs = Theme.of(context).colorScheme;
    final List<TrackEntity> tracks =
        ref.watch(trackListControllerProvider).value ?? const <TrackEntity>[];

    if (tracks.isEmpty) {
      return Padding(
        padding: EdgeInsets.symmetric(vertical: context.spaceM),
        child: Text(
          'No tracks yet.',
          style: TextStyle(color: cs.onSurfaceVariant, fontSize: context.fontM),
        ),
      );
    }

    // A long catalogue scrolls inside the sheet instead of pushing the rest
    // of the menu off the bottom.
    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: context.screenHeight * 0.45),
      child: ListView.builder(
        shrinkWrap: true,
        padding: EdgeInsets.zero,
        itemCount: tracks.length,
        itemBuilder: (BuildContext context, int index) =>
            _TrackRow(track: tracks[index]),
      ),
    );
  }
}

/// One track as a Material list tile. The one playing is filled with the
/// selected tone and carries the bars, so it is found at a glance.
class _TrackRow extends ConsumerWidget {
  const _TrackRow({required this.track});

  final TrackEntity track;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ColorScheme cs = Theme.of(context).colorScheme;
    final bool isCurrent = ref.watch(
      playerControllerProvider.select(
        (state) => state.currentTrack?.id == track.id,
      ),
    );
    final bool hasFootage =
        track.btsVideoUrl != null && track.btsVideoUrl!.isNotEmpty;
    final double iconSize = context.fontL;

    return ListTile(
      selected: isCurrent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(context.cardBorderRadius),
      ),
      contentPadding: EdgeInsets.symmetric(horizontal: context.spaceS),
      horizontalTitleGap: context.spaceM,
      // Space is kept for the marker on every row, so titles line up
      // whether or not their track is the one playing.
      leading: SizedBox.square(
        dimension: iconSize,
        child: isCurrent
            ? AppIcon(AppGlyph.nowPlaying, size: iconSize, color: cs.primary)
            : null,
      ),
      title: Text(
        track.title,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(fontSize: context.fontM, fontWeight: FontWeight.w500),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          if (hasFootage) _FootageButton(track: track, size: iconSize),
          if (track.durationSeconds != null)
            Text(
              clockOf(track.durationSeconds!),
              style: TextStyle(
                color: cs.onSurfaceVariant,
                fontFamily: AppFonts.mono,
                fontSize: context.fontS,
              ),
            ),
        ],
      ),
      onTap: () {
        Navigator.of(context).pop();
        unawaited(ref.read(playerControllerProvider.notifier).playTrack(track));
      },
    );
  }
}

/// The camera on a row: the footage of this track being played.
class _FootageButton extends ConsumerWidget {
  const _FootageButton({required this.track, required this.size});

  final TrackEntity track;
  final double size;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return IconButton(
      tooltip: 'Behind the scenes: ${track.title}',
      icon: AppIcon(
        AppGlyph.camera,
        size: size,
        color: Theme.of(context).colorScheme.onSurfaceVariant,
      ),
      onPressed: () {
        Navigator.of(context).pop();
        unawaited(showBtsModal(context, ref, track));
      },
    );
  }
}
