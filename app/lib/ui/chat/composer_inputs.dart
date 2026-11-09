import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// What the prompt box keeps outside its widget: the draft of each chat (switching chats and back keeps it) and
/// the focus that the shortcuts move to the box.
class ComposerInputs {
  final focus = FocusNode(debugLabel: 'agent-input');
  final _drafts = <String, TextEditingController>{};

  /// The draft of chat [sessionId] (or of the new-chat screen).
  TextEditingController draftOf(String sessionId) => _drafts.putIfAbsent(sessionId, TextEditingController.new);

  void dispose() {
    focus.dispose();
    for (final d in _drafts.values) {
      d.dispose();
    }
  }
}

final composerInputsProvider = Provider<ComposerInputs>((ref) {
  final inputs = ComposerInputs();
  ref.onDispose(inputs.dispose);
  return inputs;
});
