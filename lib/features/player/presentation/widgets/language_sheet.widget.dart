import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../common/utils/responsive.dart';
import '../../../../common/widgets/app_icon.widget.dart';
import '../../../../l10n/l10n.dart';
import '../../controller/language.controller.dart';
import '../../domain/app_language.dart';

/// The app's language, picked from a list: the phone's first, then every
/// language the app speaks, each in its own words. A pick shows at once
/// and closes the list.
class LanguageSheet extends ConsumerWidget {
  const LanguageSheet({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ColorScheme cs = Theme.of(context).colorScheme;
    final String? picked = ref.watch(languageControllerProvider).value;

    Widget option(String? code, String name) {
      final bool selected = code == picked;
      return ListTile(
        contentPadding: EdgeInsets.symmetric(
          horizontal: context.horizontalPadding,
        ),
        title: Text(
          name,
          style: TextStyle(
            fontSize: context.fontM,
            fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
            color: cs.onSurface,
          ),
        ),
        trailing: selected
            ? AppIcon(AppGlyph.check, size: context.fontL, color: cs.primary)
            : null,
        selected: selected,
        onTap: () {
          unawaited(ref.read(languageControllerProvider.notifier).set(code));
          Navigator.of(context).pop();
        },
      );
    }

    return SafeArea(
      child: ListView(
        shrinkWrap: true,
        children: <Widget>[
          option(null, context.l10n.languageAsOnPhone),
          for (final MapEntry<String, String> language
              in AppLanguage.names.entries)
            option(language.key, language.value),
        ],
      ),
    );
  }
}

Future<void> showLanguageSheet(BuildContext context) =>
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (BuildContext context) => const LanguageSheet(),
    );
