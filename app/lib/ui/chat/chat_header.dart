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
import '../common/prompt_dialog.dart';
import '../common/widgets.dart';
import '../shortcuts.dart';

/// The bar above a chat: the project and title, the chat's menu, and the toggles for the sidebar and the panel.
class ChatHeader extends ConsumerWidget {
  const ChatHeader({super.key, required this.thread});

  final ChatThread thread;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = AppTokens.of(context);
    final text = Theme.of(context).textTheme;
    final ui = ref.watch(uiProvider);
    final project = ref.watch(
      workspaceProvider.select((s) => s.project(thread.projectId)),
    );
    final actions = AppActions(ref);
    final l = context.l10n;

    return SizedBox(
      height: AppTheme.headerHeight,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10),
        child: LayoutBuilder(
          builder: (context, constraints) => Row(
            children: [
              if (!ui.sidebarOpen)
                ToolbarButton(
                  icon: LucideIcons.panelLeftOpen,
                  tooltip: l.chatShowSidebar,
                  shortcut: AppShortcut.toggleSidebar,
                  onPressed: ref.read(uiProvider.notifier).toggleSidebar,
                ),
              const SizedBox(width: 6),
              Expanded(
                child: Row(
                  children: [
                    Flexible(
                      child: Text(
                        thread.title,
                        style: text.titleSmall,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (project != null && constraints.maxWidth >= 600) ...[
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          project.name,
                          style: text.bodySmall?.copyWith(
                            color: tokens.textFaint,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                    const SizedBox(width: 4),
                    _ThreadMenu(thread: thread),
                  ],
                ),
              ),
              ToolbarButton(
                icon: LucideIcons.squarePen,
                tooltip: project == null
                    ? l.newChat
                    : l.chatNewChatIn(project.name),
                shortcut: AppShortcut.newChat,
                onPressed: () => actions.newChat(projectId: thread.projectId),
              ),
              ToolbarButton(
                icon: ui.panelOpen
                    ? LucideIcons.panelRightClose
                    : LucideIcons.panelRightOpen,
                tooltip: ui.panelOpen ? l.chatHidePanel : l.chatShowPanel,
                shortcut: AppShortcut.togglePanel,
                onPressed: ref.read(uiProvider.notifier).togglePanel,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ThreadMenu extends ConsumerWidget {
  const _ThreadMenu({required this.thread});

  final ChatThread thread;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    return PopupMenuButton<String>(
      tooltip: l.chatActions,
      icon: const Icon(LucideIcons.ellipsis, size: 16),
      position: PopupMenuPosition.under,
      onSelected: (value) async {
        switch (value) {
          case 'rename':
            final title = await promptForText(
              context,
              title: l.chatRenameTitle,
              initial: thread.title,
            );
            if (title != null) {
              ref
                  .read(workspaceProvider.notifier)
                  .renameThread(thread.id, title);
            }
          case 'clear':
            ref.read(agentProvider.notifier).clearConversation(thread.id);
          case 'log':
            AppActions(ref).openTab(PanelTab.log);
          case 'delete':
            await AppActions(ref).deleteChat(thread.id);
        }
      },
      itemBuilder: (_) => [
        PopupMenuItem(
          value: 'rename',
          height: AppTheme.controlHeight,
          child: _MenuRow(LucideIcons.pencil, l.rename),
        ),
        PopupMenuItem(
          value: 'log',
          height: AppTheme.controlHeight,
          child: _MenuRow(LucideIcons.terminal, l.tabLog),
        ),
        PopupMenuItem(
          value: 'clear',
          height: AppTheme.controlHeight,
          child: _MenuRow(LucideIcons.eraser, l.chatClearConversation),
        ),
        const PopupMenuDivider(),
        PopupMenuItem(
          value: 'delete',
          height: AppTheme.controlHeight,
          child: _MenuRow(LucideIcons.trash2, l.chatDelete),
        ),
      ],
    );
  }
}

class _MenuRow extends StatelessWidget {
  const _MenuRow(this.icon, this.label);

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) => Row(
    children: [Icon(icon, size: 14), const SizedBox(width: 10), Text(label)],
  );
}
