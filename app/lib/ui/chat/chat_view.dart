import 'package:flutter/material.dart';
import 'package:flutter_gen_ai_chat_ui/flutter_gen_ai_chat_ui.dart'
    hide ChatThread;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/theme/app_theme.dart';
import '../../features/agent/agent_controller.dart';
import '../../features/agent/chat_cards.dart';
import '../../features/agent/presentation/conversation_presentation.dart';
import '../../features/agent/domain/source_reference.dart';
import '../../features/workspace/chat_thread.dart';
import '../../features/workspace/workspace_state.dart';
import '../../l10n/l10n.dart';
import '../shortcuts.dart';
import '../app_actions.dart';
import 'components/agent_markdown.dart';
import 'components/component_registry.dart';
import 'components/source_link.dart';
import 'components/typed_reply.dart';
import 'chat_header.dart';
import 'composer.dart';
import 'message_actions.dart';

/// The reading column shared by legal answers and the request composer: it takes the room the window gives,
/// less a margin on each side, from [chatColumnMinWidth] up to [chatColumnMaxWidth] (beyond it a line of
/// prose is too long to read). Below the minimum the window itself is the limit.
double chatColumnWidth(double available) => (available - 2 * chatColumnMargin)
    .clamp(chatColumnMinWidth, chatColumnMaxWidth);

const chatColumnMinWidth = 760.0;
const chatColumnMaxWidth = 1180.0;
const chatColumnMargin = 32.0;

/// Prompts to try on an open document; the first two are also cards on the new-chat screen.
List<String> chatSuggestions(AppLocalizations l) => [
  l.chatSuggestionPolishPage,
  l.chatSuggestionOverview,
  l.chatSuggestionShowPage,
  l.chatSuggestionDeleteLastPage,
  l.chatSuggestionRoi,
];

/// Prompts that create a document, for a chat without one.
List<String> chatCreateSuggestions(AppLocalizations l) => [
  l.chatSuggestionProposal,
  l.chatSuggestionTeamOnePager,
];

/// The agentic conversation of the active chat.
class ChatView extends ConsumerWidget {
  const ChatView({super.key, required this.thread});

  final ChatThread thread;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final agent = ref.read(agentProvider.notifier);
    final chat = agent.chatFor(thread.id);
    final running = ref.watch(
      sessionProvider(thread.id).select((s) => s.isRunning),
    );

    return CallbackShortcuts(
      bindings: {
        if (running)
          AppShortcut.stopAgent.primary: () => agent.cancel(thread.id),
      },
      child: LayoutBuilder(
        builder: (context, constraints) {
          final column = chatColumnWidth(constraints.maxWidth);
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ChatHeader(thread: thread),
              Expanded(
                child: ListenableBuilder(
                  listenable: chat,
                  builder: (context, _) => chat.messages.isEmpty
                      ? _EmptyThread(thread: thread)
                      : _Transcript(
                          key: ValueKey(thread.id),
                          chat: chat,
                          threadId: thread.id,
                          column: column,
                        ),
                ),
              ),
              Center(
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: column),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 4, 20, 18),
                    child: Composer(
                      sessionId: thread.id,
                      documentId: thread.documentId,
                      projectId: thread.projectId,
                      onPickDocument: (id) {
                        if (id == null) return;
                        ref
                            .read(workspaceProvider.notifier)
                            .openTab(PanelTab.preview(id));
                      },
                      onSend: (prompt) => agent.send(thread.id, prompt),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _Transcript extends ConsumerWidget {
  const _Transcript({
    super.key,
    required this.chat,
    required this.threadId,
    required this.column,
  });

  final ChatMessagesController chat;
  final String threadId;
  final double column;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    return SourceCitationScope(
      onOpen: (source) => AppActions(ref).showSource(threadId, source),
      child: AiChatWidget(
        currentUser: AgentController.user,
        aiUser: AgentController.agent,
        controller: chat,
        messages: chat.messages
            .where(ConversationPresentation.visible)
            .toList(),
        onSendMessage: (_) {},
        readOnly: true,
        maxWidth: column,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        enableMarkdownStreaming: false,
        resultRenderers: componentRenderers,
        messageOptions: MessageOptions(
          showTime: false,
          showUserName: false,
          textStyle: text.bodyMedium,
          userTextColor: scheme.onSurface,
          aiTextColor: scheme.onSurface,
          customBubbleBuilder: (context, message, isUser) => MessageActions(
            // The prompt as written: the attachments line is the app's, not the lawyer's text.
            text: isUser
                ? AttachmentsLine.promptOf(message.text)
                : SourceReference.readable(
                    message.text,
                    (s) => sourceLabel(context.l10n, s),
                  ),
            time: message.createdAt,
            alignEnd: isUser,
            enabled:
                message.customProperties?[ChatProps.streaming] != true &&
                message.text.trim().isNotEmpty,
            child: isUser ? _UserMessage(message) : _AgentMessage(message),
          ),
        ),
      ),
    );
  }
}

/// The user's prompt: a quiet bubble on the right.
class _UserMessage extends StatelessWidget {
  const _UserMessage(this.message);

  final ChatMessage message;

  @override
  Widget build(BuildContext context) {
    final tokens = AppTokens.of(context);
    return LayoutBuilder(
      builder: (context, constraints) => Padding(
        padding: EdgeInsets.fromLTRB(
          constraints.maxWidth < 480 ? 24 : 72,
          20,
          8,
          12,
        ),
        child: Align(
          alignment: Alignment.centerRight,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: tokens.hover,
              borderRadius: BorderRadius.circular(AppTheme.radiusXl),
            ),
            child: SelectableText(
              message.text,
              style: AppText.of(context).chat,
            ),
          ),
        ),
      ),
    );
  }
}

/// Agent text: no bubble, full column width, markdown with fences.
class _AgentMessage extends StatelessWidget {
  const _AgentMessage(this.message);

  final ChatMessage message;

  @override
  Widget build(BuildContext context) {
    final tokens = AppTokens.of(context);
    if (message.hasError) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(8, 6, 8, 0),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: tokens.danger.withValues(alpha: AppTheme.tintFaint),
            borderRadius: BorderRadius.circular(AppTheme.radius),
            border: Border.all(
              color: tokens.danger.withValues(alpha: AppTheme.tintBorder),
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(LucideIcons.triangleAlert, size: 15, color: tokens.danger),
              const SizedBox(width: 10),
              Expanded(child: AgentMarkdown(message.text)),
            ],
          ),
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 12),
      child: TypedReply(
        message.text,
        streaming: message.customProperties?[ChatProps.streaming] == true,
      ),
    );
  }
}

/// A chat with no messages yet.
class _EmptyThread extends ConsumerWidget {
  const _EmptyThread({required this.thread});

  final ChatThread thread;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = AppTokens.of(context);
    final text = Theme.of(context).textTheme;
    final doc = ref.watch(
      workspaceProvider.select((s) => s.documents[thread.documentId]),
    );
    final agent = ref.read(agentProvider.notifier);
    final l = context.l10n;
    // Scrolls in a short window instead of overflowing at the bottom.
    return Center(
      child: SingleChildScrollView(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  doc == null
                      ? l.chatWhatToWrite
                      : l.chatWhatToDoWith(doc.title),
                  style: text.titleLarge,
                ),
                const SizedBox(height: 16),
                for (final s
                    in doc == null
                        ? chatCreateSuggestions(l)
                        : chatSuggestions(l))
                  InkWell(
                    borderRadius: BorderRadius.circular(AppTheme.radius),
                    onTap: () => agent.send(thread.id, s),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 4,
                        vertical: 8,
                      ),
                      child: Row(
                        children: [
                          Icon(
                            LucideIcons.cornerDownRight,
                            size: 14,
                            color: tokens.textFaint,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              s,
                              style: text.bodyMedium?.copyWith(
                                color: tokens.textMuted,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
