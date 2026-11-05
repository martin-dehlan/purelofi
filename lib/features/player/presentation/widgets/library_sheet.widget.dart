import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../common/utils/responsive.dart';
import '../../../../common/widgets/app_icon.widget.dart';
import '../../../library/presentation/widgets/my_music.widget.dart';
import '../../controller/downloads.controller.dart';
import '../../controller/favorites.controller.dart';
import '../../controller/collections.controller.dart';
import '../../controller/play_history.controller.dart';
import '../../controller/player.controller.dart';
import '../../controller/player.provider.dart';
import '../../controller/track.controller.dart';
import '../../controller/stats.controller.dart';
import '../../domain/listening_stats.dart';
import '../../domain/mood.entity.dart';
import '../../domain/playback_scope.dart';
import '../../domain/playlist.entity.dart';
import '../../domain/track.entity.dart';
import 'artist_list.widget.dart';
import 'artist_sheet.widget.dart';
import 'cached_picture.widget.dart';
import 'collection_page.widget.dart';
import 'library_scope.widget.dart';
import 'mini_player.widget.dart';
import 'playlist_actions_sheet.widget.dart';
import 'playlist_name_dialog.dart';
import 'search_results.widget.dart';
import 'stats_view.widget.dart';
import 'track_tile.widget.dart';
import '../../../../l10n/l10n.dart';

/// One kind of thing in the library. None chosen is the overview.
enum LibraryFilter { tracks, playlists, artists, downloaded, local }

/// A page that slides in over the library: an artist's, the favourites, or
/// what was played lately (#142).
class _LibraryPage {
  const _LibraryPage.artist(String this.artistId)
    : recent = false,
      stats = false,
      scope = null;
  const _LibraryPage.favorites()
    : artistId = null,
      recent = false,
      stats = false,
      scope = null;
  const _LibraryPage.recent()
    : artistId = null,
      recent = true,
      stats = false,
      scope = null;

  /// The week in listening (#151).
  const _LibraryPage.stats()
    : artistId = null,
      recent = false,
      stats = true,
      scope = null;

  /// A mood or one of the listener's playlists (#141).
  const _LibraryPage.collection(PlaybackScope this.scope)
    : artistId = null,
      recent = false,
      stats = false;

  final String? artistId;
  final bool recent;
  final bool stats;
  final PlaybackScope? scope;
}

/// "Your Library", the way music apps lay theirs out (#110): a big title
/// with search beside it, a row of filters, and under them the favourites
/// pinned on top and every artist, or the one kind a filter picked.
///
/// An artist or the favourites slide in over the list, with a way back,
/// rather than stacking another sheet on it; the list is as it was when
/// they slide out again. Search happens here too. The track playing sits
/// at the foot the whole time, so picking a track never has to close it.
class LibrarySheet extends ConsumerStatefulWidget {
  const LibrarySheet({super.key});

  @override
  ConsumerState<LibrarySheet> createState() => _LibrarySheetState();
}

class _LibrarySheetState extends ConsumerState<LibrarySheet>
    with SingleTickerProviderStateMixin {
  LibraryFilter? _filter;

  /// The search field is open; [_query] is what is typed in it.
  bool _searching = false;
  String _query = '';

  /// The page over the list, and how far it has slid in.
  _LibraryPage? _page;
  late final AnimationController _slide = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 280),
  )..addStatusListener((_) => setState(() {}));

  /// What each filter is called, in the listener's language (#140).
  static String nameOf(BuildContext context, LibraryFilter filter) =>
      switch (filter) {
        LibraryFilter.tracks => context.l10n.tracks,
        LibraryFilter.playlists => context.l10n.playlists,
        LibraryFilter.artists => context.l10n.artists,
        LibraryFilter.downloaded => context.l10n.downloaded,
        LibraryFilter.local => context.l10n.myMusic,
      };

  @override
  void dispose() {
    _slide.dispose();
    super.dispose();
  }

  /// A filter tapped again lets go of it, back to the overview.
  void _pick(LibraryFilter filter) =>
      setState(() => _filter = _filter == filter ? null : filter);

  void _open(_LibraryPage page) {
    setState(() => _page = page);
    unawaited(_slide.forward(from: 0));
  }

  Future<void> _back() async {
    await _slide.reverse();
    if (mounted) setState(() => _page = null);
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme cs = Theme.of(context).colorScheme;
    final _LibraryPage? page = _page;
    // Once the page covers it, the list steps out of the way entirely; it
    // keeps where it was scrolled to for the way back.
    final bool covered = page != null && _slide.isCompleted;

    return LibraryScope(
      openArtist: (String artistId) => _open(_LibraryPage.artist(artistId)),
      child: PopScope(
        canPop: page == null,
        onPopInvokedWithResult: (bool didPop, Object? _) {
          if (!didPop) unawaited(_back());
        },
        child: Column(
          children: <Widget>[
            Expanded(
              child: Stack(
                children: <Widget>[
                  Offstage(offstage: covered, child: _home(context)),
                  if (page != null)
                    SlideTransition(
                      position:
                          Tween<Offset>(
                            begin: const Offset(1, 0),
                            end: Offset.zero,
                          ).animate(
                            CurvedAnimation(
                              parent: _slide,
                              curve: Curves.easeOutCubic,
                            ),
                          ),
                      child: _PageFrame(
                        page: page,
                        slide: _slide,
                        onBack: () => unawaited(_back()),
                        background:
                            Theme.of(
                              context,
                            ).bottomSheetTheme.backgroundColor ??
                            cs.surfaceContainerLow,
                      ),
                    ),
                ],
              ),
            ),
            const MiniPlayer(),
          ],
        ),
      ),
    );
  }

  Widget _home(BuildContext context) {
    final ColorScheme cs = Theme.of(context).colorScheme;
    final LibraryFilter? filter = _filter;
    final bool searching = _searching;
    final List<TrackEntity> catalogue =
        ref.watch(trackListControllerProvider).value ?? const <TrackEntity>[];
    final Downloads downloads =
        ref.watch(downloadsControllerProvider).value ?? const Downloads();
    // Downloaded is a filter only once there is something downloaded.
    final List<LibraryFilter> filters = <LibraryFilter>[
      for (final LibraryFilter f in LibraryFilter.values)
        if (f != LibraryFilter.downloaded ||
            downloads.done.isNotEmpty ||
            filter == f)
          f,
    ];

    return CustomScrollView(
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
                          context.l10n.yourLibrary,
                          style: TextStyle(
                            color: cs.onSurface,
                            fontSize: context.fontXl,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      IconButton(
                        tooltip: context.l10n.search,
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
                  for (final LibraryFilter f in filters) ...<Widget>[
                    _FilterPill(
                      label: nameOf(context, f),
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
                  null => _Overview(
                    onFavorites: () => _open(const _LibraryPage.favorites()),
                    onRecent: () => _open(const _LibraryPage.recent()),
                    onPlaylists: () =>
                        setState(() => _filter = LibraryFilter.playlists),
                    onStats: () => _open(const _LibraryPage.stats()),
                    onCollection: (PlaybackScope scope) =>
                        _open(_LibraryPage.collection(scope)),
                  ),
                  LibraryFilter.playlists => _Playlists(
                    onCollection: (PlaybackScope scope) =>
                        _open(_LibraryPage.collection(scope)),
                  ),
                  LibraryFilter.tracks => _Tracks(
                    tracks: catalogue,
                    empty: context.l10n.noTracksYet,
                  ),
                  LibraryFilter.artists => const ArtistList(),
                  LibraryFilter.downloaded => _Tracks(
                    tracks: catalogue.where(downloads.has).toList(),
                    empty: context.l10n.nothingDownloadedYet,
                  ),
                  LibraryFilter.local => const MyMusic(),
                },
        ),
        SliverToBoxAdapter(child: SizedBox(height: context.spaceXl)),
      ],
    );
  }
}

/// A page slid in over the library: a way back on top, the page below.
/// Pulled to the right it follows the finger, and let go far or fast
/// enough it goes back, as pages do on a phone.
class _PageFrame extends StatelessWidget {
  const _PageFrame({
    required this.page,
    required this.slide,
    required this.onBack,
    required this.background,
  });

  final _LibraryPage page;
  final AnimationController slide;
  final VoidCallback onBack;
  final Color background;

  @override
  Widget build(BuildContext context) {
    final ColorScheme cs = Theme.of(context).colorScheme;
    final String? artistId = page.artistId;

    return GestureDetector(
      onHorizontalDragUpdate: (DragUpdateDetails details) =>
          slide.value -= (details.primaryDelta ?? 0) / context.screenWidth,
      onHorizontalDragEnd: (DragEndDetails details) {
        if ((details.primaryVelocity ?? 0) > 300 || slide.value < 0.6) {
          onBack();
        } else {
          unawaited(slide.forward());
        }
      },
      // Material, not a plain fill: the rows' ink lands on it.
      child: Material(
        color: background,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Padding(
              padding: EdgeInsets.symmetric(horizontal: context.spaceXs),
              child: Row(
                children: <Widget>[
                  IconButton(
                    tooltip: context.l10n.back,
                    onPressed: onBack,
                    icon: AppIcon(
                      AppGlyph.back,
                      size: context.fontXl,
                      color: cs.onSurface,
                    ),
                  ),
                  if (artistId == null)
                    Flexible(
                      child: Text(
                        page.scope?.title ??
                            (page.recent
                                ? context.l10n.recentlyPlayed
                                : page.stats
                                ? context.l10n.stats
                                : context.l10n.favorites),
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: cs.onSurface,
                          fontSize: context.fontXl,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            Expanded(
              child: artistId != null
                  ? ArtistSheet(artistId: artistId)
                  : page.scope != null
                  ? CollectionPage(scope: page.scope!, onGone: onBack)
                  : page.recent
                  ? const _RecentPage()
                  : page.stats
                  ? SingleChildScrollView(
                      padding: EdgeInsets.symmetric(
                        horizontal: context.horizontalPadding,
                        vertical: context.spaceM,
                      ),
                      child: const StatsView(),
                    )
                  : const _FavoritesPage(),
            ),
          ],
        ),
      ),
    );
  }
}

/// The marked tracks, as a page of their own.
class _FavoritesPage extends ConsumerWidget {
  const _FavoritesPage();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return CustomScrollView(
      slivers: <Widget>[
        SliverPadding(
          padding: EdgeInsets.fromLTRB(
            context.horizontalPadding,
            context.spaceS,
            context.horizontalPadding,
            context.spaceXl,
          ),
          sliver: _Tracks(
            tracks: ref.watch(favoriteTracksProvider),
            empty: context.l10n.noFavoritesYet,
          ),
        ),
      ],
    );
  }
}

/// What was played lately, each track once, newest first (#142).
class _RecentPage extends ConsumerWidget {
  const _RecentPage();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return CustomScrollView(
      slivers: <Widget>[
        SliverPadding(
          padding: EdgeInsets.fromLTRB(
            context.horizontalPadding,
            context.spaceS,
            context.horizontalPadding,
            context.spaceXl,
          ),
          sliver: _Tracks(
            tracks: ref.watch(recentlyPlayedTracksProvider),
            empty: context.l10n.nothingPlayedYet,
          ),
        ),
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
            hintText: context.l10n.tracksAndArtists,
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
          child: Text(
            context.l10n.cancel,
            style: TextStyle(fontSize: context.fontM),
          ),
        ),
      ],
    );
  }
}

/// Everything at a glance: the favourites pinned on top in the accent, as
/// music apps set liked songs apart, then every artist.
class _Overview extends ConsumerWidget {
  const _Overview({
    required this.onFavorites,
    required this.onRecent,
    required this.onPlaylists,
    required this.onStats,
    required this.onCollection,
  });

  final VoidCallback onFavorites;
  final VoidCallback onRecent;

  /// Opens the Playlists tab: the overview holds one row for them all, so
  /// it stays this short however many there are.
  final VoidCallback onPlaylists;

  /// Opens the week in listening (#151), as History opens what was heard.
  final VoidCallback onStats;

  /// Opens a mood or a playlist (#141).
  final ValueChanged<PlaybackScope> onCollection;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ColorScheme cs = Theme.of(context).colorScheme;
    final int favorites = ref.watch(favoriteTracksProvider).length;
    final List<TrackEntity> recent = ref.watch(recentlyPlayedTracksProvider);
    final ListeningStats week =
        ref.watch(weekStatsProvider).value ?? ListeningStats.empty;
    final List<MoodEntity> moods =
        ref.watch(moodsProvider).value ?? const <MoodEntity>[];
    final List<PlaylistEntity> playlists =
        ref.watch(playlistsProvider).value ?? const <PlaylistEntity>[];
    final double tile = _Tile.sizeFor(context);

    return SliverList.list(
      children: <Widget>[
        // PureLofi's moods first, as a row of covers to swipe (#141).
        if (moods.isNotEmpty) ...<Widget>[
          SizedBox(
            height: tile * 1.6 + context.fontS * 2,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: moods.length,
              separatorBuilder: (_, _) => SizedBox(width: context.spaceM),
              itemBuilder: (BuildContext context, int i) {
                final MoodEntity mood = moods[i];
                return _MoodCard(
                  mood: mood,
                  size: tile * 1.6,
                  onTap: () => onCollection(
                    PlaybackScope(
                      kind: ScopeKind.mood,
                      id: mood.id,
                      title: mood.title,
                    ),
                  ),
                );
              },
            ),
          ),
          SizedBox(height: context.spaceM),
        ],
        _Row(
          tile: _Tile(
            background: cs.primary,
            child: AppIcon(
              AppGlyph.heart,
              size: context.fontXl,
              color: cs.onPrimary,
            ),
          ),
          title: context.l10n.favorites,
          subtitle: context.l10n.trackCount(favorites),
          onTap: onFavorites,
        ),
        // Only once something was heard: an empty row is a promise.
        if (recent.isNotEmpty)
          _Row(
            tile: _Tile(
              background: cs.surfaceContainerHighest,
              child: AppIcon(
                AppGlyph.timer,
                size: context.fontXl,
                color: cs.onSurface,
              ),
            ),
            title: context.l10n.recentlyPlayed,
            subtitle: recent.first.title,
            onTap: onRecent,
          ),
        // One row for the listener's own playlists (#141), the newest
        // named under it; the list itself is the Playlists tab.
        _Row(
          tile: _Tile(
            background: cs.secondaryContainer,
            child: AppIcon(
              AppGlyph.queue,
              size: context.fontXl,
              color: cs.onSecondaryContainer,
            ),
          ),
          title: context.l10n.playlists,
          subtitle: playlists.isEmpty
              ? context.l10n.yourOwnList
              : playlists.map((PlaylistEntity p) => p.name).take(3).join(' · '),
          onTap: onPlaylists,
        ),
        _Row(
          tile: _Tile(
            background: cs.surfaceContainerHighest,
            child: AppIcon(
              AppGlyph.sort,
              size: context.fontXl,
              color: cs.onSurface,
            ),
          ),
          title: context.l10n.stats,
          subtitle: week.isEmpty
              ? context.l10n.thisWeek
              : context.l10n.timeThisWeek(listeningTimeLabel(week.total)),
          onTap: onStats,
        ),
        // Artists have a tab of their own; listed here they would bury the
        // rest as soon as there are more than a few.
      ],
    );
  }
}

/// The Playlists tab (#141): the listener's own lists, newest change first,
/// and a row to start a new one.
class _Playlists extends ConsumerWidget {
  const _Playlists({required this.onCollection});

  final ValueChanged<PlaybackScope> onCollection;

  static PlaybackScope scopeOf(PlaylistEntity playlist) => PlaybackScope(
    kind: ScopeKind.playlist,
    id: playlist.id,
    title: playlist.name,
  );

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ColorScheme cs = Theme.of(context).colorScheme;
    final List<PlaylistEntity> playlists =
        ref.watch(playlistsProvider).value ?? const <PlaylistEntity>[];

    return SliverList.list(
      children: <Widget>[
        for (final PlaylistEntity playlist in playlists)
          _Row(
            tile: _Tile(
              background: cs.secondaryContainer,
              child: AppIcon(
                AppGlyph.queue,
                size: context.fontXl,
                color: cs.onSecondaryContainer,
              ),
            ),
            title: playlist.name,
            subtitle: playlist.items.length == 1
                ? context.l10n.playlistOneTrack
                : context.l10n.playlistTrackCount(playlist.items.length),
            // A tap plays it; the ⋯ holds the rest.
            onTap: () => unawaited(
              ref
                  .read(playerControllerProvider.notifier)
                  .playScope(scopeOf(playlist)),
            ),
            trailing: IconButton(
              tooltip: context.l10n.moreFor(playlist.name),
              onPressed: () => unawaited(
                showPlaylistActionsSheet(
                  context,
                  playlist,
                  onEdit: () => onCollection(scopeOf(playlist)),
                ),
              ),
              icon: AppIcon(
                AppGlyph.more,
                size: context.fontL,
                color: cs.onSurfaceVariant,
              ),
            ),
          ),
        _Row(
          tile: _Tile(
            background: cs.surfaceContainerHighest,
            child: AppIcon(
              AppGlyph.add,
              size: context.fontXl,
              color: cs.onSurface,
            ),
          ),
          title: context.l10n.newPlaylist,
          subtitle: context.l10n.yourOwnList,
          onTap: () async {
            final String? name = await askPlaylistName(context);
            if (name == null) return;
            await ref.read(playlistRepositoryProvider).create(name);
          },
        ),
      ],
    );
  }
}

/// One of PureLofi's moods: its cover, square, with its name under it.
class _MoodCard extends StatelessWidget {
  const _MoodCard({
    required this.mood,
    required this.size,
    required this.onTap,
  });

  final MoodEntity mood;
  final double size;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ColorScheme cs = Theme.of(context).colorScheme;
    final String? cover = mood.coverUrl;
    final Widget plain = ColoredBox(
      color: cs.tertiaryContainer,
      child: Center(
        child: AppIcon(
          AppGlyph.scene,
          size: size * 0.3,
          color: cs.onTertiaryContainer,
        ),
      ),
    );

    return Semantics(
      button: true,
      label: context.l10n.moodLabel(mood.title),
      excludeSemantics: true,
      child: GestureDetector(
        onTap: onTap,
        child: SizedBox(
          width: size,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              ClipRRect(
                borderRadius: BorderRadius.circular(size * 0.08),
                child: SizedBox.square(
                  dimension: size,
                  child: cover == null
                      ? plain
                      : CachedPicture(url: cover, fallback: plain),
                ),
              ),
              SizedBox(height: context.spaceXs),
              Text(
                mood.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: cs.onSurface,
                  fontSize: context.fontS,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
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
    this.trailing,
  });

  final Widget tile;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  /// At the end of the row, such as a playlist's ⋯.
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final ColorScheme cs = Theme.of(context).colorScheme;

    // Not a ListTile: that holds its leading widget to 56 px high, and
    // the tile is wider than that on most phones, so it came out squashed.
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: context.spaceS),
        child: Row(
          children: <Widget>[
            tile,
            SizedBox(width: context.spaceM),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    title,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: cs.onSurface,
                      fontSize: context.fontM,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    subtitle,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: cs.onSurfaceVariant,
                      fontSize: context.fontS,
                    ),
                  ),
                ],
              ),
            ),
            ?trailing,
          ],
        ),
      ),
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
      tooltip: context.l10n.all,
      shape: const CircleBorder(),
      side: BorderSide.none,
      backgroundColor: cs.surfaceContainerHigh,
      padding: EdgeInsets.all(context.spaceS),
      label: AppIcon(AppGlyph.close, size: context.fontM, color: cs.onSurface),
      onPressed: onTap,
    );
  }
}

/// PureLofi's tracks, or the marked ones. Tapping one plays it; the
/// library stays open, as in music apps.
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
          onTap: () => unawaited(
            ref.read(playerControllerProvider.notifier).playTrack(track),
          ),
        );
      },
    );
  }
}

/// Opens the library, nearly all the way up, as a page of its own.
Future<void> showLibrarySheet(BuildContext context) =>
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      useSafeArea: true,
      barrierColor: Theme.of(context).colorScheme.scrim.withValues(alpha: 0.25),
      builder: (BuildContext context) =>
          const FractionallySizedBox(heightFactor: 0.92, child: LibrarySheet()),
    );
