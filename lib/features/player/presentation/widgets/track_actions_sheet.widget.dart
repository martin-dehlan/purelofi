import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../../../../common/utils/app_links.dart';
import '../../../../common/utils/responsive.dart';
import '../../../../common/widgets/app_icon.widget.dart';
import '../../../../common/widgets/menu_group.widget.dart';
import '../../../../common/widgets/menu_row.widget.dart';
import '../../../library/controller/library.controller.dart';
import '../../../library/presentation/widgets/remove_track_dialog.dart';
import '../../../pro/controller/pro.controller.dart';
import '../../../pro/presentation/widgets/paywall_sheet.widget.dart';
import '../../controller/artist.controller.dart';
import '../../controller/downloads.controller.dart';
import '../../controller/favorites.controller.dart';
import '../../controller/player.controller.dart';
import '../../domain/artist.entity.dart';
import '../../domain/artist_link.dart';
import '../../domain/track.entity.dart';
import 'add_to_playlist_sheet.widget.dart';
import 'artist_sheet.widget.dart';
import 'support_artist_button.widget.dart';
import 'library_scope.widget.dart';
import 'track_cover.widget.dart';

/// Everything that can be done with one track, in the same grouped cards as
/// the menu: the track itself on top, then marking and queueing it, then
/// passing it on or telling us something is wrong with it.
///
/// The listener's own files are theirs: no mark, nothing to share or report,
/// only a way to take them out again.
class TrackActionsSheet extends ConsumerWidget {
  const TrackActionsSheet({
    required this.track,
    super.key,
    this.onShare = _share,
    this.openArtist,
  });

  final TrackEntity track;

  /// Opens the artist's page in the library this menu was opened from;
  /// none outside it, where the page is a sheet of its own.
  final void Function(String artistId)? openArtist;

  /// Opens the share sheet; tests pass their own.
  final Future<void> Function(TrackEntity track) onShare;

  static Future<void> _share(TrackEntity track) async {
    await SharePlus.instance.share(
      ShareParams(
        text: 'Listening to "${track.title}" on PureLofi. ${AppLinks.home}',
        subject: track.title,
      ),
    );
  }

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

    final String? artistId = isCatalogue ? track.artistId : null;
    final ArtistEntity? artist = artistId == null
        ? null
        : ref.watch(artistByIdProvider(artistId));
    final Downloads downloads =
        ref.watch(downloadsControllerProvider).value ?? const Downloads();
    final bool downloadsOpen = ref.watch(downloadsOpenProvider);
    final DownloadsController downloader = ref.read(
      downloadsControllerProvider.notifier,
    );
    // The sheet's own context goes with it; what opens next opens from the
    // navigator's.
    final NavigatorState navigator = Navigator.of(context);

    // Closes the sheet, then does what the row is for.
    VoidCallback then(FutureOr<void> Function() action) => () {
      Navigator.of(context).pop();
      unawaited(Future<void>.sync(action));
    };

    return SafeArea(
      child: SingleChildScrollView(
        padding: EdgeInsets.only(bottom: context.spaceM),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            MenuGroup(
              children: <Widget>[
                Padding(
                  padding: EdgeInsets.all(context.spaceM),
                  child: Row(
                    children: <Widget>[
                      TrackCover(
                        track: track,
                        size: context.screenWidth * 0.15,
                      ),
                      SizedBox(width: context.spaceM),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text(
                              track.title,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: cs.onSurface,
                                fontSize: context.fontL,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            Text(
                              track.artistName,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: cs.onSurfaceVariant,
                                fontSize: context.fontS,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            SizedBox(height: context.spaceM),
            MenuGroup(
              children: <Widget>[
                if (isCatalogue)
                  MenuRow(
                    glyph: isFavorite ? AppGlyph.heart : AppGlyph.heartOutline,
                    title: isFavorite
                        ? 'Remove from favorites'
                        : 'Add to favorites',
                    onTap: then(
                      () => ref
                          .read(favoritesControllerProvider.notifier)
                          .toggle(track.id),
                    ),
                  ),
                MenuRow(
                  glyph: AppGlyph.next,
                  title: 'Play next',
                  onTap: then(() => player.queueNext(track)),
                ),
                MenuRow(
                  glyph: AppGlyph.queue,
                  title: 'Add to queue',
                  onTap: then(() => player.addToQueue(track)),
                ),
                MenuRow(
                  glyph: AppGlyph.add,
                  title: 'Add to playlist',
                  onTap: then(
                    () => showAddToPlaylistSheet(navigator.context, track),
                  ),
                ),
                if (isCatalogue)
                  if (downloads.isLoading(track))
                    const MenuRow(
                      glyph: AppGlyph.download,
                      title: 'Downloading…',
                      onTap: null,
                    )
                  else if (downloads.has(track))
                    MenuRow(
                      glyph: AppGlyph.download,
                      title: 'Remove download',
                      subtitle: 'Plays offline now',
                      onTap: then(
                        () => downloader.remove(<TrackEntity>[track]),
                      ),
                    )
                  else
                    MenuRow(
                      glyph: AppGlyph.download,
                      title: 'Download',
                      subtitle: downloadsOpen
                          ? 'To listen offline'
                          : 'With Pro',
                      onTap: downloadsOpen
                          ? then(
                              () => downloader.download(<TrackEntity>[track]),
                            )
                          : then(
                              () => showPaywallSheet(
                                navigator.context,
                                source: 'download',
                              ),
                            ),
                    ),
                if (artistId != null)
                  MenuRow(
                    glyph: AppGlyph.account,
                    title: 'Go to artist',
                    subtitle: track.artist,
                    onTap: then(
                      () => openArtist != null
                          ? openArtist!(artistId)
                          : showArtistSheet(navigator.context, artistId),
                    ),
                  ),
                // Straight to the artist, when they take support (#152).
                if (artist?.supportUrl != null)
                  MenuRow(
                    glyph: AppGlyph.heart,
                    title: 'Support this artist',
                    subtitle: 'Opens ${supportPlatform(artist!.supportUrl!)}',
                    onTap: then(() => SupportArtistButton.open(ref, artist)),
                  ),
              ],
            ),
            SizedBox(height: context.spaceM),
            MenuGroup(
              children: <Widget>[
                if (isCatalogue) ...<Widget>[
                  MenuRow(
                    glyph: AppGlyph.share,
                    title: 'Share',
                    onTap: () => unawaited(onShare(track)),
                  ),
                  MenuRow(
                    glyph: AppGlyph.flag,
                    title: 'Report a problem',
                    danger: true,
                    onTap: () => unawaited(
                      AppLinks.open(
                        AppLinks.report(trackId: track.id, title: track.title),
                      ),
                    ),
                  ),
                ] else
                  MenuRow(
                    glyph: AppGlyph.remove,
                    title: 'Remove from PureLofi',
                    danger: true,
                    onTap: () async {
                      if (!await confirmRemoveTrack(context, track)) return;
                      await ref
                          .read(libraryControllerProvider.notifier)
                          .remove(track.id);
                      if (context.mounted) Navigator.of(context).pop();
                    },
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Opens the actions for [track].
Future<void> showTrackActionsSheet(BuildContext context, TrackEntity track) {
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (BuildContext sheet) => TrackActionsSheet(
      track: track,
      openArtist: LibraryScope.maybeOf(context)?.openArtist,
    ),
  );
}
