import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:purelofi/common/errors/app_error.dart';
import 'package:purelofi/features/player/data/content.repository.impl.dart';
import 'package:purelofi/features/player/data/scene.model.dart';
import 'package:purelofi/features/player/data/track.model.dart';
import 'package:purelofi/features/player/domain/scene.entity.dart';
import 'package:purelofi/features/player/domain/track.entity.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../helpers/mock_repositories.dart';

void main() {
  late MockContentApi mockApi;
  late ContentRepositoryImpl repository;

  setUp(() {
    mockApi = MockContentApi();
    repository = ContentRepositoryImpl(api: mockApi);
  });

  group('getTracks', () {
    test('maps models to entities', () async {
      when(() => mockApi.fetchTracks()).thenAnswer(
        (_) async => <TrackModel>[
          makeTrackModel('track-1', durationSeconds: 184),
          makeTrackModel('track-2'),
        ],
      );

      final List<TrackEntity> result = await repository.getTracks();

      expect(result, hasLength(2));
      expect(result.first.id, 'track-1');
      expect(result.first.durationSeconds, 184);
    });

    test('throws AppError.network on a connection failure', () async {
      when(
        () => mockApi.fetchTracks(),
      ).thenThrow(Exception('SocketException: failed host lookup'));

      await expectLater(
        repository.getTracks(),
        throwsA(isA<NetworkError>()),
      );
    });

    test('throws AppError.serverError on a Postgrest failure', () async {
      when(() => mockApi.fetchTracks()).thenThrow(
        const PostgrestException(message: 'relation does not exist'),
      );

      await expectLater(
        repository.getTracks(),
        throwsA(
          isA<ServerError>().having(
            (ServerError error) => error.message,
            'message',
            'relation does not exist',
          ),
        ),
      );
    });

    test('never lets a raw exception escape', () async {
      when(() => mockApi.fetchTracks()).thenThrow(Exception('boom'));

      await expectLater(repository.getTracks(), throwsA(isA<AppError>()));
    });
  });

  group('getScenes', () {
    test('maps models to entities in the order the api returned them', () async {
      when(() => mockApi.fetchScenes()).thenAnswer(
        (_) async => <SceneModel>[
          makeSceneModel('scene-1', sortOrder: 0),
          makeSceneModel('scene-2', sortOrder: 1),
        ],
      );

      final List<SceneEntity> result = await repository.getScenes();

      expect(result.map((SceneEntity scene) => scene.id), <String>[
        'scene-1',
        'scene-2',
      ]);
    });

    test('throws AppError on failure', () async {
      when(() => mockApi.fetchScenes()).thenThrow(Exception('boom'));

      await expectLater(repository.getScenes(), throwsA(isA<AppError>()));
    });
  });

  group('getTrackById', () {
    test('returns the mapped entity', () async {
      when(
        () => mockApi.fetchTrackById('track-1'),
      ).thenAnswer((_) async => makeTrackModel('track-1'));

      final TrackEntity? result = await repository.getTrackById('track-1');

      expect(result?.id, 'track-1');
    });

    test('returns null when the track is missing or inactive', () async {
      when(
        () => mockApi.fetchTrackById('nope'),
      ).thenAnswer((_) async => null);

      expect(await repository.getTrackById('nope'), isNull);
    });

    test('throws AppError on failure', () async {
      when(() => mockApi.fetchTrackById(any())).thenThrow(Exception('boom'));

      await expectLater(
        repository.getTrackById('track-1'),
        throwsA(isA<AppError>()),
      );
    });
  });
}
