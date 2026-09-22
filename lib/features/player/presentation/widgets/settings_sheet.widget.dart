import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../common/utils/app_assets.dart';
import '../../../../common/utils/responsive.dart';
import '../../../../common/widgets/pixel_icon.widget.dart';
import '../../controller/player.controller.dart';
import '../../domain/track.entity.dart';
import 'bts_modal.widget.dart';
import 'scene_switcher_sheet.widget.dart';

/// Everything that is not playback: which scene, the footage, and who made
/// the music.
///
/// It lives behind one button so the scene itself stays uncluttered.
class SettingsSheet extends ConsumerWidget {
  const SettingsSheet({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ColorScheme cs = Theme.of(context).colorScheme;
    final TrackEntity? track = ref.watch(
      playerControllerProvider.select((state) => state.currentTrack),
    );

    return SafeArea(
      // A sheet that outgrows its space must scroll, not overflow.
      child: SingleChildScrollView(
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: context.horizontalPadding,
            vertical: context.spaceL,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              _Entry(
                asset: AppAssets.sceneSwitchIcon,
                label: 'Change scene',
                onTap: () {
                  Navigator.of(context).pop();
                  unawaited(showSceneSwitcherSheet(context));
                },
              ),
              if (track?.btsVideoUrl != null && track!.btsVideoUrl!.isNotEmpty)
                _Entry(
                  asset: AppAssets.cameraIcon,
                  label: 'Behind the scenes',
                  onTap: () {
                    Navigator.of(context).pop();
                    unawaited(showBtsModal(context, ref, track));
                  },
                ),
              SizedBox(height: context.spaceL),
              Text(
                'Every track here was played on a real guitar or bass and '
                'recorded in a room, not generated. The same recordings go up '
                'on the YouTube channel.',
                style: TextStyle(
                  color: cs.onSurfaceVariant,
                  fontSize: context.fontS,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Entry extends StatelessWidget {
  const _Entry({required this.asset, required this.label, required this.onTap});

  final String asset;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ColorScheme cs = Theme.of(context).colorScheme;

    return Semantics(
      button: true,
      label: label,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: context.spaceM),
          child: Row(
            children: <Widget>[
              PixelIcon(asset: asset, size: context.screenWidth * 0.07),
              SizedBox(width: context.spaceL),
              Expanded(
                child: Text(
                  label,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: cs.onSurface,
                    fontSize: context.fontM,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Opens the menu as a bottom sheet.
Future<void> showSettingsSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: Theme.of(context).colorScheme.surface,
    builder: (BuildContext context) => const SettingsSheet(),
  );
}
