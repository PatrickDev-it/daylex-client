import 'package:deskify/deskify.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/theme/app_theme.dart';
import '../../features/agent/agent_controller.dart';
import '../../features/workspace/chat_thread.dart';
import '../../features/workspace/workspace_state.dart';
import '../../l10n/l10n.dart';
import '../app_actions.dart';
import '../common/prompt_dialog.dart';
import '../common/time_format.dart';
import '../common/widgets.dart';
import '../shortcuts.dart';

/// The smaller icon buttons on a project row (a 13 icon) and on a chat row (12).
const sidebarRowActionSize = 26.0;
const sidebarChatActionSize = 24.0;

class NavRow extends StatelessWidget {
  const NavRow({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
    this.shortcut,
    this.active = false,
  });

  final IconData icon;
  final String label;
  final AppShortcut? shortcut;
  final bool active;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = AppTokens.of(context);
    final enabled = onTap != null;
    return HoverBuilder(
      builder: (context, hover) => RowSurface(
        active: active,
        onTap: onTap,
        child: Row(
          children: [
            Icon(
              icon,
              size: 15,
              color: enabled ? tokens.textMuted : tokens.textFaint,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                label,
                style: AppText.of(context).nav
                    .copyWith(color: enabled ? null : tokens.textFaint),
              ),
            ),
            if (hover && shortcut != null)
              Text(shortcut!.keys, style: AppText.of(context).keycap),
          ],
        ),
      ),
    );
  }
}

class ProjectRow extends StatelessWidget {
  const ProjectRow({
    super.key,
    required this.name,
    required this.collapsed,
    required this.onTap,
    required this.onNewChat,
  });

  final String name;
  final bool collapsed;
  final VoidCallback onTap;
  final VoidCallback onNewChat;

  @override
  Widget build(BuildContext context) {
    final tokens = AppTokens.of(context);
    return HoverBuilder(
      builder: (context, hover) => RowSurface(
        onTap: onTap,
        child: Row(
          children: [
            Icon(
              hover
                  ? (collapsed
                        ? LucideIcons.chevronRight
                        : LucideIcons.chevronDown)
                  : (collapsed ? LucideIcons.folder : LucideIcons.folderOpen),
              size: 15,
              color: tokens.textMuted,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                name,
                style: AppText.of(context).nav
                    .copyWith(fontWeight: FontWeight.w500),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (hover)
              ToolbarButton(
                icon: LucideIcons.squarePen,
                tooltip: context.l10n.chatNewChatIn(name),
                size: sidebarRowActionSize,
                onPressed: onNewChat,
              ),
          ],
        ),
      ),
    );
  }
}

class ChatRow extends ConsumerStatefulWidget {
  const ChatRow({super.key, required this.thread, required this.active});

  final ChatThread thread;
  final bool active;

  @override
  ConsumerState<ChatRow> createState() => ChatRowState();
}

class ChatRowState extends ConsumerState<ChatRow> {
  Future<void> _rename() async {
    final l = context.l10n;
    final title = await promptForText(
      context,
      title: l.chatRenameTitle,
      initial: widget.thread.title,
      action: l.save,
    );
    if (title != null) {
      ref
          .read(workspaceProvider.notifier)
          .renameThread(widget.thread.id, title);
    }
  }

  void _delete() => AppActions(ref).deleteChat(widget.thread.id);

  @override
  Widget build(BuildContext context) {
    final tokens = AppTokens.of(context);
    final text = Theme.of(context).textTheme;
    final l = context.l10n;
    final t = widget.thread;
    final session = ref.watch(sessionProvider(t.id));
    final waiting = session.phase == AgentPhase.waiting;

    return DeskRightClickMenu(
      items: [
        DeskContextMenuItem(
          label: l.rename,
          icon: LucideIcons.pencil,
          onTap: _rename,
        ),
        DeskContextMenuItem.divider(),
        DeskContextMenuItem(
          label: l.delete,
          icon: LucideIcons.trash2,
          onTap: _delete,
        ),
      ],
      child: HoverBuilder(
        builder: (context, hover) => RowSurface(
          active: widget.active,
          onTap: () => AppActions(ref).openChat(t.id),
          padding: const EdgeInsets.only(left: 34, right: 8),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  t.title,
                  style: AppText.of(context).nav
                      .copyWith(color: widget.active ? null : tokens.textMuted),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 6),
              if (waiting)
                Tooltip(
                  message: l.agentWaitingApproval,
                  child: Icon(
                    LucideIcons.shieldAlert,
                    size: 13,
                    color: tokens.warning,
                  ),
                )
              else if (session.isRunning)
                SizedBox(
                  width: 11,
                  height: 11,
                  child: CircularProgressIndicator(
                    strokeWidth: 1.5,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                )
              else if (hover)
                ToolbarButton(
                  icon: LucideIcons.trash2,
                  tooltip: l.chatDelete,
                  size: sidebarChatActionSize,
                  onPressed: _delete,
                )
              else
                Text(
                  relativeTime(l, t.updatedAt, DateTime.now()),
                  style: text.labelSmall?.copyWith(color: tokens.textFaint),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Hover/active background shared by sidebar rows.
class RowSurface extends StatelessWidget {
  const RowSurface({
    super.key,
    required this.child,
    required this.onTap,
    this.active = false,
    this.padding = const EdgeInsets.symmetric(horizontal: 10),
  });

  final Widget child;
  final VoidCallback? onTap;
  final bool active;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    final tokens = AppTokens.of(context);
    final accent = Theme.of(context).colorScheme.primary;
    return Material(
      color: active ? tokens.hover : Colors.transparent,
      borderRadius: BorderRadius.circular(AppTheme.radius),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppTheme.radius),
        onTap: onTap,
        hoverColor: tokens.hover.withValues(alpha: AppTheme.hoverFade),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 32),
          child: Stack(
            alignment: Alignment.centerLeft,
            children: [
              Padding(
                padding: padding.add(const EdgeInsets.symmetric(vertical: 6)),
                child: child,
              ),
              if (active)
                Positioned(
                  left: 0,
                  top: 9,
                  bottom: 9,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: accent,
                      borderRadius: BorderRadius.circular(
                        AppTheme.radiusIndicator,
                      ),
                    ),
                    child: const SizedBox(width: 2),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// How many chats are running, and the backend.
class AgentStatus extends ConsumerWidget {
  const AgentStatus({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = AppTokens.of(context);
    final text = Theme.of(context).textTheme;
    final agent = ref.watch(agentProvider);
    final client = ref.watch(agentClientProvider);
    final running = agent.running;
    final l = context.l10n;
    return Padding(
      padding: const EdgeInsets.only(left: 8),
      child: Row(
        children: [
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(
              color: running > 0
                  ? Theme.of(context).colorScheme.primary
                  : client.problem != null
                  ? tokens.danger
                  : tokens.success,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              running > 0
                  ? l.sidebarChatsRunning(running)
                  : client.problem != null
                  ? l.agentNotConnected
                  : client.isMock
                  ? l.agentMockOffline
                  : l.sidebarAgentReady,
              style: text.labelSmall?.copyWith(color: tokens.textMuted),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
