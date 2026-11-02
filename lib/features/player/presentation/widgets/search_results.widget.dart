import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../common/utils/responsive.dart';
import '../../../library/controller/library.controller.dart';
import '../../../library/domain/library_view.dart';
import '../../controller/artist.controller.dart';
import '../../controller/player.controller.dart';
import '../../controller/track.controller.dart';
import '../../domain/artist.entity.dart';
import '../../domain/track.entity.dart';
import 'artist_avatar.widget.dart';
import 'library_scope.widget.dart';
import 'track_tile.widget.dart';

/// One search over all the music: PureLofi's tracks, the listener's own and
/// the artists, matched on title or name as it is typed.
///
/// Shown inside the library, in place of its lists, while its search field
/// is open — no sheet of its own. Artists come first, then the tracks.
/// Picking a track plays it and leaves the results open, the way the
/// library does.
///
/// A group of slivers, so it scrolls as part of the library.
class SearchResults extends ConsumerWidget {
  const SearchResults({required this.query, super.key});

  final String query;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ColorScheme cs = Theme.of(context).colorScheme;
    final String q = query.trim().toLowerCase();
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

    return SliverMainAxisGroup(
      slivers: <Widget>[
        if (q.isNotEmpty && tracks.isEmpty && artists.isEmpty)
          SliverToBoxAdapter(
            child: Text(
              'Nothing matches "${query.trim()}".',
              style: TextStyle(
                color: cs.onSurfaceVariant,
                fontSize: context.fontS,
              ),
            ),
          ),
        if (artists.isNotEmpty)
          SliverList.list(
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
                  onTap: () => unawaited(openArtistPage(context, artist.id)),
                ),
            ],
          ),
        if (tracks.isNotEmpty) ...<Widget>[
          SliverToBoxAdapter(child: heading('Tracks')),
          SliverList.builder(
            itemCount: tracks.length,
            itemBuilder: (BuildContext context, int index) {
              final TrackEntity track = tracks[index];
              return TrackTile(
                track: track,
                onTap: () => unawaited(
                  ref.read(playerControllerProvider.notifier).playTrack(track),
                ),
              );
            },
          ),
        ],
      ],
    );
  }
}
