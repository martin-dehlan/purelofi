import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:purelofi/common/errors/app_error.dart';
import 'package:purelofi/features/player/controller/player.provider.dart';
import 'package:purelofi/features/player/controller/scene.controller.dart';
import 'package:purelofi/features/player/domain/scene.entity.dart';

import '../../../helpers/mock_repositories.dart';

void main() {
  late MockContentRepository mockRepo;
  late ProviderContainer container;

  ProviderContainer makeContainer() {
    final ProviderContainer container = ProviderContainer(
      overrides: [contentRepositoryProvider.overrideWithValue(mockRepo)],
      // Riverpod 3 retries failed providers on a backoff; off here so the
      // error assertions are deterministic.
      retry: (_, _) => null,
    );
    addTearDown(container.dispose);
    // Riverpod 3 providers are auto-dispose by default, and a bare `read`
    // leaves them unlistened — keep a subscription alive for the test.
    container.listen(
      sceneListControllerProvider,
      (_, _) {},
      // Errors are asserted on the provider itself; swallow them here so they
      // do not escape into the test zone.
      onError: (_, _) {},
      fireImmediately: true,
    );
    return container;
  }

  setUp(() {
    mockRepo = MockContentRepository();
    when(() => mockRepo.getTracks()).thenAnswer((_) async => <Never>[]);
  });

  group('SceneListController', () {
    test('loads scenes from the repository', () async {
      final List<SceneEntity> scenes = <SceneEntity>[
        makeScene('scene-1'),
        makeScene('scene-2'),
      ];
      when(() => mockRepo.getScenes()).thenAnswer((_) async => scenes);
      container = makeContainer();

      final List<SceneEntity> result = await container.read(
        sceneListControllerProvider.future,
      );

      expect(result, scenes);
    });

    test('terminates instead of hanging in loading', () async {
      when(() => mockRepo.getScenes()).thenAnswer((_) async => <SceneEntity>[]);
      container = makeContainer();

      await expectLater(
        container.read(sceneListControllerProvider.future),
        completes,
      );
    });

    test('surfaces a repository failure as an error state', () async {
      when(
        () => mockRepo.getScenes(),
      ).thenThrow(const AppError.network());
      container = makeContainer();

      final AsyncValue<List<SceneEntity>> state = container.read(
        sceneListControllerProvider,
      );

      expect(state.hasError, isTrue);
      expect(state.error, isA<NetworkError>());
    });
  });

  group('ActiveSceneController', () {
    test('is null while the scene list is loading', () {
      when(() => mockRepo.getScenes()).thenAnswer((_) async => <SceneEntity>[]);
      container = makeContainer();

      expect(container.read(activeSceneControllerProvider), isNull);
    });

    test('defaults to the lowest sort_order once the list loads', () async {
      when(() => mockRepo.getScenes()).thenAnswer(
        (_) async => <SceneEntity>[
          makeScene('scene-b').copyWith(sortOrder: 2),
          makeScene('scene-a').copyWith(sortOrder: 1),
        ],
      );
      container = makeContainer();
      await container.read(sceneListControllerProvider.future);

      expect(container.read(activeSceneControllerProvider)?.id, 'scene-a');
    });

    test('stays null when there are no active scenes', () async {
      when(() => mockRepo.getScenes()).thenAnswer((_) async => <SceneEntity>[]);
      container = makeContainer();
      await container.read(sceneListControllerProvider.future);

      expect(container.read(activeSceneControllerProvider), isNull);
    });

    test('switchTo replaces the active scene', () async {
      when(() => mockRepo.getScenes()).thenAnswer(
        (_) async => <SceneEntity>[makeScene('scene-a'), makeScene('scene-b')],
      );
      container = makeContainer();
      await container.read(sceneListControllerProvider.future);

      container
          .read(activeSceneControllerProvider.notifier)
          .switchTo(makeScene('scene-b'));

      expect(container.read(activeSceneControllerProvider)?.id, 'scene-b');
    });
  });
}
