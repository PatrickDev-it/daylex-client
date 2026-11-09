import 'workspace_model.dart';

// The demo older versions wrote on a first launch, before the app started empty (docs/adr/ADR-0002-primo-avvio.md).
// Its ids were fixed, so it is recognised on the disks of the installs that saved it. Never reuse them. Each with
// the name it had: a project or chat renamed was worked on.
const legacyDemoProjects = {'project-acme': 'Acme Corp', 'project-internal': 'Internal'};
const legacyDemoDocumentIds = {'doc-q3-proposal', 'doc-studio-onepager'};
const legacyDemoThreads = {
  'chat-q3-polish': 'Polish the Q3 proposal',
  'chat-q3-draft': 'Draft Q3 proposal for Acme',
  'chat-onepager': 'Studio capabilities one-pager',
};

/// [s] without the part of the demo nobody worked on: its chats nobody wrote in or renamed, its documents nobody
/// edited and no kept chat works on, its projects not renamed and left with nothing in them. What was touched
/// stays, and all of the lawyer's own work. Null when no project is left.
WorkspaceState? withoutUntouchedDemo(WorkspaceState s) {
  final threads = {
    for (final t in s.threads.values)
      if (legacyDemoThreads[t.id] != t.title || t.updatedAt.isAfter(t.createdAt)) t.id: t,
  };
  bool workedOnByChat(String docId) =>
      threads.values.any((t) => t.documentId == docId || t.tabs.any((tab) => tab.documentId == docId));
  final documents = {
    for (final d in s.documents.values)
      if (!legacyDemoDocumentIds.contains(d.id) ||
          d.metadata.updatedAt.isAfter(d.metadata.createdAt) ||
          workedOnByChat(d.id))
        d.id: d,
  };
  final projects = [
    for (final p in s.projects)
      if (legacyDemoProjects[p.id] != p.name ||
          threads.values.any((t) => t.projectId == p.id) ||
          documents.values.any((d) => d.projectId == p.id))
        p,
  ];
  if (projects.isEmpty) return null;
  if (projects.length == s.projects.length &&
      threads.length == s.threads.length &&
      documents.length == s.documents.length) {
    return s;
  }
  return WorkspaceState(
    projects: projects,
    documents: documents,
    threads: threads,
    activeThreadId: threads.containsKey(s.activeThreadId) ? s.activeThreadId : null,
    histories: s.histories,
  );
}
