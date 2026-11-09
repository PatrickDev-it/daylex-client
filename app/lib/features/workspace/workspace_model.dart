import '../document/model/document.dart';
import 'chat_thread.dart';
import 'doc_history.dart';

/// Projects, chats, documents and their edit history, as one immutable value: a change that spans them (a
/// document deleted out of every chat) is one step.
class WorkspaceState {
  const WorkspaceState({
    required this.projects,
    required this.documents,
    this.threads = const {},
    this.activeThreadId,
    this.histories = const {},
  });

  final List<Project> projects;

  /// Insertion-ordered documents by id.
  final Map<String, PaperDocument> documents;
  final Map<String, ChatThread> threads;

  /// The chat shown in the center; null shows the new-chat screen.
  final String? activeThreadId;
  final Map<String, DocHistory> histories;

  ChatThread? get activeThread =>
      activeThreadId == null ? null : threads[activeThreadId];

  /// The document the active chat works on.
  PaperDocument? get activeDocument {
    final id = activeThread?.documentId;
    return id == null ? null : documents[id];
  }

  Project? projectOf(PaperDocument doc) => project(doc.projectId);

  Project? project(String id) => projects.where((p) => p.id == id).firstOrNull;

  List<PaperDocument> documentsIn(String projectId) =>
      documents.values.where((d) => d.projectId == projectId).toList();

  /// Chats of a project, most recently active first.
  List<ChatThread> threadsIn(String projectId) =>
      threads.values.where((t) => t.projectId == projectId).toList()
        ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));

  DocHistory historyOf(String id) => histories[id] ?? const DocHistory();

  WorkspaceState copyWith({
    List<Project>? projects,
    Map<String, PaperDocument>? documents,
    Map<String, ChatThread>? threads,
    String? Function()? activeThreadId,
    Map<String, DocHistory>? histories,
  }) => WorkspaceState(
    projects: projects ?? this.projects,
    documents: documents ?? this.documents,
    threads: threads ?? this.threads,
    activeThreadId: activeThreadId != null
        ? activeThreadId()
        : this.activeThreadId,
    histories: histories ?? this.histories,
  );
}
