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
import '../../../helpers/fake_welcome_preferences.dart';
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

  Future<void> launch(
    WidgetTester tester,
    FakeWelcomePreferences welcome, {
    FakeAuthRepository? auth,
  }) async {
    await tester.pumpRoutedApp(
      overrides: overrides(),
      welcome: welcome,
      auth: auth,
    );
    await tester.pumpAndSettle();
  }

  testWidgets('the first launch offers sign-in before any sound', (
    tester,
  ) async {
    final FakeWelcomePreferences welcome = FakeWelcomePreferences(seen: false);
    await launch(tester, welcome);

    expect(find.text('Welcome to PureLofi'), findsOneWidget);
    expect(find.text('Not now'), findsOneWidget);
    expect(fakeAudio.playedTracks, isEmpty);
    expect(welcome.seen, isTrue);
  });

  testWidgets('"Not now" closes it and starts the music', (tester) async {
    await launch(tester, FakeWelcomePreferences(seen: false));

    await tester.tap(find.text('Not now'));
    await tester.pumpAndSettle();

    expect(find.byType(AccountSheet), findsNothing);
    expect(fakeAudio.playedTracks, hasLength(1));
  });

  testWidgets('dismissing it starts the music too', (tester) async {
    await launch(tester, FakeWelcomePreferences(seen: false));

    await tester.tapAt(const Offset(10, 10));
    await tester.pumpAndSettle();

    expect(find.byType(AccountSheet), findsNothing);
    expect(fakeAudio.playedTracks, hasLength(1));
  });

  testWidgets('signing in from it closes it and starts the music', (
    tester,
  ) async {
    await launch(tester, FakeWelcomePreferences(seen: false));

    await tester.tap(find.text('Continue with Google'));
    await tester.pumpAndSettle();

    expect(find.byType(AccountSheet), findsNothing);
    expect(fakeAudio.playedTracks, hasLength(1));
  });

  testWidgets('a later launch plays at once and offers nothing', (
    tester,
  ) async {
    await launch(tester, FakeWelcomePreferences());

    expect(find.byType(AccountSheet), findsNothing);
    expect(fakeAudio.playedTracks, hasLength(1));
  });

  testWidgets('nobody is asked who is already signed in', (tester) async {
    final FakeWelcomePreferences welcome = FakeWelcomePreferences(seen: false);
    await launch(
      tester,
      welcome,
      auth: FakeAuthRepository(
        signedIn: const Account(
          id: 'u1',
          method: SignInMethod.email,
          email: 'listener@example.com',
        ),
      ),
    );

    expect(find.byType(AccountSheet), findsNothing);
    expect(welcome.seen, isTrue);
  });

  testWidgets('the menu sheet has no "Not now"', (tester) async {
    await launch(tester, FakeWelcomePreferences());
    await openMenu(tester);
    await tapMenuEntry(tester, 'Sign in');

    expect(find.text('Sign in'), findsWidgets);
    expect(find.text('Not now'), findsNothing);
  });
}
