import 'package:drift/drift.dart' show DatabaseConnection;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:purelofi/common/database/app_database.dart';
import 'package:purelofi/common/database/daos/scene.dao.dart';
import 'package:purelofi/common/database/daos/track.dao.dart';
import 'package:purelofi/common/errors/app_error.dart';
import 'package:purelofi/features/player/data/content.repository.impl.dart';
import 'package:purelofi/features/player/data/scene.model.dart';
import 'package:purelofi/features/player/data/scene_layer.model.dart';
import 'package:purelofi/features/player/data/track.model.dart';
import 'package:purelofi/features/player/domain/scene.entity.dart';
import 'package:purelofi/features/player/domain/track.entity.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../helpers/mock_repositories.dart';

void main() {
  late MockContentApi mockApi;
  late AppDatabase database;
  late ContentRepositoryImpl repository;

  setUp(() {
    mockApi = MockContentApi();
    // A real database, in memory: the local-first flow is the thing under
    // test, and a mocked cache would only prove the mock works.
    database = AppDatabase.forTesting(
      DatabaseConnection(NativeDatabase.memory()),
    );
    addTearDown(database.close);

    repository = ContentRepositoryImpl(
      api: mockApi,
      trackDao: TrackDao(database),
      sceneDao: SceneDao(database),
    );
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

      await expectLater(repository.getTracks(), throwsA(isA<NetworkError>()));
    });

    test('throws AppError.serverError on a Postgrest failure', () async {
      when(
        () => mockApi.fetchTracks(),
      ).thenThrow(const PostgrestException(message: 'relation does not exist'));

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
    test(
      'maps models to entities in the order the api returned them',
      () async {
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
      },
    );

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
      when(() => mockApi.fetchTrackById('nope')).thenAnswer((_) async => null);

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

  group('the cache', () {
    test('serves the last fetch when the network is gone', () async {
      when(
        () => mockApi.fetchTracks(),
      ).thenAnswer((_) async => <TrackModel>[makeTrackModel('track-1')]);
      await repository.getTracks();

      when(
        () => mockApi.fetchTracks(),
      ).thenThrow(Exception('SocketException: failed host lookup'));

      final List<TrackEntity> offline = await repository.getTracks();

      expect(offline.single.id, 'track-1');
    });

    test('keeps the scene and its layers, not just the scene', () async {
      when(() => mockApi.fetchScenes()).thenAnswer(
        (_) async => <SceneModel>[
          makeSceneModel(
            'scene-1',
            layers: <SceneLayerModel>[
              makeLayerModel('layer-1', zIndex: 1, frameCount: 6, fps: 12),
              makeLayerModel('layer-2', zIndex: 2, tappable: true),
            ],
          ),
        ],
      );
      await repository.getScenes();

      when(() => mockApi.fetchScenes()).thenThrow(Exception('offline'));
      final List<SceneEntity> offline = await repository.getScenes();

      expect(offline.single.layers, hasLength(2));
      expect(offline.single.layers.first.frameCount, 6);
      expect(offline.single.layers.first.fps, 12);
      expect(offline.single.layers.last.tappable, isTrue);
    });

    test('still fails when it has nothing to fall back on', () async {
      when(
        () => mockApi.fetchTracks(),
      ).thenThrow(Exception('SocketException: failed host lookup'));

      await expectLater(repository.getTracks(), throwsA(isA<NetworkError>()));
    });

    test('forgets what the server stopped listing', () async {
      when(() => mockApi.fetchTracks()).thenAnswer(
        (_) async => <TrackModel>[
          makeTrackModel('track-1'),
          makeTrackModel('track-2'),
        ],
      );
      await repository.getTracks();

      when(
        () => mockApi.fetchTracks(),
      ).thenAnswer((_) async => <TrackModel>[makeTrackModel('track-1')]);
      await repository.getTracks();

      when(() => mockApi.fetchTracks()).thenThrow(Exception('offline'));
      final List<TrackEntity> offline = await repository.getTracks();

      expect(offline.map((TrackEntity track) => track.id), <String>[
        'track-1',
      ], reason: 'a track pulled from the catalogue must stop playing');
    });

    test('a layer removed from a scene disappears from the cache', () async {
      when(() => mockApi.fetchScenes()).thenAnswer(
        (_) async => <SceneModel>[
          makeSceneModel(
            'scene-1',
            layers: <SceneLayerModel>[
              makeLayerModel('layer-1', zIndex: 1),
              makeLayerModel('layer-2', zIndex: 2),
            ],
          ),
        ],
      );
      await repository.getScenes();

      when(() => mockApi.fetchScenes()).thenAnswer(
        (_) async => <SceneModel>[
          makeSceneModel(
            'scene-1',
            layers: <SceneLayerModel>[makeLayerModel('layer-1', zIndex: 1)],
          ),
        ],
      );
      final List<SceneEntity> result = await repository.getScenes();

      expect(result.single.layers, hasLength(1));
    });
  });
}
