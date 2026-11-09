import '../document/model/document.dart';
import 'chat_thread.dart';
import 'doc_history.dart';
import 'panel_tabs.dart';
import 'workspace_model.dart';
import 'workspace_threads.dart';

/// The documents of the workspace. Each change returns the workspace after it.
extension WorkspaceDocuments on WorkspaceState {
  /// With [doc] added, in its own project or else in that of [thread] (the first project without one), and
  /// opened in [thread].
  WorkspaceState addingDocument(PaperDocument doc, {ChatThread? thread}) {
    final placed = doc.copyWith(
      projectId: doc.projectId.isNotEmpty ? doc.projectId : thread?.projectId ?? projects.first.id,
    );
    final added = copyWith(documents: {...documents, placed.id: placed});
    return thread == null ? added : added.changingThread(thread.id, (t) => t.opening(PanelTab.preview(placed.id)));
  }

  /// Without document [id], its history, and its tab in every chat.
  WorkspaceState removingDocument(String id) => copyWith(
    documents: {...documents}..remove(id),
    histories: {...histories}..remove(id),
    threads: {for (final t in threads.values) t.id: t.forgetting(id)},
  );

  /// With [doc] as the current version of its document and [history] as its history.
  WorkspaceState committing(PaperDocument doc, DocHistory history) => copyWith(
    documents: {...documents, doc.id: doc},
    histories: {...histories, doc.id: history},
  );
}
