import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../common/utils/app_fonts.dart';
import '../../../../common/utils/app_version.dart';
import '../../../../common/utils/responsive.dart';
import '../../../../common/widgets/app_icon.widget.dart';
import '../../controller/player.controller.dart';
import '../../domain/track.entity.dart';
import 'bts_modal.widget.dart';
import 'scene_switcher_sheet.widget.dart';

/// The menu top right: everything that is not the music.
///
/// The music has its own places since the library and the queue arrived —
/// under the transport, where a music app keeps them. What is left here is
/// the room, the proof that the playing is real, and the account. Accounts
/// come with Phase 2; the entry is there already, greyed and saying so, so
/// the menu does not change shape when they land.
///
/// Built from Material's own list tiles, so it reads and behaves the way a
/// phone's menus do.
class SettingsSheet extends ConsumerWidget {
  const SettingsSheet({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ColorScheme cs = Theme.of(context).colorScheme;
    final TrackEntity? track = ref.watch(
      playerControllerProvider.select((state) => state.currentTrack),
    );
    final bool hasFootage =
        track?.btsVideoUrl != null && track!.btsVideoUrl!.isNotEmpty;

    return SafeArea(
      child: SingleChildScrollView(
        child: Padding(
          padding: EdgeInsets.only(bottom: context.spaceM),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              _Entry(
                glyph: AppGlyph.scene,
                title: 'Change scene',
                onTap: () {
                  Navigator.of(context).pop();
                  unawaited(showSceneSwitcherSheet(context));
                },
              ),
              _Entry(
                glyph: AppGlyph.camera,
                title: 'Behind the scenes',
                subtitle: hasFootage
                    ? 'Watch "${track.title}" being played'
                    : 'No footage for this track',
                onTap: hasFootage
                    ? () {
                        Navigator.of(context).pop();
                        unawaited(showBtsModal(context, ref, track));
                      }
                    : null,
              ),
              const _Entry(
                glyph: AppGlyph.account,
                title: 'Account',
                subtitle: 'Coming soon',
                onTap: null,
              ),
              SizedBox(height: context.spaceM),
              Text(
                'PureLofi $appVersion',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: cs.onSurfaceVariant.withValues(alpha: 0.6),
                  fontFamily: AppFonts.wordmark,
                  fontSize: context.fontXs,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// One line of the menu. [onTap] `null` greys it out.
class _Entry extends StatelessWidget {
  const _Entry({
    required this.glyph,
    required this.title,
    required this.onTap,
    this.subtitle,
  });

  final AppGlyph glyph;
  final String title;
  final String? subtitle;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final ColorScheme cs = Theme.of(context).colorScheme;
    final bool enabled = onTap != null;

    return ListTile(
      enabled: enabled,
      contentPadding: EdgeInsets.symmetric(
        horizontal: context.horizontalPadding,
      ),
      leading: AppIcon(
        glyph,
        size: context.fontL,
        color: enabled
            ? cs.onSurfaceVariant
            : cs.onSurfaceVariant.withValues(alpha: 0.38),
      ),
      title: Text(title, style: TextStyle(fontSize: context.fontM)),
      subtitle: subtitle == null
          ? null
          : Text(subtitle!, style: TextStyle(fontSize: context.fontS)),
      onTap: onTap,
    );
  }
}

/// Opens the menu as a bottom sheet.
Future<void> showSettingsSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (BuildContext context) => const SettingsSheet(),
  );
}
