import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../common/utils/responsive.dart';
import '../../../../common/widgets/app_icon.widget.dart';
import '../../controller/new_content.controller.dart';
import '../../controller/downloads.controller.dart';
import '../../controller/player.controller.dart';
import '../../domain/track.entity.dart';
import 'new_dot.widget.dart';
import 'track_actions_sheet.widget.dart';
import 'track_cover.widget.dart';
import '../../../../l10n/l10n.dart';

/// One track, the way a music app draws one: a round cover, the title, who
/// it is by, and a `⋯` with everything else that can be done with it.
///
/// Kept lean on purpose — no lengths, no badges, no filled background. The
/// one playing is told by its title in the accent and the bars on its cover.
/// Used by the library and the queue alike, so a track looks the same
/// wherever it turns up.
class TrackTile extends ConsumerWidget {
  const TrackTile({
    required this.track,
    required this.onTap,
    this.showMenu = true,
    this.markCurrent = true,
    this.repeating = false,
    super.key,
  });

  final TrackEntity track;

  /// `null` for a row that only shows, like the one playing in the queue.
  final VoidCallback? onTap;
  final bool showMenu;

  /// Off for rows that are what comes later: the track playing may be
  /// planned again, and that row is not the one playing now.
  final bool markCurrent;

  /// Set on the track playing when it is also what plays next — repeat is
  /// on, or it is the only track — so the row says so instead of the list
  /// below repeating it.
  final bool repeating;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ColorScheme cs = Theme.of(context).colorScheme;
    final bool isCurrent =
        markCurrent &&
        ref.watch(
          playerControllerProvider.select(
            (state) => state.currentTrack?.id == track.id,
          ),
        );

    final bool downloaded = ref.watch(
      downloadsControllerProvider.select(
        (AsyncValue<Downloads> d) => d.value?.has(track) ?? false,
      ),
    );

    final bool isNew = ref.watch(
      newTracksProvider.select((Set<String> ids) => ids.contains(track.id)),
    );

    return ListTile(
      selected: isCurrent,
      // The accent on the title is the whole mark; a tinted row on top of it
      // would be a second one.
      selectedTileColor: cs.surface.withValues(alpha: 0),
      contentPadding: EdgeInsets.zero,
      horizontalTitleGap: context.spaceM,
      minVerticalPadding: context.spaceS,
      leading: TrackCover(
        track: track,
        size: context.screenWidth * 0.13,
        isCurrent: isCurrent,
      ),
      title: Text(
        track.title,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(fontSize: context.fontM, fontWeight: FontWeight.w600),
      ),
      subtitle: Row(
        children: <Widget>[
          // Kept for offline: a small arrow ahead of the name, the way music
          // apps mark it.
          if (downloaded) ...<Widget>[
            Semantics(
              label: context.l10n.downloaded,
              child: AppIcon(
                AppGlyph.download,
                size: context.fontS,
                color: cs.primary,
              ),
            ),
            SizedBox(width: context.spaceXs),
          ],
          Flexible(
            child: Text(
              track.artistName,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: cs.onSurfaceVariant,
                fontSize: context.fontS,
              ),
            ),
          ),
        ],
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          // Added since the listener last looked (#148).
          if (isNew) ...<Widget>[
            const NewDot(),
            SizedBox(width: context.spaceS),
          ],
          if (repeating)
            Semantics(
              label: context.l10n.onRepeat,
              child: AppIcon(
                AppGlyph.repeatOne,
                size: context.fontL,
                color: cs.primary,
              ),
            ),
          if (showMenu) _TrackMenu(track: track),
        ],
      ),
      onTap: onTap,
    );
  }
}

/// The `⋯`: opens everything else that can be done with the track.
class _TrackMenu extends StatelessWidget {
  const _TrackMenu({required this.track});

  final TrackEntity track;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: 'More: ${track.title}',
      icon: AppIcon(
        AppGlyph.more,
        size: context.fontL,
        color: Theme.of(context).colorScheme.onSurfaceVariant,
      ),
      onPressed: () => unawaited(showTrackActionsSheet(context, track)),
    );
  }
}
