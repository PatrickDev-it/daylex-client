import 'dart:io';

import 'package:flutter/foundation.dart';

import '../document/model/document.dart';
import '../storage/local_store.dart';
import 'chat_thread.dart';
import 'legacy_demo.dart';
import 'workspace_model.dart';

/// The workspace on disk: the index (`workspace.json`: projects, chats, the order of the documents) and one file
/// per document. The only owner of those files of the [LocalStore]; the chats' own files belong to the chat
/// archive.
class WorkspaceRepository {
  WorkspaceRepository(this._store);

  final LocalStore _store;

  /// The documents as last written, so only the changed ones are written again.
  var _saved = <String, PaperDocument>{};

  /// Name of the project the work comes back in when the index of the saved work is lost.
  static const recoveredProject = 'Lavoro recuperato';

  /// The saved workspace, or what can be recovered of it; null when nothing was ever saved, or the demo an older
  /// version saved was all there was.
  WorkspaceState? load() {
    final saved = _load();
    // A recovered workspace keeps everything: without the index, a demo chat worked on cannot be told apart.
    final loaded = saved == null ? _recover() : withoutUntouchedDemo(saved);
    // The documents on disk: the next save deletes those the demo cleanup took out.
    _saved = Map.of((saved ?? loaded)?.documents ?? const {});
    return loaded;
  }

  /// Writes what changed since the last save. A failure (disk full, folder not writable) is said, and the work
  /// stays in memory: the next save tries again.
  void save(WorkspaceState s) {
    try {
      for (final doc in s.documents.values) {
        if (!identical(_saved[doc.id], doc)) _store.writeDocument(doc.id, doc.toJson());
      }
      for (final id in _saved.keys) {
        if (!s.documents.containsKey(id)) _store.deleteDocument(id);
      }
      _saved = Map.of(s.documents);
      _store.writeWorkspace(toJson(s));
    } on FileSystemException catch (e) {
      _store.saveFailed(e);
    }
  }

  /// The index: the documents themselves are in their own files.
  static Map<String, dynamic> toJson(WorkspaceState s) => {
    'projects': [for (final p in s.projects) p.toJson()],
    'threads': [for (final t in s.threads.values) t.toJson()],
    'documents': s.documents.keys.toList(),
    'activeThreadId': s.activeThreadId,
  };

  /// The workspace of index [json], with each document read by [document]. Null for an index with no project.
  static WorkspaceState? fromJson(Map<String, dynamic> json, Map<String, dynamic>? Function(String id) document) {
    final projects = [
      for (final p in json['projects'] as List? ?? const [])
        if (p is Map) Project.fromJson(p.cast<String, dynamic>()),
    ];
    if (projects.isEmpty) return null;
    final threads = <String, ChatThread>{};
    for (final t in json['threads'] as List? ?? const []) {
      if (t is! Map) continue;
      final thread = ChatThread.fromJson(t.cast<String, dynamic>());
      threads[thread.id] = thread;
    }
    // In the order they were created: the list in workspace.json keeps it.
    final documents = <String, PaperDocument>{
      for (final id in (json['documents'] as List? ?? const []).whereType<String>())
        if (document(id) case final doc?) id: PaperDocument.fromJson(doc),
    };
    final active = json['activeThreadId'] as String?;
    return WorkspaceState(
      projects: projects,
      documents: documents,
      threads: threads,
      activeThreadId: threads.containsKey(active) ? active : null,
    );
  }

  WorkspaceState? _load() {
    final json = _store.readWorkspace();
    if (json == null) return null;
    try {
      return fromJson(json, _store.readDocument);
    } on Object catch (e) {
      // JSON, but not an index this app can read: kept for a human, and the work is rebuilt from its files.
      debugPrint('PaperAgent: workspace index unreadable: $e');
      _store.setAside('workspace.json');
      return null;
    }
  }

  /// The index is lost but the documents and chats are still on disk: they come back in one project, never
  /// replaced by an empty first launch. A chat comes back without its title and its link to a document.
  WorkspaceState? _recover() {
    final documents = <String, PaperDocument>{};
    for (final id in _store.documentIds()) {
      try {
        if (_store.readDocument(id) case final json?) documents[id] = PaperDocument.fromJson(json);
      } on Object catch (e) {
        debugPrint('PaperAgent: document $id unreadable: $e');
      }
    }
    final chats = _store.chatIds();
    if (documents.isEmpty && chats.isEmpty) return null;
    final project = Project(id: newId(), name: recoveredProject);
    final threads = <String, ChatThread>{
      for (final id in chats)
        if (_store.chatSavedAt(id) case final at?)
          id: ChatThread(id: id, projectId: project.id, title: 'Conversazione recuperata', createdAt: at,
              updatedAt: at),
    };
    _store.notice.value = IndexRecoveredNotice(
      documents: documents.length,
      chats: threads.length,
      project: recoveredProject,
    );
    return WorkspaceState(projects: [project], documents: documents, threads: threads, activeThreadId: null);
  }
}
