import 'package:flutter/material.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

import '../../../../common/utils/responsive.dart';
import '../../domain/account.entity.dart';
import 'auth_button.widget.dart';
import 'google_mark.widget.dart';

/// The ways in, stacked: Apple (where there is a native Apple sheet), Google
/// (where it is set up), and email, which always works.
///
/// Apple's is drawn here rather than taken from the plugin: its own button
/// sets the label at nearly half the button's height, which put it a size
/// above the two under it. Apple allows a custom button that keeps the logo,
/// the wording and a white or black fill.
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
          AuthButton(
            label: 'Continue with Apple',
            primary: true,
            leading: SizedBox(
              width: context.fontL * (25 / 31),
              height: context.fontL,
              child: CustomPaint(
                painter: AppleLogoPainter(
                  color: Theme.of(context).colorScheme.surface,
                ),
              ),
            ),
            busy: busy == SignInMethod.apple,
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
