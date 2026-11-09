import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../core/theme/app_theme.dart';
import '../features/agent/agent_controller.dart';
import '../features/storage/local_store.dart';
import '../features/agent/domain/source_reference.dart';
import '../features/document/data/doc_templates.dart';
import '../features/workspace/chat_thread.dart';
import '../features/workspace/ui_state.dart';
import '../features/workspace/viewer_state.dart';
import '../features/workspace/pdf_export.dart';
import '../features/workspace/review_state.dart';
import '../features/workspace/workspace_state.dart';
import '../l10n/l10n.dart';
import 'chat/composer_inputs.dart';
import 'common/widgets.dart';
import 'shortcuts.dart';

final navigatorKey = GlobalKey<NavigatorState>();
final messengerKey = GlobalKey<ScaffoldMessengerState>();

/// Long enough to read a short sentence twice.
const _toastDuration = Duration(seconds: 3);

void toast(String message) => messengerKey.currentState
  ?..hideCurrentSnackBar()
  ..showSnackBar(SnackBar(content: Text(message), duration: _toastDuration));

/// App-level commands shared by shortcuts, toolbar buttons, menus and chat
/// components.
class AppActions {
  AppActions(this.ref);

  final WidgetRef ref;

  WorkspaceNotifier get _workspace => ref.read(workspaceProvider.notifier);
  UiNotifier get _ui => ref.read(uiProvider.notifier);
  AppLocalizations get _l => ref.read(l10nProvider);

  /// Writes everything still waiting to be saved (saves otherwise run a moment after each change): the window
  /// is closing, the app goes to the background or restarts to update.
  bool saveNow() {
    _workspace.flush();
    ref.read(agentProvider.notifier).flush();
    return !(ref.read(localStoreProvider)?.hasUnsavedWrites ?? false);
  }

  /// What a global shortcut does. Null for the ones bound where they act: undo and redo on the document (a
  /// text field keeps its own), Esc in the chat.
  VoidCallback? forShortcut(AppShortcut shortcut) => switch (shortcut) {
    AppShortcut.newChat => () => newChat(
      projectId: ref.read(activeThreadProvider)?.projectId,
    ),
    AppShortcut.newDocument => newDocument,
    AppShortcut.focusPrompt => focusComposer,
    AppShortcut.export => export,
    AppShortcut.preview => () => setMode(EditorMode.preview),
    AppShortcut.edit => () => setMode(EditorMode.edit),
    AppShortcut.previousPage =>
      () => ref.read(viewerProvider.notifier).previous(),
    AppShortcut.nextPage => () => ref.read(viewerProvider.notifier).next(),
    AppShortcut.zoomIn => () => ref.read(viewerProvider.notifier).zoomIn(),
    AppShortcut.zoomOut => () => ref.read(viewerProvider.notifier).zoomOut(),
    AppShortcut.zoomReset => () => ref.read(viewerProvider.notifier).setZoom(1),
    AppShortcut.libraryTab => () => openTab(PanelTab.library),
    AppShortcut.reviewTab => () => openReview(),
    AppShortcut.logTab => () => openTab(PanelTab.log),
    AppShortcut.closeTab => closeActiveTab,
    AppShortcut.toggleSidebar => _ui.toggleSidebar,
    AppShortcut.togglePanel => _ui.togglePanel,
    AppShortcut.toggleTheme => toggleTheme,
    AppShortcut.undo || AppShortcut.redo || AppShortcut.stopAgent => null,
  };

  // -- chats --------------------------------------------------------------------

  void newChat({String? projectId}) {
    _ui.newChat(projectId: projectId);
    WidgetsBinding.instance.addPostFrameCallback((_) => focusComposer());
  }

  void openChat(String threadId) => _ui.openThread(threadId);

  /// Deletes a chat once confirmed: its messages and its case file on the
  /// server go with it, and nothing brings them back.
  Future<void> deleteChat(String threadId) async {
    final thread = ref.read(workspaceProvider).threads[threadId];
    final agent = ref.read(
      agentProvider.notifier,
    ); // read now: the caller may unmount meanwhile
    if (thread == null) return;
    final ok = await _confirmDelete(
      _l.deleteTitle(thread.title),
      _l.deleteChatMessage,
    );
    if (ok) agent.deleteChat(threadId);
  }

  void focusComposer() => ref.read(composerInputsProvider).focus.requestFocus();

  // -- documents ----------------------------------------------------------------

  Future<void> newDocument() async {
    final context = navigatorKey.currentContext;
    if (context == null) return;
    final template = await showDialog<DocTemplate>(
      context: context,
      builder: (_) => const _TemplatePicker(),
    );
    if (template != null) createFromTemplate(template);
  }

  /// Creates a document in the active chat, or in a new chat for it.
  void createFromTemplate(DocTemplate template) {
    final ws = ref.read(workspaceProvider);
    if (ws.activeThread == null) {
      final projectId =
          ref.read(uiProvider).newChatProjectId ?? ws.projects.first.id;
      _workspace.createThread(projectId: projectId, title: template.name);
      _ui.openThread(ref.read(workspaceProvider).activeThreadId);
    }
    final doc = _workspace.createFromTemplate(template);
    _ui
      ..setEditorMode(EditorMode.preview)
      ..showPanel();
    toast(_l.documentCreated(doc.title));
  }

  /// Opens [documentId] in the side panel of the active chat.
  void openDocument(String documentId) {
    if (ref.read(workspaceProvider).activeThread == null) return;
    _workspace.openTab(PanelTab.preview(documentId));
    _ui.showPanel();
  }

  /// Evidence is scoped to its conversation and never becomes the editing target.
  void showSource(String threadId, SourceReference source) {
    if (!ref.read(workspaceProvider).threads.containsKey(threadId)) return;
    _workspace.openTab(
      PanelTab.source(
        source.name,
        sourcePage: source.page,
        sourceQuote: source.quote,
        sourceId: source.sourceId,
      ),
      threadId: threadId,
    );
    if (ref.read(workspaceProvider).activeThreadId == threadId) _ui.showPanel();
  }

  /// Opens [documentId] on [page] (1-based) in the side panel.
  void showPage(String documentId, int page) {
    if (ref.read(workspaceProvider).activeThread == null) return;
    _workspace.openTab(PanelTab.preview(documentId));
    ref.read(viewerProvider.notifier).revealFor(documentId, page);
    _ui
      ..setEditorMode(EditorMode.preview)
      ..showPanel();
  }

  /// Deletes a document once confirmed: its version history goes with it.
  Future<void> deleteDocument(String documentId) async {
    final doc = ref.read(workspaceProvider).documents[documentId];
    final workspace = _workspace; // read now: the caller may unmount meanwhile
    if (doc == null) return;
    final ok = await _confirmDelete(
      _l.deleteTitle(doc.title),
      _l.deleteDocumentMessage,
    );
    if (!ok) return;
    workspace.deleteDocument(documentId);
    toast(_l.documentDeleted(doc.title));
  }

  /// The one confirmation every irreversible delete goes through.
  Future<bool> _confirmDelete(String title, String message) async {
    final context = navigatorKey.currentContext;
    if (context == null) return false;
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: SizedBox(width: AppTheme.dialogWidth, child: Text(message)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(context.l10n.cancel),
          ),
          FilledButton(
            autofocus: true,
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: Text(context.l10n.delete),
          ),
        ],
      ),
    );
    return ok ?? false;
  }

  Future<void> export() async {
    final doc = ref.read(activeDocumentProvider);
    if (doc == null) return toast(_l.exportNoDocument);
    await exportDocument(doc.id);
  }

  Future<void> exportDocument(String documentId) async {
    final doc = ref.read(workspaceProvider).documents[documentId];
    if (doc == null) return;
    try {
      final path = await ref.read(exportServiceProvider).export(doc);
      if (path != null) toast(_l.exportedTo(path));
    } catch (e) {
      debugPrint('PaperAgent export: $e');
      toast(_l.exportFailed(_l.failureUnexpected));
    }
  }

  void undo() {
    final label = _workspace.undo();
    if (label != null) toast(_l.undid(label));
  }

  void redo() {
    final label = _workspace.redo();
    if (label != null) toast(_l.redid(label));
  }

  void setMode(EditorMode mode) {
    final doc = ref.read(activeDocumentProvider);
    if (doc == null) return;
    _workspace.openTab(PanelTab.preview(doc.id));
    _ui
      ..setEditorMode(mode)
      ..showPanel();
  }

  // -- side panel -----------------------------------------------------------------

  void openTab(PanelTab tab) {
    if (ref.read(workspaceProvider).activeThread == null) return;
    _workspace.openTab(tab);
    _ui.showPanel();
  }

  void openReview({String? turnId}) {
    ref.read(reviewTurnProvider.notifier).select(turnId);
    openTab(PanelTab.review);
  }

  void closeActiveTab() {
    final tab = ref.read(workspaceProvider).activeThread?.activeTab;
    if (tab != null) _workspace.closeTab(tab);
  }

  void toggleTheme() {
    final context = navigatorKey.currentContext;
    if (context == null) return;
    _ui.toggleTheme(Theme.of(context).brightness);
  }
}

class _TemplatePicker extends StatelessWidget {
  const _TemplatePicker();

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final l = context.l10n;
    return Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(l.newDocument, style: text.titleLarge),
              const SizedBox(height: 4),
              Text(l.templatePickerHint, style: text.bodySmall),
              const SizedBox(height: 16),
              for (final t in docTemplates)
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: TemplateTile(
                    template: t,
                    onTap: () => Navigator.pop(context, t),
                  ),
                ),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(LucideIcons.x, size: 14),
                  label: Text(l.cancel),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
