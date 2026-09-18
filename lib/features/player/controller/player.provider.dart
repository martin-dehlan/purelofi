import 'package:flutter/widgets.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../common/config/supabase.provider.dart';
import '../data/content.api.dart';
import '../data/content.repository.impl.dart';
import '../domain/audio_player.service.dart';
import '../domain/content.repository.dart';
import '../domain/track.entity.dart';
import '../domain/scene.entity.dart';

part 'player.provider.g.dart';

/// Every provider for the player feature lives in this file (see `docs/05`).

@Riverpod(keepAlive: true)
ContentApi contentApi(Ref ref) => ContentApi(ref.watch(supabaseClientProvider));

@Riverpod(keepAlive: true)
ContentRepository contentRepository(Ref ref) =>
    ContentRepositoryImpl(api: ref.watch(contentApiProvider));

/// Builds the widget that renders a scene's video.
typedef SceneVideoBuilder = Widget Function(SceneEntity scene);

/// Builds the widget that renders a behind-the-scenes clip.
typedef BtsVideoBuilder = Widget Function(String videoUrl);

/// Test seam for the scene video surface.
///
/// `video_player` talks to platform channels, so widget tests override this
/// with a no-op builder rather than rendering a real video (see `docs/10`).
/// `null` means "use the real player".
@riverpod
SceneVideoBuilder? sceneVideoBuilder(Ref ref) => null;

/// The audio player.
///
/// `audio_service` has to be initialised before the app starts, so `main.dart`
/// creates the handler and overrides this provider with it. Tests override it
/// with a fake.
@Riverpod(keepAlive: true)
AudioPlayerService audioPlayerService(Ref ref) => throw UnimplementedError(
  'audioPlayerServiceProvider must be overridden in main.dart',
);

/// Test seam for the behind-the-scenes video surface, for the same reason as
/// [sceneVideoBuilderProvider]. `null` means "use the real player".
@riverpod
BtsVideoBuilder? btsVideoBuilder(Ref ref) => null;

/// One track by id, for the `/track/:trackId` deep link.
@riverpod
Future<TrackEntity?> trackDetail(Ref ref, String trackId) =>
    ref.watch(contentRepositoryProvider).getTrackById(trackId);
