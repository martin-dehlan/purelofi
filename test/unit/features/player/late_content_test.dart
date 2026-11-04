import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:purelofi/features/player/controller/artist.controller.dart';
import 'package:purelofi/features/player/controller/player.provider.dart';
import 'package:purelofi/features/player/controller/scene.controller.dart';
import 'package:purelofi/features/player/controller/track.controller.dart';
import 'package:purelofi/features/player/domain/artist.entity.dart';
import 'package:purelofi/features/player/domain/scene.entity.dart';
import 'package:purelofi/features/player/domain/track.entity.dart';

import '../../../helpers/mock_repositories.dart';

/// A repository whose late fetches the test lands by hand.
class _LateContent extends MockContentRepository {
  final StreamController<void> landed = StreamController<void>.broadcast();

  @override
  Stream<void> get updates => landed.stream;
}

void main() {
  late _LateContent content;
  late ProviderContainer container;

  setUp(() {
    content = _LateContent();
    addTearDown(content.landed.close);
    container = ProviderContainer(
      overrides: [contentRepositoryProvider.overrideWithValue(content)],
      retry: (_, _) => null,
    );
    addTearDown(container.dispose);
  });

  test('a track taken off the server goes once the late fetch lands', () async {
    when(
      () => content.getTracks(),
    ).thenAnswer((_) async => <TrackEntity>[makeTrack('old'), makeTrack('a')]);
    when(
      () => content.getTracks(cachedOnly: true),
    ).thenAnswer((_) async => <TrackEntity>[makeTrack('a')]);
    container.listen(trackListControllerProvider, (_, _) {});

    expect(
      (await container.read(trackListControllerProvider.future)).length,
      2,
    );

    content.landed.add(null);
    await pumpEventQueue();

    expect(container.read(trackListControllerProvider).value!.single.id, 'a');
    // Only the cache was read again; the network once.
    verify(() => content.getTracks()).called(1);
  });

  test('artists that came late show up', () async {
    const ArtistEntity masso = ArtistEntity(id: 'masso', name: 'Masso');
    when(() => content.getArtists()).thenAnswer((_) async => <ArtistEntity>[]);
    when(
      () => content.getArtists(cachedOnly: true),
    ).thenAnswer((_) async => <ArtistEntity>[masso]);
    container.listen(artistListControllerProvider, (_, _) {});
    await container.read(artistListControllerProvider.future);

    content.landed.add(null);
    await pumpEventQueue();

    expect(container.read(artistListControllerProvider).value, <ArtistEntity>[
      masso,
    ]);
  });

  test('so do scenes', () async {
    when(
      () => content.getScenes(),
    ).thenAnswer((_) async => <SceneEntity>[makeScene('a')]);
    when(
      () => content.getScenes(cachedOnly: true),
    ).thenAnswer((_) async => <SceneEntity>[makeScene('a'), makeScene('b')]);
    container.listen(sceneListControllerProvider, (_, _) {});
    await container.read(sceneListControllerProvider.future);

    content.landed.add(null);
    await pumpEventQueue();

    expect(container.read(sceneListControllerProvider).value, hasLength(2));
  });

  test('a cache that cannot be read keeps the list on screen', () async {
    when(
      () => content.getTracks(),
    ).thenAnswer((_) async => <TrackEntity>[makeTrack('a')]);
    when(
      () => content.getTracks(cachedOnly: true),
    ).thenThrow(StateError('broken'));
    container.listen(trackListControllerProvider, (_, _) {});
    await container.read(trackListControllerProvider.future);

    content.landed.add(null);
    await pumpEventQueue();

    expect(container.read(trackListControllerProvider).value!.single.id, 'a');
  });
}
