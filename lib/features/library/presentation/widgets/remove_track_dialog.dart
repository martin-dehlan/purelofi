import 'package:flutter/material.dart';

import '../../../player/domain/track.entity.dart';

/// Asks before removing one of the listener's own tracks.
///
/// Removing deletes the copy, which cannot be undone from inside the app —
/// so it asks, and says plainly that the original is safe.
Future<bool> confirmRemoveTrack(BuildContext context, TrackEntity track) async {
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
