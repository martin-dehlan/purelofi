import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../common/utils/responsive.dart';
import '../../../../common/widgets/app_icon.widget.dart';
import '../../../library/controller/library.controller.dart';
import '../../../library/domain/library_view.dart';
import '../../controller/artist.controller.dart';
import '../../controller/player.controller.dart';
import '../../controller/track.controller.dart';
import '../../domain/artist.entity.dart';
import '../../domain/track.entity.dart';
import 'artist_avatar.widget.dart';
import 'artist_sheet.widget.dart';
import 'music_sheet.dart';
import 'track_tile.widget.dart';

/// One search over all the music: PureLofi's tracks, the listener's own and
/// the artists, matched on title or name as it is typed.
///
/// Artists come first, as a few rows at most; then the tracks. Picking a
/// track plays it and goes back to the room, the way the library does.
class SearchSheet extends ConsumerStatefulWidget {
  const SearchSheet({required this.controller, super.key});

  final ScrollController controller;

  @override
  ConsumerState<SearchSheet> createState() => _SearchSheetState();
}

class _SearchSheetState extends ConsumerState<SearchSheet> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final ColorScheme cs = Theme.of(context).colorScheme;
    final String q = _query.trim().toLowerCase();
    final List<TrackEntity> all = <TrackEntity>[
      ...?ref.watch(trackListControllerProvider).value,
      ...?ref.watch(libraryControllerProvider).value,
    ];
    final List<TrackEntity> tracks = q.isEmpty
        ? const <TrackEntity>[]
        : searchTracks(all, q);
    final List<ArtistEntity> artists = q.isEmpty
        ? const <ArtistEntity>[]
        : ref
              .watch(playableArtistsProvider)
              .where((ArtistEntity a) => a.name.toLowerCase().contains(q))
              .toList();
    final EdgeInsets sides = EdgeInsets.symmetric(
      horizontal: context.horizontalPadding,
    );

    Widget heading(String text) => Padding(
      padding: EdgeInsets.only(top: context.spaceM, bottom: context.spaceXs),
      child: Text(
        text,
        style: TextStyle(
          color: cs.onSurface,
          fontSize: context.fontM,
          fontWeight: FontWeight.w600,
        ),
      ),
    );

    return CustomScrollView(
      controller: widget.controller,
      slivers: <Widget>[
        SliverPadding(
          padding: sides,
          sliver: SliverToBoxAdapter(
            child: SearchBar(
              autoFocus: true,
              hintText: 'Tracks and artists',
              onChanged: (String value) => setState(() => _query = value),
              elevation: const WidgetStatePropertyAll<double>(0),
              backgroundColor: WidgetStatePropertyAll<Color>(
                cs.surfaceContainerHighest,
              ),
              textStyle: WidgetStatePropertyAll<TextStyle>(
                TextStyle(color: cs.onSurface, fontSize: context.fontM),
              ),
              hintStyle: WidgetStatePropertyAll<TextStyle>(
                TextStyle(color: cs.onSurfaceVariant, fontSize: context.fontM),
              ),
              leading: AppIcon(
                AppGlyph.search,
                size: context.fontL,
                color: cs.onSurfaceVariant,
              ),
            ),
          ),
        ),
        if (q.isNotEmpty && tracks.isEmpty && artists.isEmpty)
          SliverPadding(
            padding: sides.copyWith(top: context.spaceL),
            sliver: SliverToBoxAdapter(
              child: Text(
                'Nothing matches "${_query.trim()}".',
                style: TextStyle(
                  color: cs.onSurfaceVariant,
                  fontSize: context.fontS,
                ),
              ),
            ),
          ),
        if (artists.isNotEmpty)
          SliverPadding(
            padding: sides,
            sliver: SliverList.list(
              children: <Widget>[
                heading('Artists'),
                for (final ArtistEntity artist in artists)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    horizontalTitleGap: context.spaceM,
                    leading: ArtistAvatar(
                      artist: artist,
                      size: context.screenWidth * 0.13,
                    ),
                    title: Text(
                      artist.name,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: context.fontM,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    subtitle: Text(
                      'Artist',
                      style: TextStyle(
                        color: cs.onSurfaceVariant,
                        fontSize: context.fontS,
                      ),
                    ),
                    onTap: () => showArtistSheet(context, artist.id),
                  ),
              ],
            ),
          ),
        if (tracks.isNotEmpty)
          SliverPadding(
            padding: sides,
            sliver: SliverMainAxisGroup(
              slivers: <Widget>[
                SliverToBoxAdapter(child: heading('Tracks')),
                SliverList.builder(
                  itemCount: tracks.length,
                  itemBuilder: (BuildContext context, int index) {
                    final TrackEntity track = tracks[index];
                    return TrackTile(
                      track: track,
                      onTap: () {
                        Navigator.of(
                          context,
                        ).popUntil((Route<dynamic> route) => route.isFirst);
                        unawaited(
                          ref
                              .read(playerControllerProvider.notifier)
                              .playTrack(track),
                        );
                      },
                    );
                  },
                ),
              ],
            ),
          ),
        SliverToBoxAdapter(child: SizedBox(height: context.spaceXl)),
      ],
    );
  }
}

/// Opens the search.
Future<void> showSearchSheet(BuildContext context) => showMusicSheet(
  context,
  (BuildContext context, ScrollController controller) =>
      SearchSheet(controller: controller),
);
