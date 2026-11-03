import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../common/utils/responsive.dart';
import '../../../../common/widgets/app_icon.widget.dart';
import '../../../library/controller/library.controller.dart';
import '../../../library/presentation/widgets/remove_track_dialog.dart';
import '../../controller/favorites.controller.dart';
import '../../controller/player.controller.dart';
import '../../domain/track.entity.dart';
import 'bts_modal.widget.dart';
import 'track_cover.widget.dart';

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
      subtitle: Text(
        track.source == TrackSource.local
            ? (track.artist ?? 'Unknown artist')
            : 'PureLofi',
        overflow: TextOverflow.ellipsis,
        style: TextStyle(color: cs.onSurfaceVariant, fontSize: context.fontS),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          if (repeating)
            Semantics(
              label: 'On repeat',
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

/// The `⋯`: queue it, mark it, watch it being played, or take it out.
class _TrackMenu extends ConsumerWidget {
  const _TrackMenu({required this.track});

  final TrackEntity track;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ColorScheme cs = Theme.of(context).colorScheme;
    final PlayerController player = ref.read(playerControllerProvider.notifier);
    final bool isCatalogue = track.source == TrackSource.catalogue;
    final bool isFavorite = ref.watch(
      favoritesControllerProvider.select(
        (AsyncValue<Set<String>> favorites) =>
            favorites.hasValue && favorites.value!.contains(track.id),
      ),
    );
    final bool hasFootage =
        track.btsVideoUrl != null && track.btsVideoUrl!.isNotEmpty;
    final TextStyle label = TextStyle(fontSize: context.fontM);
    final double icon = context.fontL;

    Widget item(AppGlyph glyph, String text, VoidCallback onPressed) =>
        MenuItemButton(
          leadingIcon: AppIcon(glyph, size: icon, color: cs.onSurfaceVariant),
          onPressed: onPressed,
          child: Text(text, style: label),
        );

    return MenuAnchor(
      menuChildren: <Widget>[
        item(AppGlyph.next, 'Play next', () => player.queueNext(track)),
        item(AppGlyph.queue, 'Add to queue', () => player.addToQueue(track)),
        if (isCatalogue)
          item(
            isFavorite ? AppGlyph.heart : AppGlyph.heartOutline,
            isFavorite ? 'Remove from favorites' : 'Add to favorites',
            () => unawaited(
              ref.read(favoritesControllerProvider.notifier).toggle(track.id),
            ),
          ),
        if (hasFootage)
          item(AppGlyph.camera, 'Behind the scenes', () {
            Navigator.of(context).pop();
            unawaited(showBtsModal(context, ref, track));
          }),
        if (!isCatalogue)
          item(AppGlyph.remove, 'Remove from PureLofi', () async {
            if (!await confirmRemoveTrack(context, track)) return;
            await ref.read(libraryControllerProvider.notifier).remove(track.id);
          }),
      ],
      builder: (BuildContext context, MenuController menu, Widget? _) =>
          IconButton(
            tooltip: 'More: ${track.title}',
            icon: AppIcon(
              AppGlyph.more,
              size: icon,
              color: cs.onSurfaceVariant,
            ),
            onPressed: () => menu.isOpen ? menu.close() : menu.open(),
          ),
    );
  }
}
