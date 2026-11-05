import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../../../../common/utils/app_links.dart';
import '../../../../common/utils/responsive.dart';
import '../../../../common/widgets/app_icon.widget.dart';
import '../../../../common/widgets/menu_group.widget.dart';
import '../../../../common/widgets/menu_row.widget.dart';
import '../../../../l10n/l10n.dart';
import '../../controller/collections.controller.dart';
import '../../controller/player.provider.dart';
import '../../domain/playback_scope.dart';
import '../../domain/playlist.entity.dart';
import '../../domain/track.entity.dart';
import 'playlist_name_dialog.dart';

/// A playlist's ⋯ (#141), in the shape of a track's: its name on top, then
/// what can be done with it. Playing is the row's own tap, so it is not
/// here; editing opens its tracks to reorder or take out.
class PlaylistActionsSheet extends ConsumerWidget {
  const PlaylistActionsSheet({
    required this.playlist,
    required this.onEdit,
    super.key,
  });

  final PlaylistEntity playlist;

  /// Opens the playlist's own page.
  final VoidCallback onEdit;

  PlaybackScope get _scope => PlaybackScope(
    kind: ScopeKind.playlist,
    id: playlist.id,
    title: playlist.name,
  );

  /// The name and the tracks as plain lines, and where to find the app.
  static String shareText(String name, List<TrackEntity> tracks) => <String>[
    name,
    '',
    for (final TrackEntity t in tracks) '${t.title} · ${t.artistName}',
    if (tracks.isNotEmpty) '',
    AppLinks.home.toString(),
  ].join('\n');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ColorScheme cs = Theme.of(context).colorScheme;
    final PlaylistRepository playlists = ref.read(playlistRepositoryProvider);
    final List<TrackEntity> tracks =
        ref.watch(scopeTrackListProvider(_scope)).value ??
        const <TrackEntity>[];
    final NavigatorState navigator = Navigator.of(context);

    // Each action closes the menu first, then runs where it was opened.
    VoidCallback then(FutureOr<void> Function() action) => () {
      navigator.pop();
      unawaited(Future<void>.sync(action));
    };

    return SafeArea(
      child: SingleChildScrollView(
        padding: EdgeInsets.only(bottom: context.spaceM),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Padding(
              padding: EdgeInsets.fromLTRB(
                context.horizontalPadding,
                0,
                context.horizontalPadding,
                context.spaceM,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    playlist.name,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: cs.onSurface,
                      fontSize: context.fontL,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    playlist.items.length == 1
                        ? context.l10n.playlistOneTrack
                        : context.l10n.playlistTrackCount(
                            playlist.items.length,
                          ),
                    style: TextStyle(
                      color: cs.onSurfaceVariant,
                      fontSize: context.fontS,
                    ),
                  ),
                ],
              ),
            ),
            MenuGroup(
              children: <Widget>[
                MenuRow(
                  glyph: AppGlyph.queue,
                  title: context.l10n.editPlaylist,
                  onTap: then(onEdit),
                ),
                MenuRow(
                  glyph: AppGlyph.sort,
                  title: context.l10n.renamePlaylist,
                  onTap: then(() async {
                    final String? name = await askPlaylistName(
                      navigator.context,
                      initial: playlist.name,
                      title: navigator.context.l10n.renamePlaylist,
                      action: navigator.context.l10n.rename,
                    );
                    if (name != null) await playlists.rename(playlist.id, name);
                  }),
                ),
                MenuRow(
                  glyph: AppGlyph.share,
                  title: context.l10n.share,
                  onTap: then(
                    () => SharePlus.instance.share(
                      ShareParams(
                        text: shareText(playlist.name, tracks),
                        subject: playlist.name,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: context.spaceM),
            MenuGroup(
              children: <Widget>[
                MenuRow(
                  glyph: AppGlyph.remove,
                  title: context.l10n.deletePlaylist,
                  danger: true,
                  onTap: then(() async {
                    if (!await confirmDeletePlaylist(
                      navigator.context,
                      playlist.name,
                    )) {
                      return;
                    }
                    await playlists.delete(playlist.id);
                  }),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

Future<void> showPlaylistActionsSheet(
  BuildContext context,
  PlaylistEntity playlist, {
  required VoidCallback onEdit,
}) => showModalBottomSheet<void>(
  context: context,
  isScrollControlled: true,
  useSafeArea: true,
  showDragHandle: true,
  builder: (BuildContext context) =>
      PlaylistActionsSheet(playlist: playlist, onEdit: onEdit),
);
