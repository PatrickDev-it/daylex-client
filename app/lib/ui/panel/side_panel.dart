import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/theme/app_theme.dart';
import '../../features/agent/agent_controller.dart';
import '../../features/browser/browser_state.dart';
import '../../features/browser/engine/engine.dart';
import '../../features/browser/web_address.dart';
import '../../features/workspace/chat_thread.dart';
import '../../features/workspace/ui_state.dart';
import '../../features/workspace/workspace_state.dart';
import '../../l10n/l10n.dart';
import '../app_actions.dart';
import '../browser/browser_host.dart';
import '../browser/web_tab_view.dart';
import '../common/widgets.dart';
import '../shortcuts.dart';
import 'library_tab.dart';
import 'log_tab.dart';
import 'panel_tab_specs.dart';
import 'preview_tab.dart';
import 'review_tab.dart';
import 'source_tab.dart';
import '../../features/agent/domain/source_reference.dart';

/// Right column: what the agent is working on, as browser-like tabs — the
/// live document preview, the review of its changes, the library and the
/// raw agent log — then the web tabs every chat shares (rfc/052).
class SidePanel extends ConsumerWidget {
  const SidePanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final thread = ref.watch(activeThreadProvider);
    final web = ref.watch(shownWebTabProvider);
    final tokens = AppTokens.of(context);

    return ColoredBox(
      color: tokens.panel,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _TabStrip(thread: thread, web: web),
          const Divider(),
          Expanded(
            child: ColoredBox(
              color: Theme.of(context).colorScheme.surface,
              child: switch (thread?.activeTab) {
                _ when web != null => WebTabView(
                  key: ValueKey(web.id),
                  tab: web,
                ),
                null => _NoTab(thread: thread),
                PanelTab(kind: PanelTabKind.preview) => const PreviewTab(),
                PanelTab(
                  kind: PanelTabKind.source,
                  :final documentId,
                  :final sourcePage,
                  :final sourceQuote,
                  :final sourceId,
                ) =>
                  SourceTab(
                    threadId: thread!.id,
                    name: documentId!,
                    page: sourcePage,
                    quote: sourceQuote,
                    sourceId: sourceId,
                  ),
                PanelTab(kind: PanelTabKind.review) => ReviewTab(
                  threadId: thread!.id,
                ),
                PanelTab(kind: PanelTabKind.library) => const LibraryTab(),
                PanelTab(kind: PanelTabKind.log) => LogTab(
                  threadId: thread!.id,
                ),
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _TabStrip extends ConsumerWidget {
  const _TabStrip({required this.thread, required this.web});

  final ChatThread? thread;

  /// The web tab in front, if one is: then no chat tab is.
  final WebTab? web;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ws = ref.watch(workspaceProvider);
    final webTabs = ref.watch(browserProvider.select((s) => s.tabs));
    final full = ref.watch(uiProvider.select((s) => s.panelFull));
    final fits = ref.watch(uiProvider.select((s) => s.panelFits));
    final turns = thread == null
        ? 0
        : ref.watch(
            sessionProvider(
              thread!.id,
            ).select((s) => s.turns.where((t) => t.changes.isNotEmpty).length),
          );
    final tabs = thread?.tabs ?? const <PanelTab>[];
    final tokens = AppTokens.of(context);
    final actions = AppActions(ref);
    final l = context.l10n;

    String label(PanelTab tab) => switch (tab.kind) {
      PanelTabKind.preview =>
        ws.documents[tab.documentId]?.title ?? l.tabDocument,
      PanelTabKind.source => SourceReference(
        tab.documentId!,
        tab.sourcePage,
      ).title,
      PanelTabKind.review => turns == 0 ? l.tabReview : l.tabReviewCount(turns),
      PanelTabKind.library || PanelTabKind.log => tab.kind.name(l),
    };

    Color iconColor(PanelTab tab) {
      final doc = tab.kind == PanelTabKind.preview
          ? ws.documents[tab.documentId]
          : null;
      return doc != null ? Color(doc.theme.accent) : tokens.textMuted;
    }

    return SizedBox(
      height: AppTheme.tabStripHeight,
      child: Row(
        children: [
          const SizedBox(width: 6),
          Expanded(
            child: LayoutBuilder(
              builder: (context, c) {
                // Browser behaviour: tabs shrink to share the strip.
                final count = tabs.length + webTabs.length;
                final width = count == 0 ? 0.0 : (c.maxWidth - 36) / count;
                final tabWidth = width.clamp(90.0, 220.0);
                return Row(
                  children: [
                    Flexible(
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            for (final tab in tabs)
                              _Tab(
                                width: tabWidth,
                                leading: Icon(
                                  tab.kind.icon,
                                  size: 13,
                                  color: iconColor(tab),
                                ),
                                label: label(tab),
                                active: web == null && tab == thread?.activeTab,
                                onTap: () => ref
                                    .read(workspaceProvider.notifier)
                                    .activateTab(tab),
                                onClose: () => ref
                                    .read(workspaceProvider.notifier)
                                    .closeTab(tab),
                              ),
                            // The chat's own tabs, then the web tabs every chat shares.
                            if (tabs.isNotEmpty && webTabs.isNotEmpty)
                              Container(
                                width: 1,
                                height: 18,
                                margin: const EdgeInsets.only(left: 4, right: 6),
                                color: tokens.border,
                              ),
                            for (final tab in webTabs)
                              _Tab(
                                width: tabWidth,
                                leading: _WebTabIcon(tab: tab),
                                label: webTabLabel(l, tab),
                                tooltip: tab.url,
                                active: tab.id == web?.id,
                                onTap: () => actions.showWebTab(tab.id),
                                onClose: () => actions.closeWebTab(tab.id),
                              ),
                          ],
                        ),
                      ),
                    ),
                    _AddTabButton(thread: thread, web: web),
                  ],
                );
              },
            ),
          ),
          // Without room beside the chat there is only the full width.
          if (fits)
            ToolbarButton(
              icon: full ? LucideIcons.minimize2 : LucideIcons.maximize2,
              tooltip: full ? l.panelSplit : l.panelFull,
              shortcut: AppShortcut.fullPanel,
              onPressed: ref.read(uiProvider.notifier).toggleFullPanel,
            ),
          ToolbarButton(
            icon: LucideIcons.panelRightClose,
            tooltip: l.panelHide,
            shortcut: AppShortcut.togglePanel,
            onPressed: ref.read(uiProvider.notifier).togglePanel,
          ),
          const SizedBox(width: 4),
        ],
      ),
    );
  }
}

/// What a web tab is called in the strip: the page's title, its site while
/// it has none, "Nuova scheda" on the portals.
String webTabLabel(AppLocalizations l, WebTab tab) {
  if (tab.title.trim().isNotEmpty) return tab.title.trim();
  final url = Uri.tryParse(tab.url ?? '');
  return url == null || url.host.isEmpty ? l.browserNewTab : displayHost(url);
}

/// The page's icon, a spinner while it loads, a globe without either.
class _WebTabIcon extends ConsumerWidget {
  const _WebTabIcon({required this.tab});

  final WebTab tab;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = AppTokens.of(context);
    final globe = Icon(LucideIcons.globe, size: 13, color: tokens.textMuted);
    final icon = Uri.tryParse(tab.icon ?? '');
    final Widget still = icon != null && navigationFor(icon) == Navigation.web
        ? Image.network(
            icon.toString(),
            width: 14,
            height: 14,
            cacheWidth: 32,
            errorBuilder: (_, _, _) => globe,
          )
        : globe;
    final page = ref.watch(livePagesProvider).pageOf(tab.id);
    if (page == null) return still;
    return ValueListenableBuilder<PageState>(
      valueListenable: page.state,
      builder: (context, state, _) => state.loading
          ? const SizedBox.square(
              dimension: 13,
              child: CircularProgressIndicator(strokeWidth: 1.5),
            )
          : still,
    );
  }
}

class _Tab extends StatefulWidget {
  const _Tab({
    required this.width,
    required this.leading,
    required this.label,
    required this.active,
    required this.onTap,
    required this.onClose,
    this.tooltip,
  });

  final double width;
  final Widget leading;
  final String label;

  /// More than the label holds: a web tab's address.
  final String? tooltip;
  final bool active;
  final VoidCallback onTap;
  final VoidCallback onClose;

  @override
  State<_Tab> createState() => _TabState();
}

class _TabState extends State<_Tab> {
  @override
  void initState() {
    super.initState();
    if (widget.active) _reveal();
  }

  @override
  void didUpdateWidget(_Tab old) {
    super.didUpdateWidget(old);
    if (widget.active && !old.active) _reveal();
  }

  /// A tab brought in front past either end of a full strip scrolls into view.
  void _reveal() => WidgetsBinding.instance.addPostFrameCallback((_) {
    if (!mounted) return;
    for (final policy in [
      ScrollPositionAlignmentPolicy.keepVisibleAtEnd,
      ScrollPositionAlignmentPolicy.keepVisibleAtStart,
    ]) {
      Scrollable.ensureVisible(
        context,
        duration: AppTheme.fast,
        alignmentPolicy: policy,
      );
    }
  });

  @override
  Widget build(BuildContext context) {
    final tokens = AppTokens.of(context);
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final active = widget.active;
    final tab = HoverBuilder(
      builder: (context, hover) => GestureDetector(
        onTap: widget.onTap,
        onTertiaryTapUp: (_) => widget.onClose(),
        child: Container(
          width: widget.width,
          height: 32,
          margin: const EdgeInsets.only(right: 2, top: 5, bottom: 5),
          padding: const EdgeInsets.only(left: 10, right: 4),
          decoration: BoxDecoration(
            color: active
                ? scheme.surface
                : hover
                ? tokens.hover
                : Colors.transparent,
            borderRadius: BorderRadius.circular(AppTheme.radius),
            border: Border.all(
              color: active ? tokens.border : Colors.transparent,
            ),
          ),
          child: Row(
            children: [
              widget.leading,
              const SizedBox(width: 7),
              Expanded(
                child: Text(
                  widget.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: text.labelMedium?.copyWith(
                    color: active ? scheme.onSurface : tokens.textMuted,
                    fontWeight: active ? FontWeight.w600 : FontWeight.w500,
                  ),
                ),
              ),
              Opacity(
                opacity: active || hover ? 1 : 0,
                child: InkWell(
                  borderRadius: BorderRadius.circular(AppTheme.radiusXs),
                  onTap: widget.onClose,
                  child: Padding(
                    padding: const EdgeInsets.all(3),
                    child: Icon(
                      LucideIcons.x,
                      size: 12,
                      color: tokens.textFaint,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    final more = widget.tooltip;
    return more == null
        ? tab
        : Tooltip(message: '${widget.label}\n$more', child: tab);
  }
}

class _AddTabButton extends ConsumerWidget {
  const _AddTabButton({required this.thread, required this.web});

  final ChatThread? thread;
  final WebTab? web;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ws = ref.watch(workspaceProvider);
    final portals = ref.watch(browserProvider.select((s) => s.portals));
    final actions = AppActions(ref);
    final thread = this.thread;
    final docs = thread == null ? const [] : ws.documentsIn(thread.projectId);
    final l = context.l10n;
    return MenuAnchor(
      alignmentOffset: const Offset(-180, 4),
      menuChildren: [
        if (thread != null) ...[
          for (final kind in PanelTabKind.values.where(
            (k) => k.shortcut != null,
          ))
            MenuItemButton(
              leadingIcon: Icon(kind.icon, size: 15),
              // Ctrl+R reloads while a web page is in front: the hint would promise the review.
              shortcut: kind == PanelTabKind.review && web != null
                  ? null
                  : kind.shortcut!.primary,
              // The preview item opens the chat's own document, as before; the shortcut previews the active one.
              onPressed: switch (kind) {
                PanelTabKind.preview =>
                  thread.documentId == null
                      ? null
                      : () => actions.openTab(
                          PanelTab.preview(thread.documentId!),
                        ),
                PanelTabKind.review => actions.openReview,
                _ => actions.forShortcut(kind.shortcut!),
              },
              child: Text(
                kind == PanelTabKind.review ? l.reviewChanges : kind.name(l),
              ),
            ),
          if (docs.length > 1) ...[
            const Divider(height: 8),
            for (final d in docs)
              MenuItemButton(
                leadingIcon: Icon(
                  PanelTabKind.preview.icon,
                  size: 15,
                  color: Color(d.theme.accent),
                ),
                onPressed: () => actions.openDocument(d.id),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 220),
                  child: Text(d.title, overflow: TextOverflow.ellipsis),
                ),
              ),
          ],
          const Divider(height: 8),
        ],
        MenuItemButton(
          leadingIcon: const Icon(LucideIcons.globe, size: 15),
          shortcut: AppShortcut.newWebTab.primary,
          onPressed: actions.openWebTab,
          child: Text(l.shortcutNewWebTab),
        ),
        if (portals.isNotEmpty)
          _ClickSafeSubmenu(
            leadingIcon: const Icon(LucideIcons.bookmark, size: 15),
            menuChildren: [
              for (final p in portals)
                MenuItemButton(
                  onPressed: () =>
                      actions.openWebTab(url: Uri.tryParse(p.url)),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 240),
                    child: Text(p.name, overflow: TextOverflow.ellipsis),
                  ),
                ),
            ],
            child: Text(l.browserPortalsMenu),
          ),
      ],
      builder: (context, controller, _) => ToolbarButton(
        icon: LucideIcons.plus,
        tooltip: l.panelOpenTab,
        onPressed: () =>
            controller.isOpen ? controller.close() : controller.open(),
      ),
    );
  }
}

class _NoTab extends ConsumerWidget {
  const _NoTab({required this.thread});

  final ChatThread? thread;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final actions = AppActions(ref);
    final l = context.l10n;
    final browser = OutlinedButton.icon(
      onPressed: actions.openWebTab,
      icon: const Icon(LucideIcons.globe, size: 15),
      label: Text(l.sidebarBrowser),
    );
    if (thread == null) {
      return EmptyState(
        icon: LucideIcons.panelRight,
        title: l.panelNothingOpenTitle,
        message: l.panelNothingOpenMessage,
        actions: [browser],
      );
    }
    return EmptyState(
      icon: LucideIcons.panelRight,
      title: l.panelNoTabsTitle,
      message: l.panelNoTabsMessage,
      actions: [
        if (thread!.documentId != null)
          FilledButton.icon(
            onPressed: () =>
                actions.openTab(PanelTab.preview(thread!.documentId!)),
            icon: Icon(PanelTabKind.preview.icon, size: 15),
            label: Text(PanelTabKind.preview.name(l)),
          ),
        OutlinedButton.icon(
          onPressed: () => actions.openTab(PanelTab.library),
          icon: Icon(PanelTabKind.library.icon, size: 15),
          label: Text(PanelTabKind.library.name(l)),
        ),
        browser,
      ],
    );
  }
}

/// A submenu the click on it leaves open. The pointer resting on it opens it, and Flutter's submenus toggle on a
/// click: the click a lawyer makes next closed what had just opened. Esc, a sibling item or a click elsewhere close it.
class _ClickSafeSubmenu extends StatefulWidget {
  const _ClickSafeSubmenu({
    required this.leadingIcon,
    required this.menuChildren,
    required this.child,
  });

  final Widget leadingIcon;
  final List<Widget> menuChildren;
  final Widget child;

  @override
  State<_ClickSafeSubmenu> createState() => _ClickSafeSubmenuState();
}

class _ClickSafeSubmenuState extends State<_ClickSafeSubmenu> {
  var _open = false;

  void _opened(bool open) {
    if (mounted && open != _open) setState(() => _open = open);
  }

  @override
  Widget build(BuildContext context) => IgnorePointer(
    ignoring: _open,
    child: SubmenuButton(
      leadingIcon: widget.leadingIcon,
      onOpen: () => _opened(true),
      onClose: () => _opened(false),
      menuChildren: widget.menuChildren,
      child: widget.child,
    ),
  );
}
