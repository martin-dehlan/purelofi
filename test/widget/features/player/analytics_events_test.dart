import 'package:flutter/material.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:purelofi/common/analytics/analytics.provider.dart';
import 'package:purelofi/features/player/controller/player.provider.dart';
import 'package:purelofi/features/player/domain/scene.entity.dart';
import 'package:purelofi/features/player/domain/track.entity.dart';
import 'package:purelofi/features/player/presentation/widgets/bts_button.widget.dart';
import 'package:purelofi/features/player/presentation/widgets/scene_switcher.widget.dart';

import '../../../helpers/fake_audio_player.service.dart';
import '../../../helpers/mock_repositories.dart';
import '../../../helpers/pump_routed_app.dart';
import '../../../helpers/recording_analytics.service.dart';

void main() {
  late MockContentRepository mockRepo;
  late FakeAudioPlayerService fakeAudio;
  late RecordingAnalyticsService analytics;

  setUp(() {
    mockRepo = MockContentRepository();
    fakeAudio = FakeAudioPlayerService();
    analytics = RecordingAnalyticsService();
    addTearDown(fakeAudio.dispose);
    when(() => mockRepo.getScenes()).thenAnswer(
      (_) async => <SceneEntity>[
        makeScene('scene-a').copyWith(sortOrder: 1),
        makeScene('scene-b', title: 'Night Bus').copyWith(sortOrder: 2),
      ],
    );
    when(() => mockRepo.getTracks()).thenAnswer(
      (_) async => <TrackEntity>[
        makeTrack(
          'track-1',
        ).copyWith(btsVideoUrl: 'https://example.com/bts.mp4'),
      ],
    );
  });

  List<Override> overrides() => <Override>[
    contentRepositoryProvider.overrideWithValue(mockRepo),
    audioPlayerServiceProvider.overrideWithValue(fakeAudio),
    analyticsServiceProvider.overrideWithValue(analytics),
    sceneVideoBuilderProvider.overrideWithValue(
      (SceneEntity scene) => const SizedBox.shrink(),
    ),
    btsVideoBuilderProvider.overrideWithValue(
      (String url) => const SizedBox.shrink(),
    ),
  ];

  testWidgets('playing a track reports track_played with its id', (
    tester,
  ) async {
    await tester.pumpRoutedApp(overrides: overrides());
    await tester.pumpAndSettle();

    expect(analytics.eventNames, contains('track_played'));
    expect(analytics.events.first.$2, <String, Object>{
      'track_id': 'track-1',
    });
  });

  testWidgets('opening the footage reports bts_opened with the track id', (
    tester,
  ) async {
    await tester.pumpRoutedApp(overrides: overrides());
    await tester.pumpAndSettle();

    await tester.tap(find.byType(BtsButton));
    await tester.pumpAndSettle();

    expect(analytics.eventNames, contains('bts_opened'));
    expect(
      analytics.events
          .firstWhere(
            ((String, Map<String, Object>) e) => e.$1 == 'bts_opened',
          )
          .$2,
      <String, Object>{'track_id': 'track-1'},
    );
  });

  testWidgets('switching scenes reports scene_switched with the scene id', (
    tester,
  ) async {
    await tester.pumpRoutedApp(overrides: overrides());
    await tester.pumpAndSettle();

    await tester.tap(find.byType(SceneSwitcher));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Night Bus'));
    await tester.pumpAndSettle();

    expect(
      analytics.events
          .firstWhere(
            ((String, Map<String, Object>) e) => e.$1 == 'scene_switched',
          )
          .$2,
      <String, Object>{'scene_id': 'scene-b'},
    );
  });

  testWidgets('nothing personal is ever attached to an event', (tester) async {
    await tester.pumpRoutedApp(overrides: overrides());
    await tester.pumpAndSettle();
    await tester.tap(find.byType(BtsButton));
    await tester.pumpAndSettle();

    for (final (String, Map<String, Object>) event in analytics.events) {
      expect(event.$2.keys, everyElement(anyOf('track_id', 'scene_id')));
    }
  });
}
