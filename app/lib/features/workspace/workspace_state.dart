import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/l10n.dart';
import '../../l10n/labels.dart';
import '../document/data/doc_templates.dart';
import '../document/model/document.dart';
import '../document/model/operations.dart';
import '../document/service/document_service.dart';
import '../storage/local_store.dart';
import 'chat_thread.dart';
import 'doc_history.dart';
import 'document_review.dart';
import 'first_run.dart';
import 'panel_tabs.dart';
import 'workspace_documents.dart';
import 'workspace_model.dart';
import 'workspace_repository.dart';
import 'workspace_threads.dart';

export 'doc_history.dart';
export 'workspace_model.dart';

final documentServiceProvider = Provider((_) => const DocumentService());

final workspaceProvider = NotifierProvider<WorkspaceNotifier, WorkspaceState>(
  WorkspaceNotifier.new,
);

final activeThreadProvider = Provider<ChatThread?>(
  (ref) => ref.watch(workspaceProvider.select((s) => s.activeThread)),
);

final activeDocumentProvider = Provider<PaperDocument?>(
  (ref) => ref.watch(workspaceProvider.select((s) => s.activeDocument)),
);

/// Owns projects, chats, documents and edit history. Every document mutation
/// goes through [apply], which is what the agent tools and the editor call.
///
/// The changes themselves are the transitions of [WorkspaceThreads], [WorkspaceDocuments], [PanelTabs] and
/// [DocHistory]; what is on disk is the [WorkspaceRepository]'s.
class WorkspaceNotifier extends Notifier<WorkspaceState> {
  DocumentService get _service => ref.read(documentServiceProvider);

  /// Name of the project the work comes back in when the index of the saved work is lost.
  static const recoveredProject = WorkspaceRepository.recoveredProject;

  WorkspaceRepository? _repository;
  Timer? _saveTimer;

  @override
  WorkspaceState build() {
    final store = ref.read(localStoreProvider);
    final repository = _repository = store == null
        ? null
        : WorkspaceRepository(store);
    final loaded = repository?.load();
    // Also called once right after build: a first run writes its project, so the next one opens on it.
    listenSelf((previous, next) {
      _scheduleSave();
      for (final doc in next.documents.values) {
        if (!identical(previous?.documents[doc.id], doc)) {
          // Start at the commit, not at the next widget frame: consecutive agent edits are distinct revisions.
          unawaited(
            ref
                .read(documentReviewProvider(doc).future)
                .then<void>((_) {}, onError: (Object _, StackTrace _) {}),
          );
        }
      }
    });
    ref.onDispose(() => _saveTimer?.cancel());
    return loaded ?? ref.read(firstRunWorkspaceProvider);
  }

  void _scheduleSave() {
    if (_repository == null) return;
    _saveTimer?.cancel();
    _saveTimer = Timer(LocalStore.saveDelay, flush);
  }

  /// Writes what changed since the last save: on a timer after each change, and when the window closes.
  void flush() {
    _saveTimer?.cancel();
    _repository?.save(state);
  }

  // -- projects -----------------------------------------------------------------

  Project createProject(String name) {
    final project = Project(
      id: newId(),
      name: name.trim().isEmpty
          ? ref.read(l10nProvider).untitledProject
          : name.trim(),
      color: kProjectPalette[state.projects.length % kProjectPalette.length],
    );
    state = state.copyWith(projects: [...state.projects, project]);
    return project;
  }

  // -- chats --------------------------------------------------------------------

  /// Shows [threadId] in the center, or the new-chat screen for null.
  void selectThread(String? threadId) => state = state.showingThread(threadId);

  /// A new chat in [projectId], titled [title] or "New chat" in the app's language.
  ChatThread createThread({
    required String projectId,
    String? title,
    String? documentId,
  }) {
    final thread = newChat(
      id: newId(),
      projectId: projectId,
      title: title ?? ref.read(l10nProvider).newChat,
      documentId: documentId,
    );
    state = state.addingThread(thread);
    return thread;
  }

  void renameThread(String id, String title) => _changeThread(
    id,
    (t) => t.copyWith(title: title.trim().isEmpty ? t.title : title.trim()),
  );

  /// Marks a chat as active now so it rises to the top of its project.
  void touchThread(String id) =>
      _changeThread(id, (t) => t.copyWith(updatedAt: DateTime.now()));

  /// Takes the chat out of the workspace. Its saved messages are the agent's to delete
  /// (`AgentController.deleteChat`).
  void deleteThread(String id) => state = state.removingThread(id);

  void _changeThread(String id, ChatThread Function(ChatThread) change) =>
      state = state.changingThread(id, change);

  // -- side-panel tabs ----------------------------------------------------------

  /// Opens [tab] in [threadId] (the active chat by default) and focuses it.
  void openTab(PanelTab tab, {String? threadId}) =>
      _changeTabs(threadId, (t) => t.opening(tab));

  void activateTab(PanelTab tab, {String? threadId}) =>
      _changeTabs(threadId, (t) => t.activating(tab));

  void closeTab(PanelTab tab, {String? threadId}) =>
      _changeTabs(threadId, (t) => t.closing(tab));

  void _changeTabs(String? threadId, ChatThread Function(ChatThread) change) {
    final id = threadId ?? state.activeThreadId;
    if (id != null) _changeThread(id, change);
  }

  // -- documents ----------------------------------------------------------------

  /// Adds [doc] and opens it in the chat [threadId] (or the active chat).
  void addDocument(PaperDocument doc, {String? threadId}) =>
      state = state.addingDocument(
        doc,
        thread: state.threads[threadId ?? state.activeThreadId],
      );

  PaperDocument createFromTemplate(DocTemplate template, {String? projectId}) {
    final doc = template.build(
      projectId ?? state.activeThread?.projectId ?? state.projects.first.id,
    );
    addDocument(doc);
    return doc;
  }

  void duplicate(String documentId) {
    final source = state.documents[documentId];
    if (source == null) return;
    final copy = PaperDocument.fromJson({...source.toJson(), 'id': newId()});
    addDocument(
      copy.copyWith(
        metadata: copy.metadata.copyWith(title: '${source.title} (${ref.read(l10nProvider).copy.toLowerCase()})'),
      ),
    );
  }

  void deleteDocument(String documentId) =>
      state = state.removingDocument(documentId);

  // -- history ------------------------------------------------------------------

  /// Applies [ops] to a document as a single undoable step.
  /// Throws [DocumentOperationException] and leaves state untouched on error.
  void apply(List<DocOperation> ops, {String? documentId, String? label}) {
    final id = documentId ?? state.activeThread?.documentId;
    final doc = id == null ? null : state.documents[id];
    if (doc == null) {
      throw const DocumentOperationException.noDocument();
    }
    _push(
      doc,
      _service.applyAll(doc, ops),
      label ?? ref.read(l10nProvider).operation(ops.first),
    );
  }

  /// Puts [snapshot] back as the current version, as an undoable step.
  void restore(PaperDocument snapshot, {required String label}) {
    final current = state.documents[snapshot.id];
    if (current == null) return;
    _push(current, snapshot, label);
  }

  void _push(PaperDocument current, PaperDocument next, String label) =>
      state = state.committing(
        next,
        state.historyOf(current.id).pushed(current, label),
      );

  bool get canUndo {
    final doc = state.activeDocument;
    return doc != null && state.historyOf(doc.id).undo.isNotEmpty;
  }

  bool get canRedo {
    final doc = state.activeDocument;
    return doc != null && state.historyOf(doc.id).redo.isNotEmpty;
  }

  /// Returns the label of the undone step, or null if nothing to undo.
  String? undo() {
    final doc = state.activeDocument;
    return doc == null ? null : _step(state.historyOf(doc.id).undone(doc));
  }

  /// Returns the label of the redone step, or null if nothing to redo.
  String? redo() {
    final doc = state.activeDocument;
    return doc == null ? null : _step(state.historyOf(doc.id).redone(doc));
  }

  String? _step((PaperDocument, String, DocHistory)? step) {
    if (step == null) return null;
    final (doc, label, history) = step;
    state = state.committing(doc, history);
    return label;
  }
}
