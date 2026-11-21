import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/platform/files.dart';
import '../../core/theme/app_theme.dart';
import '../../features/browser/browser_state.dart';
import '../../features/browser/engine/engine.dart';
import '../../features/browser/web_address.dart';
import '../../l10n/l10n.dart';
import '../app_actions.dart';
import '../common/copy_feedback.dart';
import '../common/widgets.dart';
import '../shortcuts.dart';
import 'address_bar.dart';
import 'browser_host.dart';
import 'new_tab_page.dart';
import 'portal_dialog.dart';

/// Where Microsoft gives the WebView2 runtime away.
final _webView2Download = Uri.https('developer.microsoft.com', '/microsoft-edge/webview2/');

/// A web tab in the side panel (rfc/052 §5): the page under a browser's bar, or the portals while it has no
/// address. Where this computer cannot show pages, each address opens in the system browser instead.
class WebTabView extends ConsumerWidget {
  const WebTabView({super.key, required this.tab});

  final WebTab tab;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final support = ref.watch(browserSupportProvider).value;
    if (support == BrowserSupport.embedded) return _EmbeddedTab(tab: tab);
    final l = context.l10n;
    final actions = AppActions(ref);
    final url = Uri.tryParse(tab.url ?? '');
    final notice = switch (support) {
      BrowserSupport.missingRuntime => _Notice(
        icon: LucideIcons.triangleAlert,
        title: l.browserRuntimeTitle,
        message: l.browserRuntimeMessage,
        action: FilledButton.icon(
          onPressed: () => actions.openOutside(_webView2Download),
          icon: const Icon(LucideIcons.download, size: 14),
          label: Text(l.browserRuntimeDownload),
        ),
      ),
      BrowserSupport.external => _Notice(
        icon: LucideIcons.externalLink,
        title: l.browserExternalTitle,
        message: l.browserExternalMessage,
      ),
      _ => null,
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Toolbar(tab: tab, page: null, state: null, outside: support == BrowserSupport.external),
        const Divider(),
        Expanded(
          child: support == null
              ? const SizedBox.shrink()
              : url == null || !url.hasScheme
              ? NewTabPage(tabId: tab.id, notice: notice)
              : ListView(
                  padding: const EdgeInsets.all(24),
                  children: [
                    ?notice,
                    const SizedBox(height: 16),
                    Center(
                      child: FilledButton.icon(
                        onPressed: () => actions.openOutside(url),
                        icon: const Icon(LucideIcons.externalLink, size: 14),
                        label: Text(l.browserOpenOutside),
                      ),
                    ),
                  ],
                ),
        ),
      ],
    );
  }
}

/// A tab drawn by the engine.
class _EmbeddedTab extends ConsumerStatefulWidget {
  const _EmbeddedTab({required this.tab});

  final WebTab tab;

  @override
  ConsumerState<_EmbeddedTab> createState() => _EmbeddedTabState();
}

class _EmbeddedTabState extends ConsumerState<_EmbeddedTab> {
  BrowserPage? _page;
  StreamSubscription<PageEvent>? _events;

  /// The download the lawyer closed the bar of.
  String? _dismissed;

  @override
  void dispose() {
    unawaited(_events?.cancel());
    super.dispose();
  }

  /// Listens to what [page] asks of the app while it is the one shown.
  void _listen(BrowserPage page) {
    if (identical(page, _page)) return;
    _page = page;
    unawaited(_events?.cancel());
    _events = page.events.listen((event) {
      if (!mounted) return;
      final actions = AppActions(ref);
      switch (event) {
        case OpenInNewTab(:final uri):
          if (navigationFor(uri) == Navigation.web) actions.openWebTab(url: uri, after: widget.tab.id);
        case OpenOutside(:final uri):
          unawaited(actions.openNotWeb(uri));
        case PageKey(:final combo):
          final shortcut = shortcutFor(combo);
          if (shortcut != null) actions.forShortcut(shortcut)?.call();
        case PageZoom(:final step):
          unawaited(page.setZoom(zoomStep(page.state.value.zoom, step)));
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final tab = widget.tab;
    if (tab.url == null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _Toolbar(tab: tab, page: null, state: null),
          const Divider(),
          Expanded(child: NewTabPage(tabId: tab.id)),
        ],
      );
    }
    final page = ref.read(livePagesProvider).pageFor(tab);
    _listen(page);
    return ValueListenableBuilder<PageState>(
      valueListenable: page.state,
      builder: (context, state, _) {
        final download = state.download != _dismissed ? state.download : null;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _Toolbar(tab: tab, page: page, state: state),
            _LoadingLine(loading: state.loading && state.problem == null),
            Expanded(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  page.view(),
                  if (state.problem case final problem?)
                    _ProblemPanel(
                      tabId: tab.id,
                      problem: problem,
                      page: page,
                      url: state.url ?? Uri.parse(tab.url!),
                    ),
                ],
              ),
            ),
            if (download != null)
              _DownloadBar(path: download, onClose: () => setState(() => _dismissed = download)),
          ],
        );
      },
    );
  }
}

class _Toolbar extends ConsumerStatefulWidget {
  const _Toolbar({required this.tab, required this.page, required this.state, this.outside = false});

  final WebTab tab;

  /// Null on the portals, or where pages open outside.
  final BrowserPage? page;
  final PageState? state;

  /// Every page of this computer opens in the system browser: no tab here ever goes back, reloads or has a page
  /// to attach, so the bar shows none of those (without WebView2 they stay, disabled, until it is installed).
  final bool outside;

  @override
  ConsumerState<_Toolbar> createState() => _ToolbarState();
}

class _ToolbarState extends ConsumerState<_Toolbar> {
  /// Narrower than this, «Allega» is an icon.
  static const _compactWidth = 460.0;

  var _attaching = false;

  Future<void> _attach() async {
    setState(() => _attaching = true);
    try {
      await AppActions(ref).attachPage(widget.tab.id);
    } finally {
      if (mounted) setState(() => _attaching = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final actions = AppActions(ref);
    final page = widget.page;
    final state = widget.state;
    final url = state?.url ?? Uri.tryParse(widget.tab.url ?? '');
    final web = url != null && navigationFor(url) == Navigation.web;
    final canAttach = page != null && web && state?.problem == null && !_attaching;

    return LayoutBuilder(
      builder: (context, c) {
        final compact = c.maxWidth < _compactWidth;
        return PanelToolbar(
          children: [
            if (!widget.outside) ...[
              ToolbarButton(
                icon: LucideIcons.arrowLeft,
                tooltip: l.browserBack,
                shortcut: AppShortcut.previousPage,
                onPressed: state?.canGoBack ?? false ? page!.back : null,
              ),
              ToolbarButton(
                icon: LucideIcons.arrowRight,
                tooltip: l.browserForward,
                shortcut: AppShortcut.nextPage,
                onPressed: state?.canGoForward ?? false ? page!.forward : null,
              ),
              if (state?.loading ?? false)
                ToolbarButton(icon: LucideIcons.x, tooltip: l.browserStop, onPressed: page!.stop)
              else
                ToolbarButton(
                  icon: LucideIcons.rotateCw,
                  tooltip: l.browserReload,
                  shortcut: AppShortcut.reload,
                  onPressed: page?.reload,
                ),
              const SizedBox(width: 4),
            ],
            Expanded(
              child: AddressBar(tabId: widget.tab.id, url: web || url == null ? url : null, problem: state?.problem),
            ),
            const SizedBox(width: 6),
            if (!widget.outside) ...[
              if (compact)
                ToolbarButton(
                  icon: _attaching ? LucideIcons.loaderCircle : LucideIcons.paperclip,
                  tooltip: l.browserAttachHelp,
                  onPressed: canAttach ? _attach : null,
                )
              else
                Tooltip(
                  message: l.browserAttachHelp,
                  child: FilledButton.icon(
                    onPressed: canAttach ? _attach : null,
                    style: FilledButton.styleFrom(visualDensity: VisualDensity.compact),
                    icon: _attaching
                        ? const SizedBox.square(dimension: 14, child: CircularProgressIndicator(strokeWidth: 1.6))
                        : const Icon(LucideIcons.paperclip, size: 14),
                    label: Text(l.browserAttachShort),
                  ),
                ),
              const SizedBox(width: 2),
            ],
            ToolbarButton(
              icon: LucideIcons.externalLink,
              tooltip: l.browserOpenOutsideHelp,
              onPressed: web ? () => actions.openOutside(url) : null,
            ),
            _MoreMenu(tab: widget.tab, page: page, url: web ? url : null, zoom: state?.zoom),
          ],
        );
      },
    );
  }
}

/// The tab's menu: the address, the portals, the zoom, closing.
class _MoreMenu extends ConsumerWidget {
  const _MoreMenu({required this.tab, required this.page, required this.url, required this.zoom});

  final WebTab tab;
  final BrowserPage? page;
  final Uri? url;
  final double? zoom;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final actions = AppActions(ref);
    final tokens = AppTokens.of(context);
    final text = Theme.of(context).textTheme;
    final url = this.url, page = this.page, zoom = this.zoom;

    return MenuAnchor(
      alignmentOffset: const Offset(-200, 4),
      menuChildren: [
        MenuItemButton(
          leadingIcon: const Icon(LucideIcons.copy, size: 15),
          onPressed: url == null
              ? null
              : () async {
                  await copyText(url.toString());
                  toast(l.browserAddressCopied);
                },
          child: Text(l.browserCopyAddress),
        ),
        MenuItemButton(
          leadingIcon: const Icon(LucideIcons.bookmarkPlus, size: 15),
          onPressed: url == null ? null : () => addPortalFromPage(ref, url: url, title: tab.title),
          child: Text(l.browserAddPortal),
        ),
        if (page != null && zoom != null) ...[
          const Divider(height: 8),
          // The zoom stays open while it is stepped, as in a browser's menu.
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 2, 6, 2),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(LucideIcons.zoomIn, size: 15, color: tokens.textMuted),
                const SizedBox(width: 12),
                SizedBox(
                  width: 96,
                  child: Text(l.browserZoom((zoom * 100).round()), style: text.bodyMedium),
                ),
                ToolbarButton(
                  icon: LucideIcons.minus,
                  tooltip: AppShortcut.zoomOut.label(l),
                  shortcut: AppShortcut.zoomOut,
                  size: 28,
                  onPressed: zoom <= zoomSteps.first ? null : () => page.setZoom(zoomStep(zoom, -1)),
                ),
                ToolbarButton(
                  icon: LucideIcons.plus,
                  tooltip: AppShortcut.zoomIn.label(l),
                  shortcut: AppShortcut.zoomIn,
                  size: 28,
                  onPressed: zoom >= zoomSteps.last ? null : () => page.setZoom(zoomStep(zoom, 1)),
                ),
                ToolbarButton(
                  icon: LucideIcons.rotateCcw,
                  tooltip: AppShortcut.zoomReset.label(l),
                  shortcut: AppShortcut.zoomReset,
                  size: 28,
                  onPressed: zoom == 1 ? null : () => page.setZoom(1),
                ),
              ],
            ),
          ),
        ],
        const Divider(height: 8),
        MenuItemButton(
          leadingIcon: const Icon(LucideIcons.x, size: 15),
          shortcut: AppShortcut.closeTab.primary,
          onPressed: () => actions.closeWebTab(tab.id),
          child: Text(l.shortcutCloseTab),
        ),
      ],
      builder: (context, controller, _) => ToolbarButton(
        icon: LucideIcons.ellipsis,
        tooltip: l.browserMore,
        onPressed: () => controller.isOpen ? controller.close() : controller.open(),
      ),
    );
  }
}

/// Asks the name of the page at [url] as a portal, then adds it.
Future<void> addPortalFromPage(WidgetRef ref, {required Uri url, required String title}) async {
  final context = navigatorKey.currentContext;
  if (context == null) return;
  final l = context.l10n;
  final browser = ref.read(browserProvider.notifier);
  final portal = await showPortalDialog(context, name: title, url: url.toString());
  if (portal == null) return;
  browser.addPortal(portal.name, portal.url);
  toast(l.browserPortalAdded(portal.name.trim().isEmpty ? displayHost(url) : portal.name.trim()));
}

/// A thin line under the bar while the page loads; nothing for a page that answers at once.
class _LoadingLine extends StatefulWidget {
  const _LoadingLine({required this.loading});

  final bool loading;

  /// A page that loads faster than this shows no line at all.
  static const delay = Duration(milliseconds: 150);

  @override
  State<_LoadingLine> createState() => _LoadingLineState();
}

class _LoadingLineState extends State<_LoadingLine> {
  Timer? _timer;
  var _shown = false;

  @override
  void initState() {
    super.initState();
    _follow();
  }

  @override
  void didUpdateWidget(_LoadingLine old) {
    super.didUpdateWidget(old);
    if (old.loading != widget.loading) _follow();
  }

  void _follow() {
    _timer?.cancel();
    if (!widget.loading) {
      if (_shown) setState(() => _shown = false);
      return;
    }
    _timer = Timer(_LoadingLine.delay, () {
      if (mounted) setState(() => _shown = true);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SizedBox(
    height: 2,
    child: _shown
        ? LinearProgressIndicator(minHeight: 2, backgroundColor: AppTokens.of(context).border)
        : ColoredBox(color: AppTokens.of(context).border),
  );
}

/// Why the page is not there, and what the lawyer can do: its site's "www." address when the bare domain did not
/// answer, as a browser suggests; try again; or open it outside.
class _ProblemPanel extends ConsumerWidget {
  const _ProblemPanel({required this.tabId, required this.problem, required this.page, required this.url});

  final String tabId;
  final PageProblem problem;
  final BrowserPage page;
  final Uri url;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final actions = AppActions(ref);
    final (icon, title, message) = switch (problem) {
      PageProblem.unreachable => (
        LucideIcons.wifiOff,
        l.browserProblemUnreachableTitle,
        l.browserProblemUnreachableMessage,
      ),
      PageProblem.timeout => (LucideIcons.clock, l.browserProblemTimeoutTitle, l.browserProblemTimeoutMessage),
      PageProblem.certificate => (
        LucideIcons.shieldAlert,
        l.browserProblemCertificateTitle,
        l.browserProblemCertificateMessage,
      ),
      PageProblem.engine => (LucideIcons.triangleAlert, l.browserProblemEngineTitle, l.browserProblemEngineMessage),
      PageProblem.other => (LucideIcons.circleAlert, l.browserProblemOtherTitle, l.browserProblemOtherMessage),
    };
    final www = problem == PageProblem.unreachable ? wwwAlternative(url) : null;
    const retryIcon = Icon(LucideIcons.rotateCw, size: 14);
    final retryLabel = Text(l.browserRetry);
    return ColoredBox(
      color: Theme.of(context).colorScheme.surface,
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: EmptyState(
          icon: icon,
          title: title,
          message: message,
          actions: [
            // The likeliest way out goes first, and is the one the keyboard is on.
            if (www != null)
              FilledButton.icon(
                autofocus: true,
                onPressed: () => actions.openAddress(tabId, www.toString()),
                icon: const Icon(LucideIcons.arrowRight, size: 14),
                label: Text(l.browserOpenWww(www.host)),
              ),
            if (problem != PageProblem.engine)
              if (www == null)
                FilledButton.icon(autofocus: true, onPressed: page.reload, icon: retryIcon, label: retryLabel)
              else
                OutlinedButton.icon(onPressed: page.reload, icon: retryIcon, label: retryLabel),
            // A certificate that is not valid is never opened anywhere from here.
            if (problem != PageProblem.certificate)
              OutlinedButton.icon(
                onPressed: () => actions.openOutside(url),
                icon: const Icon(LucideIcons.externalLink, size: 14),
                label: Text(l.browserOpenOutside),
              ),
          ],
        ),
      ),
    );
  }
}

/// The file the page saved last: into the chat, or shown in its folder.
class _DownloadBar extends ConsumerWidget {
  const _DownloadBar({required this.path, required this.onClose});

  final String path;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final tokens = AppTokens.of(context);
    final text = Theme.of(context).textTheme;
    final name = path.split(RegExp(r'[\\/]')).last;
    return Container(
      height: AppTheme.toolbarHeight,
      padding: const EdgeInsets.only(left: 12, right: 6),
      decoration: BoxDecoration(
        color: tokens.panel,
        border: Border(top: BorderSide(color: tokens.border)),
      ),
      child: Row(
        children: [
          Icon(LucideIcons.circleCheck, size: 15, color: tokens.success),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              l.browserDownloaded(name),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: text.bodyMedium,
            ),
          ),
          const SizedBox(width: 8),
          FilledButton.icon(
            onPressed: () => AppActions(ref).attachFile(path),
            style: FilledButton.styleFrom(visualDensity: VisualDensity.compact),
            icon: const Icon(LucideIcons.paperclip, size: 14),
            label: Text(l.browserAttach),
          ),
          const SizedBox(width: 4),
          TextButton(onPressed: () => revealFile(path), child: Text(l.browserShowInFolder)),
          ToolbarButton(icon: LucideIcons.x, tooltip: l.close, onPressed: onClose),
        ],
      ),
    );
  }
}

/// Why pages open outside on this computer, and the way out when there is one.
class _Notice extends StatelessWidget {
  const _Notice({required this.icon, required this.title, required this.message, this.action});

  final IconData icon;
  final String title;
  final String message;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final tokens = AppTokens.of(context);
    final text = Theme.of(context).textTheme;
    return OutlinedBox(
      radius: AppTheme.radiusLg,
      padding: const EdgeInsets.all(16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: tokens.textMuted),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: text.titleSmall),
                const SizedBox(height: 4),
                Text(message, style: text.bodySmall),
                if (action != null) ...[const SizedBox(height: 12), action!],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
