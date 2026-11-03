import 'package:flutter/material.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:purelofi/features/auth/domain/account.entity.dart';
import 'package:purelofi/features/auth/presentation/widgets/account_sheet.widget.dart';
import 'package:purelofi/features/player/controller/player.provider.dart';
import 'package:purelofi/features/player/domain/scene.entity.dart';
import 'package:purelofi/features/player/domain/track.entity.dart';

import '../../../helpers/fake_audio_player.service.dart';
import '../../../helpers/fake_auth.repository.dart';
import '../../../helpers/mock_repositories.dart';
import '../../../helpers/pump_routed_app.dart';

void main() {
  late MockContentRepository mockRepo;
  late FakeAudioPlayerService fakeAudio;

  setUp(() {
    mockRepo = MockContentRepository();
    fakeAudio = FakeAudioPlayerService();
    addTearDown(fakeAudio.dispose);
    when(
      () => mockRepo.getScenes(),
    ).thenAnswer((_) async => <SceneEntity>[makeScene('scene-1')]);
    when(
      () => mockRepo.getTracks(),
    ).thenAnswer((_) async => <TrackEntity>[makeTrack('a')]);
  });

  List<Override> overrides() => <Override>[
    contentRepositoryProvider.overrideWithValue(mockRepo),
    audioPlayerServiceProvider.overrideWithValue(fakeAudio),
    sceneVideoBuilderProvider.overrideWithValue(
      (SceneEntity scene) => const SizedBox.shrink(),
    ),
  ];

  testWidgets('signed out, the menu offers it as optional', (tester) async {
    await tester.pumpRoutedApp(overrides: overrides());
    await tester.pumpAndSettle();
    await openMenu(tester);

    expect(find.text('Optional — sign in if you like'), findsOneWidget);

    await tapMenuEntry(tester, 'Account');

    expect(find.byType(AccountSheet), findsOneWidget);
    expect(find.text('Sign in'), findsOneWidget);
  });

  testWidgets('signed in, the menu says who', (tester) async {
    await tester.pumpRoutedApp(
      overrides: overrides(),
      auth: FakeAuthRepository(
        signedIn: const Account(
          id: 'u1',
          method: SignInMethod.google,
          email: 'me@example.com',
        ),
      ),
    );
    await tester.pumpAndSettle();
    await openMenu(tester);

    expect(find.text('me@example.com'), findsOneWidget);
  });

  testWidgets('the music plays the same signed out', (tester) async {
    await tester.pumpRoutedApp(overrides: overrides());
    await tester.pumpAndSettle();

    expect(fakeAudio.playedTracks.single.id, 'a');
  });
}
