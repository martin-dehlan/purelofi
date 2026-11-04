import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../common/errors/app_error.dart';
import '../../../../common/utils/responsive.dart';
import '../../controller/auth.controller.dart';
import '../../domain/account.entity.dart';
import 'delete_account_dialog.dart';
import 'email_password_form.widget.dart';
import 'sign_in_options.widget.dart';
import 'signed_in_account.widget.dart';
import '../../../../l10n/l10n.dart';

/// The account in a sheet of its own: on the way to Pro (#108) and as the
/// first launch's welcome. The room page shows the same [AccountPanel]
/// inline, at its top.
class AccountSheet extends StatelessWidget {
  const AccountSheet({this.reason, this.welcome = false, super.key});

  final String? reason;
  final bool welcome;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SingleChildScrollView(
        // The keyboard comes up for the email, password and code; the sheet
        // rises with it rather than hiding the field.
        padding: EdgeInsets.fromLTRB(
          context.horizontalPadding,
          0,
          context.horizontalPadding,
          context.spaceL + MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: AccountPanel(reason: reason, welcome: welcome),
      ),
    );
  }
}

/// The account itself, wherever it is shown.
///
/// Optional from top to bottom: no onboarding, nothing gated, the music
/// plays the same either way (#38). Signed out it offers the ways in;
/// signed in it says who, and how to leave.
///
/// As the [welcome] on a first launch it carries a way past it, and closes
/// itself once someone is signed in.
class AccountPanel extends ConsumerStatefulWidget {
  const AccountPanel({
    this.reason,
    this.welcome = false,
    this.badge,
    this.actions = true,
    super.key,
  });

  /// Why an account is asked for here, said under the title — the sheet
  /// was opened on the way to something (Pro, #108), so it closes the
  /// moment the sign-in lands and that something carries on.
  final String? reason;

  /// The one-time offer on the first launch, with a way to skip it.
  final bool welcome;

  /// What else the listener has, such as Pro: under the name when signed
  /// in, over the ways in when not.
  final Widget? badge;

  /// Whether sign out and delete show here, or elsewhere on the page.
  final bool actions;

  @override
  ConsumerState<AccountPanel> createState() => _AccountPanelState();
}

class _AccountPanelState extends ConsumerState<AccountPanel> {
  bool _email = false;

  /// The sign-in, sign-out or deletion under way.
  SignInMethod? _signingIn;
  bool _leaving = false;
  String? _error;

  Future<void> _run(Future<void> Function() action) async {
    setState(() => _error = null);
    try {
      await action();
    } on AppError catch (error) {
      if (mounted) setState(() => _error = error.userMessage);
    }
  }

  Future<void> _signIn(SignInMethod method) => _run(() async {
    setState(() => _signingIn = method);
    try {
      final AuthController auth = ref.read(authControllerProvider.notifier);
      // `false` is the listener closing the sheet: no message for that.
      await (method == SignInMethod.apple
          ? auth.signInWithApple()
          : auth.signInWithGoogle());
    } finally {
      if (mounted) setState(() => _signingIn = null);
    }
  });

  Future<void> _leave(Future<void> Function() action) => _run(() async {
    setState(() => _leaving = true);
    try {
      await action();
    } finally {
      if (mounted) setState(() => _leaving = false);
    }
  });

  Future<void> _delete() async {
    if (!await confirmDeleteAccount(context)) return;
    await _leave(ref.read(authControllerProvider.notifier).deleteAccount);
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme cs = Theme.of(context).colorScheme;
    final Account? account = ref.watch(authControllerProvider).value;
    final AuthController auth = ref.read(authControllerProvider.notifier);
    final String? reason = widget.reason;
    // On the way to something, or as the welcome: done once signed in.
    if (reason != null || widget.welcome) {
      ref.listen<AsyncValue<Account?>>(authControllerProvider, (
        AsyncValue<Account?>? previous,
        AsyncValue<Account?> next,
      ) {
        if (previous?.value == null && next.value != null) {
          Navigator.of(context).pop();
        }
      });
    }

    final Widget body;
    if (account != null) {
      body = SignedInAccount(
        account: account,
        busy: _leaving,
        onSignOut: () => _leave(auth.signOut),
        onDelete: _delete,
        badge: widget.badge,
        actions: widget.actions,
      );
    } else if (_email) {
      body = EmailPasswordForm(onBack: () => setState(() => _email = false));
    } else {
      body = SignInOptions(
        showApple: auth.canUseApple,
        showGoogle: auth.canUseGoogle,
        busy: _signingIn,
        onApple: () => _signIn(SignInMethod.apple),
        onGoogle: () => _signIn(SignInMethod.google),
        onEmail: () => setState(() {
          _email = true;
          _error = null;
        }),
      );
    }

    final Widget? badge = widget.badge;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        if (account == null) ...<Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      widget.welcome ? 'Welcome to PureLofi' : 'Sign in',
                      style: TextStyle(
                        color: cs.onSurface,
                        fontSize: context.fontL,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    SizedBox(height: context.spaceXs),
                    Text(
                      reason ??
                          'Optional. The music plays the same either way.',
                      style: TextStyle(
                        color: cs.onSurfaceVariant,
                        fontSize: context.fontS,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          // Under the line, so the words keep the card's width.
          if (badge != null && !_email) ...<Widget>[
            SizedBox(height: context.spaceM),
            Align(alignment: Alignment.centerLeft, child: badge),
          ],
          SizedBox(height: context.spaceL),
        ],
        body,
        if (widget.welcome && account == null && !_email) ...<Widget>[
          SizedBox(height: context.spaceS),
          Center(
            child: TextButton(
              onPressed: () => Navigator.of(context).pop(),
              style: TextButton.styleFrom(foregroundColor: cs.onSurface),
              child: Text(
                context.l10n.notNow,
                style: TextStyle(fontSize: context.fontM),
              ),
            ),
          ),
        ],
        if (_error != null) ...<Widget>[
          SizedBox(height: context.spaceM),
          Center(
            child: Text(
              _error!,
              textAlign: TextAlign.center,
              style: TextStyle(color: cs.error, fontSize: context.fontS),
            ),
          ),
        ],
      ],
    );
  }
}

/// Opens the account sheet. With a [reason] it is a step on the way to
/// something else and closes once signed in.
Future<void> showAccountSheet(BuildContext context, {String? reason}) {
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (BuildContext context) => AccountSheet(reason: reason),
  );
}

/// Opens the account sheet as the first launch's welcome.
Future<void> showWelcomeSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (BuildContext context) => const AccountSheet(welcome: true),
  );
}
