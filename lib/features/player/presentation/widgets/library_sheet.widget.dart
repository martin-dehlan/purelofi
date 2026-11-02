import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../common/utils/app_fonts.dart';
import '../../../../common/utils/responsive.dart';
import '../../../../common/widgets/app_icon.widget.dart';
import '../../../library/controller/library.controller.dart';
import '../../../library/presentation/widgets/my_music.widget.dart';
import '../../controller/artist.controller.dart';
import '../../controller/favorites.controller.dart';
import '../../controller/player.controller.dart';
import '../../controller/track.controller.dart';
import '../../domain/artist.entity.dart';
import '../../domain/track.entity.dart';
import 'artist_avatar.widget.dart';
import 'artist_list.widget.dart';
import 'artist_sheet.widget.dart';
import 'music_sheet.dart';
import 'search_results.widget.dart';
import 'track_tile.widget.dart';

/// One kind of thing in the library. None chosen is the overview.
enum LibraryFilter { tracks, artists, favorites, local }

/// "Your Library", the way music apps lay theirs out (#110): a big title
/// with search beside it, a row of filters big enough to hit, and under
/// them either everything at a glance — the collections first, then the
/// artists — or the one kind the filter picked.
///
/// Search happens here too: the magnifier turns the title into a search
/// field and the lists into results, and Cancel turns them back.
///
/// It opens all the way, as a page; the queue has its own sheet.
class LibrarySheet extends ConsumerStatefulWidget {
  const LibrarySheet({required this.controller, super.key});

  final ScrollController controller;

  @override
  ConsumerState<LibrarySheet> createState() => _LibrarySheetState();
}

class _LibrarySheetState extends ConsumerState<LibrarySheet> {
  LibraryFilter? _filter;

  /// The search field is open; [_query] is what is typed in it.
  bool _searching = false;
  String _query = '';

  static const Map<LibraryFilter, String> names = <LibraryFilter, String>{
    LibraryFilter.tracks: 'Tracks',
    LibraryFilter.artists: 'Artists',
    LibraryFilter.favorites: 'Favorites',
    LibraryFilter.local: 'My music',
  };

  /// A filter tapped again lets go of it, back to the overview.
  void _pick(LibraryFilter filter) =>
      setState(() => _filter = _filter == filter ? null : filter);

  @override
  Widget build(BuildContext context) {
    final ColorScheme cs = Theme.of(context).colorScheme;
    final LibraryFilter? filter = _filter;
    final bool searching = _searching;

    return CustomScrollView(
      controller: widget.controller,
      slivers: <Widget>[
        SliverPadding(
          padding: EdgeInsets.symmetric(horizontal: context.horizontalPadding),
          sliver: SliverToBoxAdapter(
            child: searching
                ? _SearchField(
                    onChanged: (String value) => setState(() => _query = value),
                    onCancel: () => setState(() {
                      _searching = false;
                      _query = '';
                    }),
                  )
                : Row(
                    children: <Widget>[
                      Expanded(
                        child: Text(
                          'Your Library',
                          style: TextStyle(
                            color: cs.onSurface,
                            fontSize: context.fontXl,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      IconButton(
                        tooltip: 'Search',
                        iconSize: context.fontXl,
                        icon: AppIcon(
                          AppGlyph.search,
                          size: context.fontXl,
                          color: cs.onSurface,
                        ),
                        onPressed: () => setState(() => _searching = true),
                      ),
                    ],
                  ),
          ),
        ),
        SliverToBoxAdapter(child: SizedBox(height: context.spaceS)),
        // The filters scroll sideways rather than shrink: they stay the size
        // a thumb needs, however narrow the phone or large the text. A
        // search runs over everything, so they step aside for it.
        if (!searching)
          SliverToBoxAdapter(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: EdgeInsets.symmetric(
                horizontal: context.horizontalPadding,
              ),
              child: Row(
                children: <Widget>[
                  if (filter != null) ...<Widget>[
                    _ClearFilter(onTap: () => setState(() => _filter = null)),
                    SizedBox(width: context.spaceS),
                  ],
                  for (final LibraryFilter f
                      in LibraryFilter.values) ...<Widget>[
                    _FilterPill(
                      label: names[f]!,
                      selected: filter == f,
                      onTap: () => _pick(f),
                    ),
                    SizedBox(width: context.spaceS),
                  ],
                ],
              ),
            ),
          ),
        SliverToBoxAdapter(child: SizedBox(height: context.spaceM)),
        SliverPadding(
          padding: EdgeInsets.symmetric(horizontal: context.horizontalPadding),
          sliver: searching
              ? SearchResults(query: _query)
              : switch (filter) {
                  null => _Overview(onPick: _pick),
                  LibraryFilter.tracks => _Tracks(
                    tracks:
                        ref.watch(trackListControllerProvider).value ??
                        const <TrackEntity>[],
                    empty: 'No tracks yet.',
                  ),
                  LibraryFilter.artists => const ArtistList(),
                  LibraryFilter.favorites => _Tracks(
                    tracks: ref.watch(favoriteTracksProvider),
                    empty:
                        'Nothing marked yet. Tap ⋯ on a track, or the heart '
                        'beside the one playing.',
                  ),
                  LibraryFilter.local => const MyMusic(),
                },
        ),
        SliverToBoxAdapter(child: SizedBox(height: context.spaceXl)),
      ],
    );
  }
}

/// The library's search field, with Cancel beside it to close it.
class _SearchField extends StatelessWidget {
  const _SearchField({required this.onChanged, required this.onCancel});

  final ValueChanged<String> onChanged;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final ColorScheme cs = Theme.of(context).colorScheme;

    return Row(
      children: <Widget>[
        Expanded(
          child: SearchBar(
            autoFocus: true,
            hintText: 'Tracks and artists',
            onChanged: onChanged,
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
        TextButton(
          onPressed: onCancel,
          style: TextButton.styleFrom(foregroundColor: cs.onSurface),
          child: Text('Cancel', style: TextStyle(fontSize: context.fontM)),
        ),
      ],
    );
  }
}

/// Everything at a glance: the three collections, then every artist.
class _Overview extends ConsumerWidget {
  const _Overview({required this.onPick});

  final void Function(LibraryFilter filter) onPick;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ColorScheme cs = Theme.of(context).colorScheme;
    final int catalogue =
        (ref.watch(trackListControllerProvider).value ?? const <TrackEntity>[])
            .length;
    final int favorites = ref.watch(favoriteTracksProvider).length;
    final int local =
        (ref.watch(libraryControllerProvider).value ?? const <TrackEntity>[])
            .length;
    final List<ArtistEntity> artists = ref.watch(playableArtistsProvider);

    String tracks(int n) => n == 1 ? '1 track' : '$n tracks';

    return SliverList.list(
      children: <Widget>[
        _Row(
          tile: _Tile(
            background: cs.surfaceContainerHigh,
            child: Text(
              'P',
              style: TextStyle(
                color: cs.onSurface,
                fontFamily: AppFonts.wordmark,
                fontSize: context.fontXl,
              ),
            ),
          ),
          title: 'PureLofi',
          subtitle: 'Collection · ${tracks(catalogue)}',
          onTap: () => onPick(LibraryFilter.tracks),
        ),
        // The marked tracks in the accent, the one coloured tile here, as
        // music apps set their liked songs apart.
        _Row(
          tile: _Tile(
            background: cs.primary,
            child: AppIcon(
              AppGlyph.heart,
              size: context.fontXl,
              color: cs.onPrimary,
            ),
          ),
          title: 'Favorites',
          subtitle: 'Collection · ${tracks(favorites)}',
          onTap: () => onPick(LibraryFilter.favorites),
        ),
        _Row(
          tile: _Tile(
            background: cs.surfaceContainerHigh,
            child: AppIcon(
              AppGlyph.storage,
              size: context.fontXl,
              color: cs.onSurface,
            ),
          ),
          title: 'My music',
          subtitle: 'On this phone · ${tracks(local)}',
          onTap: () => onPick(LibraryFilter.local),
        ),
        for (final ArtistEntity artist in artists)
          _Row(
            tile: ArtistAvatar(artist: artist, size: _Tile.sizeFor(context)),
            title: artist.name,
            subtitle: 'Artist',
            onTap: () => unawaited(showArtistSheet(context, artist.id)),
          ),
      ],
    );
  }
}

/// One entry of the overview: a picture, a name and what it is.
class _Row extends StatelessWidget {
  const _Row({
    required this.tile,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final Widget tile;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ColorScheme cs = Theme.of(context).colorScheme;

    return ListTile(
      contentPadding: EdgeInsets.zero,
      horizontalTitleGap: context.spaceM,
      minVerticalPadding: context.spaceS,
      leading: tile,
      title: Text(
        title,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(fontSize: context.fontM, fontWeight: FontWeight.w600),
      ),
      subtitle: Text(
        subtitle,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(color: cs.onSurfaceVariant, fontSize: context.fontS),
      ),
      onTap: onTap,
    );
  }
}

/// The square picture of a collection, the size of a track's cover.
class _Tile extends StatelessWidget {
  const _Tile({required this.background, required this.child});

  final Color background;
  final Widget child;

  static double sizeFor(BuildContext context) => context.screenWidth * 0.15;

  @override
  Widget build(BuildContext context) {
    final double size = sizeFor(context);

    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(size * 0.12),
      ),
      child: child,
    );
  }
}

/// One filter: filled in the foreground colour when chosen, a quiet surface
/// otherwise. Material's chip, with the outline taken off.
class _FilterPill extends StatelessWidget {
  const _FilterPill({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ColorScheme cs = Theme.of(context).colorScheme;

    return ChoiceChip(
      tooltip: label,
      showCheckmark: false,
      shape: const StadiumBorder(),
      side: BorderSide.none,
      backgroundColor: cs.surfaceContainerHigh,
      selectedColor: cs.onSurface,
      padding: EdgeInsets.symmetric(
        horizontal: context.spaceS,
        vertical: context.spaceS,
      ),
      label: Text(
        label,
        style: TextStyle(
          color: selected ? cs.surface : cs.onSurface,
          fontSize: context.fontM,
          fontWeight: FontWeight.w500,
        ),
      ),
      selected: selected,
      onSelected: (_) => onTap(),
    );
  }
}

/// The round × ahead of a chosen filter: back to everything.
class _ClearFilter extends StatelessWidget {
  const _ClearFilter({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ColorScheme cs = Theme.of(context).colorScheme;

    return ActionChip(
      tooltip: 'All',
      shape: const CircleBorder(),
      side: BorderSide.none,
      backgroundColor: cs.surfaceContainerHigh,
      padding: EdgeInsets.all(context.spaceS),
      label: AppIcon(AppGlyph.close, size: context.fontM, color: cs.onSurface),
      onPressed: onTap,
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

/// Opens the library, all the way up.
Future<void> showLibrarySheet(BuildContext context) => showMusicSheet(
  context,
  (BuildContext context, ScrollController controller) =>
      LibrarySheet(controller: controller),
  initialSize: 0.92,
);
