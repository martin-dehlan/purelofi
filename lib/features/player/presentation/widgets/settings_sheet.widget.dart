import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../common/cache/media_cache.service.dart';
import '../../../../common/utils/responsive.dart';
import '../../../../common/widgets/app_icon.widget.dart';
import '../../../../common/widgets/menu_group.widget.dart';
import '../../../../common/widgets/menu_row.widget.dart';
import '../../controller/auto_hide_controls.controller.dart';
import '../../controller/player.provider.dart';

/// The few things about the app a listener may want differently: whether
/// the controls step aside, and the room the saved files take up.
class SettingsSheet extends ConsumerStatefulWidget {
  const SettingsSheet({super.key});

  /// "84 MB", "1.2 GB" — whole megabytes are precise enough here.
  static String sizeLabel(int bytes) {
    const int mb = 1024 * 1024;
    if (bytes >= 1024 * mb) {
      return '${(bytes / (1024 * mb)).toStringAsFixed(1)} GB';
    }
    return '${(bytes / mb).round()} MB';
  }

  @override
  ConsumerState<SettingsSheet> createState() => _SettingsSheetState();
}

class _SettingsSheetState extends ConsumerState<SettingsSheet> {
  /// What the saved files take up; `null` while it is being counted, and
  /// when there is no cache to count.
  int? _bytes;

  @override
  void initState() {
    super.initState();
    unawaited(_count());
  }

  Future<void> _count() async {
    final MediaCache? cache = ref.read(mediaCacheProvider);
    if (cache == null) return;
    final int bytes = await cache.sizeInBytes();
    if (mounted) setState(() => _bytes = bytes);
  }

  Future<void> _clear() async {
    final MediaCache? cache = ref.read(mediaCacheProvider);
    if (cache == null) return;
    await cache.clear();
    // The room covers held on to their files; they fetch them again.
    ref.invalidate(sceneCoverProvider);
    await _count();
  }

  @override
  Widget build(BuildContext context) {
    final bool autoHide =
        ref.watch(autoHideControlsControllerProvider).value ?? true;
    final bool hasCache = ref.watch(mediaCacheProvider) != null;
    final int? bytes = _bytes;
    final VoidCallback? clear = bytes == null || bytes == 0
        ? null
        : () => unawaited(_clear());

    return SafeArea(
      child: SingleChildScrollView(
        padding: EdgeInsets.only(bottom: context.spaceM),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Padding(
              padding: EdgeInsets.fromLTRB(
                context.horizontalPadding,
                0,
                context.horizontalPadding,
                context.spaceM,
              ),
              child: Text(
                'Settings',
                style: TextStyle(
                  fontSize: context.fontL,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            MenuGroup(
              children: <Widget>[
                MenuRow(
                  glyph: AppGlyph.menu,
                  title: 'Hide controls',
                  subtitle: 'After a few seconds without a tap',
                  trailing: Switch(
                    value: autoHide,
                    onChanged: (bool on) => unawaited(
                      ref
                          .read(autoHideControlsControllerProvider.notifier)
                          .set(on),
                    ),
                  ),
                  onTap: () => unawaited(
                    ref
                        .read(autoHideControlsControllerProvider.notifier)
                        .set(!autoHide),
                  ),
                ),
              ],
            ),
            if (hasCache) ...<Widget>[
              SizedBox(height: context.spaceM),
              MenuGroup(
                children: <Widget>[
                  MenuRow(
                    glyph: AppGlyph.queue,
                    title: 'Saved music and rooms',
                    subtitle: bytes == null
                        ? 'Counting…'
                        : '${SettingsSheet.sizeLabel(bytes)} on this phone',
                    trailing: TextButton(
                      onPressed: clear,
                      child: const Text('Clear'),
                    ),
                    onTap: clear,
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Opens the settings.
Future<void> showSettingsSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (BuildContext context) => const SettingsSheet(),
  );
}
