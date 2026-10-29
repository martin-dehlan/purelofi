import 'package:flutter/material.dart';

import '../../../../common/utils/responsive.dart';

/// One way to sign in: a full-width pill, the same shape and height as
/// Apple's own button beside it, so the three read as one set.
class AuthButton extends StatelessWidget {
  const AuthButton({
    required this.label,
    required this.onPressed,
    this.leading,
    this.busy = false,
    super.key,
  });

  final String label;
  final Widget? leading;

  /// `null` greys the button out — another sign-in is already under way.
  final VoidCallback? onPressed;

  /// This one is the sign-in under way: a small spinner instead of the mark.
  final bool busy;

  static double heightFor(BuildContext context) => context.screenHeight * 0.06;

  @override
  Widget build(BuildContext context) {
    final ColorScheme cs = Theme.of(context).colorScheme;
    final double mark = context.fontL;

    return SizedBox(
      width: double.infinity,
      height: heightFor(context),
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          shape: const StadiumBorder(),
          backgroundColor: cs.surfaceContainerHigh,
          foregroundColor: cs.onSurface,
          side: BorderSide(color: cs.outlineVariant),
          padding: EdgeInsets.symmetric(horizontal: context.spaceM),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            if (busy)
              SizedBox.square(
                dimension: mark,
                child: CircularProgressIndicator(
                  strokeWidth: mark * 0.12,
                  color: cs.onSurfaceVariant,
                ),
              )
            else
              ?leading,
            if (busy || leading != null) SizedBox(width: context.spaceS),
            Flexible(
              child: Text(
                label,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: context.fontM,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
