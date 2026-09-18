import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:purelofi/common/errors/app_error.dart';
import 'package:purelofi/common/widgets/error_state.widget.dart';
import 'package:purelofi/common/widgets/loading_state.widget.dart';
import 'package:purelofi/features/player/controller/player.provider.dart';
import 'package:purelofi/features/player/domain/scene.entity.dart';
import 'package:purelofi/features/player/presentation/widgets/scene_background.widget.dart';

import '../../../helpers/mock_repositories.dart';
import '../../../helpers/pump_routed_app.dart';

/// Stands in for the real video surface: `video_player` talks to platform
/// channels, so the widget is injected through `sceneVideoBuilderProvider`
/// (see `docs/10`).
Widget stubVideo(SceneEntity scene) =>
    Text('playing ${scene.id}', textDirection: TextDirection.ltr);

void main() {
  late MockContentRepository mockRepo;

  setUp(() {
    mockRepo = MockContentRepository();
  });

  List<Override> overrides() => <Override>[
    contentRepositoryProvider.overrideWithValue(mockRepo),
    sceneVideoBuilderProvider.overrideWithValue(stubVideo),
  ];

  testWidgets('shows the loading state while scenes load', (tester) async {
    final Completer<List<SceneEntity>> completer =
        Completer<List<SceneEntity>>();
    when(() => mockRepo.getScenes()).thenAnswer((_) => completer.future);

    await tester.pumpProviderApp(
      child: const SceneBackground(),
      overrides: overrides(),
    );

    expect(find.byType(LoadingState), findsOneWidget);

    completer.complete(<SceneEntity>[makeScene('scene-1')]);
    await tester.pumpAndSettle();
  });

  testWidgets('shows the error state when the fetch fails', (tester) async {
    when(() => mockRepo.getScenes()).thenThrow(const AppError.network());

    await tester.pumpProviderApp(
      child: const SceneBackground(),
      overrides: overrides(),
    );
    await tester.pumpAndSettle();

    expect(find.byType(ErrorState), findsOneWidget);
    expect(
      find.text('No internet connection. Check your network.'),
      findsOneWidget,
    );
  });

  testWidgets('retry refetches the scenes', (tester) async {
    int calls = 0;
    when(() => mockRepo.getScenes()).thenAnswer((_) async {
      calls++;
      throw const AppError.network();
    });

    await tester.pumpProviderApp(
      child: const SceneBackground(),
      overrides: overrides(),
    );
    await tester.pumpAndSettle();
    expect(calls, 1);

    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();

    expect(calls, 2);
  });

  testWidgets('renders the first scene by sort_order', (tester) async {
    when(() => mockRepo.getScenes()).thenAnswer(
      (_) async => <SceneEntity>[
        makeScene('scene-b').copyWith(sortOrder: 2),
        makeScene('scene-a').copyWith(sortOrder: 1),
      ],
    );

    await tester.pumpProviderApp(
      child: const SceneBackground(),
      overrides: overrides(),
    );
    await tester.pumpAndSettle();

    expect(find.text('playing scene-a'), findsOneWidget);
  });

  testWidgets('fills the available space', (tester) async {
    when(
      () => mockRepo.getScenes(),
    ).thenAnswer((_) async => <SceneEntity>[makeScene('scene-1')]);

    await tester.pumpProviderApp(
      child: const SceneBackground(),
      overrides: overrides(),
    );
    await tester.pumpAndSettle();

    final Size size = tester.getSize(find.byType(SceneBackground));
    expect(size, tester.view.physicalSize / tester.view.devicePixelRatio);
  });

  testWidgets('shows the surface when no scene is active', (tester) async {
    when(() => mockRepo.getScenes()).thenAnswer((_) async => <SceneEntity>[]);

    await tester.pumpProviderApp(
      child: const SceneBackground(),
      overrides: overrides(),
    );
    await tester.pumpAndSettle();

    expect(find.byType(LoadingState), findsNothing);
    expect(find.textContaining('playing'), findsNothing);
  });
}
