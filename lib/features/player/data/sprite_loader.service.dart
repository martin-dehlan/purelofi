import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/painting.dart';

import '../../../common/cache/media_cache.service.dart';

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
///
/// Takes a URL for real scenes and an asset path for the bundled development
/// scene, so both go through exactly the same renderer.
///
/// With a [MediaCache] it prefers the copy on disk, and downloads one in the
/// background when there is none. The scene therefore draws from the network
/// the first time and from the device every time after — including with no
/// network at all.
class NetworkSpriteLoader implements SpriteLoader {
  NetworkSpriteLoader({MediaCache? cache}) : _cache = cache;

  final MediaCache? _cache;
  final Map<String, Future<ui.Image>> _inFlight = <String, Future<ui.Image>>{};

  @override
  Future<ui.Image> load(String url) {
    return _inFlight.putIfAbsent(url, () async {
      // A failure is not worth remembering: kept in the map, it would make
      // every retry hand back the same old error without touching the
      // network again.
      try {
        return await _resolve(url);
      } on Object {
        // remove() hands back the very future that is failing; ignoring it
        // marks it handled here without hiding the error from the caller.
        _inFlight.remove(url)?.ignore();
        rethrow;
      }
    });
  }

  Future<ui.Image> _resolve(String url) async {
    final ImageProvider<Object> provider = await _providerFor(url);

    return _decode(provider);
  }

  /// The cached file when there is one, the network otherwise — and a
  /// download started for next time.
  Future<ImageProvider<Object>> _providerFor(String url) async {
    if (!url.startsWith('http')) return AssetImage(url);

    final MediaCache? cache = _cache;
    if (cache == null) return NetworkImage(url);

    final File? cached = await cache.fileFor(url);
    if (cached != null) return FileImage(cached);

    // Not awaited: the first view of a scene should not wait for the whole
    // strip to land on disk before it draws.
    unawaited(cache.store(url));

    return NetworkImage(url);
  }

  Future<ui.Image> _decode(ImageProvider<Object> provider) {
    final Completer<ui.Image> completer = Completer<ui.Image>();
    final ImageStream stream = provider.resolve(ImageConfiguration.empty);

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
