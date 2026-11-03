import 'package:flutter/material.dart';

import '../../../../common/utils/responsive.dart';
import '../../domain/account.entity.dart';
import 'auth_button.widget.dart';

/// Who is signed in, and the two ways out: signing out, and deleting the
/// account — the stores require that the second is in the app.
class SignedInAccount extends StatelessWidget {
  const SignedInAccount({
    required this.account,
    required this.busy,
    required this.onSignOut,
    required this.onDelete,
    super.key,
  });

  final Account account;
  final bool busy;
  final VoidCallback onSignOut;
  final VoidCallback onDelete;

  static String methodLabel(SignInMethod method) => switch (method) {
    SignInMethod.apple => 'Signed in with Apple',
    SignInMethod.google => 'Signed in with Google',
    SignInMethod.email => 'Signed in with email',
  };

  @override
  Widget build(BuildContext context) {
    final ColorScheme cs = Theme.of(context).colorScheme;
    final String headline = account.name ?? account.email ?? 'Signed in';
    // The address under the name, unless it already is the headline or
    // Apple kept it private.
    final String? address = account.name != null ? account.email : null;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Text(
          headline,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: cs.onSurface,
            fontSize: context.fontL,
            fontWeight: FontWeight.w600,
          ),
        ),
        if (address != null)
          Text(
            address,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: cs.onSurfaceVariant,
              fontSize: context.fontS,
            ),
          ),
        SizedBox(height: context.spaceXs),
        Text(
          methodLabel(account.method),
          style: TextStyle(color: cs.onSurfaceVariant, fontSize: context.fontS),
        ),
        SizedBox(height: context.spaceL),
        AuthButton(
          label: 'Sign out',
          busy: busy,
          onPressed: busy ? null : onSignOut,
        ),
        SizedBox(height: context.spaceS),
        TextButton(
          onPressed: busy ? null : onDelete,
          style: TextButton.styleFrom(foregroundColor: cs.error),
          child: const Text('Delete account'),
        ),
      ],
    );
  }
}
