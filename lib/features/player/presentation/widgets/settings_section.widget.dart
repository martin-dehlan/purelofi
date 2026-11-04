import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../common/cache/media_cache.service.dart';
import '../../../../common/utils/responsive.dart';
import '../../../../common/widgets/app_icon.widget.dart';
import '../../../../common/widgets/menu_group.widget.dart';
import '../../../../common/widgets/menu_row.widget.dart';
import '../../../../common/errors/app_error.dart';
import '../../../../common/utils/app_links.dart';
import '../../../auth/controller/auth.provider.dart';
import '../../../auth/presentation/widgets/account_sheet.widget.dart';
import '../../../pro/controller/pro.controller.dart';
import '../../../pro/domain/pro_status.entity.dart';
import '../../controller/auto_hide_controls.controller.dart';
import '../../controller/downloads.controller.dart';
import '../../controller/play_history.controller.dart';
import '../../controller/player.provider.dart';
import '../../controller/room_music.controller.dart';
import '../../controller/soft_transitions.controller.dart';

/// The few things about the app a listener may want differently: whether
/// the controls step aside, the room the saved files take up and, where Pro
/// is for sale, getting a purchase back or changing it.
///
/// A part of the room page, not a page of its own: it lays out at its full
/// height and the page scrolls.
class SettingsSection extends ConsumerStatefulWidget {
  const SettingsSection({super.key});

  /// "84 MB", "1.2 GB" — whole megabytes are precise enough here.
  static String sizeLabel(int bytes) {
    const int mb = 1024 * 1024;
    if (bytes >= 1024 * mb) {
      return '${(bytes / (1024 * mb)).toStringAsFixed(1)} GB';
    }
    return '${(bytes / mb).round()} MB';
  }

  @override
  ConsumerState<SettingsSection> createState() => _SettingsSectionState();
}

class _SettingsSectionState extends ConsumerState<SettingsSection> {
  /// What the saved files take up; `null` while it is being counted, and
  /// when there is no cache to count.
  int? _bytes;

  /// What the downloads take up, counted with the rest.
  int? _downloadedBytes;

  /// What the last restore found, said under its row.
  String? _restored;
  bool _restoring = false;

  @override
  void initState() {
    super.initState();
    unawaited(_count());
  }

  Future<void> _count() async {
    final MediaCache? cache = ref.read(mediaCacheProvider);
    if (cache == null) return;
    final int bytes = await cache.sizeInBytes();
    final int downloaded = await cache.downloadedBytes();
    if (mounted) {
      setState(() {
        _bytes = bytes;
        _downloadedBytes = downloaded;
      });
    }
  }

  Future<void> _clear() async {
    final MediaCache? cache = ref.read(mediaCacheProvider);
    if (cache == null) return;
    await cache.clear();
    // The room covers held on to their files; they fetch them again.
    ref.invalidate(sceneCoverProvider);
    await _count();
  }

  Future<void> _restore() async {
    // Pro belongs to the account (#108): restoring needs one to land on.
    if (ref.read(authRepositoryProvider).current == null) {
      await showAccountSheet(
        context,
        reason: 'Pro stays with your account, on every phone you sign in on.',
      );
      if (!mounted || ref.read(authRepositoryProvider).current == null) return;
    }
    setState(() {
      _restoring = true;
      _restored = null;
    });
    String said;
    try {
      said = await ref.read(proControllerProvider.notifier).restore()
          ? 'Pro is back'
          : 'No earlier purchase on this store account';
    } on AppError catch (error) {
      said = error.userMessage;
    }
    if (mounted) {
      setState(() {
        _restoring = false;
        _restored = said;
      });
    }
  }

  /// "3 tracks, 14 MB", or that there are none.
  static String _downloadsLabel(int count, int? bytes) {
    if (count == 0) return 'Nothing downloaded yet';
    final String tracks = count == 1 ? '1 track' : '$count tracks';

    return bytes == null
        ? tracks
        : '$tracks, ${SettingsSection.sizeLabel(bytes)}';
  }

  Future<void> _removeDownloads() async {
    await ref.read(downloadsControllerProvider.notifier).removeAll();
    await _count();
  }

  @override
  Widget build(BuildContext context) {
    final bool sellsPro = ref.read(proControllerProvider.notifier).isAvailable;
    final ProStatus pro =
        ref.watch(proControllerProvider).value ?? ProStatus.free;
    final String? manage = pro.manageUrl;
    final int downloadCount =
        ref.watch(downloadsControllerProvider).value?.done.length ?? 0;
    final int? downloadedBytes = _downloadedBytes;
    final bool autoHide =
        ref.watch(autoHideControlsControllerProvider).value ?? true;
    final bool softTransitions =
        ref.watch(softTransitionsControllerProvider).value ?? true;
    final bool followRoom =
        ref.watch(followRoomControllerProvider).value ?? false;
    final bool hasHistory =
        ref.watch(recentPlaysProvider).value?.isNotEmpty ?? false;
    final bool hasCache = ref.watch(mediaCacheProvider) != null;
    final int? bytes = _bytes;
    final VoidCallback? clear = bytes == null || bytes == 0
        ? null
        : () => unawaited(_clear());

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        MenuGroup(
          children: <Widget>[
            MenuRow(
              glyph: AppGlyph.eye,
              title: 'Hide controls',
              subtitle: 'After a few seconds without a tap',
              trailing: Switch(
                value: autoHide,
                onChanged: (bool on) => unawaited(
                  ref.read(autoHideControlsControllerProvider.notifier).set(on),
                ),
              ),
              onTap: () => unawaited(
                ref
                    .read(autoHideControlsControllerProvider.notifier)
                    .set(!autoHide),
              ),
            ),
            MenuRow(
              glyph: AppGlyph.next,
              title: 'Soft transitions',
              subtitle: 'Tracks fade into each other',
              trailing: Switch(
                value: softTransitions,
                onChanged: (bool on) => unawaited(
                  ref.read(softTransitionsControllerProvider.notifier).set(on),
                ),
              ),
              onTap: () => unawaited(
                ref
                    .read(softTransitionsControllerProvider.notifier)
                    .set(!softTransitions),
              ),
            ),
            MenuRow(
              glyph: AppGlyph.scene,
              title: 'Music follows the room',
              subtitle: 'Each room plays its own mood',
              trailing: Switch(
                value: followRoom,
                onChanged: (bool on) => unawaited(
                  ref.read(followRoomControllerProvider.notifier).set(on),
                ),
              ),
              onTap: () => unawaited(
                ref
                    .read(followRoomControllerProvider.notifier)
                    .set(!followRoom),
              ),
            ),
            // The log behind "Recently played" (#142): only ever on the
            // phone, and the listener's to throw away.
            MenuRow(
              glyph: AppGlyph.timer,
              title: 'Listening history',
              subtitle: 'Kept on this phone only',
              trailing: TextButton(
                onPressed: hasHistory
                    ? () => unawaited(
                        ref.read(playHistoryRepositoryProvider).clear(),
                      )
                    : null,
                child: const Text('Clear'),
              ),
              onTap: null,
            ),
          ],
        ),
        if (hasCache) ...<Widget>[
          SizedBox(height: context.spaceM),
          MenuGroup(
            children: <Widget>[
              MenuRow(
                glyph: AppGlyph.storage,
                title: 'Saved music and rooms',
                subtitle: bytes == null
                    ? 'Counting…'
                    : '${SettingsSection.sizeLabel(bytes)} on this phone',
                trailing: TextButton(
                  onPressed: clear,
                  child: const Text('Clear'),
                ),
                onTap: clear,
              ),
              MenuRow(
                glyph: AppGlyph.download,
                title: 'Downloads',
                subtitle: _downloadsLabel(downloadCount, downloadedBytes),
                trailing: TextButton(
                  onPressed: downloadCount == 0
                      ? null
                      : () => unawaited(_removeDownloads()),
                  child: const Text('Remove all'),
                ),
                // Nothing to open: the row says what is kept, the button
                // takes it back. Greyed while there is nothing.
                onTap: downloadCount == 0 ? null : () {},
              ),
            ],
          ),
        ],
        if (sellsPro) ...<Widget>[
          SizedBox(height: context.spaceM),
          MenuGroup(
            children: <Widget>[
              MenuRow(
                glyph: AppGlyph.inOrder,
                title: 'Restore purchases',
                subtitle: _restoring ? 'Asking the store…' : _restored,
                onTap: _restoring ? null : () => unawaited(_restore()),
              ),
              if (pro.isPro && manage != null)
                MenuRow(
                  glyph: AppGlyph.settings,
                  title: 'Manage subscription',
                  subtitle: 'Change or cancel in your store',
                  onTap: () => unawaited(AppLinks.open(Uri.parse(manage))),
                ),
            ],
          ),
        ],
      ],
    );
  }
}
