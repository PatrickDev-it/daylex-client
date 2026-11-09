import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// How long every copy button shows its "copied" check mark.
const copiedFor = Duration(milliseconds: 1500);

/// A copy button's state: [copy] puts text on the clipboard and keeps [copied] true for a moment, so the button
/// can show a check mark that goes away by itself.
mixin CopyFeedback<T extends StatefulWidget> on State<T> {
  var copied = false;
  Timer? _reset;

  @override
  void dispose() {
    _reset?.cancel();
    super.dispose();
  }

  Future<void> copy(String text) async {
    await Clipboard.setData(ClipboardData(text: text));
    if (!mounted) return;
    setState(() => copied = true);
    _reset?.cancel();
    _reset = Timer(copiedFor, () {
      if (mounted) setState(() => copied = false);
    });
  }
}
