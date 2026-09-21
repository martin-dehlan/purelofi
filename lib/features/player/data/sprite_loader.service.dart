import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/painting.dart';

/// Loads sprite strips for the scene renderer.
///
/// Behind an interface because the renderer must be testable without a
/// network: widget tests supply generated images instead (see `docs/10`).
abstract class SpriteLoader {
  Future<ui.Image> load(String url);

  void dispose();
}

/// Loads through Flutter's own image pipeline, which gives us its cache for
/// free — the same sprite used by two scenes is fetched once.
class NetworkSpriteLoader implements SpriteLoader {
  final Map<String, Future<ui.Image>> _inFlight = <String, Future<ui.Image>>{};

  @override
  Future<ui.Image> load(String url) {
    return _inFlight.putIfAbsent(url, () => _resolve(url));
  }

  Future<ui.Image> _resolve(String url) {
    final Completer<ui.Image> completer = Completer<ui.Image>();
    final ImageStream stream = NetworkImage(
      url,
    ).resolve(ImageConfiguration.empty);

    late final ImageStreamListener listener;
    listener = ImageStreamListener(
      (ImageInfo info, bool _) {
        if (!completer.isCompleted) completer.complete(info.image);
        stream.removeListener(listener);
      },
      onError: (Object error, StackTrace? stackTrace) {
        if (!completer.isCompleted) completer.completeError(error, stackTrace);
        stream.removeListener(listener);
      },
    );

    stream.addListener(listener);
    return completer.future;
  }

  @override
  void dispose() => _inFlight.clear();
}
