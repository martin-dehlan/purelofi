import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../common/errors/app_error.dart';
import '../../../../common/utils/app_fonts.dart';
import '../../../../common/utils/app_links.dart';
import '../../../../common/utils/responsive.dart';
import '../../../../common/widgets/loading_dots.widget.dart';
import '../../../../common/widgets/skeleton.widget.dart';
import '../../../auth/controller/auth.provider.dart';
import '../../../auth/presentation/widgets/account_sheet.widget.dart';
import '../../../player/controller/scene.controller.dart';
import '../../../player/domain/scene.entity.dart';
import '../../controller/pro.controller.dart';
import '../../domain/pro.repository.dart';
import '../../domain/pro_plan.entity.dart';
import 'locked_rooms_strip.widget.dart';
import 'plan_option.widget.dart';
import '../../../../l10n/l10n.dart';

/// PureLofi Pro, offered once and plainly (#16): what it opens, the two
/// plans as the store prices them, one button. No countdowns, no
/// pre-ticked extras, no guilt (`docs/09`).
///
/// [scene] is the locked room that was tapped, if one was: it opens the
/// moment the purchase goes through.
class PaywallSheet extends ConsumerStatefulWidget {
  const PaywallSheet({required this.source, this.scene, super.key});

  /// Where the paywall was opened from, for the funnel (#82).
  final String source;
  final SceneEntity? scene;

  @override
  ConsumerState<PaywallSheet> createState() => _PaywallSheetState();
}

class _PaywallSheetState extends ConsumerState<PaywallSheet> {
  late Future<List<ProPlan>> _plans;
  PlanPeriod _chosen = PlanPeriod.yearly;
  bool _busy = false;
  String? _message;
  bool _messageIsError = false;

  ProController get _pro => ref.read(proControllerProvider.notifier);

  @override
  void initState() {
    super.initState();
    _plans = _pro.plans();
    _pro.paywallViewed(widget.source, sceneId: widget.scene?.id);
  }

  void _say(String message, {bool error = false}) => setState(() {
    _message = message;
    _messageIsError = error;
  });

  bool get _hasAccount => ref.read(authRepositoryProvider).current != null;

  /// Pro belongs to the account (#108), so a signed-out listener signs in
  /// first. `true` once there is an account to buy for.
  Future<bool> _signIn() async {
    if (_hasAccount) return true;
    await showAccountSheet(context, reason: context.l10n.proStaysWithAccount);

    return _hasAccount;
  }

  Future<void> _buy(ProPlan plan) async {
    // Read before any await: the context may be gone after one.
    final AppLocalizations l10n = context.l10n;
    if (!await _signIn() || !mounted) return;
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      switch (await _pro.purchase(plan)) {
        case PurchaseOutcome.purchased:
          final SceneEntity? scene = widget.scene;
          if (scene != null) {
            ref
                .read(activeSceneControllerProvider.notifier)
                .switchTo(scene, justBought: true);
          }
          if (mounted) Navigator.of(context).pop();
        case PurchaseOutcome.cancelled:
          break;
        case PurchaseOutcome.pending:
          _say(l10n.waitingForStore);
      }
    } on AppError catch (error) {
      _say(error.userMessageIn(l10n), error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _restore() async {
    // Read before any await: the context may be gone after one.
    final AppLocalizations l10n = context.l10n;
    if (!await _signIn() || !mounted) return;
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      if (await _pro.restore()) {
        if (mounted) Navigator.of(context).pop();
      } else {
        _say(l10n.noEarlierPurchaseSentence);
      }
    } on AppError catch (error) {
      _say(error.userMessageIn(l10n), error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme cs = Theme.of(context).colorScheme;
    final Set<String> locked = ref.watch(lockedScenesProvider);
    final List<SceneEntity> rooms =
        (ref.watch(sceneListControllerProvider).value ?? const <SceneEntity>[])
            .where((SceneEntity s) => locked.contains(s.id))
            .toList()
          ..sort((SceneEntity a, SceneEntity b) {
            // The tapped room first: that is the one they wanted.
            if (a.id == widget.scene?.id) return -1;
            if (b.id == widget.scene?.id) return 1;
            return a.sortOrder.compareTo(b.sortOrder);
          });
    final TextStyle quiet = TextStyle(
      color: cs.onSurfaceVariant,
      fontSize: context.fontS,
      height: 1.4,
    );

    return SafeArea(
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
          context.horizontalPadding,
          0,
          context.horizontalPadding,
          context.spaceL,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            // One big line in the middle and the reason under it, the way
            // the rest of the sheets open now.
            Text(
              context.l10n.purelofiPro,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: cs.onSurface,
                fontFamily: AppFonts.wordmark,
                fontSize: context.fontXxl,
              ),
            ),
            SizedBox(height: context.spaceS),
            Text(
              rooms.isEmpty
                  ? context.l10n.everyRoomAndOffline
                  : context.l10n.everyRoomMore(rooms.length),
              textAlign: TextAlign.center,
              style: quiet.copyWith(fontSize: context.fontM),
            ),
            // The trial, said up top and in the accent, not only on a
            // plan's corner: it is what makes trying it easy.
            FutureBuilder<List<ProPlan>>(
              future: _plans,
              builder:
                  (BuildContext context, AsyncSnapshot<List<ProPlan>> snap) {
                    final int? days =
                        <int?>[
                          for (final ProPlan plan
                              in snap.data ?? const <ProPlan>[])
                            plan.trialDays,
                        ].whereType<int>().fold<int?>(
                          null,
                          (int? a, int b) => a == null || b > a ? b : a,
                        );
                    if (days == null) return const SizedBox.shrink();
                    return Padding(
                      padding: EdgeInsets.only(top: context.spaceM),
                      child: Center(
                        child: Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: context.spaceM,
                            vertical: context.spaceS,
                          ),
                          decoration: ShapeDecoration(
                            shape: const StadiumBorder(),
                            color: cs.primary.withValues(alpha: 0.16),
                          ),
                          child: Text(
                            context.l10n.trialBanner(days),
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: cs.primary,
                              fontSize: context.fontS,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    );
                  },
            ),
            if (rooms.isNotEmpty) ...<Widget>[
              SizedBox(height: context.spaceM),
              LockedRoomsStrip(scenes: rooms),
            ],
            SizedBox(height: context.spaceL),
            FutureBuilder<List<ProPlan>>(
              future: _plans,
              builder: (BuildContext context, AsyncSnapshot<List<ProPlan>> snap) {
                if (snap.connectionState != ConnectionState.done) {
                  // The two plans' places, breathing until the prices come.
                  return Column(
                    children: <Widget>[
                      for (int i = 0; i < 2; i++) ...<Widget>[
                        Skeleton(
                          width: double.infinity,
                          height: context.screenHeight * 0.08,
                          borderRadius: BorderRadius.circular(
                            context.cardBorderRadius,
                          ),
                        ),
                        SizedBox(height: context.spaceS),
                      ],
                    ],
                  );
                }
                final List<ProPlan> plans = snap.data ?? const <ProPlan>[];
                if (snap.hasError || plans.isEmpty) {
                  return Column(
                    children: <Widget>[
                      Text(
                        context.l10n.plansDidNotLoad,
                        style: quiet,
                        textAlign: TextAlign.center,
                      ),
                      TextButton(
                        // A block, not an arrow: setState must not be
                        // handed the Future.
                        onPressed: () => setState(() {
                          _plans = _pro.plans();
                        }),
                        child: Text(context.l10n.tryAgain),
                      ),
                    ],
                  );
                }

                final ProPlan chosen = plans.firstWhere(
                  (ProPlan p) => p.period == _chosen,
                  orElse: () => plans.first,
                );
                final int? trial = chosen.trialDays;

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    for (final ProPlan plan in plans) ...<Widget>[
                      PlanOption(
                        plan: plan,
                        selected: plan.period == chosen.period,
                        onTap: _busy
                            ? null
                            : () {
                                setState(() => _chosen = plan.period);
                                _pro.planSelected(plan);
                              },
                      ),
                      SizedBox(height: context.spaceS),
                    ],
                    SizedBox(height: context.spaceS),
                    SizedBox(
                      height: context.screenHeight * 0.06,
                      child: FilledButton(
                        onPressed: _busy ? null : () => _buy(chosen),
                        // White on the dark sheet: the one thing to do
                        // here, with "Not now" as plain text under it.
                        style: FilledButton.styleFrom(
                          backgroundColor: cs.onSurface,
                          foregroundColor: cs.surface,
                          shape: const StadiumBorder(),
                        ),
                        child: _busy
                            ? LoadingDots(
                                size: context.fontL,
                                color: cs.surface,
                              )
                            : Text(
                                trial != null
                                    ? context.l10n.startTrial(trial)
                                    : context.l10n.getPro,
                                style: TextStyle(
                                  fontSize: context.fontM,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                      ),
                    ),
                    TextButton(
                      onPressed: _busy
                          ? null
                          : () => Navigator.of(context).pop(),
                      style: TextButton.styleFrom(
                        foregroundColor: cs.onSurface,
                      ),
                      child: Text(
                        context.l10n.notNow,
                        style: TextStyle(fontSize: context.fontM),
                      ),
                    ),
                    Text(
                      '${trial != null ? 'Free for $trial days, then ${chosen.price} ' : 'Renews at ${chosen.price} '}'
                      '${PlanOption.perFor(chosen.period)}. '
                      '${context.l10n.paywallFinePrint}',
                      style: quiet,
                      textAlign: TextAlign.center,
                    ),
                  ],
                );
              },
            ),
            if (_message != null) ...<Widget>[
              SizedBox(height: context.spaceM),
              Text(
                _message!,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: _messageIsError ? cs.error : cs.onSurfaceVariant,
                  fontSize: context.fontS,
                ),
              ),
            ],
            SizedBox(height: context.spaceS),
            Wrap(
              alignment: WrapAlignment.center,
              children: <Widget>[
                TextButton(
                  onPressed: _busy ? null : _restore,
                  child: Text(context.l10n.restorePurchases),
                ),
                TextButton(
                  onPressed: () => AppLinks.open(AppLinks.terms),
                  child: Text(context.l10n.terms),
                ),
                TextButton(
                  onPressed: () => AppLinks.open(AppLinks.privacy),
                  child: Text(context.l10n.privacy),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Opens the paywall. [source] says from where, for the funnel (#82).
Future<void> showPaywallSheet(
  BuildContext context, {
  required String source,
  SceneEntity? scene,
}) {
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (BuildContext context) =>
        PaywallSheet(source: source, scene: scene),
  );
}
