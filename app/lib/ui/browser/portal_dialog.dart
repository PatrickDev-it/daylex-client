import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../features/browser/web_address.dart';
import '../../l10n/l10n.dart';

/// Asks a portal's name and address; with [rename], only its name. Null when the lawyer cancels.
Future<({String name, String url})?> showPortalDialog(
  BuildContext context, {
  String? name,
  String? url,
  bool rename = false,
}) => showDialog(
  context: context,
  builder: (_) => _PortalDialog(name: name ?? '', url: url ?? '', rename: rename),
);

class _PortalDialog extends StatefulWidget {
  const _PortalDialog({required this.name, required this.url, required this.rename});

  final String name;
  final String url;
  final bool rename;

  @override
  State<_PortalDialog> createState() => _PortalDialogState();
}

class _PortalDialogState extends State<_PortalDialog> {
  late final _name = TextEditingController(text: widget.name.trim());
  late final _url = TextEditingController(text: widget.url);

  /// Shown once the lawyer tried to add an address that is not one, until it is changed.
  var _invalid = false;

  @override
  void dispose() {
    _name.dispose();
    _url.dispose();
    super.dispose();
  }

  void _done() {
    if (widget.rename) {
      if (_name.text.trim().isNotEmpty) Navigator.pop(context, (name: _name.text.trim(), url: widget.url));
      return;
    }
    final uri = typedAddress(_url.text);
    if (uri == null || navigationFor(uri) != Navigation.web) return setState(() => _invalid = true);
    Navigator.pop(context, (name: _name.text.trim(), url: uri.toString()));
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return AlertDialog(
      title: Text(widget.rename ? l.browserPortalRenameTitle : l.browserPortalDialogTitle),
      content: SizedBox(
        width: AppTheme.dialogWidth,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _name,
              autofocus: true,
              textInputAction: widget.rename ? TextInputAction.done : TextInputAction.next,
              decoration: InputDecoration(labelText: l.browserPortalName),
              onSubmitted: widget.rename ? (_) => _done() : null,
            ),
            if (!widget.rename) ...[
              const SizedBox(height: 12),
              TextField(
                controller: _url,
                keyboardType: TextInputType.url,
                autocorrect: false,
                decoration: InputDecoration(
                  labelText: l.browserPortalAddress,
                  errorText: _invalid ? l.browserPortalAddressInvalid : null,
                ),
                onChanged: (_) {
                  if (_invalid) setState(() => _invalid = false);
                },
                onSubmitted: (_) => _done(),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: Text(l.cancel)),
        FilledButton(onPressed: _done, child: Text(widget.rename ? l.save : l.browserPortalAdd)),
      ],
    );
  }
}
