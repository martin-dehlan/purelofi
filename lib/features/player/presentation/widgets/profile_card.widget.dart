import 'package:flutter/material.dart';

import '../../../../common/utils/responsive.dart';
import '../../../../common/widgets/app_icon.widget.dart';
import '../../../auth/domain/account.entity.dart';
import '../../../auth/presentation/widgets/profile_avatar.widget.dart';

/// The top of the menu: who is listening. Signed in it shows the initial,
/// the name and the address; signed out, the way in.
class ProfileCard extends StatelessWidget {
  const ProfileCard({required this.account, required this.onTap, super.key});

  final Account? account;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ColorScheme cs = Theme.of(context).colorScheme;
    final Account? account = this.account;
    final double avatar = context.fontXxl * 1.5;
    final String title = account == null
        ? 'Sign in'
        : account.name ?? account.email ?? 'Signed in';
    // The address under the name, unless it already is the title.
    final String? subtitle = account == null
        ? 'Apple, Google or email'
        : account.name != null
        ? account.email
        : null;

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: EdgeInsets.all(context.spaceM),
        child: Row(
          children: <Widget>[
            if (account != null)
              ProfileAvatar(account: account, size: avatar)
            else
              Container(
                width: avatar,
                height: avatar,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: cs.surfaceContainerHighest,
                  shape: BoxShape.circle,
                ),
                child: AppIcon(
                  AppGlyph.account,
                  size: avatar * 0.5,
                  color: cs.onSurfaceVariant,
                ),
              ),
            SizedBox(width: context.spaceM),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    title,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: cs.onSurface,
                      fontSize: context.fontM,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (subtitle != null)
                    Text(
                      subtitle,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: cs.onSurfaceVariant,
                        fontSize: context.fontS,
                      ),
                    ),
                ],
              ),
            ),
            AppIcon(
              AppGlyph.chevron,
              size: context.fontM,
              color: cs.onSurfaceVariant,
            ),
          ],
        ),
      ),
    );
  }
}
