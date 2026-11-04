import 'dart:async';

import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../pro/controller/pro.controller.dart';
import '../../pro/controller/pro.provider.dart';
import '../domain/ambient_loop.dart';
import '../domain/ambient_sound.entity.dart';
import '../domain/audio_player.service.dart';
import '../domain/mix_preferences.service.dart';
import '../domain/scene.entity.dart';
import '../domain/volume_layer.dart';
import 'player.provider.dart';
import 'scene.controller.dart';

part 'mix.controller.g.dart';

/// The listener's mix (#136, #154): how loud the music is, how loud the
/// room's sounds are, and each sound's own level in each room.
///
/// The audio service plays; this keeps the settings, hands them over, and
/// hands the room's sounds over again whenever the room changes. Built at
/// the root, so the rain is there from the first second.
@Riverpod(keepAlive: true)
class MixController extends _$MixController {
  Timer? _save;

  /// The mix as last loaded or set. Held here rather than read from
  /// `state`, so a room that changes while the mix is still loading is
  /// answered with the mix, not with nothing.
  MixSettings _settings = const MixSettings();

  /// How long a slider must rest before its level is written.
  static const Duration saveAfter = Duration(milliseconds: 400);

  @override
  Future<MixSettings> build() async {
    ref.onDispose(() => _save?.cancel());

    MixSettings settings;
    try {
      settings = await ref.read(mixPreferencesProvider).load();
    } on Object {
      settings = const MixSettings();
    }

    _settings = settings;
    ref.listen<SceneEntity?>(
      activeSceneControllerProvider,
      (_, _) => _pushAmbience(),
      fireImmediately: true,
    );
    _push(settings);

    return settings;
  }

  AudioPlayerService get _audio => ref.read(audioPlayerServiceProvider);

  MixSettings get _current => _settings;

  /// The level [sound] plays at in [sceneId]: the listener's, or the room's.
  static double levelOf(
    MixSettings settings,
    String sceneId,
    AmbientSoundEntity sound,
  ) =>
      settings.soundLevels[MixSettings.soundKey(sceneId, sound.id)] ??
      sound.defaultLevel;

  void setMusicLevel(double level) =>
      _update(_current.copyWith(musicLevel: level));

  void setAmbienceLevel(double level) =>
      _update(_current.copyWith(ambienceLevel: level));

  void setAmbienceOn(bool on) => _update(_current.copyWith(ambienceOn: on));

  void setSoundLevel(String sceneId, String soundId, double level) => _update(
    _current.copyWith(
      soundLevels: <String, double>{
        ..._current.soundLevels,
        MixSettings.soundKey(sceneId, soundId): level,
      },
    ),
  );

  void _update(MixSettings next) {
    _settings = next;
    state = AsyncData<MixSettings>(next);
    _push(next);
    _save?.cancel();
    _save = Timer(saveAfter, () async {
      try {
        await ref.read(mixPreferencesProvider).save(next);
      } on Object {
        // A mix that fails to save is set again next time.
      }
    });
  }

  void _push(MixSettings settings) {
    unawaited(_audio.setVolumeLayer(VolumeLayer.music, settings.musicLevel));
    unawaited(
      _audio.setVolumeLayer(VolumeLayer.ambience, settings.ambienceLevel),
    );
    _pushAmbience(settings);
  }

  void _pushAmbience([MixSettings? settings]) {
    final MixSettings mix = settings ?? _current;
    final SceneEntity? scene = ref.read(activeSceneControllerProvider);
    unawaited(
      _audio.setAmbience(<AmbientLoop>[
        if (mix.ambienceOn && scene != null)
          for (final AmbientSoundEntity sound in scene.ambients)
            if (levelOf(mix, scene.id, sound) > 0)
              AmbientLoop(
                id: sound.id,
                url: sound.audioUrl,
                level: levelOf(mix, scene.id, sound),
              ),
      ]),
    );
  }
}

/// Whether the listener may set each sound's own level: with Pro, or
/// anywhere Pro is not for sale. Everyone hears the room's sounds and sets
/// the overall levels; the fine mix is Pro (#136).
@riverpod
bool mixerOpen(Ref ref) {
  if (!ref.watch(proRepositoryProvider).isAvailable) return true;

  return ref.watch(proControllerProvider).value?.isPro ?? false;
}
