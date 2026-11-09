import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/theme/app_theme.dart';
import '../../features/agent/agent_controller.dart';
import '../../features/workspace/chat_thread.dart';
import '../../features/workspace/ui_state.dart';
import '../../features/workspace/workspace_state.dart';
import '../../l10n/l10n.dart';
import '../app_actions.dart';
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
/// raw agent log.
class SidePanel extends ConsumerWidget {
  const SidePanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final thread = ref.watch(activeThreadProvider);
    final tokens = AppTokens.of(context);

    return ColoredBox(
      color: tokens.panel,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _TabStrip(thread: thread),
          const Divider(),
          Expanded(
            child: ColoredBox(
              color: Theme.of(context).colorScheme.surface,
              child: switch (thread?.activeTab) {
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
  const _TabStrip({required this.thread});

  final ChatThread? thread;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ws = ref.watch(workspaceProvider);
    final turns = thread == null
        ? 0
        : ref.watch(
            sessionProvider(
              thread!.id,
            ).select((s) => s.turns.where((t) => t.changes.isNotEmpty).length),
          );
    final tabs = thread?.tabs ?? const <PanelTab>[];
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

    return SizedBox(
      height: AppTheme.tabStripHeight,
      child: Row(
        children: [
          const SizedBox(width: 6),
          Expanded(
            child: LayoutBuilder(
              builder: (context, c) {
                // Browser behaviour: tabs shrink to share the strip.
                final width = tabs.isEmpty
                    ? 0.0
                    : (c.maxWidth - 36) / tabs.length;
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
                                icon: tab.kind.icon,
                                color: tab.kind == PanelTabKind.preview
                                    ? ws.documents[tab.documentId]?.theme.accent
                                    : null,
                                label: label(tab),
                                active: tab == thread?.activeTab,
                                onTap: () => ref
                                    .read(workspaceProvider.notifier)
                                    .activateTab(tab),
                                onClose: () => ref
                                    .read(workspaceProvider.notifier)
                                    .closeTab(tab),
                              ),
                          ],
                        ),
                      ),
                    ),
                    if (thread != null) _AddTabButton(thread: thread!),
                  ],
                );
              },
            ),
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

class _Tab extends StatelessWidget {
  const _Tab({
    required this.width,
    required this.icon,
    required this.label,
    required this.active,
    required this.onTap,
    required this.onClose,
    this.color,
  });

  final double width;
  final IconData icon;
  final int? color;
  final String label;
  final bool active;
  final VoidCallback onTap;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final tokens = AppTokens.of(context);
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    return HoverBuilder(
      builder: (context, hover) => GestureDetector(
        onTap: onTap,
        onTertiaryTapUp: (_) => onClose(),
        child: Container(
          width: width,
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
              Icon(
                icon,
                size: 13,
                color: color != null ? Color(color!) : tokens.textMuted,
              ),
              const SizedBox(width: 7),
              Expanded(
                child: Text(
                  label,
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
                  onTap: onClose,
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
  }
}

class _AddTabButton extends ConsumerWidget {
  const _AddTabButton({required this.thread});

  final ChatThread thread;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ws = ref.watch(workspaceProvider);
    final actions = AppActions(ref);
    final docs = ws.documentsIn(thread.projectId);
    final l = context.l10n;
    return MenuAnchor(
      alignmentOffset: const Offset(-180, 4),
      menuChildren: [
        for (final kind in PanelTabKind.values.where((k) => k.shortcut != null))
          MenuItemButton(
            leadingIcon: Icon(kind.icon, size: 15),
            shortcut: kind.shortcut!.primary,
            // The preview item opens the chat's own document, as before; the shortcut previews the active one.
            onPressed: kind != PanelTabKind.preview
                ? actions.forShortcut(kind.shortcut!)
                : thread.documentId == null
                ? null
                : () => actions.openTab(PanelTab.preview(thread.documentId!)),
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
    if (thread == null) {
      return EmptyState(
        icon: LucideIcons.panelRight,
        title: l.panelNothingOpenTitle,
        message: l.panelNothingOpenMessage,
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
      ],
    );
  }
}
