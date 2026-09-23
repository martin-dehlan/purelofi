import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../common/utils/responsive.dart';
import '../../../../common/widgets/empty_state.widget.dart';
import '../../controller/favorites.controller.dart';
import '../../controller/player.controller.dart';
import '../../domain/track.entity.dart';
import 'favorite_button.widget.dart';

/// The marked tracks, and a way back into one of them.
///
/// The stream still shuffles on its own; this is for when the listener wants
/// a particular track now rather than eventually.
class FavoritesSheet extends ConsumerWidget {
  const FavoritesSheet({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final List<TrackEntity> tracks = ref.watch(favoriteTracksProvider);

    if (tracks.isEmpty) {
      return SafeArea(
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: context.horizontalPadding,
            vertical: context.spaceXl,
          ),
          child: const EmptyState(
            message:
                'Nothing marked yet. Tap the heart beside a track and it '
                'turns up here.',
          ),
        ),
      );
    }

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: context.spaceL),
        child: ListView.builder(
          shrinkWrap: true,
          itemCount: tracks.length,
          itemBuilder: (BuildContext context, int index) =>
              _FavoriteRow(track: tracks[index]),
        ),
      ),
    );
  }
}

class _FavoriteRow extends ConsumerWidget {
  const _FavoriteRow({required this.track});

  final TrackEntity track;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ColorScheme cs = Theme.of(context).colorScheme;
    final bool isPlaying = ref.watch(
      playerControllerProvider.select(
        (state) => state.currentTrack?.id == track.id,
      ),
    );

    return Semantics(
      button: true,
      selected: isPlaying,
      label: track.title,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          Navigator.of(context).pop();
          unawaited(
            ref.read(playerControllerProvider.notifier).playTrack(track),
          );
        },
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: context.horizontalPadding,
            vertical: context.spaceM,
          ),
          child: Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  track.title,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    // The one that is playing is brighter; nothing else marks
                    // it, because a second badge on every row is noise.
                    color: isPlaying ? cs.onSurface : cs.onSurfaceVariant,
                    fontSize: context.fontM,
                  ),
                ),
              ),
              FavoriteButton(trackId: track.id, size: context.fontM),
            ],
          ),
        ),
      ),
    );
  }
}

/// Opens the marked tracks as a bottom sheet.
Future<void> showFavoritesSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: Theme.of(context).colorScheme.surface,
    builder: (BuildContext context) => const FavoritesSheet(),
  );
}
