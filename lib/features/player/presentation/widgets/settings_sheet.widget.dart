import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../common/utils/app_fonts.dart';
import '../../../../common/utils/app_version.dart';
import '../../../../common/utils/responsive.dart';
import '../../../../common/widgets/app_icon.widget.dart';
import 'scene_switcher_sheet.widget.dart';
import 'track_list.widget.dart';

/// The menu: the tracks first, then the room, then who made the music.
///
/// The track list is what people look for in a player, so it leads (#67).
/// Behind-the-scenes footage is reached from its track's row, not from an
/// entry of its own. Favourites are out of the menu until the catalogue is
/// big enough for choosing among tracks to matter; the code for them stays.
class SettingsSheet extends StatelessWidget {
  const SettingsSheet({super.key});

  @override
  Widget build(BuildContext context) {
    final ColorScheme cs = Theme.of(context).colorScheme;

    return SafeArea(
      // A sheet that outgrows its space must scroll, not overflow: a short
      // screen or a landscape phone cannot fit the list and the rest at once.
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
              const TrackList(),
              SizedBox(height: context.spaceM),
              _Entry(
                glyph: AppGlyph.scene,
                label: 'Change scene',
                onTap: () {
                  Navigator.of(context).pop();
                  unawaited(showSceneSwitcherSheet(context));
                },
              ),
              SizedBox(height: context.spaceM),
              Text(
                'Every track here was played on a real guitar or bass and '
                'recorded in a room, not generated. The same recordings go up '
                'on the YouTube channel.',
                style: TextStyle(
                  color: cs.onSurfaceVariant,
                  fontSize: context.fontS,
                  height: 1.5,
                ),
              ),
              SizedBox(height: context.spaceM),
              Text(
                'PureLofi $appVersion',
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

class _Entry extends StatelessWidget {
  const _Entry({required this.glyph, required this.label, required this.onTap});

  final AppGlyph glyph;
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
              AppIcon(glyph, size: context.fontL),
              // The same gap as a track row, so this label lines up with the
              // titles above it.
              SizedBox(width: context.spaceM),
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
///
/// Scroll-controlled so it may grow past Flutter's default of 9/16 of the
/// screen: a full track list plus the rest of the menu does not fit in that.
/// The list caps itself, so the sheet still never covers the whole scene.
Future<void> showSettingsSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Theme.of(context).colorScheme.surface,
    builder: (BuildContext context) => const SettingsSheet(),
  );
}
