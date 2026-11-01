import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../common/utils/app_fonts.dart';
import '../../../../common/utils/app_version.dart';
import '../../../../common/utils/responsive.dart';
import '../../../../common/widgets/app_icon.widget.dart';
import '../../../../common/widgets/legal_links.widget.dart';
import '../../../auth/controller/auth.controller.dart';
import '../../../auth/domain/account.entity.dart';
import '../../../auth/presentation/widgets/account_sheet.widget.dart';
import '../../controller/player.controller.dart';
import '../../domain/track.entity.dart';
import 'bts_modal.widget.dart';
import 'now_playing_header.widget.dart';
import 'scene_switcher_sheet.widget.dart';

/// The menu top right: everything that is not the music.
///
/// The music has its own places since the library and the queue arrived —
/// under the transport, where a music app keeps them. What is left here is
/// what is playing and where, the room, the proof that the playing is real,
/// the profile — which is optional, and says so — and, at the bottom, the
/// links to the legal pages on purelofi.app (#95).
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
    final Account? account = ref.watch(authControllerProvider).value;
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
              const NowPlayingHeader(),
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
              _Entry(
                glyph: AppGlyph.account,
                title: account == null ? 'Sign in' : 'Profile',
                subtitle: account == null
                    ? 'Optional. The music never needs it.'
                    : account.email ?? account.name ?? 'Signed in',
                onTap: () {
                  Navigator.of(context).pop();
                  unawaited(showAccountSheet(context));
                },
              ),
              SizedBox(height: context.spaceM),
              const LegalLinks(),
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
    // As tall as what is in it: the default caps a sheet at 9/16 of the
    // screen, which on a small phone hid the last rows behind a scroll.
    isScrollControlled: true,
    builder: (BuildContext context) => const SettingsSheet(),
  );
}
