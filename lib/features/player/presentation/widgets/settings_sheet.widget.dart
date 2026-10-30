import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../common/utils/app_fonts.dart';
import '../../../../common/utils/app_links.dart';
import '../../../../common/utils/app_version.dart';
import '../../../../common/utils/responsive.dart';
import '../../../../common/widgets/app_icon.widget.dart';
import '../../../auth/controller/auth.controller.dart';
import '../../../auth/domain/account.entity.dart';
import '../../../auth/presentation/widgets/account_sheet.widget.dart';
import '../../../pro/controller/pro.controller.dart';
import '../../../pro/domain/pro_plan.entity.dart';
import '../../../pro/domain/pro_status.entity.dart';
import '../../../pro/presentation/widgets/paywall_sheet.widget.dart';
import '../../controller/player.controller.dart';
import '../../domain/track.entity.dart';
import 'bts_modal.widget.dart';
import 'scene_switcher_sheet.widget.dart';

/// The menu top right: everything that is not the music.
///
/// The music has its own places since the library and the queue arrived —
/// under the transport, where a music app keeps them. What is left here is
/// the room, the proof that the playing is real, and the account — which is
/// optional, and says so.
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
    final ProController proController = ref.read(
      proControllerProvider.notifier,
    );
    final ProStatus pro =
        ref.watch(proControllerProvider).value ?? ProStatus.free;
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
              // Only where Pro can be bought; a build without RevenueCat's
              // keys has nothing to offer here (#16).
              if (proController.isAvailable)
                _Entry(
                  glyph: pro.isPro ? AppGlyph.check : AppGlyph.lock,
                  title: 'PureLofi Pro',
                  subtitle: pro.isPro
                      ? switch (pro.plan) {
                          PlanPeriod.yearly => 'Pro · yearly',
                          PlanPeriod.monthly => 'Pro · monthly',
                          null => 'Pro',
                        }
                      : 'Unlock every room',
                  onTap: () {
                    Navigator.of(context).pop();
                    final String? manage = pro.manageUrl;
                    if (pro.isPro && manage != null) {
                      unawaited(AppLinks.open(Uri.parse(manage)));
                    } else if (!pro.isPro) {
                      unawaited(showPaywallSheet(context, source: 'menu'));
                    }
                  },
                ),
              _Entry(
                glyph: AppGlyph.account,
                title: 'Account',
                subtitle: account == null
                    ? 'Optional — sign in if you like'
                    : account.email ?? account.name ?? 'Signed in',
                onTap: () {
                  Navigator.of(context).pop();
                  unawaited(showAccountSheet(context));
                },
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
