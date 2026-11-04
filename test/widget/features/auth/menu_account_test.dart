import 'package:flutter/material.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:purelofi/common/widgets/legal_links.widget.dart';
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

  testWidgets('signed out, the ways in are right on the page', (tester) async {
    await tester.pumpRoutedApp(overrides: overrides());
    await tester.pumpAndSettle();
    await openMenu(tester);

    // No second sheet to open first.
    expect(find.byType(AccountSheet), findsNothing);
    expect(find.byType(AccountPanel), findsOneWidget);
    expect(find.text('Continue with Google'), findsOneWidget);
    expect(find.text('Continue with email'), findsOneWidget);
  });

  testWidgets('signed in, sign out is right on the page', (tester) async {
    final FakeAuthRepository auth = FakeAuthRepository(
      signedIn: const Account(
        id: 'u1',
        method: SignInMethod.google,
        email: 'me@example.com',
      ),
    );
    await tester.pumpRoutedApp(overrides: overrides(), auth: auth);
    await tester.pumpAndSettle();
    await openMenu(tester);

    await tapMenuEntry(tester, 'Sign out');

    expect(find.text('Continue with Google'), findsOneWidget);
    expect(find.byType(AccountSheet), findsNothing);
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
    expect(find.text('Sign in'), findsNothing);
  });

  testWidgets('the room page names the room playing', (tester) async {
    await tester.pumpRoutedApp(overrides: overrides());
    await tester.pumpAndSettle();
    await openMenu(tester);

    expect(find.text('Room'), findsOneWidget);
    expect(find.text(makeScene('scene-1').title), findsOneWidget);
  });

  testWidgets('behind the scenes is gone from the menu', (tester) async {
    await tester.pumpRoutedApp(overrides: overrides());
    await tester.pumpAndSettle();
    await openMenu(tester);

    expect(find.text('Behind the scenes'), findsNothing);
    expect(find.text('Sleep timer'), findsOneWidget);
    expect(find.text('Settings'), findsOneWidget);
    expect(find.text('Share PureLofi'), findsOneWidget);
    expect(find.text('Send feedback'), findsOneWidget);
  });

  testWidgets('the legal pages are links at the bottom', (tester) async {
    await tester.pumpRoutedApp(overrides: overrides());
    await tester.pumpAndSettle();
    await openMenu(tester);

    expect(find.byType(LegalLinks), findsOneWidget);
    expect(find.text('Privacy'), findsOneWidget);
    expect(find.text('Terms'), findsOneWidget);
    expect(find.text('Imprint'), findsOneWidget);
  });

  testWidgets('the music plays the same signed out', (tester) async {
    await tester.pumpRoutedApp(overrides: overrides());
    await tester.pumpAndSettle();

    expect(fakeAudio.playedTracks.single.id, 'a');
  });
}
