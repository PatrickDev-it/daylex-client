import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/theme/app_theme.dart';
import '../../features/agent/agent_controller.dart';
import '../../features/workspace/ui_state.dart';
import '../../features/workspace/workspace_state.dart';
import '../../l10n/l10n.dart';
import '../common/widgets.dart';
import '../shortcuts.dart';
import 'chat_view.dart';
import 'composer.dart';

/// Home of a new chat: pick project and document, then write the first
/// prompt. Sending creates the chat.
class NewChatView extends ConsumerStatefulWidget {
  const NewChatView({super.key});

  @override
  ConsumerState<NewChatView> createState() => _NewChatViewState();
}

class _NewChatViewState extends ConsumerState<NewChatView> {
  /// The document the lawyer picked for the chat; none until they pick one, so a new chat starts clean.
  String? _documentId;

  @override
  Widget build(BuildContext context) {
    final tokens = AppTokens.of(context);
    final text = Theme.of(context).textTheme;
    final l = context.l10n;
    final ws = ref.watch(workspaceProvider);
    final ui = ref.watch(uiProvider);
    final project = ws.project(ui.newChatProjectId ?? '') ?? ws.projects.first;
    final picked = ws
        .documentsIn(project.id)
        .where((d) => d.id == _documentId)
        .firstOrNull;

    void start(String prompt) => ref
        .read(agentProvider.notifier)
        .startChat(
          projectId: project.id,
          prompt: prompt,
          documentId: picked?.id,
        );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          height: AppTheme.headerHeight,
          child: Row(
            children: [
              const SizedBox(width: 10),
              if (!ui.sidebarOpen)
                ToolbarButton(
                  icon: LucideIcons.panelLeftOpen,
                  tooltip: l.chatShowSidebar,
                  shortcut: AppShortcut.toggleSidebar,
                  onPressed: ref.read(uiProvider.notifier).toggleSidebar,
                ),
            ],
          ),
        ),
        Expanded(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 720),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Icon(
                      LucideIcons.fileText,
                      size: 30,
                      color: tokens.textFaint,
                    ),
                    const SizedBox(height: 14),
                    Text(
                      l.chatWhatToWrite,
                      textAlign: TextAlign.center,
                      style: text.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Center(
                      child: PopupMenuButton<String>(
                        tooltip: l.chatNewProject,
                        position: PopupMenuPosition.under,
                        onSelected: (id) {
                          setState(() => _documentId = null);
                          ref.read(uiProvider.notifier).setNewChatProject(id);
                        },
                        itemBuilder: (_) => [
                          for (final p in ws.projects)
                            PopupMenuItem(
                              value: p.id,
                              height: AppTheme.controlHeight,
                              child: Row(
                                children: [
                                  const Icon(LucideIcons.folder, size: 14),
                                  const SizedBox(width: 8),
                                  Text(p.name),
                                  if (p.id == project.id) ...[
                                    const SizedBox(width: 8),
                                    const Icon(LucideIcons.check, size: 14),
                                  ],
                                ],
                              ),
                            ),
                        ],
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                LucideIcons.folder,
                                size: 14,
                                color: tokens.textMuted,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                project.name,
                                style: text.titleSmall?.copyWith(
                                  color: tokens.textMuted,
                                ),
                              ),
                              const SizedBox(width: 4),
                              Icon(
                                LucideIcons.chevronDown,
                                size: 14,
                                color: tokens.textFaint,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 28),
                    Composer(
                      sessionId: AgentController.draftId,
                      documentId: picked?.id,
                      projectId: project.id,
                      onPickDocument: (id) => setState(() => _documentId = id),
                      hint: picked == null
                          ? l.chatNewHintNoDocument
                          : l.chatNewHintDocument(picked.title),
                      onSend: start,
                    ),
                    const SizedBox(height: 22),
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: [
                        for (final (icon, title, prompt) in [
                          if (picked != null) ...[
                            (
                              LucideIcons.sparkles,
                              l.chatNewCardPolish,
                              chatSuggestions(l)[0],
                            ),
                            (
                              LucideIcons.listTree,
                              l.chatNewCardOverview,
                              chatSuggestions(l)[1],
                            ),
                          ],
                          (
                            LucideIcons.filePlus,
                            l.chatNewCardProposal,
                            chatCreateSuggestions(l)[0],
                          ),
                          (
                            LucideIcons.users,
                            l.chatNewCardTeam,
                            chatCreateSuggestions(l)[1],
                          ),
                        ])
                          _SuggestionCard(
                            icon: icon,
                            title: title,
                            prompt: prompt,
                            onTap: () {
                              // Creation prompts start without a document.
                              if (icon == LucideIcons.filePlus ||
                                  icon == LucideIcons.users) {
                                ref
                                    .read(agentProvider.notifier)
                                    .startChat(
                                      projectId: project.id,
                                      prompt: prompt,
                                    );
                              } else {
                                start(prompt);
                              }
                            },
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _SuggestionCard extends StatelessWidget {
  const _SuggestionCard({
    required this.icon,
    required this.title,
    required this.prompt,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String prompt;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = AppTokens.of(context);
    final text = Theme.of(context).textTheme;
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 112),
      child: SizedBox(
        width: 170,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(AppTheme.radiusLg),
            child: OutlinedBox(
              padding: const EdgeInsets.all(12),
              radius: AppTheme.radiusLg,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(icon, size: 16, color: tokens.textMuted),
                  const SizedBox(height: 8),
                  Text(title, style: text.labelLarge),
                  const SizedBox(height: 4),
                  Text(
                    prompt,
                    style: text.bodySmall?.copyWith(color: tokens.textFaint),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
