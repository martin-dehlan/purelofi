import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../common/errors/app_error.dart';
import '../../../../common/utils/app_fonts.dart';
import '../../../../common/utils/app_links.dart';
import '../../../../common/utils/responsive.dart';
import '../../../player/controller/scene.controller.dart';
import '../../../player/domain/scene.entity.dart';
import '../../controller/pro.controller.dart';
import '../../domain/pro.repository.dart';
import '../../domain/pro_plan.entity.dart';
import 'locked_rooms_strip.widget.dart';
import 'plan_option.widget.dart';

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

  Future<void> _buy(ProPlan plan) async {
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
          _say('Waiting for the store to confirm. Pro opens when it does.');
      }
    } on AppError catch (error) {
      _say(error.userMessage, error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _restore() async {
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      if (await _pro.restore()) {
        if (mounted) Navigator.of(context).pop();
      } else {
        _say('No earlier purchase on this store account.');
      }
    } on AppError catch (error) {
      _say(error.userMessage, error: true);
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
            Text(
              'PureLofi Pro',
              style: TextStyle(
                color: cs.onSurface,
                fontFamily: AppFonts.wordmark,
                fontSize: context.fontXl,
              ),
            ),
            SizedBox(height: context.spaceXs),
            Text(
              rooms.isEmpty
                  ? 'Every room, every night.'
                  : 'Every room, every night — '
                        '${rooms.length} more to sit in.',
              style: quiet,
            ),
            if (rooms.isNotEmpty) ...<Widget>[
              SizedBox(height: context.spaceM),
              LockedRoomsStrip(scenes: rooms),
            ],
            SizedBox(height: context.spaceL),
            FutureBuilder<List<ProPlan>>(
              future: _plans,
              builder:
                  (BuildContext context, AsyncSnapshot<List<ProPlan>> snap) {
                    if (snap.connectionState != ConnectionState.done) {
                      return Padding(
                        padding: EdgeInsets.symmetric(vertical: context.spaceL),
                        child: Center(
                          child: CircularProgressIndicator(
                            color: cs.onSurfaceVariant,
                          ),
                        ),
                      );
                    }
                    final List<ProPlan> plans = snap.data ?? const <ProPlan>[];
                    if (snap.hasError || plans.isEmpty) {
                      return Column(
                        children: <Widget>[
                          Text(
                            'The plans could not be loaded.',
                            style: quiet,
                            textAlign: TextAlign.center,
                          ),
                          TextButton(
                            onPressed: () =>
                                setState(() => _plans = _pro.plans()),
                            child: const Text('Try again'),
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
                            style: FilledButton.styleFrom(
                              shape: const StadiumBorder(),
                            ),
                            child: _busy
                                ? SizedBox.square(
                                    dimension: context.fontL,
                                    child: CircularProgressIndicator(
                                      strokeWidth: context.fontL * 0.12,
                                      color: cs.onPrimary,
                                    ),
                                  )
                                : Text(
                                    trial != null
                                        ? 'Start $trial-day free trial'
                                        : 'Get Pro',
                                    style: TextStyle(
                                      fontSize: context.fontM,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                          ),
                        ),
                        SizedBox(height: context.spaceS),
                        Text(
                          trial != null
                              ? 'Free for $trial days, then ${chosen.price} '
                                    '${PlanOption.perFor(chosen.period)}. '
                                    'Cancel any time in your store settings.'
                              : 'Renews at ${chosen.price} '
                                    '${PlanOption.perFor(chosen.period)}. '
                                    'Cancel any time in your store settings.',
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
                  child: const Text('Restore purchases'),
                ),
                TextButton(
                  onPressed: () => AppLinks.open(AppLinks.terms),
                  child: const Text('Terms'),
                ),
                TextButton(
                  onPressed: () => AppLinks.open(AppLinks.privacy),
                  child: const Text('Privacy'),
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
