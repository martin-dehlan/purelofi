import 'package:flutter/material.dart';
import '../../../../l10n/l10n.dart';

/// Asks for a playlist's name (#141): a new one, or a new name for one.
/// `null` when the listener cancelled or left it empty.
Future<String?> askPlaylistName(
  BuildContext context, {
  String initial = '',
  String title = 'New playlist',
  String action = 'Create',
}) async {
  final String? name = await showDialog<String>(
    context: context,
    builder: (BuildContext context) =>
        _PlaylistNameDialog(initial: initial, title: title, action: action),
  );

  final String trimmed = name?.trim() ?? '';
  return trimmed.isEmpty ? null : trimmed;
}

/// Owns its text field's controller, so it lives exactly as long as the
/// dialog does — through its closing animation too.
class _PlaylistNameDialog extends StatefulWidget {
  const _PlaylistNameDialog({
    required this.initial,
    required this.title,
    required this.action,
  });

  final String initial;
  final String title;
  final String action;

  @override
  State<_PlaylistNameDialog> createState() => _PlaylistNameDialogState();
}

class _PlaylistNameDialogState extends State<_PlaylistNameDialog> {
  late final TextEditingController _field = TextEditingController(
    text: widget.initial,
  );

  @override
  void dispose() {
    _field.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(widget.title),
    content: TextField(
      controller: _field,
      autofocus: true,
      maxLength: 100,
      textCapitalization: TextCapitalization.sentences,
      decoration: InputDecoration(hintText: context.l10n.rainyEvenings),
      onSubmitted: (String value) => Navigator.of(context).pop(value),
    ),
    actions: <Widget>[
      TextButton(
        onPressed: () => Navigator.of(context).pop(),
        child: Text(context.l10n.cancel),
      ),
      TextButton(
        onPressed: () => Navigator.of(context).pop(_field.text),
        child: Text(widget.action),
      ),
    ],
  );
}

/// Asks before deleting a playlist. The tracks stay; only the list goes.
Future<bool> confirmDeletePlaylist(BuildContext context, String name) async {
  final bool? delete = await showDialog<bool>(
    context: context,
    builder: (BuildContext context) => AlertDialog(
      title: Text('Delete "$name"?'),
      content: Text(context.l10n.theTracksStayInPurelofiOnly),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(context.l10n.keep),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: Text(context.l10n.delete),
        ),
      ],
    ),
  );

  return delete ?? false;
}
