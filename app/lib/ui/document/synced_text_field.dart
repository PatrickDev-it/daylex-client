import 'dart:async';

import 'package:flutter/material.dart';

/// How long a field waits after the last keystroke before it commits: long enough not to make an undo step
/// per letter, short enough that the preview follows the typing.
const _kCommitDelay = Duration(milliseconds: 500);

/// Text field bound to a model value.
///
/// Edits are committed after a short pause or when focus leaves, and outside
/// changes (agent edits, undo) flow back in unless the user is typing.
class SyncedTextField extends StatefulWidget {
  const SyncedTextField({
    super.key,
    required this.value,
    required this.onCommit,
    this.style,
    this.hint,
    this.multiline = false,
    this.boxed = false,
  });

  final String value;
  final void Function(String) onCommit;
  final TextStyle? style;
  final String? hint;
  final bool multiline;

  /// Shows a bordered input instead of inline text.
  final bool boxed;

  @override
  State<SyncedTextField> createState() => _SyncedTextFieldState();
}

class _SyncedTextFieldState extends State<SyncedTextField> {
  late final _controller = TextEditingController(text: widget.value);
  final _focus = FocusNode();
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _focus.addListener(_onFocusChange);
  }

  void _onFocusChange() {
    if (!_focus.hasFocus) _flush();
  }

  @override
  void didUpdateWidget(SyncedTextField old) {
    super.didUpdateWidget(old);
    if (!_focus.hasFocus && widget.value != _controller.text) {
      _controller.text = widget.value;
    }
  }

  @override
  void dispose() {
    // A pending edit (younger than [_kCommitDelay]) is the user's text too: committed, not dropped.
    // onCommit must tolerate a call from here: `_apply` defers it past the frame.
    _focus.removeListener(_onFocusChange);
    _flush();
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _flush() {
    if (_debounce?.isActive ?? false) {
      _debounce!.cancel();
      _commit();
    }
  }

  void _commit() {
    if (_controller.text != widget.value) widget.onCommit(_controller.text);
  }

  @override
  Widget build(BuildContext context) {
    final style = widget.style ?? Theme.of(context).textTheme.bodyMedium;
    return TextField(
      controller: _controller,
      focusNode: _focus,
      style: style,
      minLines: 1,
      maxLines: widget.multiline ? null : 1,
      keyboardType: widget.multiline ? TextInputType.multiline : TextInputType.text,
      onChanged: (_) {
        _debounce?.cancel();
        _debounce = Timer(_kCommitDelay, _commit);
      },
      onSubmitted: (_) => _flush(),
      decoration: widget.boxed
          ? InputDecoration(hintText: widget.hint)
          : InputDecoration(
              hintText: widget.hint,
              isDense: true,
              filled: false,
              contentPadding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
            ),
    );
  }
}
