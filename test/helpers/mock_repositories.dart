import 'package:mocktail/mocktail.dart';
import 'package:purelofi/features/player/data/content.api.dart';
import 'package:purelofi/features/player/data/scene.model.dart';
import 'package:purelofi/features/player/data/track.model.dart';
import 'package:purelofi/features/player/domain/content.repository.dart';
import 'package:purelofi/features/player/domain/scene.entity.dart';
import 'package:purelofi/features/player/domain/track.entity.dart';

class MockContentRepository extends Mock implements ContentRepository {}

class MockContentApi extends Mock implements ContentApi {}

final DateTime testCreatedAt = DateTime.utc(2026);

TrackEntity makeTrack(String id, {String title = 'Rainy Nights'}) =>
    TrackEntity(
      id: id,
      title: title,
      audioUrl: 'https://example.com/$id.mp3',
      createdAt: testCreatedAt,
    );

SceneEntity makeScene(String id, {String title = 'Rainy Room'}) => SceneEntity(
  id: id,
  title: title,
  videoUrl: 'https://example.com/$id.mp4',
  sortOrder: 0,
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
}) => SceneModel(
  id: id,
  title: title,
  videoUrl: 'https://example.com/$id.mp4',
  sortOrder: sortOrder,
  isActive: true,
  createdAt: testCreatedAt,
  thumbnailUrl: thumbnailUrl,
);
