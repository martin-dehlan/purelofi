import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../common/utils/app_fonts.dart';
import '../../../../common/utils/app_version.dart';
import '../../../../common/utils/responsive.dart';
import '../../../../common/widgets/app_icon.widget.dart';
import '../../../library/presentation/widgets/my_music.widget.dart';
import '../../controller/playback_source.controller.dart';
import '../../domain/track.entity.dart';
import 'scene_switcher_sheet.widget.dart';
import 'track_list.widget.dart';

/// The menu: the tracks first, then a way to the next room.
///
/// The track list is what people look for in a player, so it leads (#67).
/// Behind-the-scenes footage is reached from its track's row, not from an
/// entry of its own. Favourites are out of the menu until the catalogue is
/// big enough for choosing among tracks to matter; the code for them stays.
///
/// Beside PureLofi's list sits the listener's own (#66). The switch between
/// them only shows a list; the stream changes side when a track from the
/// other one is played. The menu opens on whichever side is playing.
///
/// Built from Material's own parts — a segmented switch, list tiles, a
/// tonal button — so it reads and behaves the way a phone's menus do.
class SettingsSheet extends ConsumerStatefulWidget {
  const SettingsSheet({super.key});

  @override
  ConsumerState<SettingsSheet> createState() => _SettingsSheetState();
}

class _SettingsSheetState extends ConsumerState<SettingsSheet> {
  late TrackSource _tab = ref.read(playbackSourceControllerProvider);

  @override
  Widget build(BuildContext context) {
    final ColorScheme cs = Theme.of(context).colorScheme;

    return SafeArea(
      // A sheet that outgrows its space must scroll, not overflow: a short
      // screen or a landscape phone cannot fit the list and the rest at once.
      child: SingleChildScrollView(
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            context.horizontalPadding,
            0,
            context.horizontalPadding,
            context.spaceM,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              _SourceSwitch(
                selected: _tab,
                onSelect: (TrackSource tab) => setState(() => _tab = tab),
              ),
              SizedBox(height: context.spaceM),
              if (_tab == TrackSource.catalogue)
                const TrackList()
              else
                const MyMusic(),
              SizedBox(height: context.spaceM),
              const _ChangeSceneButton(),
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

/// PureLofi's music or the listener's own, as one full-width switch.
class _SourceSwitch extends StatelessWidget {
  const _SourceSwitch({required this.selected, required this.onSelect});

  final TrackSource selected;
  final ValueChanged<TrackSource> onSelect;

  @override
  Widget build(BuildContext context) {
    final TextStyle label = TextStyle(
      fontSize: context.fontM,
      fontWeight: FontWeight.w600,
    );

    return SegmentedButton<TrackSource>(
      expandedInsets: EdgeInsets.zero,
      showSelectedIcon: false,
      segments: <ButtonSegment<TrackSource>>[
        // PureLofi first: the recordings are what the app is for.
        ButtonSegment<TrackSource>(
          value: TrackSource.catalogue,
          label: Text('PureLofi', style: label),
        ),
        ButtonSegment<TrackSource>(
          value: TrackSource.local,
          label: Text('My music', style: label),
        ),
      ],
      selected: <TrackSource>{selected},
      onSelectionChanged: (Set<TrackSource> picked) => onSelect(picked.single),
    );
  }
}

class _ChangeSceneButton extends StatelessWidget {
  const _ChangeSceneButton();

  @override
  Widget build(BuildContext context) {
    final ColorScheme cs = Theme.of(context).colorScheme;

    return FilledButton.tonalIcon(
      style: FilledButton.styleFrom(
        padding: EdgeInsets.symmetric(vertical: context.spaceM),
      ),
      icon: AppIcon(
        AppGlyph.scene,
        size: context.fontL,
        color: cs.onSecondaryContainer,
      ),
      label: Text('Change scene', style: TextStyle(fontSize: context.fontM)),
      onPressed: () {
        Navigator.of(context).pop();
        unawaited(showSceneSwitcherSheet(context));
      },
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
    builder: (BuildContext context) => const SettingsSheet(),
  );
}
