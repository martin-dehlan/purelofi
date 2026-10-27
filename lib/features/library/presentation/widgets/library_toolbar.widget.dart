import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../common/utils/responsive.dart';
import '../../../../common/widgets/app_icon.widget.dart';
import '../../controller/library.controller.dart';
import '../../domain/library_view.dart';

/// Sort and, for a library big enough to need it, search (#66).
///
/// Material's own controls for these: a chip that opens a menu of sort
/// orders, and a search bar. Each says what it does before it is touched.
/// Shuffle lives in the transport, where it covers both sides.
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

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final LibraryView view =
        ref.watch(libraryViewControllerProvider).value ?? const LibraryView();
    final LibraryViewController controller = ref.read(
      libraryViewControllerProvider.notifier,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        if (showSearch) ...<Widget>[
          _Search(onSearch: onSearch),
          SizedBox(height: context.spaceS),
        ],
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: _SortChip(
            sort: view.sort,
            onSort: (LibrarySort sort) => unawaited(controller.setSort(sort)),
          ),
        ),
      ],
    );
  }
}

/// A chip that names the current order and opens the others.
class _SortChip extends StatelessWidget {
  const _SortChip({required this.sort, required this.onSort});

  final LibrarySort sort;
  final ValueChanged<LibrarySort> onSort;

  static const Map<LibrarySort, String> names = <LibrarySort, String>{
    LibrarySort.recent: 'Recently added',
    LibrarySort.title: 'Title',
    LibrarySort.artist: 'Artist',
  };

  @override
  Widget build(BuildContext context) {
    final ColorScheme cs = Theme.of(context).colorScheme;

    return MenuAnchor(
      menuChildren: <Widget>[
        for (final LibrarySort option in LibrarySort.values)
          MenuItemButton(
            // The current order is ticked; the others keep the same indent.
            leadingIcon: SizedBox.square(
              dimension: context.fontM,
              child: option == sort
                  ? AppIcon(
                      AppGlyph.check,
                      size: context.fontM,
                      color: cs.primary,
                    )
                  : null,
            ),
            onPressed: () => onSort(option),
            child: Text(
              names[option]!,
              style: TextStyle(fontSize: context.fontM),
            ),
          ),
      ],
      builder: (BuildContext context, MenuController menu, Widget? child) =>
          ActionChip(
            avatar: AppIcon(
              AppGlyph.sort,
              size: context.fontM,
              color: cs.onSurfaceVariant,
            ),
            tooltip: 'Sort by: ${names[sort]}',
            label: Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text(names[sort]!, style: TextStyle(fontSize: context.fontS)),
                AppIcon(
                  AppGlyph.dropDown,
                  size: context.fontM,
                  color: cs.onSurfaceVariant,
                ),
              ],
            ),
            onPressed: () => menu.isOpen ? menu.close() : menu.open(),
          ),
    );
  }
}

class _Search extends StatelessWidget {
  const _Search({required this.onSearch});

  final ValueChanged<String> onSearch;

  @override
  Widget build(BuildContext context) {
    final ColorScheme cs = Theme.of(context).colorScheme;

    return SearchBar(
      hintText: 'Search your music',
      onChanged: onSearch,
      elevation: const WidgetStatePropertyAll<double>(0),
      backgroundColor: WidgetStatePropertyAll<Color>(
        cs.surfaceContainerHighest,
      ),
      textStyle: WidgetStatePropertyAll<TextStyle>(
        TextStyle(color: cs.onSurface, fontSize: context.fontM),
      ),
      hintStyle: WidgetStatePropertyAll<TextStyle>(
        TextStyle(color: cs.onSurfaceVariant, fontSize: context.fontM),
      ),
      leading: AppIcon(
        AppGlyph.search,
        size: context.fontL,
        color: cs.onSurfaceVariant,
      ),
    );
  }
}
