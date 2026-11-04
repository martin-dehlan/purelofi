import 'dart:async';

import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../domain/new_content.dart';
import '../domain/player.state.dart';
import '../domain/scene.entity.dart';
import '../domain/track.entity.dart';
import 'player.controller.dart';
import 'player.provider.dart';
import 'scene.controller.dart';
import 'track.controller.dart';

part 'new_content.controller.g.dart';

/// When the app was first opened on this device.
@Riverpod(keepAlive: true)
Future<DateTime> firstLaunch(Ref ref) =>
    ref.watch(newContentRepositoryProvider).firstLaunch();

@Riverpod(keepAlive: true)
Stream<Set<String>> seenScenes(Ref ref) =>
    ref.watch(newContentRepositoryProvider).watchSeen(SeenKind.scene);

@Riverpod(keepAlive: true)
Stream<Set<String>> seenTracks(Ref ref) =>
    ref.watch(newContentRepositoryProvider).watchSeen(SeenKind.track);

/// The rooms added since the first launch and not yet stepped into (#148).
@riverpod
Set<String> newScenes(Ref ref) {
  final DateTime? first = ref.watch(firstLaunchProvider).value;
  final Set<String>? seen = ref.watch(seenScenesProvider).value;
  if (first == null || seen == null) return const <String>{};

  return newIds<SceneEntity>(
    ref.watch(sceneListControllerProvider).value ?? const <SceneEntity>[],
    id: (SceneEntity s) => s.id,
    createdAt: (SceneEntity s) => s.createdAt,
    firstLaunch: first,
    seen: seen,
  );
}

/// The tracks added since the first launch and not yet played (#148).
@riverpod
Set<String> newTracks(Ref ref) {
  final DateTime? first = ref.watch(firstLaunchProvider).value;
  final Set<String>? seen = ref.watch(seenTracksProvider).value;
  if (first == null || seen == null) return const <String>{};

  return newIds<TrackEntity>(
    ref.watch(trackListControllerProvider).value ?? const <TrackEntity>[],
    id: (TrackEntity t) => t.id,
    createdAt: (TrackEntity t) => t.createdAt,
    firstLaunch: first,
    seen: seen,
  );
}

/// Marks a room seen once it is stepped into, a track once it plays.
/// Built once at the root.
@Riverpod(keepAlive: true)
class NewContentMarker extends _$NewContentMarker {
  @override
  void build() {
    // Settles the first launch now, before any content arrives to compare.
    ref.listen(firstLaunchProvider, (_, _) {}, fireImmediately: true);

    ref.listen<SceneEntity?>(activeSceneControllerProvider, (
      SceneEntity? _,
      SceneEntity? scene,
    ) {
      if (scene != null) _mark(SeenKind.scene, scene.id);
    }, fireImmediately: true);

    String? playing;
    ref.listen<PlayerState>(playerControllerProvider, (
      PlayerState? _,
      PlayerState player,
    ) {
      final String? id = player.currentTrack?.id;
      if (id == null || id == playing) return;
      playing = id;
      _mark(SeenKind.track, id);
    }, fireImmediately: true);
  }

  void _mark(SeenKind kind, String id) => unawaited(() async {
    try {
      await ref.read(newContentRepositoryProvider).markSeen(kind, id);
    } on Object {
      // A mark that stays a little longer is no one's problem.
    }
  }());
}
