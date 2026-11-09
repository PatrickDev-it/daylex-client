import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';

import '../../l10n/l10n.dart';

/// Small text prompt used for renaming chats and projects.
Future<String?> promptForText(
  BuildContext context, {
  required String title,
  String initial = '',
  String hint = '',

  /// The confirm button; [AppLocalizations.save] when null.
  String? action,
}) async {
  final value = await showDialog<String>(
    context: context,
    builder: (context) => _PromptDialog(title: title, initial: initial, hint: hint, action: action),
  );
  final trimmed = value?.trim();
  return trimmed == null || trimmed.isEmpty ? null : trimmed;
}

/// Owns its field's controller: the dialog is still built through its exit animation, after [showDialog]
/// has returned, so only the route going away may dispose of it.
class _PromptDialog extends StatefulWidget {
  const _PromptDialog({required this.title, required this.initial, required this.hint, required this.action});

  final String title;
  final String initial;
  final String hint;
  final String? action;

  @override
  State<_PromptDialog> createState() => _PromptDialogState();
}

class _PromptDialogState extends State<_PromptDialog> {
  late final _controller = TextEditingController(text: widget.initial);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return AlertDialog(
      title: Text(widget.title),
      content: SizedBox(
        width: AppTheme.dialogWidth,
        child: TextField(
          controller: _controller,
          autofocus: true,
          decoration: InputDecoration(hintText: widget.hint),
          onSubmitted: (v) => Navigator.pop(context, v),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: Text(l.cancel)),
        FilledButton(onPressed: () => Navigator.pop(context, _controller.text), child: Text(widget.action ?? l.save)),
      ],
    );
  }
}
