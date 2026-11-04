import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../common/errors/app_error.dart';
import '../../../../common/utils/responsive.dart';
import '../../../../common/widgets/app_icon.widget.dart';
import '../../../../common/widgets/menu_group.widget.dart';
import '../../../../common/widgets/menu_row.widget.dart';
import '../../controller/auth.controller.dart';
import '../../domain/account.entity.dart';
import 'delete_account_dialog.dart';
import '../../../../l10n/l10n.dart';

/// The ways out of an account, as rows at the foot of the room page:
/// signing out, and deleting it, which the stores require in the app.
/// Nothing while signed out.
class AccountActions extends ConsumerStatefulWidget {
  const AccountActions({super.key});

  @override
  ConsumerState<AccountActions> createState() => _AccountActionsState();
}

class _AccountActionsState extends ConsumerState<AccountActions> {
  bool _busy = false;
  String? _error;

  Future<void> _leave(Future<void> Function() action) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await action();
    } on AppError catch (error) {
      if (mounted) setState(() => _error = error.userMessage);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _delete() async {
    if (!await confirmDeleteAccount(context)) return;
    await _leave(ref.read(authControllerProvider.notifier).deleteAccount);
  }

  @override
  Widget build(BuildContext context) {
    final Account? account = ref.watch(authControllerProvider).value;
    if (account == null) return const SizedBox.shrink();

    final ColorScheme cs = Theme.of(context).colorScheme;
    final AuthController auth = ref.read(authControllerProvider.notifier);
    final String? error = _error;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        MenuGroup(
          children: <Widget>[
            MenuRow(
              glyph: AppGlyph.account,
              title: context.l10n.signOut,
              onTap: _busy ? null : () => _leave(auth.signOut),
            ),
            MenuRow(
              glyph: AppGlyph.remove,
              title: context.l10n.deleteAccount,
              danger: true,
              onTap: _busy ? null : _delete,
            ),
          ],
        ),
        if (error != null)
          Padding(
            padding: EdgeInsets.fromLTRB(
              context.horizontalPadding,
              context.spaceS,
              context.horizontalPadding,
              0,
            ),
            child: Text(
              error,
              textAlign: TextAlign.center,
              style: TextStyle(color: cs.error, fontSize: context.fontS),
            ),
          ),
      ],
    );
  }
}
