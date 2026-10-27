import 'package:flutter/material.dart';

/// Opens [builder] as the tall sheet the library and the queue live in.
///
/// It comes up most of the way and can be pulled to the top or flicked away,
/// and it never covers the whole screen: a strip of the room stays in view
/// above it, behind a light scrim, because the room is half of what the app
/// is. [builder] gets the scroll controller the sheet's list must use, so
/// dragging the list and dragging the sheet are one gesture.
Future<void> showMusicSheet(
  BuildContext context,
  Widget Function(BuildContext context, ScrollController controller) builder,
) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    useSafeArea: true,
    barrierColor: Theme.of(context).colorScheme.scrim.withValues(alpha: 0.25),
    builder: (BuildContext context) => DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.75,
      minChildSize: 0.4,
      maxChildSize: 0.92,
      snap: true,
      builder: builder,
    ),
  );
}
