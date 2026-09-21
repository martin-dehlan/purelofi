import 'package:flutter_test/flutter_test.dart';
import 'package:purelofi/features/player/data/scene.model.dart';
import 'package:purelofi/features/player/data/scene_layer.model.dart';
import 'package:purelofi/features/player/domain/scene.entity.dart';
import 'package:purelofi/features/player/domain/scene_layer.entity.dart';

void main() {
  Map<String, dynamic> layerJson({
    String id = 'layer-1',
    int zIndex = 3,
    int frameCount = 6,
    double fps = 12,
  }) => <String, dynamic>{
    'id': id,
    'scene_id': 'scene-1',
    'z_index': zIndex,
    'sprite_url': 'https://example.com/rain.png',
    'frame_count': frameCount,
    'fps': fps,
    'offset_x': 10,
    'offset_y': 20,
    'parallax': 0.5,
    'tiles': true,
    'only_while_playing': false,
    'event_interval_min_seconds': null,
    'event_interval_max_seconds': null,
  };

  group('SceneLayerModel', () {
    test('maps the snake_case columns', () {
      final SceneLayerModel model = SceneLayerModel.fromJson(layerJson());

      expect(model.zIndex, 3);
      expect(model.spriteUrl, 'https://example.com/rain.png');
      expect(model.frameCount, 6);
      expect(model.fps, 12);
      expect(model.offsetX, 10);
      expect(model.offsetY, 20);
      expect(model.parallax, 0.5);
      expect(model.tiles, isTrue);
    });

    test('falls back to a still, stationary layer when columns are absent', () {
      final SceneLayerModel model = SceneLayerModel.fromJson(<String, dynamic>{
        'id': 'layer-2',
        'scene_id': 'scene-1',
        'z_index': 0,
        'sprite_url': 'https://example.com/room.png',
      });

      expect(model.frameCount, 1);
      expect(model.fps, 0);
      expect(model.parallax, 1);
      expect(model.tiles, isFalse);
      expect(model.onlyWhilePlaying, isFalse);
    });
  });

  group('SceneLayerEntity', () {
    test('knows whether it animates', () {
      expect(
        SceneLayerModel.fromJson(layerJson()).toEntity().isAnimated,
        isTrue,
      );
      expect(
        SceneLayerModel.fromJson(
          layerJson(frameCount: 1, fps: 0),
        ).toEntity().isAnimated,
        isFalse,
      );
    });

    test('knows whether it is an event', () {
      final SceneLayerEntity looping = SceneLayerModel.fromJson(
        layerJson(),
      ).toEntity();
      expect(looping.isEvent, isFalse);

      final SceneLayerEntity event = SceneLayerModel.fromJson(<String, dynamic>{
        ...layerJson(),
        'event_interval_min_seconds': 40,
        'event_interval_max_seconds': 90,
      }).toEntity();
      expect(event.isEvent, isTrue);
    });
  });

  group('SceneModel with embedded layers', () {
    Map<String, dynamic> sceneJson(List<Map<String, dynamic>> layers) =>
        <String, dynamic>{
          'id': 'scene-1',
          'title': 'Rainy Room',
          'video_url': 'https://example.com/scene.mp4',
          'sort_order': 1,
          'is_active': true,
          'created_at': '2026-01-01T00:00:00.000Z',
          'canvas_width': 320,
          'canvas_height': 568,
          'scene_layers': layers,
        };

    test('sorts layers back to front regardless of api order', () {
      final SceneEntity scene = SceneModel.fromJson(
        sceneJson(<Map<String, dynamic>>[
          layerJson(id: 'front', zIndex: 9),
          layerJson(id: 'back', zIndex: 0),
          layerJson(id: 'middle', zIndex: 4),
        ]),
      ).toEntity();

      expect(scene.layers.map((SceneLayerEntity l) => l.id), <String>[
        'back',
        'middle',
        'front',
      ]);
    });

    test('carries the canvas size through', () {
      final SceneEntity scene = SceneModel.fromJson(
        sceneJson(<Map<String, dynamic>>[]),
      ).toEntity();

      expect(scene.canvasWidth, 320);
      expect(scene.canvasHeight, 568);
    });

    test('a scene without layers is a video scene', () {
      final SceneEntity scene = SceneModel.fromJson(
        sceneJson(<Map<String, dynamic>>[]),
      ).toEntity();

      expect(scene.layers, isEmpty);
      expect(scene.isLayered, isFalse);
      expect(scene.videoUrl, 'https://example.com/scene.mp4');
    });

    test('a scene with layers is a layered scene', () {
      final SceneEntity scene = SceneModel.fromJson(
        sceneJson(<Map<String, dynamic>>[layerJson()]),
      ).toEntity();

      expect(scene.isLayered, isTrue);
    });

    test('defaults the canvas when the columns are missing', () {
      final Map<String, dynamic> json = sceneJson(<Map<String, dynamic>>[])
        ..remove('canvas_width')
        ..remove('canvas_height');

      final SceneEntity scene = SceneModel.fromJson(json).toEntity();

      expect(scene.canvasWidth, 320);
      expect(scene.canvasHeight, 568);
    });
  });
}
