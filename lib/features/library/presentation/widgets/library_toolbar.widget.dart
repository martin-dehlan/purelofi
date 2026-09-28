import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../common/utils/responsive.dart';
import '../../controller/library.controller.dart';
import '../../domain/library_view.dart';

/// Order, sort and, for a library big enough to need it, search (#66).
///
/// Two words that change when tapped rather than a row of controls: the
/// menu sits over the room, and it should read as a list, not a settings
/// page.
class LibraryToolbar extends ConsumerWidget {
  const LibraryToolbar({
    required this.showSearch,
    required this.onSearch,
    super.key,
  });

  /// Search earns its place only once scrolling stops being enough.
  static const int searchFrom = 6;

  final bool showSearch;
  final ValueChanged<String> onSearch;

  static const Map<LibrarySort, String> _sortNames = <LibrarySort, String>{
    LibrarySort.recent: 'Recently added',
    LibrarySort.title: 'Title',
    LibrarySort.artist: 'Artist',
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ColorScheme cs = Theme.of(context).colorScheme;
    final LibraryView view =
        ref.watch(libraryViewControllerProvider).value ?? const LibraryView();
    final LibraryViewController controller = ref.read(
      libraryViewControllerProvider.notifier,
    );

    final LibrarySort nextSort =
        LibrarySort.values[(view.sort.index + 1) % LibrarySort.values.length];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        // Wraps rather than overflows: large system text on a narrow phone
        // puts the sort on its own line.
        Wrap(
          spacing: context.spaceL,
          children: <Widget>[
            _Toggle(
              label: view.order == LibraryOrder.shuffle
                  ? 'Shuffle'
                  : 'In order',
              hint: 'Play order',
              onTap: () => unawaited(
                controller.setOrder(
                  view.order == LibraryOrder.shuffle
                      ? LibraryOrder.inOrder
                      : LibraryOrder.shuffle,
                ),
              ),
            ),
            _Toggle(
              label: _sortNames[view.sort]!,
              hint: 'Sort by',
              onTap: () => unawaited(controller.setSort(nextSort)),
            ),
          ],
        ),
        if (showSearch)
          TextField(
            onChanged: onSearch,
            style: TextStyle(color: cs.onSurface, fontSize: context.fontM),
            decoration: InputDecoration(
              isDense: true,
              hintText: 'Search your music',
              hintStyle: TextStyle(
                color: cs.onSurfaceVariant,
                fontSize: context.fontM,
              ),
              border: UnderlineInputBorder(
                borderSide: BorderSide(color: cs.outlineVariant),
              ),
              focusedBorder: UnderlineInputBorder(
                borderSide: BorderSide(color: cs.primary),
              ),
            ),
          ),
      ],
    );
  }
}

class _Toggle extends StatelessWidget {
  const _Toggle({required this.label, required this.hint, required this.onTap});

  final String label;
  final String hint;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ColorScheme cs = Theme.of(context).colorScheme;

    return Semantics(
      button: true,
      label: '$hint: $label',
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: context.spaceS),
          child: Text.rich(
            TextSpan(
              children: <InlineSpan>[
                TextSpan(
                  text: '$hint  ',
                  style: TextStyle(color: cs.onSurfaceVariant),
                ),
                TextSpan(
                  text: label,
                  style: TextStyle(color: cs.primary),
                ),
              ],
            ),
            style: TextStyle(fontSize: context.fontS),
          ),
        ),
      ),
    );
  }
}
