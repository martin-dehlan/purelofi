import 'package:flutter_test/flutter_test.dart';
import 'package:purelofi/features/player/data/scene.model.dart';
import 'package:purelofi/features/player/data/track.model.dart';

void main() {
  group('TrackModel', () {
    test('fromJson maps the snake_case Supabase columns', () {
      final TrackModel model = TrackModel.fromJson(<String, dynamic>{
        'id': 'track-1',
        'title': 'Rainy Nights',
        'audio_url': 'https://example.com/track-1.mp3',
        'bts_video_url': 'https://example.com/track-1-bts.mp4',
        'duration_seconds': 184,
        'is_active': true,
        'created_at': '2026-01-01T00:00:00.000Z',
      });

      expect(model.audioUrl, 'https://example.com/track-1.mp3');
      expect(model.btsVideoUrl, 'https://example.com/track-1-bts.mp4');
      expect(model.durationSeconds, 184);
      expect(model.isActive, isTrue);
      expect(model.createdAt, DateTime.utc(2026));
    });

    test('fromJson leaves the optional columns null when absent', () {
      final TrackModel model = TrackModel.fromJson(<String, dynamic>{
        'id': 'track-2',
        'title': 'No BTS Yet',
        'audio_url': 'https://example.com/track-2.mp3',
        'is_active': true,
        'created_at': '2026-01-01T00:00:00.000Z',
      });

      expect(model.btsVideoUrl, isNull);
      expect(model.durationSeconds, isNull);
    });

    test('toEntity drops the columns the domain does not need', () {
      final TrackModel model = TrackModel.fromJson(<String, dynamic>{
        'id': 'track-1',
        'title': 'Rainy Nights',
        'audio_url': 'https://example.com/track-1.mp3',
        'bts_video_url': 'https://example.com/track-1-bts.mp4',
        'duration_seconds': 184,
        'is_active': true,
        'created_at': '2026-01-01T00:00:00.000Z',
      });

      final entity = model.toEntity();

      expect(entity.id, 'track-1');
      expect(entity.title, 'Rainy Nights');
      expect(entity.audioUrl, 'https://example.com/track-1.mp3');
      expect(entity.btsVideoUrl, 'https://example.com/track-1-bts.mp4');
      expect(entity.durationSeconds, 184);
      expect(entity.createdAt, DateTime.utc(2026));
    });
  });

  group('SceneModel', () {
    test('fromJson maps the snake_case Supabase columns', () {
      final SceneModel model = SceneModel.fromJson(<String, dynamic>{
        'id': 'scene-1',
        'title': 'Rainy Room',
        'video_url': 'https://example.com/scene-1.mp4',
        'thumbnail_url': 'https://example.com/scene-1.png',
        'sort_order': 3,
        'is_active': true,
        'created_at': '2026-01-01T00:00:00.000Z',
      });

      expect(model.videoUrl, 'https://example.com/scene-1.mp4');
      expect(model.thumbnailUrl, 'https://example.com/scene-1.png');
      expect(model.sortOrder, 3);
    });

    test('toEntity keeps the fields the switcher and background need', () {
      final SceneModel model = SceneModel.fromJson(<String, dynamic>{
        'id': 'scene-1',
        'title': 'Rainy Room',
        'video_url': 'https://example.com/scene-1.mp4',
        'thumbnail_url': 'https://example.com/scene-1.png',
        'sort_order': 3,
        'is_active': true,
        'created_at': '2026-01-01T00:00:00.000Z',
      });

      final entity = model.toEntity();

      expect(entity.id, 'scene-1');
      expect(entity.title, 'Rainy Room');
      expect(entity.videoUrl, 'https://example.com/scene-1.mp4');
      expect(entity.thumbnailUrl, 'https://example.com/scene-1.png');
      expect(entity.sortOrder, 3);
    });
  });
}
