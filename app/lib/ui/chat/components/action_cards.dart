import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/platform/files.dart';
import '../../../core/theme/app_theme.dart';
import '../../../features/agent/agent_controller.dart';
import '../../../features/agent/presentation/ui_components.dart';
import '../../../l10n/l10n.dart';
import '../../app_actions.dart';
import '../../common/widgets.dart';
import 'agent_markdown.dart';
import 'card_chrome.dart';
import 'card_props.dart';

/// `export_result`: the exported PDF with shortcuts to open it.
class ExportCard extends StatelessWidget {
  const ExportCard({super.key, required this.props});

  final Map<String, dynamic> props;

  @override
  Widget build(BuildContext context) {
    final tokens = AppTokens.of(context);
    final text = Theme.of(context).textTheme;
    final l = context.l10n;
    final path = propString(props['path']) ?? '';
    final name = path.split(RegExp(r'[\\/]')).last;
    final file = kIsWeb ? null : File(path);
    final size = file != null && file.existsSync() ? file.lengthSync() : null;
    final pages = propIntOrNull(props['pages']);

    return CardWidth(
      maxWidth: CardWidth.compact,
      child: CardBox(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 46,
              alignment: Alignment.bottomCenter,
              padding: const EdgeInsets.only(bottom: 6),
              decoration: BoxDecoration(
                color: tokens.danger.withValues(alpha: AppTheme.tintSoft),
                borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                border: Border.all(
                  color: tokens.danger.withValues(alpha: AppTheme.tintBorder),
                ),
              ),
              child: Text(
                'PDF',
                style: AppText.of(context).badge.copyWith(color: tokens.danger),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: text.labelLarge,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    [
                      if (pages != null) l.pageCount(pages),
                      if (size != null)
                        '${(size / 1024).toStringAsFixed(0)} KB',
                      path,
                    ].join(' · '),
                    style: text.labelSmall?.copyWith(color: tokens.textFaint),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            if (!kIsWeb) ComponentButton(
              label: l.cardOpen,
              icon: LucideIcons.externalLink,
              onPressed: size == null ? null : () => openFile(path),
            ),
            if (!kIsWeb) const SizedBox(width: 6),
            if (!kIsWeb) ComponentButton(
              label: l.cardShowInFolder,
              icon: LucideIcons.folderOpen,
              onPressed: size == null ? null : () => revealFile(path),
            ),
          ],
        ),
      ),
    );
  }
}

/// `approval`: the agent waits for the user before a destructive tool.
class ApprovalCard extends ConsumerWidget {
  const ApprovalCard({super.key, required this.props});

  final Map<String, dynamic> props;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = AppTokens.of(context);
    final text = Theme.of(context).textTheme;
    final l = context.l10n;
    final status = propString(props['status']) ?? CardStatus.pending;
    final threadId = propString(props['threadId']);
    final id = propString(props['id']);
    final agent = ref.read(agentProvider.notifier);
    final pending =
        status == CardStatus.pending && threadId != null && id != null;

    return CardWidth(
      maxWidth: CardWidth.compact,
      child: ComponentFrame(
        icon: LucideIcons.shieldAlert,
        title: l.cardApprovalNeeded,
        subtitle: propString(props['tool']),
        accent: pending ? tokens.warning : null,
        actions: [
          if (!pending)
            Pill(
              switch (status) {
                CardStatus.approved => l.cardApproved,
                CardStatus.expired => l.cardExpired,
                _ => l.cardRejected,
              },
              icon: switch (status) {
                CardStatus.approved => LucideIcons.check,
                CardStatus.expired => LucideIcons.clock,
                _ => LucideIcons.x,
              },
              color: status == CardStatus.approved
                  ? tokens.success
                  : tokens.textMuted,
            ),
        ],
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(propString(props['title']) ?? '', style: text.labelLarge),
            const SizedBox(height: 4),
            AgentMarkdown(propString(props['description']) ?? ''),
            if (pending) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  ComponentButton(
                    label: l.cardApprove,
                    icon: LucideIcons.check,
                    danger: true,
                    onPressed: () =>
                        agent.resolveApproval(threadId, id, approved: true),
                  ),
                  const SizedBox(width: 6),
                  ComponentButton(
                    label: l.cardReject,
                    onPressed: () =>
                        agent.resolveApproval(threadId, id, approved: false),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// `change_summary`: what a turn changed, with Undo and Review — the
/// equivalent of "Edited N files" in a coding agent.
class ChangeSummaryCard extends ConsumerStatefulWidget {
  const ChangeSummaryCard({super.key, required this.props});

  final Map<String, dynamic> props;

  @override
  ConsumerState<ChangeSummaryCard> createState() => _ChangeSummaryCardState();
}

class _ChangeSummaryCardState extends ConsumerState<ChangeSummaryCard> {
  var _reverted = false;

  @override
  Widget build(BuildContext context) {
    final tokens = AppTokens.of(context);
    final text = Theme.of(context).textTheme;
    final l = context.l10n;
    final p = widget.props;
    final pages = propMaps(p['pages']);
    final threadId = propString(p['threadId']);
    final turnId = propString(p['turnId']);
    final documentId = propString(p['documentId']);
    final actions = AppActions(ref);

    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: CardWidth.wider),
      child: ComponentFrame(
        icon: LucideIcons.fileDiff,
        title: l.cardEditedPages(pages.length),
        subtitle: propString(p['title']),
        padding: EdgeInsets.zero,
        actions: [
          if (_reverted)
            Pill(l.cardReverted, icon: LucideIcons.undo2)
          else
            TextButton.icon(
              onPressed:
                  threadId == null || turnId == null || documentId == null
                  ? null
                  : () {
                      ref
                          .read(agentProvider.notifier)
                          .undoTurn(threadId, turnId, documentId);
                      setState(() => _reverted = true);
                    },
              icon: const Icon(LucideIcons.undo2, size: 13),
              label: Text(l.cardUndo),
              style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
            ),
          const SizedBox(width: 4),
          ComponentButton(
            label: l.cardReview,
            onPressed: () => actions.openReview(turnId: turnId),
          ),
        ],
        child: Column(
          children: [
            for (final e in pages)
              InkWell(
                onTap: documentId == null || e['kind'] == 'removed'
                    ? null
                    : () => actions.showPage(documentId, propInt(e['page'])),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  child: Row(
                    children: [
                      Icon(
                        switch (e['kind']) {
                          'added' => LucideIcons.filePlus,
                          'removed' => LucideIcons.fileMinus,
                          _ => LucideIcons.filePen,
                        },
                        size: 14,
                        color: switch (e['kind']) {
                          'added' => tokens.success,
                          'removed' => tokens.danger,
                          _ => tokens.textMuted,
                        },
                      ),
                      const SizedBox(width: 10),
                      Text(
                        l.pageNumber(propInt(e['page'])),
                        style: text.labelMedium?.copyWith(
                          color: tokens.textMuted,
                        ),
                      ),
                      Text(
                        '  /  ',
                        style: text.labelMedium?.copyWith(
                          color: tokens.textFaint,
                        ),
                      ),
                      Expanded(
                        child: Text(
                          propString(e['title']) ?? '',
                          style: text.labelLarge,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
