import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../workspace/chat_thread.dart';
import '../workspace/ui_state.dart';
import '../workspace/viewer_state.dart';
import '../workspace/workspace_state.dart';

/// Shows [page] of [documentId] in the side panel of [threadId]. The panel itself opens only when that chat is
/// the one on screen.
void revealPage(Ref ref, String threadId, String documentId, int page) {
  ref.read(workspaceProvider.notifier).openTab(PanelTab.preview(documentId), threadId: threadId);
  ref.read(viewerProvider.notifier).revealFor(documentId, page);
  if (ref.read(workspaceProvider).activeThreadId != threadId) return;
  ref.read(uiProvider.notifier)
    ..setEditorMode(EditorMode.preview)
    ..showPanel();
}
