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
import '../../controller/scene.controller.dart';
import '../../controller/sleep_timer.controller.dart';
import '../../domain/scene.entity.dart';
import 'profile_card.widget.dart';
import 'scene_switcher_sheet.widget.dart';
import 'settings_sheet.widget.dart';
import 'sleep_timer_sheet.widget.dart';

/// The menu top right: everything that is not the music.
///
/// The music has its own sheet under the transport. This one starts with
/// who is listening — signed in or not, which is optional and changes
/// nothing about the music (#38) — then the room, the sleep timer and the
/// settings, then telling someone about the app or telling us about it.
/// At the bottom, the links to the legal pages on purelofi.app (#95).
///
/// Laid out in groups on cards, the way a phone's own settings are. The
/// room, the sleep timer and the settings open inside it, sliding in with
/// a way back, rather than as sheets of their own.
class MenuSheet extends ConsumerStatefulWidget {
  const MenuSheet({super.key, this.onShare = _share});

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
  ConsumerState<MenuSheet> createState() => _MenuSheetState();

  /// "23:40" or "11:40 PM", the way the phone tells the time.
  static String _timeOfDay(BuildContext context, DateTime at) =>
      MaterialLocalizations.of(context).formatTimeOfDay(
        TimeOfDay.fromDateTime(at),
        alwaysUse24HourFormat: MediaQuery.alwaysUse24HourFormatOf(context),
      );
}

/// What opens inside the menu.
enum _MenuPage { room, sleepTimer, settings }

class _MenuSheetState extends ConsumerState<MenuSheet> {
  _MenuPage? _page;

  /// Which way the last change went, so the page slides the right way.
  bool _forward = true;

  void _open(_MenuPage page) => setState(() {
    _forward = true;
    _page = page;
  });

  void _back() => setState(() {
    _forward = false;
    _page = null;
  });

  @override
  Widget build(BuildContext context) {
    final _MenuPage? page = _page;

    return PopScope(
      canPop: page == null,
      onPopInvokedWithResult: (bool didPop, Object? _) {
        if (!didPop) _back();
      },
      // The sheet grows and shrinks to what is in it; the pages slide.
      child: AnimatedSize(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOutCubic,
        alignment: Alignment.bottomCenter,
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 250),
          transitionBuilder: (Widget child, Animation<double> animation) {
            final bool incoming = child.key == ValueKey<_MenuPage?>(page);
            final double from = (incoming == _forward) ? 0.3 : -0.3;

            return FadeTransition(
              opacity: animation,
              child: SlideTransition(
                position: Tween<Offset>(
                  begin: Offset(from, 0),
                  end: Offset.zero,
                ).animate(animation),
                child: child,
              ),
            );
          },
          layoutBuilder: (Widget? current, List<Widget> previous) => Stack(
            alignment: Alignment.bottomCenter,
            children: <Widget>[...previous, ?current],
          ),
          child: KeyedSubtree(
            key: ValueKey<_MenuPage?>(page),
            child: page == null ? _main(context) : _sub(context, page),
          ),
        ),
      ),
    );
  }

  /// One of the pages inside the menu: its name with a way back, then it.
  /// Swiped to the right, it goes back too.
  Widget _sub(BuildContext context, _MenuPage page) {
    final ColorScheme cs = Theme.of(context).colorScheme;

    return GestureDetector(
      onHorizontalDragEnd: (DragEndDetails details) {
        if ((details.primaryVelocity ?? 0) > 300) _back();
      },
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Padding(
            padding: EdgeInsets.fromLTRB(
              context.spaceXs,
              0,
              context.horizontalPadding,
              context.spaceS,
            ),
            child: Row(
              children: <Widget>[
                IconButton(
                  tooltip: 'Back',
                  onPressed: _back,
                  icon: AppIcon(
                    AppGlyph.back,
                    size: context.fontL,
                    color: cs.onSurface,
                  ),
                ),
                Expanded(
                  child: Text(
                    switch (page) {
                      _MenuPage.room => 'Change room',
                      _MenuPage.sleepTimer => 'Sleep timer',
                      _MenuPage.settings => 'Settings',
                    },
                    style: TextStyle(
                      fontSize: context.fontL,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Flexible(
            child: switch (page) {
              _MenuPage.room => const SceneSwitcherSheet(),
              _MenuPage.sleepTimer => const SleepTimerSheet(),
              _MenuPage.settings => const SettingsSheet(),
            },
          ),
        ],
      ),
    );
  }

  Widget _main(BuildContext context) {
    final ColorScheme cs = Theme.of(context).colorScheme;
    final Account? account = ref.watch(authControllerProvider).value;
    final SceneEntity? scene = ref.watch(activeSceneControllerProvider);
    final DateTime? stopsAt = ref.watch(sleepTimerControllerProvider);
    final bool sellsPro = ref.read(proControllerProvider.notifier).isAvailable;
    final ProStatus pro =
        ref.watch(proControllerProvider).value ?? ProStatus.free;
    final String? manage = pro.manageUrl;

    // Closes the menu, then opens what the row is for.
    VoidCallback then(Future<void> Function() open) => () {
      Navigator.of(context).pop();
      unawaited(open());
    };

    return SafeArea(
      child: SingleChildScrollView(
        child: Padding(
          padding: EdgeInsets.only(bottom: context.spaceM),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              MenuGroup(
                children: <Widget>[
                  ProfileCard(
                    account: account,
                    onTap: then(() => showAccountSheet(context)),
                  ),
                  // Right under who is listening, as what they have. Only
                  // where Pro can be bought; a build without RevenueCat's
                  // keys has nothing to offer here (#16).
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
                                : () => unawaited(
                                    AppLinks.open(Uri.parse(manage)),
                                  ))
                          : then(
                              () => showPaywallSheet(context, source: 'menu'),
                            ),
                    ),
                ],
              ),
              SizedBox(height: context.spaceM),
              MenuGroup(
                children: <Widget>[
                  MenuRow(
                    glyph: AppGlyph.scene,
                    title: 'Change room',
                    subtitle: scene?.title,
                    onTap: () => _open(_MenuPage.room),
                  ),
                  MenuRow(
                    glyph: AppGlyph.timer,
                    title: 'Sleep timer',
                    subtitle: stopsAt == null
                        ? 'Off'
                        : 'Stops at ${MenuSheet._timeOfDay(context, stopsAt)}',
                    onTap: () => _open(_MenuPage.sleepTimer),
                  ),
                  MenuRow(
                    glyph: AppGlyph.settings,
                    title: 'Settings',
                    onTap: () => _open(_MenuPage.settings),
                  ),
                ],
              ),
              SizedBox(height: context.spaceM),
              MenuGroup(
                children: <Widget>[
                  MenuRow(
                    glyph: AppGlyph.share,
                    title: 'Share PureLofi',
                    onTap: () => unawaited(widget.onShare()),
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
        ),
      ),
    );
  }
}

/// Opens the menu as a bottom sheet.
Future<void> showMenuSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    // As tall as what is in it: the default caps a sheet at 9/16 of the
    // screen, which on a small phone hid the last rows behind a scroll.
    isScrollControlled: true,
    builder: (BuildContext context) => const MenuSheet(),
  );
}
