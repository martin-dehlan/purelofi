import 'package:flutter/material.dart';

import '../../../../common/utils/responsive.dart';
import '../../domain/account.entity.dart';
import 'auth_button.widget.dart';
import 'account_header.widget.dart';
import '../../../../l10n/l10n.dart';

/// The profile (#96): who is signed in, since when, and the two ways out —
/// signing out, and deleting the account, which the stores require in the
/// app.
class SignedInAccount extends StatelessWidget {
  const SignedInAccount({
    required this.account,
    required this.busy,
    required this.onSignOut,
    required this.onDelete,
    this.badge,
    this.actions = true,
    super.key,
  });

  final Account account;
  final bool busy;
  final VoidCallback onSignOut;
  final VoidCallback onDelete;

  /// Under the name: what else this listener has, such as Pro.
  final Widget? badge;

  /// Sign out and delete under the header. The room page has them as rows
  /// at its foot instead (`AccountActions`).
  final bool actions;

  static String methodLabel(SignInMethod method) => switch (method) {
    SignInMethod.apple => 'Signed in with Apple',
    SignInMethod.google => 'Signed in with Google',
    SignInMethod.email => 'Signed in with email',
  };

  @override
  Widget build(BuildContext context) {
    final ColorScheme cs = Theme.of(context).colorScheme;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        AccountHeader(account: account, badge: badge),
        if (actions) ...<Widget>[
          SizedBox(height: context.spaceL),
          AuthButton(
            label: context.l10n.signOut,
            busy: busy,
            onPressed: busy ? null : onSignOut,
          ),
          SizedBox(height: context.spaceS),
          TextButton(
            onPressed: busy ? null : onDelete,
            style: TextButton.styleFrom(foregroundColor: cs.error),
            child: Text(context.l10n.deleteAccount),
          ),
        ],
      ],
    );
  }
}
