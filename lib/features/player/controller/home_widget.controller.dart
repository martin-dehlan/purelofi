import 'dart:async';
import 'dart:io';

import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../common/cache/media_cache.service.dart';
import '../../../common/theme/app_palette.dart';
import '../domain/home_widget.service.dart';
import '../domain/player.state.dart';
import '../domain/scene.entity.dart';
import 'player.controller.dart';
import 'palette.controller.dart';
import 'player.provider.dart';
import 'scene.controller.dart';

part 'home_widget.controller.g.dart';

/// Keeps the home and lock screen widgets in step with the app (#144):
/// the room, the track, playing or not, and the app's accent. Only when something they show
/// changed: the position ticking along is not their business. Built at
/// the root.
@Riverpod(keepAlive: true)
class HomeWidgetSync extends _$HomeWidgetSync {
  WidgetSnapshot? _last;

  @override
  void build() {
    ref.listen<SceneEntity?>(
      activeSceneControllerProvider,
      (_, _) => unawaited(_push()),
      fireImmediately: true,
    );
    ref.listen<PlayerState>(playerControllerProvider, (
      PlayerState? before,
      PlayerState now,
    ) {
      if (before?.currentTrack?.id != now.currentTrack?.id ||
          before?.isPlaying != now.isPlaying) {
        unawaited(_push());
      }
    });
    // A palette picked in the settings colours the widget too.
    ref.listen<AsyncValue<AppPalette>>(
      paletteControllerProvider,
      (_, _) => unawaited(_push()),
    );
  }

  Future<void> _push() async {
    final SceneEntity? scene = ref.read(activeSceneControllerProvider);
    if (scene == null) return;
    final PlayerState player = ref.read(playerControllerProvider);

    String? cover;
    final String? url = scene.thumbnailUrl;
    final MediaCache? cache = ref.read(mediaCacheProvider);
    if (url != null && cache != null) {
      try {
        final File? file = await cache.store(url);
        cover = file?.path;
      } on Object {
        cover = null;
      }
    }

    final WidgetSnapshot next = WidgetSnapshot(
      room: scene.title,
      track: player.currentTrack?.title,
      artist: player.currentTrack?.artistName,
      coverPath: cover,
      isPlaying: player.isPlaying,
      accent:
          (ref.read(paletteControllerProvider).value ?? AppPalette.lamp).hex,
    );
    if (next == _last) return;
    _last = next;
    await ref.read(homeWidgetServiceProvider).show(next);
  }
}
