import 'package:flutter/material.dart';

import '../../../../common/utils/responsive.dart';
import '../../domain/account.entity.dart';
import '../../domain/member_since.dart';
import 'auth_button.widget.dart';
import 'profile_avatar.widget.dart';

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
    super.key,
  });

  final Account account;
  final bool busy;
  final VoidCallback onSignOut;
  final VoidCallback onDelete;

  /// Under the name: what else this listener has, such as Pro.
  final Widget? badge;

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
    final DateTime? since = account.memberSince;
    final TextStyle quiet = TextStyle(
      color: cs.onSurfaceVariant,
      fontSize: context.fontS,
    );

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Row(
          children: <Widget>[
            ProfileAvatar(account: account, size: context.fontXxl * 1.8),
            SizedBox(width: context.spaceM),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
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
                      style: quiet,
                    ),
                  if (badge case final Widget badge) ...<Widget>[
                    SizedBox(height: context.spaceS),
                    badge,
                  ],
                ],
              ),
            ),
          ],
        ),
        SizedBox(height: context.spaceM),
        if (since != null) Text(memberSinceLabel(since), style: quiet),
        Text(methodLabel(account.method), style: quiet),
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
