import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/theme/app_theme.dart';
import '../../features/agent/agent_controller.dart';
import '../../features/agent/domain/agent_protocol.dart';
import '../../features/workspace/viewer_state.dart';
import '../../features/workspace/workspace_state.dart';
import '../../l10n/l10n.dart';
import '../common/widgets.dart';
import '../common/elapsed_time.dart';
import '../shortcuts.dart';
import 'composer_inputs.dart';
import 'file_drop.dart';

/// Prompt box shared by chats and the new-chat screen: attachments, the
/// document the agent will edit, the backend and send/stop.
class Composer extends ConsumerStatefulWidget {
  const Composer({
    super.key,
    required this.sessionId,
    required this.onSend,
    this.documentId,
    this.projectId,
    this.onPickDocument,
    this.suggestions = const [],
    this.hint,
  });

  /// Chat id, or [AgentController.draftId].
  final String sessionId;
  final ValueChanged<String> onSend;
  final String? documentId;

  /// Project whose documents the document picker lists.
  final String? projectId;
  final ValueChanged<String?>? onPickDocument;

  /// Chips shown above the box while idle.
  final List<String> suggestions;

  /// The placeholder; [AppLocalizations.composerHint] when null.
  final String? hint;

  @override
  ConsumerState<Composer> createState() => _ComposerState();
}

class _ComposerState extends ConsumerState<Composer> {
  late TextEditingController _text;

  @override
  void initState() {
    super.initState();
    _bind();
  }

  @override
  void didUpdateWidget(Composer old) {
    super.didUpdateWidget(old);
    if (old.sessionId != widget.sessionId) {
      _text.removeListener(_changed);
      _bind();
    }
  }

  void _bind() {
    _text = ref.read(composerInputsProvider).draftOf(widget.sessionId)
      ..addListener(_changed);
  }

  void _changed() => setState(() {});

  @override
  void dispose() {
    _text.removeListener(_changed);
    super.dispose();
  }

  void _send([String? value]) {
    final prompt = value ?? _text.text;
    if (prompt.trim().isEmpty) return;
    if (value == null) _text.clear();
    widget.onSend(prompt);
  }

  Future<void> _pickAttachments(AgentController agent) async {
    final messenger = ScaffoldMessenger.maybeOf(context);
    final l = context.l10n;
    showLeftOut(messenger, l, await agent.pickAttachments(widget.sessionId));
  }

  @override
  Widget build(BuildContext context) {
    final tokens = AppTokens.of(context);
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final l = context.l10n;
    final session = ref.watch(sessionProvider(widget.sessionId));
    final agent = ref.read(agentProvider.notifier);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        AnimatedSize(
          duration: AppTheme.normal,
          alignment: Alignment.bottomCenter,
          child: session.isRunning
              ? _Activity(session: session)
              : widget.suggestions.isEmpty
              ? const SizedBox(width: double.infinity)
              : SizedBox(
                  height: AppTheme.controlHeight,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.only(bottom: 8),
                    children: [
                      for (final s in widget.suggestions)
                        Padding(
                          padding: const EdgeInsets.only(right: 6),
                          child: ActionChip(
                            label: Text(s, style: text.labelSmall),
                            onPressed: () => _send(s),
                            visualDensity: VisualDensity.compact,
                            side: BorderSide(color: tokens.border),
                            backgroundColor: scheme.surface,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(
                                AppTheme.radiusPill,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
        ),
        Container(
          decoration: BoxDecoration(
            color: scheme.surface,
            borderRadius: BorderRadius.circular(AppTheme.radiusXl),
            border: Border.all(color: tokens.borderStrong),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 16,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (session.attachments.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.fromLTRB(10, 10, 10, 0),
                  child: Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      for (final a in session.attachments)
                        InputChip(
                          // Reading (OCR may take a while), read, or not read: the tooltip says what.
                          avatar: switch (a.status) {
                            AttachmentStatus.uploading => const SizedBox.square(
                              dimension: 12,
                              child: CircularProgressIndicator(
                                strokeWidth: 1.5,
                              ),
                            ),
                            AttachmentStatus.failed => Icon(
                              LucideIcons.triangleAlert,
                              size: 13,
                              color: tokens.danger,
                            ),
                            AttachmentStatus.ready => Icon(
                              LucideIcons.circleCheck,
                              size: 13,
                              color: tokens.success,
                            ),
                            AttachmentStatus.local => Icon(
                              a.isImage
                                  ? LucideIcons.image
                                  : LucideIcons.fileText,
                              size: 13,
                            ),
                          },
                          tooltip: a.summary,
                          label: Text(a.name, style: text.labelSmall),
                          onDeleted: () =>
                              agent.removeAttachment(widget.sessionId, a),
                          deleteIcon: const Icon(LucideIcons.x, size: 12),
                          visualDensity: VisualDensity.compact,
                          side: BorderSide(color: tokens.border),
                        ),
                    ],
                  ),
                ),
              CallbackShortcuts(
                bindings: {
                  const SingleActivator(LogicalKeyboardKey.enter): _send,
                },
                child: TextField(
                  controller: _text,
                  focusNode: ref.read(composerInputsProvider).focus,
                  minLines: 1,
                  maxLines: 8,
                  style: AppText.of(context).chat,
                  keyboardType: TextInputType.multiline,
                  decoration: InputDecoration(
                    hintText: widget.hint ?? l.composerHint,
                    filled: false,
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    contentPadding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
                child: Row(
                  children: [
                    ToolbarButton(
                      icon: LucideIcons.plus,
                      tooltip: l.composerAttach,
                      onPressed: session.isRunning
                          ? null
                          : () => _pickAttachments(agent),
                    ),
                    const SizedBox(width: 2),
                    Expanded(
                      child: Align(
                        alignment: Alignment.centerLeft,
                        // Under the chip's own minimum (icon, gap, chevron) it would overflow.
                        child: LayoutBuilder(
                          builder: (context, c) => c.maxWidth < 56
                              ? const SizedBox.shrink()
                              : _DocumentPicker(
                                  documentId: widget.documentId,
                                  projectId: widget.projectId,
                                  onPick: widget.onPickDocument,
                                ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    session.isRunning
                        ? IconButton.filled(
                            tooltip:
                                '${AppShortcut.stopAgent.label(l)}  ·  ${AppShortcut.stopAgent.keys}',
                            onPressed: () => agent.cancel(widget.sessionId),
                            icon: const Icon(LucideIcons.square, size: 11),
                            style: IconButton.styleFrom(
                              backgroundColor: scheme.onSurface,
                              foregroundColor: scheme.surface,
                              minimumSize: const Size(32, 32),
                            ),
                          )
                        : IconButton.filled(
                            tooltip: l.composerSend,
                            onPressed: _text.text.trim().isEmpty ? null : _send,
                            icon: const Icon(LucideIcons.arrowUp, size: 15),
                            style: IconButton.styleFrom(
                              backgroundColor: scheme.onSurface,
                              foregroundColor: scheme.surface,
                              disabledBackgroundColor: tokens.hover,
                              minimumSize: const Size(32, 32),
                            ),
                          ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Which document the agent works on; lists the project's documents.
class _DocumentPicker extends ConsumerWidget {
  const _DocumentPicker({
    required this.documentId,
    required this.projectId,
    required this.onPick,
  });

  final String? documentId;
  final String? projectId;
  final ValueChanged<String?>? onPick;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = AppTokens.of(context);
    final text = Theme.of(context).textTheme;
    final l = context.l10n;
    final ws = ref.watch(workspaceProvider);
    final doc = documentId == null ? null : ws.documents[documentId];
    final page = ref.watch(viewerProvider.select((v) => v.page));
    final onScreen = doc != null && ws.activeDocument?.id == doc.id;
    final docs = projectId == null
        ? ws.documents.values.toList()
        : ws.documentsIn(projectId!);

    final label = doc == null
        ? l.composerNoDocument
        : onScreen
        ? l.composerDocumentOnPage(doc.title, page)
        : doc.title;

    return PopupMenuButton<String>(
      tooltip: l.composerPickDocument,
      enabled: onPick != null,
      position: PopupMenuPosition.over,
      onSelected: (id) => onPick?.call(id.isEmpty ? null : id),
      itemBuilder: (_) => [
        for (final d in docs)
          PopupMenuItem(
            value: d.id,
            height: AppTheme.controlHeight,
            child: Row(
              children: [
                Icon(
                  LucideIcons.fileText,
                  size: 14,
                  color: Color(d.theme.accent),
                ),
                const SizedBox(width: 8),
                Expanded(child: Text(d.title, overflow: TextOverflow.ellipsis)),
                if (d.id == documentId) const Icon(LucideIcons.check, size: 14),
              ],
            ),
          ),
        const PopupMenuDivider(),
        PopupMenuItem(
          value: '',
          height: AppTheme.controlHeight,
          child: Row(
            children: [
              const Icon(LucideIcons.filePlus, size: 14),
              const SizedBox(width: 8),
              // The menu is as wide as its widest title: a long label must shrink, not overflow.
              Flexible(
                child: Text(
                  l.composerNoDocumentCreate,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ],
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppTheme.radiusPill),
          border: Border.all(color: tokens.border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              doc == null ? LucideIcons.filePlus : LucideIcons.fileText,
              size: 13,
              color: doc == null ? tokens.textFaint : Color(doc.theme.accent),
            ),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                label,
                style: text.labelMedium?.copyWith(color: tokens.textMuted),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 2),
            Icon(LucideIcons.chevronDown, size: 12, color: tokens.textFaint),
          ],
        ),
      ),
    );
  }
}

/// Current operation remains visible even when the user is reading older messages.
class _Activity extends StatelessWidget {
  const _Activity({required this.session});

  final SessionState session;

  @override
  Widget build(BuildContext context) {
    final tokens = AppTokens.of(context);
    final text = Theme.of(context).textTheme;
    final l = context.l10n;
    final waiting = session.phase == AgentPhase.waiting;
    return Semantics(
      liveRegion: true,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(6, 0, 6, 10),
        child: Row(
          children: [
            if (waiting)
              Icon(LucideIcons.shieldAlert, size: 13, color: tokens.warning)
            else
              SizedBox(
                width: 12,
                height: 12,
                child: CircularProgressIndicator(
                  strokeWidth: 1.5,
                  color: tokens.textMuted,
                ),
              ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    session.activity ?? l.composerWorking,
                    style: text.labelMedium?.copyWith(color: tokens.textMuted),
                  ),
                  if (session.activityDetail.isNotEmpty)
                    Text(
                      session.activityDetail,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: text.bodySmall?.copyWith(color: tokens.textMuted),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            ElapsedTime(
              startedAt: session.startedAt,
              running: session.isRunning,
              style: text.labelSmall?.copyWith(color: tokens.textMuted),
            ),
          ],
        ),
      ),
    );
  }
}
