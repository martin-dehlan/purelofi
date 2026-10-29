import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../common/errors/app_error.dart';
import '../../../../common/utils/responsive.dart';
import '../../controller/auth.controller.dart';
import '../../domain/account.entity.dart';
import 'delete_account_dialog.dart';
import 'email_code_form.widget.dart';
import 'sign_in_options.widget.dart';
import 'signed_in_account.widget.dart';

/// The account, in the same lean sheet as the menu it is opened from.
///
/// Optional from top to bottom: no onboarding, nothing gated, the music
/// plays the same either way (#38). Signed out it offers the ways in;
/// signed in it says who, and how to leave.
class AccountSheet extends ConsumerStatefulWidget {
  const AccountSheet({super.key});

  @override
  ConsumerState<AccountSheet> createState() => _AccountSheetState();
}

class _AccountSheetState extends ConsumerState<AccountSheet> {
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

    final Widget body;
    if (account != null) {
      body = SignedInAccount(
        account: account,
        busy: _leaving,
        onSignOut: () => _leave(auth.signOut),
        onDelete: _delete,
      );
    } else if (_email) {
      body = EmailCodeForm(onBack: () => setState(() => _email = false));
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

    return SafeArea(
      child: SingleChildScrollView(
        // The keyboard comes up for the email and the code; the sheet rises
        // with it rather than hiding the field.
        padding: EdgeInsets.fromLTRB(
          context.horizontalPadding,
          0,
          context.horizontalPadding,
          context.spaceL + MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            if (account == null) ...<Widget>[
              Text(
                'Sign in',
                style: TextStyle(
                  color: cs.onSurface,
                  fontSize: context.fontL,
                  fontWeight: FontWeight.w600,
                ),
              ),
              SizedBox(height: context.spaceXs),
              Text(
                'Optional. The music never needs it.',
                style: TextStyle(
                  color: cs.onSurfaceVariant,
                  fontSize: context.fontS,
                ),
              ),
              SizedBox(height: context.spaceL),
            ],
            body,
            if (_error != null) ...<Widget>[
              SizedBox(height: context.spaceM),
              Text(
                _error!,
                style: TextStyle(color: cs.error, fontSize: context.fontS),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Opens the account sheet.
Future<void> showAccountSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (BuildContext context) => const AccountSheet(),
  );
}
