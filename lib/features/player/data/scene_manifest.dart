/// Reads a scene folder: sprite strips named by convention plus a
/// `scene.json` describing how they move.
///
/// This is the contract Martin's export has to satisfy, and it lives here so
/// the renderer and the upload tool can never disagree about it.
///
/// ```
/// L03_rain_6f.png   →  z_index 3, name "rain", 6 frames
/// scene.json        →  title, canvas size, per-layer fps/offset/parallax
/// ```
library;

import 'dart:convert';

/// Thrown when a folder does not match the contract. The message names the
/// file, because that is what you need to fix it.
class SceneManifestException implements Exception {
  const SceneManifestException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// What a sprite file name tells us.
class SpriteFileName {
  const SpriteFileName({
    required this.zIndex,
    required this.name,
    required this.frameCount,
    required this.fileName,
  });

  final int zIndex;
  final String name;
  final int frameCount;
  final String fileName;

  /// The key used to look this layer up in `scene.json`, e.g. `L03_rain`.
  String get manifestKey => 'L${zIndex.toString().padLeft(2, '0')}_$name';

  static final RegExp _pattern = RegExp(r'^L(\d{2})_(.+)_(\d+)f\.png$');

  /// Parses `L03_rain_6f.png`.
  static SpriteFileName parse(String fileName) {
    final RegExpMatch? match = _pattern.firstMatch(fileName);
    if (match == null) {
      throw SceneManifestException(
        '$fileName does not match L<zz>_<name>_<frames>f.png '
        '— for example L03_rain_6f.png',
      );
    }

    final int frameCount = int.parse(match.group(3)!);
    if (frameCount < 1) {
      throw SceneManifestException('$fileName declares $frameCount frames');
    }

    return SpriteFileName(
      zIndex: int.parse(match.group(1)!),
      name: match.group(2)!,
      frameCount: frameCount,
      fileName: fileName,
    );
  }
}

/// How one layer behaves, from `scene.json`.
class LayerManifest {
  const LayerManifest({
    this.fps = 0,
    this.offsetX = 0,
    this.offsetY = 0,
    this.parallax = 1,
    this.tiles = false,
    this.onlyWhilePlaying = false,
    this.hideWhenPaused = false,
    this.tappable = false,
    this.idleFrameCount = 0,
    this.eventIntervalMinSeconds,
    this.eventIntervalMaxSeconds,
  });

  final double fps;
  final int offsetX;
  final int offsetY;
  final double parallax;
  final bool tiles;
  final bool onlyWhilePlaying;
  final bool hideWhenPaused;
  final bool tappable;
  final int idleFrameCount;
  final int? eventIntervalMinSeconds;
  final int? eventIntervalMaxSeconds;

  factory LayerManifest.fromJson(String key, Map<String, dynamic> json) {
    final List<dynamic> offset =
        (json['offset'] as List<dynamic>?) ?? <dynamic>[0, 0];
    if (offset.length != 2) {
      throw SceneManifestException('$key: offset must be [x, y]');
    }

    final List<dynamic>? event = json['event_interval'] as List<dynamic>?;
    if (event != null && event.length != 2) {
      throw SceneManifestException(
        '$key: event_interval must be [minSeconds, maxSeconds]',
      );
    }

    return LayerManifest(
      fps: (json['fps'] as num?)?.toDouble() ?? 0,
      offsetX: (offset[0] as num).toInt(),
      offsetY: (offset[1] as num).toInt(),
      parallax: (json['parallax'] as num?)?.toDouble() ?? 1,
      tiles: json['tiles'] as bool? ?? false,
      onlyWhilePlaying: json['only_while_playing'] as bool? ?? false,
      hideWhenPaused: json['hide_when_paused'] as bool? ?? false,
      tappable: json['tappable'] as bool? ?? false,
      idleFrameCount: (json['idle_frames'] as num?)?.toInt() ?? 0,
      eventIntervalMinSeconds: event == null ? null : (event[0] as num).toInt(),
      eventIntervalMaxSeconds: event == null ? null : (event[1] as num).toInt(),
    );
  }
}

/// A whole scene folder, validated.
class SceneManifest {
  const SceneManifest({
    required this.title,
    required this.canvasWidth,
    required this.canvasHeight,
    required this.layers,
  });

  final String title;
  final int canvasWidth;
  final int canvasHeight;

  /// Layers back to front, each paired with what `scene.json` says about it.
  final List<(SpriteFileName file, LayerManifest settings)> layers;

  /// Builds a manifest from `scene.json` and the PNG names beside it.
  ///
  /// Every sprite must have an entry and every entry a sprite: a silent
  /// mismatch is how a layer goes missing without anyone noticing.
  factory SceneManifest.parse({
    required String sceneJson,
    required List<String> spriteFileNames,
  }) {
    final Map<String, dynamic> json =
        jsonDecode(sceneJson) as Map<String, dynamic>;

    final Map<String, dynamic> canvas =
        (json['canvas'] as Map<String, dynamic>?) ?? <String, dynamic>{};
    final Map<String, dynamic> layerSettings =
        (json['layers'] as Map<String, dynamic>?) ?? <String, dynamic>{};

    final List<SpriteFileName> files =
        spriteFileNames.map(SpriteFileName.parse).toList()..sort(
          (SpriteFileName a, SpriteFileName b) => a.zIndex.compareTo(b.zIndex),
        );

    final Set<int> seen = <int>{};
    for (final SpriteFileName file in files) {
      if (!seen.add(file.zIndex)) {
        throw SceneManifestException(
          'two layers claim z_index ${file.zIndex}: ${file.fileName}',
        );
      }
    }

    final List<(SpriteFileName, LayerManifest)> layers =
        <(SpriteFileName, LayerManifest)>[];

    for (final SpriteFileName file in files) {
      final Object? settings = layerSettings[file.manifestKey];
      if (settings == null) {
        throw SceneManifestException(
          '${file.fileName}: no "${file.manifestKey}" entry in scene.json',
        );
      }

      final LayerManifest layer = LayerManifest.fromJson(
        file.manifestKey,
        settings as Map<String, dynamic>,
      );

      if (file.frameCount > 1 && layer.fps <= 0) {
        throw SceneManifestException(
          '${file.fileName}: ${file.frameCount} frames but no fps in scene.json',
        );
      }
      if (file.frameCount == 1 && layer.fps > 0) {
        throw SceneManifestException(
          '${file.fileName}: a single frame cannot have an fps',
        );
      }

      layers.add((file, layer));
    }

    final Set<String> keys = layerSettings.keys.toSet()
      ..removeAll(files.map((SpriteFileName f) => f.manifestKey));
    if (keys.isNotEmpty) {
      throw SceneManifestException(
        'scene.json describes layers with no sprite: ${keys.join(', ')}',
      );
    }

    return SceneManifest(
      title: json['title'] as String? ?? 'Untitled scene',
      canvasWidth: (canvas['width'] as num?)?.toInt() ?? 320,
      canvasHeight: (canvas['height'] as num?)?.toInt() ?? 696,
      layers: layers,
    );
  }
}
