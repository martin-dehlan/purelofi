import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../common/utils/responsive.dart';
import '../../../../common/widgets/app_icon.widget.dart';
import '../../../../common/widgets/menu_row.widget.dart';
import '../../../pro/presentation/widgets/paywall_sheet.widget.dart';
import '../../../pro/presentation/widgets/pro_pill.widget.dart';
import '../../controller/mix.controller.dart';
import '../../controller/room_music.controller.dart';
import '../../controller/soft_transitions.controller.dart';
import '../../controller/scene.controller.dart';
import '../../domain/ambient_sound.entity.dart';
import '../../domain/mix_preferences.service.dart';
import '../../domain/scene.entity.dart';
import '../../../../l10n/l10n.dart';

/// The room page's "Sound" card (#136, #154): the music's level, the room's
/// sounds on or off with their overall level, and a slider for each sound
/// the room brings.
class SoundMix extends ConsumerWidget {
  const SoundMix({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ColorScheme cs = Theme.of(context).colorScheme;
    final MixSettings mix =
        ref.watch(mixControllerProvider).value ?? const MixSettings();
    final MixController controller = ref.read(mixControllerProvider.notifier);
    final SceneEntity? scene = ref.watch(activeSceneControllerProvider);
    final List<AmbientSoundEntity> sounds =
        scene?.ambients ?? const <AmbientSoundEntity>[];
    final bool open = ref.watch(mixerOpenProvider);
    final bool softTransitions =
        ref.watch(softTransitionsControllerProvider).value ?? true;
    final bool followRoom =
        ref.watch(followRoomControllerProvider).value ?? false;

    TextStyle label([bool dim = false]) => TextStyle(
      color: dim ? cs.onSurfaceVariant : cs.onSurface,
      fontSize: context.fontS,
      fontWeight: FontWeight.w600,
    );

    Widget slider({
      required String title,
      required double value,
      required ValueChanged<double>? onChanged,
      Widget? trailing,
      bool dim = false,
    }) => Padding(
      padding: EdgeInsets.symmetric(horizontal: context.spaceM),
      child: Row(
        children: <Widget>[
          SizedBox(
            width: context.screenWidth * 0.22,
            child: Text(
              title,
              overflow: TextOverflow.ellipsis,
              style: label(dim),
            ),
          ),
          Expanded(
            child: Slider(
              value: value.clamp(0.0, 1.0),
              onChanged: onChanged,
              semanticFormatterCallback: (double v) =>
                  '$title ${(v * 100).round()}%',
            ),
          ),
          ?trailing,
        ],
      ),
    );

    return Padding(
      padding: EdgeInsets.symmetric(vertical: context.spaceS),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          slider(
            title: context.l10n.music,
            value: mix.musicLevel,
            onChanged: controller.setMusicLevel,
          ),
          if (sounds.isNotEmpty) ...<Widget>[
            SwitchListTile(
              contentPadding: EdgeInsets.symmetric(horizontal: context.spaceM),
              title: Text(context.l10n.roomSounds, style: label()),
              subtitle: Text(
                sounds.map((AmbientSoundEntity s) => s.title).join(' · '),
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: cs.onSurfaceVariant,
                  fontSize: context.fontS,
                ),
              ),
              value: mix.ambienceOn,
              onChanged: controller.setAmbienceOn,
            ),
            if (mix.ambienceOn) ...<Widget>[
              slider(
                title: context.l10n.sounds,
                value: mix.ambienceLevel,
                onChanged: controller.setAmbienceLevel,
              ),
              for (final AmbientSoundEntity sound in sounds)
                slider(
                  title: sound.title,
                  dim: !open,
                  value: MixController.levelOf(mix, scene!.id, sound),
                  // Each sound's own level is the fine mix, and Pro.
                  onChanged: open
                      ? (double v) =>
                            controller.setSoundLevel(scene.id, sound.id, v)
                      : null,
                  trailing: open
                      ? null
                      : ProPill(
                          label: context.l10n.pro,
                          filled: true,
                          onTap: () => unawaited(
                            showPaywallSheet(context, source: 'mixer'),
                          ),
                        ),
                ),
            ],
          ],
          // How the music runs, beside how loud it is: one card for all
          // of the sound, not half of it under Settings.
          MenuRow(
            glyph: AppGlyph.next,
            title: context.l10n.softTransitions,
            subtitle: context.l10n.tracksFadeIntoEachOther,
            trailing: Switch(
              value: softTransitions,
              onChanged: (bool on) => unawaited(
                ref.read(softTransitionsControllerProvider.notifier).set(on),
              ),
            ),
            onTap: () => unawaited(
              ref
                  .read(softTransitionsControllerProvider.notifier)
                  .set(!softTransitions),
            ),
          ),
          MenuRow(
            glyph: AppGlyph.scene,
            title: context.l10n.musicFollowsTheRoom,
            subtitle: context.l10n.eachRoomPlaysItsOwnMood,
            trailing: Switch(
              value: followRoom,
              onChanged: (bool on) => unawaited(
                ref.read(followRoomControllerProvider.notifier).set(on),
              ),
            ),
            onTap: () => unawaited(
              ref.read(followRoomControllerProvider.notifier).set(!followRoom),
            ),
          ),
        ],
      ),
    );
  }
}
