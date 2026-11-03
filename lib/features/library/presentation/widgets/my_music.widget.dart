import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../common/utils/responsive.dart';
import '../../../../common/widgets/app_icon.widget.dart';
import '../../../player/domain/track.entity.dart';
import '../../controller/library.controller.dart';
import '../../domain/import_report.dart';
import '../../domain/library_view.dart';
import 'library_toolbar.widget.dart';
import 'local_track_row.widget.dart';

/// The listener's own music, in the library beside PureLofi's (#66).
///
/// Adding copies files in from the phone; tapping one plays it and turns the
/// stream over to the library; swiping one away removes the copy.
///
/// A group of slivers, so a long library scrolls as part of the sheet rather
/// than as a list boxed inside it.
class MyMusic extends ConsumerStatefulWidget {
  const MyMusic({super.key});

  @override
  ConsumerState<MyMusic> createState() => _MyMusicState();
}

class _MyMusicState extends ConsumerState<MyMusic> {
  bool _importing = false;
  String _query = '';

  /// What the last import turned away, in words. Cleared by the next one.
  List<RejectedImport> _rejected = const <RejectedImport>[];

  Future<void> _add() async {
    setState(() => _importing = true);
    try {
      final ImportReport? report = await ref
          .read(libraryControllerProvider.notifier)
          .importFromDevice();
      if (!mounted) return;
      setState(() => _rejected = report?.rejected ?? const <RejectedImport>[]);
    } finally {
      if (mounted) setState(() => _importing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme cs = Theme.of(context).colorScheme;
    final List<TrackEntity> all =
        ref.watch(libraryControllerProvider).value ?? const <TrackEntity>[];
    final LibraryView view =
        ref.watch(libraryViewControllerProvider).value ?? const LibraryView();
    // Search narrows what is shown, never what plays next: the order the
    // stream follows is the whole sorted list.
    final List<TrackEntity> tracks = searchTracks(
      sortTracks(all, view.sort),
      _query,
    );
    final TextStyle quiet = TextStyle(
      color: cs.onSurfaceVariant,
      fontSize: context.fontS,
      height: 1.5,
    );

    return SliverMainAxisGroup(
      slivers: <Widget>[
        SliverToBoxAdapter(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              _AddButton(busy: _importing, onTap: _add),
              for (final RejectedImport rejected in _rejected)
                Padding(
                  padding: EdgeInsets.only(top: context.spaceS),
                  child: Text(
                    '${rejected.name}: ${rejected.reason}',
                    style: TextStyle(color: cs.error, fontSize: context.fontS),
                  ),
                ),
              SizedBox(height: context.spaceM),
              if (all.isEmpty)
                Text(
                  'Your own music, played in these rooms. Files you add are '
                  'copied into PureLofi, so they play without a connection.',
                  style: quiet,
                )
              else ...<Widget>[
                LibraryToolbar(
                  showSearch: all.length >= LibraryToolbar.searchFrom,
                  onSearch: (String query) => setState(() => _query = query),
                ),
                SizedBox(height: context.spaceS),
                if (tracks.isEmpty)
                  Text('Nothing called "$_query".', style: quiet),
              ],
            ],
          ),
        ),
        SliverList.builder(
          itemCount: tracks.length,
          itemBuilder: (BuildContext context, int index) =>
              LocalTrackRow(track: tracks[index]),
        ),
      ],
    );
  }
}

/// Adding is a quiet line at the top of the list, not a slab: the music is
/// what the sheet is for.
class _AddButton extends StatelessWidget {
  const _AddButton({required this.busy, required this.onTap});

  final bool busy;
  final Future<void> Function() onTap;

  @override
  Widget build(BuildContext context) {
    final ColorScheme cs = Theme.of(context).colorScheme;

    return Align(
      alignment: AlignmentDirectional.centerStart,
      child: TextButton.icon(
        icon: AppIcon(AppGlyph.add, size: context.fontL, color: cs.primary),
        label: Text(
          busy ? 'Adding…' : 'Add music',
          style: TextStyle(fontSize: context.fontM),
        ),
        onPressed: busy ? null : () => unawaited(onTap()),
      ),
    );
  }
}
