import 'package:flutter/material.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:purelofi/common/errors/app_error.dart';
import 'package:purelofi/common/widgets/app_icon.widget.dart';
import 'package:purelofi/features/player/controller/player.provider.dart';
import 'package:purelofi/features/player/domain/scene.entity.dart';
import 'package:purelofi/features/player/domain/track.entity.dart';
import 'package:purelofi/features/player/presentation/widgets/scene_switcher_sheet.widget.dart';
import 'package:purelofi/features/pro/domain/pro.repository.dart';
import 'package:purelofi/features/pro/domain/pro_plan.entity.dart';
import 'package:purelofi/features/pro/domain/pro_status.entity.dart';
import 'package:purelofi/features/pro/presentation/widgets/paywall_sheet.widget.dart';

import '../../../helpers/fake_audio_player.service.dart';
import '../../../helpers/fake_pro.repository.dart';
import '../../../helpers/mock_repositories.dart';
import '../../../helpers/pump_routed_app.dart';

void main() {
  late MockContentRepository mockRepo;
  late FakeAudioPlayerService fakeAudio;

  final List<SceneEntity> scenes = <SceneEntity>[
    makeScene('autumn', title: 'Autumn Bookshop').copyWith(sortOrder: 1),
    makeScene('rainy', title: 'Rainy Room').copyWith(sortOrder: 2),
    makeScene('snow', title: 'Snow Cabin').copyWith(sortOrder: 3),
  ];

  /// A phone, not the test default of 800×600: the sheet's buttons sit
  /// below the plans, and a tap has to reach them.
  void phoneSized(WidgetTester tester) {
    tester.view.physicalSize = const Size(1179, 2556);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
  }

  setUp(() {
    mockRepo = MockContentRepository();
    fakeAudio = FakeAudioPlayerService();
    addTearDown(fakeAudio.dispose);
    when(() => mockRepo.getScenes()).thenAnswer((_) async => scenes);
    when(
      () => mockRepo.getTracks(),
    ).thenAnswer((_) async => <TrackEntity>[makeTrack('a')]);
  });

  List<Override> overrides() => <Override>[
    contentRepositoryProvider.overrideWithValue(mockRepo),
    audioPlayerServiceProvider.overrideWithValue(fakeAudio),
    sceneVideoBuilderProvider.overrideWithValue(
      (SceneEntity scene) => Text('scene ${scene.id}'),
    ),
  ];

  Future<void> openSwitcher(WidgetTester tester, FakeProRepository pro) async {
    phoneSized(tester);
    await tester.pumpRoutedApp(overrides: overrides(), pro: pro);
    await tester.pumpAndSettle();
    await openMenu(tester);
    await tapMenuEntry(tester, 'Change scene');
  }

  Finder lockOn(String title) => find.descendant(
    of: find.widgetWithText(ListTile, title),
    matching: find.byWidgetPredicate(
      (Widget w) => w is AppIcon && w.glyph == AppGlyph.lock,
    ),
  );

  group('the scene list', () {
    testWidgets('the first two are open, the rest carry a lock', (
      tester,
    ) async {
      await openSwitcher(tester, FakeProRepository());

      expect(lockOn('Autumn Bookshop'), findsNothing);
      expect(lockOn('Rainy Room'), findsNothing);
      expect(lockOn('Snow Cabin'), findsOneWidget);
    });

    testWidgets('a locked room opens the paywall, not the room', (
      tester,
    ) async {
      await openSwitcher(tester, FakeProRepository());

      await tester.tap(find.text('Snow Cabin'));
      await tester.pumpAndSettle();

      expect(find.byType(PaywallSheet), findsOneWidget);
      expect(find.text('scene snow'), findsNothing);
    });

    testWidgets('buying from there opens the room that was tapped', (
      tester,
    ) async {
      final FakeProRepository pro = FakeProRepository();
      await openSwitcher(tester, pro);
      await tester.tap(find.text('Snow Cabin'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Start 7-day free trial'));
      await tester.pumpAndSettle();

      expect(pro.calls, <String>['purchase yearly']);
      expect(find.byType(PaywallSheet), findsNothing);
      expect(find.text('scene snow'), findsOneWidget);
    });

    testWidgets('with Pro there are no locks', (tester) async {
      await openSwitcher(
        tester,
        FakeProRepository(initial: const ProStatus(isPro: true)),
      );

      expect(lockOn('Snow Cabin'), findsNothing);
    });

    testWidgets('where Pro is not for sale there are no locks', (tester) async {
      await openSwitcher(tester, FakeProRepository(available: false));

      expect(lockOn('Snow Cabin'), findsNothing);
      expect(find.byType(SceneSwitcherSheet), findsOneWidget);
    });
  });

  group('the paywall', () {
    Future<FakeProRepository> open(
      WidgetTester tester, [
      FakeProRepository? repository,
    ]) async {
      final FakeProRepository pro = repository ?? FakeProRepository();
      phoneSized(tester);
      await tester.pumpProviderApp(
        child: const Scaffold(body: PaywallSheet(source: 'menu')),
        overrides: overrides(),
        pro: pro,
      );
      await tester.pumpAndSettle();
      return pro;
    }

    testWidgets('shows both plans, yearly chosen, with the trial', (
      tester,
    ) async {
      await open(tester);

      expect(find.text('PureLofi Pro'), findsOneWidget);
      expect(find.text('Yearly'), findsOneWidget);
      expect(find.text('Monthly'), findsOneWidget);
      expect(find.text('7 days free'), findsOneWidget);
      expect(find.text('Start 7-day free trial'), findsOneWidget);
      expect(
        find.text(
          'Free for 7 days, then €29.99 a year. '
          'Cancel any time in your store settings.',
        ),
        findsOneWidget,
      );
    });

    testWidgets('monthly has no trial, and says what it renews at', (
      tester,
    ) async {
      final FakeProRepository pro = await open(tester);

      await tester.tap(find.text('Monthly'));
      await tester.pumpAndSettle();
      expect(find.text('Get Pro'), findsOneWidget);
      expect(
        find.text(
          'Renews at €3.99 a month. Cancel any time in your store settings.',
        ),
        findsOneWidget,
      );

      await tester.tap(find.text('Get Pro'));
      await tester.pumpAndSettle();
      expect(pro.calls, <String>['purchase monthly']);
    });

    testWidgets('closing the store sheet says nothing', (tester) async {
      await open(
        tester,
        FakeProRepository()..outcome = PurchaseOutcome.cancelled,
      );

      await tester.tap(find.text('Start 7-day free trial'));
      await tester.pumpAndSettle();

      expect(find.byType(PaywallSheet), findsOneWidget);
      expect(find.textContaining('did not go through'), findsNothing);
    });

    testWidgets('a pending purchase says it is waiting', (tester) async {
      await open(
        tester,
        FakeProRepository()..outcome = PurchaseOutcome.pending,
      );

      await tester.tap(find.text('Start 7-day free trial'));
      await tester.pumpAndSettle();

      expect(
        find.text('Waiting for the store to confirm. Pro opens when it does.'),
        findsOneWidget,
      );
    });

    testWidgets('a failure is one sentence', (tester) async {
      await open(
        tester,
        FakeProRepository()
          ..failWith = const AppError.purchase(
            message: 'The purchase did not go through. Please try again.',
          ),
      );

      await tester.tap(find.text('Start 7-day free trial'));
      await tester.pumpAndSettle();

      expect(
        find.text('The purchase did not go through. Please try again.'),
        findsOneWidget,
      );
    });

    testWidgets('restore with nothing to restore says so', (tester) async {
      await open(tester);

      await tester.tap(find.text('Restore purchases'));
      await tester.pumpAndSettle();

      expect(
        find.text('No earlier purchase on this store account.'),
        findsOneWidget,
      );
    });

    testWidgets('shows the locked rooms it opens', (tester) async {
      await open(tester);

      expect(
        find.text('Every room, every night — 1 more to sit in.'),
        findsOneWidget,
      );
      expect(find.bySemanticsLabel('Snow Cabin'), findsOneWidget);
    });
  });

  group('the menu', () {
    testWidgets('offers Pro where it is for sale', (tester) async {
      await tester.pumpRoutedApp(
        overrides: overrides(),
        pro: FakeProRepository(),
      );
      await tester.pumpAndSettle();
      await openMenu(tester);

      expect(find.text('PureLofi Pro'), findsOneWidget);
      expect(find.text('Unlock every room'), findsOneWidget);

      await tapMenuEntry(tester, 'PureLofi Pro');
      expect(find.byType(PaywallSheet), findsOneWidget);
    });

    testWidgets('says which plan a Pro listener has', (tester) async {
      await tester.pumpRoutedApp(
        overrides: overrides(),
        pro: FakeProRepository(
          initial: const ProStatus(isPro: true, plan: PlanPeriod.yearly),
        ),
      );
      await tester.pumpAndSettle();
      await openMenu(tester);

      expect(find.text('Pro · yearly'), findsOneWidget);
    });

    testWidgets('has no Pro row where Pro is not for sale', (tester) async {
      await tester.pumpRoutedApp(overrides: overrides());
      await tester.pumpAndSettle();
      await openMenu(tester);

      expect(find.text('PureLofi Pro'), findsNothing);
    });
  });
}
