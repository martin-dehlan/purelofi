import 'package:flutter/material.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

import '../../../../common/utils/responsive.dart';
import '../../domain/account.entity.dart';
import 'auth_button.widget.dart';
import 'google_mark.widget.dart';

/// The ways in, stacked: Apple (where there is a native Apple sheet), Google
/// (where it is set up), and email, which always works.
///
/// Apple's button is Apple's own, as its guidelines ask; the other two take
/// its shape and height so the three read as one set.
class SignInOptions extends StatelessWidget {
  const SignInOptions({
    required this.showApple,
    required this.showGoogle,
    required this.busy,
    required this.onApple,
    required this.onGoogle,
    required this.onEmail,
    super.key,
  });

  final bool showApple;
  final bool showGoogle;

  /// The sign-in under way, if any. While one runs the others wait.
  final SignInMethod? busy;

  final VoidCallback onApple;
  final VoidCallback onGoogle;
  final VoidCallback onEmail;

  @override
  Widget build(BuildContext context) {
    final bool idle = busy == null;
    final double gap = context.spaceS;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        if (showApple) ...<Widget>[
          SignInWithAppleButton(
            text: 'Continue with Apple',
            height: AuthButton.heightFor(context),
            style: SignInWithAppleButtonStyle.white,
            borderRadius: BorderRadius.circular(
              AuthButton.heightFor(context) / 2,
            ),
            onPressed: idle ? onApple : null,
          ),
          SizedBox(height: gap),
        ],
        if (showGoogle) ...<Widget>[
          AuthButton(
            label: 'Continue with Google',
            leading: GoogleMark(size: context.fontL),
            busy: busy == SignInMethod.google,
            onPressed: idle ? onGoogle : null,
          ),
          SizedBox(height: gap),
        ],
        AuthButton(
          label: 'Continue with email',
          onPressed: idle ? onEmail : null,
        ),
      ],
    );
  }
}
