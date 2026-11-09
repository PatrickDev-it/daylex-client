import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import '../../features/agent/whatsapp_bridge.dart';
import '../../features/workspace/chat_thread.dart';
import '../access/activity_region.dart';
import '../../features/workspace/ui_state.dart';
import '../../features/workspace/workspace_state.dart';
import '../../features/workspace/document_review.dart';
import '../chat/chat_view.dart';
import '../chat/file_drop.dart';
import '../chat/new_chat_view.dart';
import '../common/widgets.dart';
import '../panel/side_panel.dart';
import '../settings/settings_view.dart';
import '../sidebar/app_sidebar.dart';
import '../whatsapp/pairing_overlay.dart';

/// Sidebar (projects and chats) · agent chat · side panel with tabs.
class AppShell extends ConsumerWidget {
  const AppShell({super.key});

  /// The chat never gets narrower than this; the panel gives way first.
  static const minCenterWidth = 420.0;

  /// Below this window width the sidebar stays hidden, even if open: the chat needs the room more.
  static const sidebarBreakpoint = 760.0;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(reviewAllDocumentsProvider);
    final ui = ref.watch(uiProvider);
    final thread = ref.watch(activeThreadProvider);
    final whatsapp = ref.watch(whatsappProvider);

    return Scaffold(
      body: ListenableBuilder(
        listenable: whatsapp,
        builder: (context, _) => Stack(
          fit: StackFit.expand,
          children: [
            FileDrop(
              child: LayoutBuilder(
                builder: (context, c) {
                  final sidebar =
                      ui.sidebarOpen && c.maxWidth >= sidebarBreakpoint
                      ? AppSidebar.width
                      : 0.0;
                  final showPanel =
                      ui.panelOpen &&
                      ui.section == AppSection.chat &&
                      thread != null &&
                      c.maxWidth - sidebar >=
                          minCenterWidth + UiNotifier.minPanelWidth;
                  final panel = showPanel
                      ? ui.panelWidth.clamp(
                          UiNotifier.minPanelWidth,
                          c.maxWidth - sidebar - minCenterWidth,
                        )
                      : 0.0;

                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _Slide(width: sidebar, child: const AppSidebar()),
                      if (sidebar > 0) const VerticalDivider(width: 1),
                      Expanded(
                        child: ActivityRegion(
                          area: ui.section.name,
                          child: AnimatedSwitcher(
                            duration: AppTheme.normal,
                            switchInCurve: Curves.easeOut,
                            child: KeyedSubtree(
                              key: ValueKey(
                                ui.section == AppSection.settings
                                    ? 'settings'
                                    : thread?.id ?? 'new',
                              ),
                              child: switch ((ui.section, thread)) {
                                (AppSection.settings, _) =>
                                  const SettingsView(),
                                (AppSection.chat, null) => const NewChatView(),
                                (AppSection.chat, final t?) => ChatView(
                                  thread: t,
                                ),
                              },
                            ),
                          ),
                        ),
                      ),
                      if (panel > 0) const _ResizeHandle(),
                      _Slide(
                        width: panel,
                        alignRight: true,
                        child: ActivityRegion(
                          area: switch (thread?.activeTab?.kind) {
                            PanelTabKind.preview => 'document',
                            PanelTabKind.review => 'review',
                            PanelTabKind.library => 'library',
                            PanelTabKind.source => 'sources',
                            _ => 'chat',
                          },
                          child: const SidePanel(),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
            if (whatsapp.showPairing && !whatsapp.ready)
              WhatsappPairingOverlay(bridge: whatsapp),
          ],
        ),
      ),
    );
  }
}

/// Animates a column in and out without squeezing its content.
class _Slide extends StatefulWidget {
  const _Slide({
    required this.width,
    required this.child,
    this.alignRight = false,
  });

  final double width;
  final Widget child;
  final bool alignRight;

  @override
  State<_Slide> createState() => _SlideState();
}

class _SlideState extends State<_Slide> {
  /// Width the content keeps while the column slides out.
  late double _content = widget.width;
  late bool _open = widget.width > 0;

  @override
  Widget build(BuildContext context) {
    // Resizing an open column follows the pointer; only open/close animates.
    final resizing = widget.width > 0 && _open;
    _open = widget.width > 0;
    if (_open) _content = widget.width;
    return TweenAnimationBuilder<double>(
      tween: Tween(end: widget.width),
      duration: resizing ? Duration.zero : AppTheme.slow,
      curve: Curves.easeOutCubic,
      builder: (context, w, child) => SizedBox(
        width: w,
        child: w < 1 || _content < 1
            ? null
            : ClipRect(
                child: OverflowBox(
                  alignment: widget.alignRight
                      ? Alignment.centerRight
                      : Alignment.centerLeft,
                  minWidth: _content,
                  maxWidth: _content,
                  child: child,
                ),
              ),
      ),
      child: widget.child,
    );
  }
}

/// Drag to resize the side panel.
class _ResizeHandle extends ConsumerWidget {
  const _ResizeHandle();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = AppTokens.of(context);
    final scheme = Theme.of(context).colorScheme;
    return HoverBuilder(
      cursor: SystemMouseCursors.resizeColumn,
      builder: (context, hover) => GestureDetector(
        behavior: HitTestBehavior.opaque,
        onHorizontalDragUpdate: (d) =>
            ref.read(uiProvider.notifier).resizePanel(-d.delta.dx),
        child: SizedBox(
          width: 5,
          child: Center(
            child: AnimatedContainer(
              duration: AppTheme.fast,
              width: hover ? 3 : 1,
              color: hover
                  ? scheme.primary.withValues(alpha: AppTheme.hoverFade)
                  : tokens.border,
            ),
          ),
        ),
      ),
    );
  }
}
