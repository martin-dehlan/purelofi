import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../common/widgets/skeleton.widget.dart';
import '../../controller/player.provider.dart';

/// A picture from the network, kept on the phone after the first time
/// (`pictureFileProvider`), so a cover or a photo seen once is there at
/// once ever after, offline too.
///
/// While it is on its way a [Skeleton] breathes in its place, never a
/// spinner, and the picture fades in over it when it lands. One that will
/// not load leaves [fallback] for good.
class CachedPicture extends ConsumerWidget {
  const CachedPicture({
    required this.url,
    required this.fallback,
    this.decodeWidth,
    super.key,
  });

  final String url;

  /// What stands in when the picture will not load.
  final Widget fallback;

  /// The width in pixels to decode at: the size it is drawn, not the size
  /// it was uploaded.
  final int? decodeWidth;

  static const Duration fadeIn = Duration(milliseconds: 250);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final Widget skeleton = LayoutBuilder(
      builder: (BuildContext context, BoxConstraints box) =>
          Skeleton(width: box.maxWidth, height: box.maxHeight),
    );

    Widget picture(ImageProvider<Object> source) {
      final int? width = decodeWidth;

      return Image(
        image: width == null ? source : ResizeImage(source, width: width),
        fit: BoxFit.cover,
        frameBuilder:
            (
              BuildContext context,
              Widget child,
              int? frame,
              bool wasSynchronouslyLoaded,
            ) {
              // Already in memory: no skeleton, no fade, just the picture.
              if (wasSynchronouslyLoaded) return child;

              return Stack(
                fit: StackFit.expand,
                children: <Widget>[
                  if (frame == null) skeleton,
                  AnimatedOpacity(
                    opacity: frame == null ? 0 : 1,
                    duration: fadeIn,
                    curve: Curves.easeOut,
                    child: child,
                  ),
                ],
              );
            },
        errorBuilder: (_, _, _) => fallback,
      );
    }

    return ref
        .watch(pictureFileProvider(url))
        .when(
          data: (File? file) =>
              picture(file == null ? NetworkImage(url) : FileImage(file)),
          loading: () => skeleton,
          error: (_, _) => picture(NetworkImage(url)),
        );
  }
}
