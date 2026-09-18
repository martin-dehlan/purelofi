import 'package:flutter/widgets.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../common/config/supabase.provider.dart';
import '../data/content.api.dart';
import '../data/content.repository.impl.dart';
import '../domain/content.repository.dart';
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

/// Test seam for the scene video surface.
///
/// `video_player` talks to platform channels, so widget tests override this
/// with a no-op builder rather than rendering a real video (see `docs/10`).
/// `null` means "use the real player".
@riverpod
SceneVideoBuilder? sceneVideoBuilder(Ref ref) => null;
