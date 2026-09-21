import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:purelofi/features/player/data/sprite_loader.service.dart';

/// Generates sprite strips in memory, so the renderer can be tested without
/// touching the network (see `docs/10`).
class FakeSpriteLoader implements SpriteLoader {
  FakeSpriteLoader({this.failingUrls = const <String>{}});

  /// URLs that should fail, to prove a broken sprite costs only its layer.
  final Set<String> failingUrls;

  final List<String> requestedUrls = <String>[];
  bool disposed = false;

  @override
  Future<ui.Image> load(String url) async {
    requestedUrls.add(url);
    if (failingUrls.contains(url)) {
      throw Exception('sprite not found: $url');
    }

    return createStrip();
  }

  @override
  void dispose() => disposed = true;

  /// A [frames]-frame horizontal strip, each frame [frameSize] square.
  static Future<ui.Image> createStrip({
    int frames = 1,
    int frameSize = 8,
  }) async {
    final ui.PictureRecorder recorder = ui.PictureRecorder();
    final Canvas canvas = Canvas(recorder);

    for (int i = 0; i < frames; i++) {
      canvas.drawRect(
        Rect.fromLTWH(i * frameSize.toDouble(), 0, frameSize.toDouble(),
            frameSize.toDouble()),
        Paint()..color = Color.fromARGB(255, 10 * i, 120, 200),
      );
    }

    return recorder.endRecording().toImage(frames * frameSize, frameSize);
  }
}
