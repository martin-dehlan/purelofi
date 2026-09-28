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

/// The listener's own music, in the menu beside PureLofi's (#66).
///
/// Adding copies files in from the phone; tapping one plays it and turns the
/// stream over to the library; swiping one away removes the copy.
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

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        if (all.isNotEmpty)
          LibraryToolbar(
            showSearch: all.length >= LibraryToolbar.searchFrom,
            onSearch: (String query) => setState(() => _query = query),
          ),
        if (all.isNotEmpty && tracks.isEmpty)
          Padding(
            padding: EdgeInsets.symmetric(vertical: context.spaceM),
            child: Text(
              'Nothing called "$_query".',
              style: TextStyle(
                color: cs.onSurfaceVariant,
                fontSize: context.fontS,
              ),
            ),
          )
        else if (all.isEmpty)
          Padding(
            padding: EdgeInsets.symmetric(vertical: context.spaceM),
            child: Text(
              'Your own music, played in these rooms. Files you add are '
              'copied into PureLofi, so they play without a connection.',
              style: TextStyle(
                color: cs.onSurfaceVariant,
                fontSize: context.fontS,
                height: 1.5,
              ),
            ),
          )
        else
          ConstrainedBox(
            constraints: BoxConstraints(maxHeight: context.screenHeight * 0.4),
            child: ListView.separated(
              shrinkWrap: true,
              padding: EdgeInsets.zero,
              itemCount: tracks.length,
              separatorBuilder: (BuildContext context, int index) =>
                  Divider(height: 1, color: cs.outlineVariant),
              itemBuilder: (BuildContext context, int index) =>
                  LocalTrackRow(track: tracks[index]),
            ),
          ),
        for (final RejectedImport rejected in _rejected)
          Padding(
            padding: EdgeInsets.only(top: context.spaceS),
            child: Text(
              '${rejected.name}: ${rejected.reason}',
              style: TextStyle(color: cs.error, fontSize: context.fontS),
            ),
          ),
        _AddButton(busy: _importing, onTap: _add),
      ],
    );
  }
}

class _AddButton extends StatelessWidget {
  const _AddButton({required this.busy, required this.onTap});

  final bool busy;
  final Future<void> Function() onTap;

  @override
  Widget build(BuildContext context) {
    final ColorScheme cs = Theme.of(context).colorScheme;

    return Semantics(
      button: true,
      label: 'Add music from this phone',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: busy ? null : () => unawaited(onTap()),
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: context.spaceM),
          child: Row(
            children: <Widget>[
              AppIcon(AppGlyph.add, size: context.fontL, color: cs.primary),
              SizedBox(width: context.spaceM),
              Text(
                busy ? 'Adding…' : 'Add music',
                style: TextStyle(color: cs.primary, fontSize: context.fontM),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
