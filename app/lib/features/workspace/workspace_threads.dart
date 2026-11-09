import 'chat_thread.dart';
import 'workspace_model.dart';

/// A new chat in [projectId], working on [documentId] (shown in its panel) if given.
ChatThread newChat({required String projectId, required String id, required String title, String? documentId}) {
  final now = DateTime.now();
  return ChatThread(
    id: id,
    projectId: projectId,
    title: title,
    createdAt: now,
    updatedAt: now,
    documentId: documentId,
    tabs: [if (documentId != null) PanelTab.preview(documentId)],
    activeTab: documentId == null ? null : PanelTab.preview(documentId),
  );
}

/// The chats of the workspace. Each change returns the workspace after it; the same one when there is nothing
/// to change.
extension WorkspaceThreads on WorkspaceState {
  /// With [thread] added and shown.
  WorkspaceState addingThread(ChatThread thread) =>
      copyWith(threads: {...threads, thread.id: thread}, activeThreadId: () => thread.id);

  /// With chat [id] changed by [change].
  WorkspaceState changingThread(String id, ChatThread Function(ChatThread) change) {
    final thread = threads[id];
    return thread == null ? this : copyWith(threads: {...threads, id: change(thread)});
  }

  /// Without chat [id]; the new-chat screen shows if it was on screen.
  WorkspaceState removingThread(String id) => copyWith(
    threads: {...threads}..remove(id),
    activeThreadId: activeThreadId == id ? () => null : null,
  );

  /// With [id] in the center, or the new-chat screen for null.
  WorkspaceState showingThread(String? id) =>
      id != null && !threads.containsKey(id) ? this : copyWith(activeThreadId: () => id);
}
