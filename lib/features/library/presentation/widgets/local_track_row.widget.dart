import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../common/utils/app_fonts.dart';
import '../../../../common/utils/clock.dart';
import '../../../../common/utils/responsive.dart';
import '../../../player/controller/player.controller.dart';
import '../../../player/domain/track.entity.dart';
import '../../controller/library.controller.dart';

/// One of the listener's own tracks: tap to play, swipe to remove (#66).
class LocalTrackRow extends ConsumerWidget {
  const LocalTrackRow({required this.track, super.key});

  final TrackEntity track;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ColorScheme cs = Theme.of(context).colorScheme;
    final bool isCurrent = ref.watch(
      playerControllerProvider.select(
        (state) => state.currentTrack?.id == track.id,
      ),
    );
    final double coverSize = context.fontL * 1.6;

    return Dismissible(
      key: ValueKey<String>('local-${track.id}'),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: EdgeInsets.symmetric(horizontal: context.spaceM),
        color: cs.errorContainer,
        child: Text(
          'Remove',
          style: TextStyle(color: cs.onErrorContainer, fontSize: context.fontS),
        ),
      ),
      confirmDismiss: (_) => _confirmRemove(context, track),
      onDismissed: (_) => unawaited(
        ref.read(libraryControllerProvider.notifier).remove(track.id),
      ),
      child: Semantics(
        button: true,
        selected: isCurrent,
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
            padding: EdgeInsets.symmetric(vertical: context.spaceS),
            child: Row(
              children: <Widget>[
                _Cover(path: track.coverPath, size: coverSize),
                SizedBox(width: context.spaceM),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        track.title,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: isCurrent ? cs.primary : cs.onSurface,
                          fontSize: context.fontM,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      if (track.artist != null)
                        Text(
                          track.artist!,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: cs.onSurfaceVariant,
                            fontSize: context.fontS,
                          ),
                        ),
                    ],
                  ),
                ),
                if (track.durationSeconds != null) ...<Widget>[
                  SizedBox(width: context.spaceM),
                  Text(
                    clockOf(track.durationSeconds!),
                    style: TextStyle(
                      color: cs.onSurfaceVariant,
                      fontFamily: AppFonts.mono,
                      fontSize: context.fontS,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Removing deletes the copy, which cannot be undone from inside the app —
  /// so it asks, and says plainly that the original is safe.
  static Future<bool> _confirmRemove(
    BuildContext context,
    TrackEntity track,
  ) async {
    final bool? remove = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        title: Text('Remove "${track.title}"?'),
        content: const Text(
          'This deletes the copy in PureLofi. The file on your phone stays.',
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Keep'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );

    return remove ?? false;
  }
}

/// The cover from the file's tags, or a quiet square where there is none.
class _Cover extends StatelessWidget {
  const _Cover({required this.path, required this.size});

  final String? path;
  final double size;

  @override
  Widget build(BuildContext context) {
    final ColorScheme cs = Theme.of(context).colorScheme;
    final Widget blank = ColoredBox(color: cs.surfaceContainerHighest);

    return ClipRRect(
      borderRadius: BorderRadius.circular(context.screenWidth * 0.01),
      child: SizedBox.square(
        dimension: size,
        child: path == null
            ? blank
            : Image.file(
                File(path!),
                fit: BoxFit.cover,
                cacheWidth: (size * MediaQuery.devicePixelRatioOf(context))
                    .round(),
                errorBuilder: (_, _, _) => blank,
              ),
      ),
    );
  }
}
