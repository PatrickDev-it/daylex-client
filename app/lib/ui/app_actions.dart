import 'package:file_selector/file_selector.dart' show XFile;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../core/theme/app_theme.dart';
import '../features/agent/agent_controller.dart';
import '../features/browser/browser_state.dart';
import '../features/browser/engine/engine.dart';
import '../features/browser/page_file.dart';
import '../features/browser/web_address.dart';
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
import 'browser/browser_host.dart';
import 'chat/composer_inputs.dart';
import 'chat/file_drop.dart';
import 'common/time_format.dart';
import 'common/web_link.dart';
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

  /// The keyboard in [node] once the next frame has built it. The node is read before: the action may come from
  /// a widget that frame takes off screen (Ctrl+T pressed in a page leaves its tab), whose `ref` is gone by then.
  void _focusAfterFrame(FocusNode node) => WidgetsBinding.instance.addPostFrameCallback((_) => node.requestFocus());

  /// Writes everything still waiting to be saved (saves otherwise run a moment after each change): the window
  /// is closing, the app goes to the background or restarts to update.
  bool saveNow() {
    _workspace.flush();
    ref.read(agentProvider.notifier).flush();
    ref.read(browserProvider.notifier).flush();
    return !(ref.read(localStoreProvider)?.hasUnsavedWrites ?? false);
  }

  /// What a global shortcut does. Null for the ones bound where they act: undo and redo on the document (a
  /// text field keeps its own), Esc in the chat. A key a browser gives its page (back, zoom, reload, close the
  /// tab) acts on the web page while the panel shows one, on the document otherwise.
  VoidCallback? forShortcut(AppShortcut shortcut) => switch (shortcut) {
    AppShortcut.newChat => () => newChat(
      projectId: ref.read(activeThreadProvider)?.projectId,
    ),
    AppShortcut.newDocument => newDocument,
    AppShortcut.focusPrompt => focusComposer,
    AppShortcut.export => export,
    AppShortcut.preview => () => setMode(EditorMode.preview),
    AppShortcut.edit => () => setMode(EditorMode.edit),
    AppShortcut.previousPage => () => _onPage(
      (p) => p.back(),
      otherwise: ref.read(viewerProvider.notifier).previous,
    ),
    AppShortcut.nextPage => () => _onPage(
      (p) => p.forward(),
      otherwise: ref.read(viewerProvider.notifier).next,
    ),
    AppShortcut.zoomIn => () => _onPage(
      (p) => p.setZoom(zoomStep(p.state.value.zoom, 1)),
      otherwise: ref.read(viewerProvider.notifier).zoomIn,
    ),
    AppShortcut.zoomOut => () => _onPage(
      (p) => p.setZoom(zoomStep(p.state.value.zoom, -1)),
      otherwise: ref.read(viewerProvider.notifier).zoomOut,
    ),
    AppShortcut.zoomReset => () => _onPage(
      (p) => p.setZoom(1),
      otherwise: () => ref.read(viewerProvider.notifier).setZoom(1),
    ),
    AppShortcut.libraryTab => () => openTab(PanelTab.library),
    // Ctrl+R reloads, in every browser.
    AppShortcut.reviewTab => () => _onPage((p) => p.reload(), otherwise: openReview),
    AppShortcut.logTab => () => openTab(PanelTab.log),
    AppShortcut.closeTab => closeActiveTab,
    AppShortcut.newWebTab => openWebTab,
    AppShortcut.reopenTab => reopenWebTab,
    AppShortcut.nextTab => () => cycleTab(1),
    AppShortcut.previousTab => () => cycleTab(-1),
    AppShortcut.focusAddress => focusAddress,
    AppShortcut.reload => () => _onPage((p) => p.reload(), otherwise: () {}),
    AppShortcut.toggleSidebar => _ui.toggleSidebar,
    AppShortcut.togglePanel => _ui.togglePanel,
    AppShortcut.fullPanel => _ui.toggleFullPanel,
    AppShortcut.toggleTheme => toggleTheme,
    AppShortcut.undo || AppShortcut.redo || AppShortcut.stopAgent => null,
  };

  // -- chats --------------------------------------------------------------------

  void newChat({String? projectId}) {
    _ui.newChat(projectId: projectId);
    _focusAfterFrame(ref.read(composerInputsProvider).focus);
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
  Future<bool> _confirmDelete(String title, String message) =>
      _confirm(title, message, _l.delete);

  /// Asks before something that cannot be undone; [action] names it on the button that does it.
  Future<bool> _confirm(String title, String message, String action) async {
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
            child: Text(action),
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
      debugPrint('Daylex export: $e');
      toast(_l.exportFailed(describePdfFailure(_l, e)));
    }
  }

  /// Splits the pages of a document too long for the PDF into consecutive pages, as one undo step.
  Future<void> fitPages(String documentId) async {
    final doc = ref.read(workspaceProvider).documents[documentId];
    if (doc == null) return;
    final fit = await ref.read(pageFitProvider)(doc);
    if (!identical(ref.read(workspaceProvider).documents[documentId], doc)) {
      return toast(_l.pdfFitChanged);
    }
    if (fit.changed) {
      _workspace.apply(
        fit.operations,
        documentId: documentId,
        label: _l.pdfSplitPages,
      );
    }
    toast(
      fit.overflowing.isNotEmpty
          ? _l.pdfBlockTooLarge
          : _l.pdfPagesSplit(fit.document.pages.length),
    );
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

  /// Closes the tab in front: the web tab the panel shows, or the chat's own.
  void closeActiveTab() {
    final web = ref.read(visibleWebTabProvider);
    if (web != null) return closeWebTab(web.id);
    final tab = ref.read(workspaceProvider).activeThread?.activeTab;
    if (tab != null) _workspace.closeTab(tab);
  }

  /// The next tab of the strip ([step] 1) or the one before (-1), round: the chat's tabs, then the web tabs.
  void cycleTab(int step) {
    final thread = ref.read(activeThreadProvider);
    final strip = <Object>[...?thread?.tabs, ...ref.read(browserProvider).tabs];
    if (strip.isEmpty) return;
    final web = ref.read(shownWebTabProvider);
    final at = web != null
        ? strip.indexWhere((t) => t is WebTab && t.id == web.id)
        : thread?.activeTab == null
        ? -1
        : strip.indexOf(thread!.activeTab!);
    switch (strip[(at + step) % strip.length]) {
      case final WebTab t:
        showWebTab(t.id);
      case final PanelTab t:
        _workspace.activateTab(t);
        _ui.showPanel();
    }
  }

  // -- browser ----------------------------------------------------------------------

  BrowserNotifier get _browser => ref.read(browserProvider.notifier);

  /// Runs [onPage] on the web page in front of the lawyer, or [otherwise] when the panel shows no web tab. A web
  /// tab still on its portals has no page: nothing happens.
  void _onPage(void Function(BrowserPage page) onPage, {required VoidCallback otherwise}) {
    final tab = ref.read(visibleWebTabProvider);
    if (tab == null) return otherwise();
    final page = ref.read(livePagesProvider).pageOf(tab.id);
    if (page != null) onPage(page);
  }

  /// A new web tab on [url], right after [after] when given; without an address it opens on the portals, with
  /// the keyboard in its address bar.
  void openWebTab({Uri? url, String? after}) {
    _browser.open(url: url?.toString(), after: after);
    _showActiveWebTab(address: url == null);
  }

  /// The web tabs as the lawyer left them, or a new one when there is none.
  void showBrowser() {
    final active = ref.read(browserProvider).active;
    active == null ? openWebTab() : showWebTab(active.id);
  }

  void showWebTab(String id) {
    _browser.activate(id);
    _showActiveWebTab();
  }

  void closeWebTab(String id) {
    final shown = ref.read(visibleWebTabProvider)?.id == id;
    _browser.close(id);
    if (shown) _keyboardToActiveWebTab();
  }

  void reopenWebTab() {
    if (!_browser.reopenClosed()) return;
    _showActiveWebTab();
  }

  /// The web tab in front shown in the panel, the keyboard in it; [address] puts it in its address bar.
  void _showActiveWebTab({bool address = false}) {
    _ui
      ..show(AppSection.chat)
      ..showPanel();
    _keyboardToActiveWebTab(address: address);
  }

  /// The keyboard follows the web tab brought forward, as in a browser: into its page, or into its address bar
  /// while it is on the portals or with [address]. Not while the lawyer writes in a field of the app: the chat is
  /// written with a page read beside it.
  void _keyboardToActiveWebTab({bool address = false}) {
    final tab = ref.read(browserProvider).active;
    final bar = ref.read(addressFocusProvider);
    if (tab == null) return;
    if (address) return _focusAfterFrame(bar);
    if (_writingInApp(bar)) return;
    if (tab.url == null) return _focusAfterFrame(bar);
    bar.unfocus();
    final pages = ref.read(livePagesProvider);
    WidgetsBinding.instance.addPostFrameCallback((_) => pages.pageOf(tab.id)?.focus());
  }

  /// A text field of the app other than the address [bar] has the keyboard.
  static bool _writingInApp(FocusNode bar) {
    final node = FocusManager.instance.primaryFocus;
    final context = node == bar ? null : node?.context;
    return context != null && context.mounted && context.findAncestorStateOfType<EditableTextState>() != null;
  }

  /// The keyboard in the address bar, the web tabs shown first if they were not.
  void focusAddress() {
    final focus = ref.read(addressFocusProvider);
    if (ref.read(visibleWebTabProvider) != null) return focus.requestFocus();
    showBrowser();
    _focusAfterFrame(focus);
  }

  /// What the lawyer typed in the address bar of tab [id], or a portal picked there: a web page opens in the tab,
  /// mail and phone in the system's own app, anything else not at all.
  Future<void> openAddress(String id, String input) async {
    final uri = addressFor(input);
    if (uri == null) return;
    if (navigationFor(uri) != Navigation.web) return openNotWeb(uri);
    _browser.go(id, uri.toString());
    // Where this computer shows no page, the address opens outside; the tab keeps it.
    if (ref.read(browserSupportProvider).value != BrowserSupport.embedded) return openOutside(uri);
    // A live page goes there now; a tab without one starts on the new address.
    await ref.read(livePagesProvider).pageOf(id)?.load(uri);
  }

  /// An address no tab shows, typed in the bar or clicked in a page: mail and phone in the system's own app,
  /// anything else not at all.
  Future<void> openNotWeb(Uri uri) async {
    if (navigationFor(uri) == Navigation.system) return openOutside(uri);
    toast(_l.browserRefused);
  }

  /// [uri] in the system browser, or the system's app for mail and phone.
  Future<void> openOutside(Uri uri) async {
    final context = navigatorKey.currentContext;
    if (context != null) await openWebLink(context, uri);
  }

  /// The page of tab [id] in the chat's attachments (rfc/052 §7): a PDF as it is, any other page as HTML that
  /// says where and when it was taken. The open chat gets it, or the new chat being written.
  Future<void> attachPage(String id) async {
    final page = ref.read(livePagesProvider).pageOf(id);
    if (page == null) return;
    final attach = _attacher();
    final l = _l;
    final at = DateTime.now();
    final String path;
    try {
      final file = pageFile(await page.capture(), at, note: l.browserCaptureNote(longDate(l, at), clockTime(at)));
      path = await savePageFile(file);
    } on Object catch (e) {
      debugPrint('Daylex browser: page not attached: $e');
      return toast(l.browserAttachFailed);
    }
    await attach(path);
  }

  /// Signs the lawyer out of every portal once confirmed: the sign-ins the web tabs kept go (rfc/052 §3).
  Future<void> signOutOfPortals() async {
    final pages = ref.read(livePagesProvider);
    final l = _l;
    final ok = await _confirm(
      l.settingsBrowserSignOutConfirmTitle,
      l.settingsBrowserSignOutConfirmMessage,
      l.settingsBrowserSignOutButton,
    );
    if (!ok) return;
    try {
      await pages.clearData();
    } on Object catch (e) {
      debugPrint('Daylex browser: sign-out failed: $e');
      return toast(l.settingsBrowserSignOutFailed);
    }
    toast(l.settingsBrowserSignedOut);
  }

  /// A file on disk (a page kept, a download) in the chat's attachments, as if dropped on the window.
  Future<void> attachFile(String path) => _attacher()(path);

  /// Attaches a file to the chat in front now, even once it is ready later: what that needs is read here, as the
  /// tab that asked may close while its page is taken.
  Future<void> Function(String path) _attacher() {
    final l = _l;
    final threadId = ref.read(workspaceProvider).activeThreadId ?? AgentController.draftId;
    final agent = ref.read(agentProvider.notifier);
    return (path) async {
      final left = await agent.addFiles(threadId, [XFile(path)]);
      if (!left.isEmpty) return showLeftOut(messengerKey.currentState, l, left);
      toast(l.browserAttached(path.split(RegExp(r'[\\/]')).last));
    };
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
