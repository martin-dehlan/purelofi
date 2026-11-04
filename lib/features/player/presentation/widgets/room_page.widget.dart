import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../../../../common/utils/app_fonts.dart';
import '../../../../common/utils/app_links.dart';
import '../../../../common/utils/app_version.dart';
import '../../../../common/utils/responsive.dart';
import '../../../../common/widgets/app_icon.widget.dart';
import '../../../../common/widgets/legal_links.widget.dart';
import '../../../../common/widgets/menu_group.widget.dart';
import '../../../../common/widgets/menu_row.widget.dart';
import '../../../auth/controller/auth.controller.dart';
import '../../../auth/domain/account.entity.dart';
import '../../../auth/presentation/widgets/account_sheet.widget.dart';
import '../../../pro/controller/pro.controller.dart';
import '../../../pro/domain/pro_plan.entity.dart';
import '../../../pro/domain/pro_status.entity.dart';
import '../../../pro/presentation/widgets/paywall_sheet.widget.dart';
import 'profile_card.widget.dart';
import 'scene_strip.widget.dart';
import 'settings_section.widget.dart';
import 'sleep_timer_chips.widget.dart';

/// Everything that is not the music, on one page: who is listening, which
/// room they sit in, when the music stops, how the app behaves, and a way
/// to tell someone about it or tell us. The legal links at the foot (#95).
///
/// One sheet with everything open, not a menu of menus: each choice is a
/// tap where it is shown. It is always the same height, so nothing jumps
/// when a choice is made.
class RoomPage extends ConsumerWidget {
  const RoomPage({super.key, this.controller, this.onShare = _share});

  /// The scroll position, shared with the sheet that drags the page away.
  final ScrollController? controller;

  /// Opens the share sheet; tests pass their own.
  final Future<void> Function() onShare;

  static Future<void> _share() async {
    await SharePlus.instance.share(
      ShareParams(
        text: 'Real lo-fi in little pixel rooms. ${AppLinks.home}',
        subject: 'PureLofi',
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ColorScheme cs = Theme.of(context).colorScheme;
    final Account? account = ref.watch(authControllerProvider).value;
    final bool sellsPro = ref.read(proControllerProvider.notifier).isAvailable;
    final ProStatus pro =
        ref.watch(proControllerProvider).value ?? ProStatus.free;
    final String? manage = pro.manageUrl;

    Widget heading(String text) => Padding(
      padding: EdgeInsets.fromLTRB(
        context.horizontalPadding,
        context.spaceL,
        context.horizontalPadding,
        context.spaceS,
      ),
      child: Text(
        text,
        style: TextStyle(
          color: cs.onSurfaceVariant,
          fontSize: context.fontS,
          fontWeight: FontWeight.w600,
          letterSpacing: context.fontS * 0.06,
        ),
      ),
    );

    return SingleChildScrollView(
      controller: controller,
      padding: EdgeInsets.only(
        bottom: MediaQuery.paddingOf(context).bottom + context.spaceL,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Padding(
            padding: EdgeInsets.fromLTRB(
              context.horizontalPadding,
              0,
              context.horizontalPadding,
              context.spaceM,
            ),
            child: Text(
              'Your room',
              style: TextStyle(
                color: cs.onSurface,
                fontFamily: AppFonts.wordmark,
                fontSize: context.fontXl,
              ),
            ),
          ),
          MenuGroup(
            children: <Widget>[
              ProfileCard(
                account: account,
                onTap: () => unawaited(showAccountSheet(context)),
              ),
              // Right under who is listening, as what they have.
              // Only where Pro can be bought; a build without
              // RevenueCat's keys has nothing to offer here (#16).
              if (sellsPro)
                MenuRow(
                  glyph: pro.isPro ? AppGlyph.check : AppGlyph.lock,
                  title: 'PureLofi Pro',
                  subtitle: pro.isPro
                      ? switch (pro.plan) {
                          PlanPeriod.yearly => 'Pro · yearly',
                          PlanPeriod.monthly => 'Pro · monthly',
                          null => 'Pro',
                        }
                      : 'Unlock every room',
                  onTap: pro.isPro
                      ? (manage == null
                            ? null
                            : () => unawaited(AppLinks.open(Uri.parse(manage))))
                      : () => unawaited(
                          showPaywallSheet(context, source: 'menu'),
                        ),
                ),
            ],
          ),
          heading('Room'),
          const SceneStrip(),
          heading('Sleep timer'),
          const SleepTimerChips(),
          heading('Settings'),
          const SettingsSection(),
          SizedBox(height: context.spaceL),
          MenuGroup(
            children: <Widget>[
              MenuRow(
                glyph: AppGlyph.share,
                title: 'Share PureLofi',
                onTap: () => unawaited(onShare()),
              ),
              MenuRow(
                glyph: AppGlyph.mail,
                title: 'Send feedback',
                subtitle: 'Ideas, bugs or a hello',
                onTap: () => unawaited(AppLinks.open(AppLinks.feedback)),
              ),
            ],
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
    );
  }
}

/// Opens the room page as a bottom sheet over the scene.
///
/// A fixed height, most of the screen: the scene still shows above it and
/// nothing in it changes the sheet's size. It scrolls inside; a swipe down
/// from the top, or a tap on the scene, puts it away.
Future<void> showRoomPage(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (BuildContext context) => DraggableScrollableSheet(
      expand: false,
      initialChildSize: sheetSize,
      maxChildSize: sheetSize,
      minChildSize: sheetSize * 0.6,
      snap: true,
      builder: (BuildContext context, ScrollController controller) =>
          RoomPage(controller: controller),
    ),
  );
}

/// How much of the screen the sheet takes.
const double sheetSize = 0.88;
