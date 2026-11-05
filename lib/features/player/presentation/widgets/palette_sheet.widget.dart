import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../common/theme/app_palette.dart';
import '../../../../common/theme/app_theme.dart';
import '../../../../common/utils/responsive.dart';
import '../../../../common/widgets/app_icon.widget.dart';
import '../../../../l10n/l10n.dart';
import '../../controller/palette.controller.dart';

/// The app's colours, picked from a list. Each row shows its palette as
/// three small squares, the accent and the tones grown from it, so what a
/// pick does is seen before it is made. A pick recolours the app at once
/// and closes the list.
class PaletteSheet extends ConsumerWidget {
  const PaletteSheet({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ColorScheme cs = Theme.of(context).colorScheme;
    final AppPalette picked =
        ref.watch(paletteControllerProvider).value ?? AppPalette.lamp;

    Widget option(AppPalette palette) {
      final bool selected = palette == picked;
      return ListTile(
        contentPadding: EdgeInsets.symmetric(
          horizontal: context.horizontalPadding,
        ),
        leading: _Swatch(AppTheme.of(palette).colorScheme),
        title: Text(
          paletteName(context, palette),
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
          unawaited(ref.read(paletteControllerProvider.notifier).set(palette));
          Navigator.of(context).pop();
        },
      );
    }

    return SafeArea(
      child: ListView(
        shrinkWrap: true,
        children: <Widget>[
          for (final AppPalette palette in AppPalette.values) option(palette),
        ],
      ),
    );
  }
}

/// What a palette is called, in the app's language.
String paletteName(BuildContext context, AppPalette palette) =>
    switch (palette) {
      AppPalette.lamp => context.l10n.paletteLamp,
      AppPalette.moss => context.l10n.paletteMoss,
      AppPalette.sea => context.l10n.paletteSea,
      AppPalette.dusk => context.l10n.paletteDusk,
      AppPalette.blossom => context.l10n.paletteBlossom,
      AppPalette.paper => context.l10n.palettePaper,
    };

/// Three hard-edged squares in a row, pixel-like: the accent, the quieter
/// tone grown from it and the surface a card takes on in that palette.
class _Swatch extends StatelessWidget {
  const _Swatch(this.scheme);

  final ColorScheme scheme;

  @override
  Widget build(BuildContext context) {
    final double side = context.fontM;
    Widget square(Color color) => SizedBox.square(
      dimension: side,
      child: ColoredBox(color: color),
    );

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        square(scheme.primary),
        square(scheme.secondary),
        square(scheme.surfaceContainerHighest),
      ],
    );
  }
}

Future<void> showPaletteSheet(BuildContext context) =>
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (BuildContext context) => const PaletteSheet(),
    );
