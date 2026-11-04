import 'package:flutter/material.dart';

import '../../../../common/utils/responsive.dart';
import '../../../../common/widgets/app_icon.widget.dart';
import '../../../auth/domain/account.entity.dart';
import '../../../auth/presentation/widgets/profile_avatar.widget.dart';

/// The top of the room page: who is listening, and whether they have Pro. Signed in it shows the initial,
/// the name and the address; signed out, the way in.
///
/// Pro is not a row of its own but a pill under the name: "Get Pro" to the
/// paywall, or the plan a Pro listener has.
class ProfileCard extends StatelessWidget {
  const ProfileCard({
    required this.account,
    required this.onTap,
    this.pro,
    this.isPro = false,
    this.onPro,
    super.key,
  });

  final Account? account;
  final VoidCallback onTap;

  /// The pill's words; none where Pro is not for sale.
  final String? pro;

  /// Whether the pill says what the listener has, rather than offers it.
  final bool isPro;

  final VoidCallback? onPro;

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

                  if (pro case final String label) ...<Widget>[
                    SizedBox(height: context.spaceS),
                    _ProPill(label: label, filled: !isPro, onTap: onPro),
                  ],
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

/// "Get Pro" filled in the accent, or the plan, quiet, once it is theirs.
class _ProPill extends StatelessWidget {
  const _ProPill({required this.label, required this.filled, this.onTap});

  final String label;
  final bool filled;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final ColorScheme cs = Theme.of(context).colorScheme;

    return Material(
      color: filled ? cs.primary : cs.surfaceContainerHighest,
      shape: const StadiumBorder(),
      child: InkWell(
        customBorder: const StadiumBorder(),
        onTap: onTap,
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: context.spaceM,
            vertical: context.spaceXs * 1.5,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              AppIcon(
                filled ? AppGlyph.lock : AppGlyph.check,
                size: context.fontS,
                color: filled ? cs.onPrimary : cs.primary,
              ),
              SizedBox(width: context.spaceXs * 1.5),
              Text(
                label,
                style: TextStyle(
                  color: filled ? cs.onPrimary : cs.onSurface,
                  fontSize: context.fontS,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
