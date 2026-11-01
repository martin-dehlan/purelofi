import 'package:flutter/material.dart';

import '../../../../common/utils/app_fonts.dart';
import '../../domain/account.entity.dart';

/// The first letter of the listener's name or address, in a circle.
///
/// No photo: Apple and Google only sometimes give one, and a profile that
/// looks different depending on how someone signed in is not worth it.
class ProfileAvatar extends StatelessWidget {
  const ProfileAvatar({required this.account, required this.size, super.key});

  final Account account;
  final double size;

  /// The letter shown; `?` when there is neither a name nor an address.
  static String initialOf(Account account) {
    final String source = (account.name ?? account.email ?? '').trim();
    return source.isEmpty ? '?' : source.characters.first.toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme cs = Theme.of(context).colorScheme;

    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: cs.primaryContainer,
        shape: BoxShape.circle,
      ),
      child: Text(
        initialOf(account),
        style: TextStyle(
          color: cs.onPrimaryContainer,
          fontFamily: AppFonts.wordmark,
          fontSize: size * 0.5,
        ),
      ),
    );
  }
}
