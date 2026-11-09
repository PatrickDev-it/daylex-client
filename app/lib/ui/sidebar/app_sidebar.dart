import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/theme/app_theme.dart';
import '../../features/workspace/chat_thread.dart';
import '../../features/workspace/ui_state.dart';
import '../../features/workspace/workspace_state.dart';
import '../../l10n/l10n.dart';
import '../app_actions.dart';
import '../common/prompt_dialog.dart';
import '../common/widgets.dart';
import '../shortcuts.dart';
import 'sidebar_rows.dart';
import 'update_button.dart';

/// Left column: a few commands, then projects with their chats — plain rows,
/// no cards, like a coding agent's thread list.
class AppSidebar extends ConsumerStatefulWidget {
  const AppSidebar({super.key});

  static const width = 260.0;

  @override
  ConsumerState<AppSidebar> createState() => _AppSidebarState();
}

/// The sidebar's icon buttons are smaller than the theme's 32, as they were before [ToolbarButton]: the header and
/// footer ones (a 15 icon), the one on a project row (13) and the one on a chat row (12).
const _actionSize = 28.0;

class _AppSidebarState extends ConsumerState<AppSidebar> {
  static const _visibleChats = 5;

  final _collapsed = <String>{};
  final _expanded = <String>{};
  final _search = TextEditingController();
  var _searching = false;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _newProject() async {
    final l = context.l10n;
    final name = await promptForText(
      context,
      title: l.sidebarNewProject,
      hint: l.sidebarNewProjectHint,
      action: l.sidebarCreate,
    );
    if (name == null) return;
    final project = ref.read(workspaceProvider.notifier).createProject(name);
    AppActions(ref).newChat(projectId: project.id);
  }

  @override
  Widget build(BuildContext context) {
    final tokens = AppTokens.of(context);
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final l = context.l10n;
    final ws = ref.watch(workspaceProvider);
    final ui = ref.watch(uiProvider);
    final actions = AppActions(ref);
    final query = _search.text.trim().toLowerCase();

    return ColoredBox(
      color: tokens.panel,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header
          SizedBox(
            height: AppTheme.headerHeight,
            child: Padding(
              padding: const EdgeInsets.only(left: 14, right: 6),
              child: Row(
                children: [
                  Container(
                    width: 22,
                    height: 22,
                    decoration: BoxDecoration(
                      color: scheme.primary,
                      borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                    ),
                    child: Icon(LucideIcons.fileText, size: 13, color: scheme.onPrimary),
                  ),
                  const SizedBox(width: 9),
                  Expanded(child: Text(l.appTitle, style: text.titleSmall)),
                  ToolbarButton(
                    icon: LucideIcons.panelLeftClose,
                    tooltip: l.sidebarHide,
                    shortcut: AppShortcut.toggleSidebar,
                    size: _actionSize,
                    onPressed: ref.read(uiProvider.notifier).toggleSidebar,
                  ),
                ],
              ),
            ),
          ),
          // Commands
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Column(
              children: [
                NavRow(
                  icon: LucideIcons.squarePen,
                  label: l.newChat,
                  shortcut: AppShortcut.newChat,
                  active: ui.section == AppSection.chat && ws.activeThreadId == null,
                  onTap: () => actions.newChat(),
                ),
                NavRow(
                  icon: LucideIcons.search,
                  label: l.sidebarSearchChats,
                  active: _searching,
                  onTap: () => setState(() {
                    _searching = !_searching;
                    if (!_searching) _search.clear();
                  }),
                ),
                NavRow(
                  icon: LucideIcons.filePlus,
                  label: l.newDocument,
                  shortcut: AppShortcut.newDocument,
                  onTap: actions.newDocument,
                ),
                NavRow(
                  icon: LucideIcons.library,
                  label: l.tabLibrary,
                  shortcut: AppShortcut.libraryTab,
                  onTap: ws.activeThread == null ? null : () => actions.openTab(PanelTab.library),
                ),
              ],
            ),
          ),
          if (_searching)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 6, 12, 0),
              child: TextField(
                controller: _search,
                autofocus: true,
                onChanged: (_) => setState(() {}),
                style: text.bodySmall,
                decoration: InputDecoration(
                  isDense: true,
                  hintText: l.sidebarFilterChats,
                  prefixIcon: const Icon(LucideIcons.search, size: 14),
                  prefixIconConstraints: const BoxConstraints(minWidth: 32),
                  contentPadding: const EdgeInsets.symmetric(vertical: 8),
                ),
              ),
            ),
          // Projects
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 18, 8, 4),
            child: Row(
              children: [
                Expanded(
                  child: Text(l.sidebarProjects, style: text.labelSmall?.copyWith(color: tokens.textFaint)),
                ),
                ToolbarButton(
                  icon: LucideIcons.folderPlus,
                  tooltip: l.sidebarNewProject,
                  size: _actionSize,
                  onPressed: _newProject,
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(8, 0, 8, 12),
              children: [
                for (final project in ws.projects)
                  ...() {
                    final all = ws
                        .threadsIn(project.id)
                        .where((t) => query.isEmpty || t.title.toLowerCase().contains(query))
                        .toList();
                    if (query.isNotEmpty && all.isEmpty) return const <Widget>[];
                    final collapsed = _collapsed.contains(project.id) && query.isEmpty;
                    final expanded = _expanded.contains(project.id) || query.isNotEmpty;
                    final shown = expanded ? all : all.take(_visibleChats).toList();
                    // Keep the active chat visible even past the limit.
                    final active = ws.activeThread;
                    if (active != null &&
                        active.projectId == project.id &&
                        !shown.contains(active) &&
                        all.contains(active)) {
                      shown.add(active);
                    }
                    return [
                      ProjectRow(
                        name: project.name,
                        collapsed: collapsed,
                        onTap: () => setState(() {
                          collapsed ? _collapsed.remove(project.id) : _collapsed.add(project.id);
                        }),
                        onNewChat: () => actions.newChat(projectId: project.id),
                      ),
                      if (!collapsed) ...[
                        for (final t in shown)
                          ChatRow(thread: t, active: ui.section == AppSection.chat && t.id == ws.activeThreadId),
                        if (all.isEmpty)
                          Padding(
                            padding: const EdgeInsets.fromLTRB(34, 4, 8, 6),
                            child: Text(l.sidebarNoChats, style: text.bodySmall?.copyWith(color: tokens.textFaint)),
                          ),
                        if (all.length > _visibleChats && query.isEmpty)
                          Padding(
                            padding: const EdgeInsets.only(left: 26),
                            child: TextButton(
                              style: TextButton.styleFrom(
                                visualDensity: VisualDensity.compact,
                                alignment: Alignment.centerLeft,
                                foregroundColor: tokens.textFaint,
                              ),
                              onPressed: () => setState(() {
                                expanded ? _expanded.remove(project.id) : _expanded.add(project.id);
                              }),
                              child: Text(expanded ? l.sidebarShowLess : l.sidebarShowMore),
                            ),
                          ),
                      ],
                      const SizedBox(height: 4),
                    ];
                  }(),
              ],
            ),
          ),
          // Footer
          const Divider(),
          const UpdateButton(),
          Padding(
            padding: const EdgeInsets.all(8),
            child: Row(
              children: [
                const Expanded(child: AgentStatus()),
                ToolbarButton(
                  icon: LucideIcons.settings,
                  tooltip: l.settings,
                  selected: ui.section == AppSection.settings,
                  size: _actionSize,
                  onPressed: () => ref.read(uiProvider.notifier).show(AppSection.settings),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
