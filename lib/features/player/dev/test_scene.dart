import 'package:flutter/services.dart';

import '../data/scene_manifest.dart';
import '../domain/scene.entity.dart';
import '../domain/scene_layer.entity.dart';

/// The development placeholder scene, bundled with the app.
///
/// Flat shapes, no art — it exists so the renderer, the parallax and the
/// drift can be seen working before the real PixelLab assets land. Never
/// shown to users: it loads only behind `--dart-define=DEV_SCENE=true`.
abstract final class DevTestScene {
  static const bool enabled = bool.fromEnvironment('DEV_SCENE');

  static const String _folder = 'assets/dev/scenes/test_room';

  /// The sprite files in the folder. Listed explicitly because the asset
  /// bundle cannot be enumerated at runtime.
  static const List<String> _spriteFiles = <String>[
    'L00_sky_1f.png',
    'L01_stars_4f.png',
    'L02_skyline_1f.png',
    'L03_rain_6f.png',
    'L04_reels_8f.png',
  ];

  /// Builds the scene from the same manifest format the upload tool reads,
  /// so a mistake here is a mistake there too.
  static Future<SceneEntity> load() async {
    final String sceneJson = await rootBundle.loadString('$_folder/scene.json');
    final SceneManifest manifest = SceneManifest.parse(
      sceneJson: sceneJson,
      spriteFileNames: _spriteFiles,
    );

    return SceneEntity(
      id: 'dev-test-room',
      title: manifest.title,
      videoUrl: '',
      sortOrder: 0,
      canvasWidth: manifest.canvasWidth,
      canvasHeight: manifest.canvasHeight,
      layers: <SceneLayerEntity>[
        for (final (SpriteFileName file, LayerManifest settings)
            in manifest.layers)
          SceneLayerEntity(
            id: file.manifestKey,
            zIndex: file.zIndex,
            spriteUrl: '$_folder/${file.fileName}',
            frameCount: file.frameCount,
            fps: settings.fps,
            offsetX: settings.offsetX,
            offsetY: settings.offsetY,
            parallax: settings.parallax,
            tiles: settings.tiles,
            onlyWhilePlaying: settings.onlyWhilePlaying,
            eventIntervalMinSeconds: settings.eventIntervalMinSeconds,
            eventIntervalMaxSeconds: settings.eventIntervalMaxSeconds,
          ),
      ],
    );
  }
}
