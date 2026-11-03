import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../common/utils/responsive.dart';
import '../../../../common/widgets/app_icon.widget.dart';
import '../../../library/presentation/widgets/my_music.widget.dart';
import '../../controller/favorites.controller.dart';
import '../../controller/playback_source.controller.dart';
import '../../controller/player.controller.dart';
import '../../controller/track.controller.dart';
import '../../domain/track.entity.dart';
import 'music_sheet.dart';
import 'track_tile.widget.dart';
import 'up_next.widget.dart';

/// What the sheet shows: what plays next, one of the two sides, or the
/// marked tracks.
enum LibraryFilter { upNext, catalogue, local, favorites }

/// All the music in one lean sheet, the way a music app's library looks: a
/// row of pills, and a list of tracks with round covers.
///
/// "Up next" sits in the same row as the sides, so the queue needs no
/// button of its own. The sheet opens on whichever side is playing. Picking
/// a track from the other side is what turns the stream over to it (#66);
/// the pills only change what is shown.
class LibrarySheet extends ConsumerStatefulWidget {
  const LibrarySheet({required this.controller, super.key});

  final ScrollController controller;

  @override
  ConsumerState<LibrarySheet> createState() => _LibrarySheetState();
}

class _LibrarySheetState extends ConsumerState<LibrarySheet> {
  late LibraryFilter _filter =
      ref.read(playbackSourceControllerProvider) == TrackSource.local
      ? LibraryFilter.local
      : LibraryFilter.catalogue;

  static const Map<LibraryFilter, String> _names = <LibraryFilter, String>{
    LibraryFilter.upNext: 'Up next',
    LibraryFilter.catalogue: 'PureLofi',
    LibraryFilter.local: 'My music',
    LibraryFilter.favorites: 'Favorites',
  };

  @override
  Widget build(BuildContext context) {
    final EdgeInsets sides = EdgeInsets.symmetric(
      horizontal: context.horizontalPadding,
    );

    return CustomScrollView(
      controller: widget.controller,
      slivers: <Widget>[
        // One line that always fits: favourites is a heart alone, and on a
        // narrow phone or under large text the row shrinks rather than
        // running off the edge of the sheet.
        SliverPadding(
          padding: EdgeInsets.fromLTRB(
            context.horizontalPadding,
            0,
            context.horizontalPadding,
            context.spaceM,
          ),
          sliver: SliverToBoxAdapter(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: AlignmentDirectional.centerStart,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  for (final LibraryFilter filter in LibraryFilter.values)
                    Padding(
                      padding: EdgeInsetsDirectional.only(end: context.spaceS),
                      child: _Pill(
                        label: _names[filter]!,
                        heart: filter == LibraryFilter.favorites,
                        selected: _filter == filter,
                        onTap: () => setState(() => _filter = filter),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
        SliverPadding(
          padding: sides,
          sliver: switch (_filter) {
            LibraryFilter.upNext => const UpNext(),
            LibraryFilter.catalogue => _Tracks(
              tracks:
                  ref.watch(trackListControllerProvider).value ??
                  const <TrackEntity>[],
              empty: 'No tracks yet.',
            ),
            LibraryFilter.local => const MyMusic(),
            LibraryFilter.favorites => _Tracks(
              tracks: ref.watch(favoriteTracksProvider),
              empty:
                  'Nothing marked yet. Tap ⋯ on a track, or the heart '
                  'beside the one playing.',
            ),
          },
        ),
        SliverToBoxAdapter(child: SizedBox(height: context.spaceXl)),
      ],
    );
  }
}

/// One filter, as a pill: filled in the foreground colour when chosen, a
/// quiet surface otherwise. Material's chip, with the outline taken off.
class _Pill extends StatelessWidget {
  const _Pill({
    required this.label,
    required this.heart,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool heart;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ColorScheme cs = Theme.of(context).colorScheme;
    final Color ink = selected ? cs.surface : cs.onSurface;

    return ChoiceChip(
      tooltip: label,
      showCheckmark: false,
      shape: const StadiumBorder(),
      side: BorderSide.none,
      backgroundColor: cs.surfaceContainerHigh,
      selectedColor: cs.onSurface,
      // The heart alone is the favourites pill: the shape says it, and
      // the tooltip names it for anyone who cannot see it.
      label: heart
          ? AppIcon(AppGlyph.heart, size: context.fontM, color: ink)
          : Text(
              label,
              style: TextStyle(
                color: ink,
                fontSize: context.fontM,
                fontWeight: FontWeight.w500,
              ),
            ),
      selected: selected,
      onSelected: (_) => onTap(),
    );
  }
}

/// PureLofi's tracks, or the marked ones. Tapping one plays it and goes
/// back to the room.
class _Tracks extends ConsumerWidget {
  const _Tracks({required this.tracks, required this.empty});

  final List<TrackEntity> tracks;
  final String empty;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (tracks.isEmpty) {
      return SliverToBoxAdapter(
        child: Text(
          empty,
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
            fontSize: context.fontS,
            height: 1.5,
          ),
        ),
      );
    }

    return SliverList.builder(
      itemCount: tracks.length,
      itemBuilder: (BuildContext context, int index) {
        final TrackEntity track = tracks[index];
        return TrackTile(
          track: track,
          onTap: () {
            Navigator.of(context).pop();
            unawaited(
              ref.read(playerControllerProvider.notifier).playTrack(track),
            );
          },
        );
      },
    );
  }
}

/// Opens the library.
Future<void> showLibrarySheet(BuildContext context) => showMusicSheet(
  context,
  (BuildContext context, ScrollController controller) =>
      LibrarySheet(controller: controller),
);
