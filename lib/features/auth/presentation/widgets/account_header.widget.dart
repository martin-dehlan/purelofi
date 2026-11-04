import 'package:flutter/material.dart';

import '../../../../common/utils/responsive.dart';
import '../../domain/account.entity.dart';
import '../../domain/member_since.dart';
import 'profile_avatar.widget.dart';

/// Who is signed in, in one row: the avatar, the name, the address and one
/// quiet line for how and since when. [badge] sits at the row's end, such
/// as the Pro pill.
class AccountHeader extends StatelessWidget {
  const AccountHeader({required this.account, this.badge, super.key});

  final Account account;
  final Widget? badge;

  static String methodName(SignInMethod method) => switch (method) {
    SignInMethod.apple => 'Apple',
    SignInMethod.google => 'Google',
    SignInMethod.email => 'Email',
  };

  @override
  Widget build(BuildContext context) {
    final ColorScheme cs = Theme.of(context).colorScheme;
    final String headline = account.name ?? account.email ?? 'Signed in';
    // The address under the name, unless it already is the headline or
    // Apple kept it private.
    final String? address = account.name != null ? account.email : null;
    final DateTime? since = account.memberSince;
    final String meta = <String>[
      if (since != null) sinceLabel(since),
      methodName(account.method),
    ].join(' · ');
    final Widget? badge = this.badge;

    return Row(
      children: <Widget>[
        ProfileAvatar(account: account, size: context.fontXxl * 1.6),
        SizedBox(width: context.spaceM),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                headline,
                maxLines: 1,
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
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: cs.onSurfaceVariant,
                    fontSize: context.fontS,
                  ),
                ),
              SizedBox(height: context.spaceXs),
              Text(
                meta,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: cs.onSurfaceVariant.withValues(alpha: 0.7),
                  fontSize: context.fontXs,
                ),
              ),
            ],
          ),
        ),
        if (badge != null) ...<Widget>[
          SizedBox(width: context.spaceS),
          // Shrinks rather than pushes the name off a small screen.
          Flexible(
            flex: 0,
            child: FittedBox(fit: BoxFit.scaleDown, child: badge),
          ),
        ],
      ],
    );
  }
}
