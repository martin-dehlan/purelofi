import 'package:mocktail/mocktail.dart';
import 'package:purelofi/features/player/data/content.api.dart';
import 'package:purelofi/features/player/data/scene.model.dart';
import 'package:purelofi/features/player/data/scene_layer.model.dart';
import 'package:purelofi/features/player/data/track.model.dart';
import 'package:purelofi/features/player/domain/content.repository.dart';
import 'package:purelofi/features/player/domain/scene.entity.dart';
import 'package:purelofi/features/player/domain/scene_layer.entity.dart';
import 'package:purelofi/features/player/domain/track.entity.dart';

class MockContentRepository extends Mock implements ContentRepository {}

class MockContentApi extends Mock implements ContentApi {}

final DateTime testCreatedAt = DateTime.utc(2026);

TrackEntity makeTrack(
  String id, {
  String title = 'Rainy Nights',
  String? btsVideoUrl,
}) => TrackEntity(
  id: id,
  title: title,
  audioUrl: 'https://example.com/$id.mp3',
  btsVideoUrl: btsVideoUrl,
  createdAt: testCreatedAt,
);

SceneEntity makeScene(
  String id, {
  String title = 'Rainy Room',
  String? thumbnailUrl,
}) => SceneEntity(
  id: id,
  title: title,
  videoUrl: 'https://example.com/$id.mp4',
  sortOrder: 0,
  thumbnailUrl: thumbnailUrl,
);

TrackModel makeTrackModel(
  String id, {
  String title = 'Rainy Nights',
  String? btsVideoUrl,
  int? durationSeconds,
}) => TrackModel(
  id: id,
  title: title,
  audioUrl: 'https://example.com/$id.mp3',
  isActive: true,
  createdAt: testCreatedAt,
  btsVideoUrl: btsVideoUrl,
  durationSeconds: durationSeconds,
);

SceneModel makeSceneModel(
  String id, {
  String title = 'Rainy Room',
  int sortOrder = 0,
  String? thumbnailUrl,
  List<SceneLayerModel> layers = const <SceneLayerModel>[],
}) => SceneModel(
  id: id,
  title: title,
  videoUrl: 'https://example.com/$id.mp4',
  sortOrder: sortOrder,
  isActive: true,
  createdAt: testCreatedAt,
  thumbnailUrl: thumbnailUrl,
  layers: layers,
);

SceneLayerEntity makeLayer(
  String id, {
  int zIndex = 0,
  int frameCount = 1,
  double fps = 0,
  bool tiles = false,
  bool onlyWhilePlaying = false,
}) => SceneLayerEntity(
  id: id,
  zIndex: zIndex,
  spriteUrl: 'https://example.com/$id.png',
  frameCount: frameCount,
  fps: fps,
  tiles: tiles,
  onlyWhilePlaying: onlyWhilePlaying,
);

SceneLayerModel makeLayerModel(
  String id, {
  String sceneId = 'scene-1',
  int zIndex = 0,
  int frameCount = 1,
  double fps = 0,
  bool tappable = false,
}) => SceneLayerModel(
  id: id,
  sceneId: sceneId,
  zIndex: zIndex,
  spriteUrl: 'https://example.com/$id.png',
  frameCount: frameCount,
  fps: fps,
  tappable: tappable,
);
