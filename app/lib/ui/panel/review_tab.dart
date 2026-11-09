import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/theme/app_theme.dart';
import '../../features/agent/agent_controller.dart';
import '../../features/document/render/page_images.dart';
import '../../features/document/render/pdf_renderer.dart';
import '../../features/document/service/document_diff.dart';
import '../../features/workspace/review_state.dart';
import '../../l10n/l10n.dart';
import '../../l10n/labels.dart';
import '../app_actions.dart';
import '../chat/components/page_cards.dart';
import '../common/time_format.dart';
import '../common/widgets.dart';

/// Below this width the changed pages go above the diff instead of beside it: two columns would be too narrow.
const _kSideBySideMinWidth = 620.0;

/// The before/after renders stop growing here, so a wide panel does not blow them up past legibility.
const _kRendersMaxWidth = 620.0;

/// Changes made by one agent turn: changed pages on the side, before/after
/// renders and a text diff of the selected page.
class ReviewTab extends ConsumerStatefulWidget {
  const ReviewTab({super.key, required this.threadId});

  final String threadId;

  @override
  ConsumerState<ReviewTab> createState() => _ReviewTabState();
}

/// One changed page of a turn, with the snapshots it compares.
typedef _Entry = ({String documentId, String before, String after, PageChange change});

class _ReviewTabState extends ConsumerState<ReviewTab> {
  var _selected = 0;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final tokens = AppTokens.of(context);
    final text = Theme.of(context).textTheme;
    final turns = ref.watch(
      sessionProvider(widget.threadId).select((s) => s.turns.where((t) => t.changes.isNotEmpty).toList()),
    );
    final wanted = ref.watch(reviewTurnProvider);
    final snapshots = ref.read(snapshotStoreProvider);

    if (turns.isEmpty) {
      return EmptyState(icon: LucideIcons.gitCompare, title: l.reviewEmptyTitle, message: l.reviewEmptyMessage);
    }

    final turn = turns.where((t) => t.id == wanted).firstOrNull ?? turns.last;
    final entries = <_Entry>[
      for (final MapEntry(key: docId, value: (before, after)) in turn.changes.entries)
        if (snapshots.get(before) case final b?)
          if (snapshots.get(after) case final a?)
            for (final change in comparePages(b, a)) (documentId: docId, before: before, after: after, change: change),
    ];
    final selected = entries.isEmpty ? null : entries[_selected.clamp(0, entries.length - 1)];
    final added = entries.fold(0, (s, e) {
      final d = e.change.wordsAfter - e.change.wordsBefore;
      return d > 0 ? s + d : s;
    });
    final removed = entries.fold(0, (s, e) {
      final d = e.change.wordsAfter - e.change.wordsBefore;
      return d < 0 ? s - d : s;
    });

    final now = DateTime.now();
    final header = PanelToolbar(
      children: [
        PopupMenuButton<String>(
          tooltip: l.reviewPickTurn,
          position: PopupMenuPosition.under,
          onSelected: (id) {
            setState(() => _selected = 0);
            ref.read(reviewTurnProvider.notifier).select(id);
          },
          itemBuilder: (_) => [
            for (final (i, t) in turns.reversed.indexed)
              PopupMenuItem(
                value: t.id,
                height: 40,
                child: SizedBox(
                  width: 300,
                  child: Row(
                    children: [
                      Icon(t.id == turn.id ? LucideIcons.check : LucideIcons.messageSquare, size: 14),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          i == 0 ? l.reviewLastTurnPrompt(t.prompt) : t.prompt,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(relativeTime(l, t.endedAt, now), style: text.labelSmall),
                    ],
                  ),
                ),
              ),
          ],
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  turn == turns.last ? l.reviewLastTurn : l.reviewTurnNumber(turns.indexOf(turn) + 1),
                  style: text.labelLarge,
                ),
                const SizedBox(width: 4),
                Icon(LucideIcons.chevronDown, size: 14, color: tokens.textFaint),
              ],
            ),
          ),
        ),
        const SizedBox(width: 8),
        Text('+$added', style: text.labelMedium?.copyWith(color: tokens.success)),
        const SizedBox(width: 6),
        Text('−$removed', style: text.labelMedium?.copyWith(color: tokens.danger)),
        const SizedBox(width: 4),
        Text(l.reviewWordsUnit(added + removed), style: text.labelSmall?.copyWith(color: tokens.textFaint)),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            turn.prompt,
            style: text.bodySmall?.copyWith(color: tokens.textFaint),
            overflow: TextOverflow.ellipsis,
          ),
        ),
        TextButton.icon(
          onPressed: () {
            for (final docId in turn.changes.keys) {
              ref.read(agentProvider.notifier).undoTurn(widget.threadId, turn.id, docId);
            }
            toast(l.reviewTurnReverted);
          },
          style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
          icon: const Icon(LucideIcons.undo2, size: 13),
          label: Text(l.reviewUndoTurn),
        ),
      ],
    );

    final list = _ChangeList(entries: entries, selected: selected, onSelect: (i) => setState(() => _selected = i));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        header,
        const Divider(),
        Expanded(
          child: LayoutBuilder(
            builder: (context, c) {
              final detail = selected == null
                  ? EmptyState(
                      icon: LucideIcons.fileDiff,
                      title: l.reviewNothingToCompareTitle,
                      message: l.reviewNothingToCompareMessage,
                    )
                  : _PageDiff(key: ValueKey(selected), entry: selected);
              if (c.maxWidth < _kSideBySideMinWidth) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    ConstrainedBox(constraints: const BoxConstraints(maxHeight: 150), child: list),
                    const Divider(),
                    Expanded(child: detail),
                  ],
                );
              }
              return Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(child: detail),
                  const VerticalDivider(width: 1),
                  SizedBox(width: 220, child: list),
                ],
              );
            },
          ),
        ),
      ],
    );
  }
}

/// Changed pages of the turn, like the file tree of a code review.
class _ChangeList extends StatelessWidget {
  const _ChangeList({required this.entries, required this.selected, required this.onSelect});

  final List<_Entry> entries;
  final _Entry? selected;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    final tokens = AppTokens.of(context);
    final text = Theme.of(context).textTheme;
    return ListView(
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 6),
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(8, 4, 8, 6),
          child: Text(
            context.l10n.reviewPagesChanged(entries.length),
            style: text.labelSmall?.copyWith(color: tokens.textFaint),
          ),
        ),
        for (final (i, e) in entries.indexed)
          Material(
            color: e == selected ? tokens.hover : Colors.transparent,
            borderRadius: BorderRadius.circular(AppTheme.radiusSm),
            child: InkWell(
              borderRadius: BorderRadius.circular(AppTheme.radiusSm),
              onTap: () => onSelect(i),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
                child: Row(
                  children: [
                    Icon(
                      switch (e.change.kind) {
                        PageChangeKind.added => LucideIcons.filePlus,
                        PageChangeKind.removed => LucideIcons.fileMinus,
                        PageChangeKind.edited => LucideIcons.filePen,
                      },
                      size: 14,
                      color: switch (e.change.kind) {
                        PageChangeKind.added => tokens.success,
                        PageChangeKind.removed => tokens.danger,
                        PageChangeKind.edited => tokens.warning,
                      },
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '${(e.change.afterIndex ?? e.change.beforeIndex!) + 1}. ${e.change.title}',
                        style: text.labelMedium,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    _WordDelta(e.change),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _WordDelta extends StatelessWidget {
  const _WordDelta(this.change);

  final PageChange change;

  @override
  Widget build(BuildContext context) {
    final tokens = AppTokens.of(context);
    final style = Theme.of(context).textTheme.labelSmall;
    final d = change.wordsAfter - change.wordsBefore;
    if (d == 0) return Text('±0', style: style?.copyWith(color: tokens.textFaint));
    return Text(d > 0 ? '+$d' : '−${-d}', style: style?.copyWith(color: d > 0 ? tokens.success : tokens.danger));
  }
}

/// Before/after renders and the line diff of one page.
class _PageDiff extends ConsumerWidget {
  const _PageDiff({super.key, required this.entry});

  final _Entry entry;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final tokens = AppTokens.of(context);
    final text = Theme.of(context).textTheme;
    final change = entry.change;
    final actions = AppActions(ref);
    final lines = change.lines;

    // [after]: the right-hand side, the page as the turn left it; a tap there opens it in the preview.
    Widget side({required bool after, String? snapshot, int? index}) => Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(after ? l.reviewAfter : l.reviewBefore, style: text.labelMedium?.copyWith(color: tokens.textMuted)),
          const SizedBox(height: 8),
          if (snapshot == null || index == null)
            AspectRatio(
              aspectRatio: kA4AspectRatio,
              child: OutlinedBox(
                radius: AppTheme.radiusXs,
                child: Center(
                  child: Text(
                    after ? l.reviewDeletedPage : l.reviewNewPage,
                    style: text.labelSmall?.copyWith(color: tokens.textFaint),
                  ),
                ),
              ),
            )
          else
            LayoutBuilder(
              builder: (context, c) => PageThumbnail(
                snapshot: snapshot,
                page: index + 1,
                width: c.maxWidth,
                onTap: after ? () => actions.showPage(entry.documentId, index + 1) : null,
              ),
            ),
        ],
      ),
    );

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                '${l.pageNumber((change.afterIndex ?? change.beforeIndex!) + 1)} · ${change.title}',
                style: text.titleSmall,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (change.layoutChanged) Pill('${l.layout(change.before!.layout)} → ${l.layout(change.after!.layout)}'),
          ],
        ),
        const SizedBox(height: 14),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: _kRendersMaxWidth),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              side(after: false, snapshot: change.before == null ? null : entry.before, index: change.beforeIndex),
              const SizedBox(width: 14),
              side(after: true, snapshot: change.after == null ? null : entry.after, index: change.afterIndex),
            ],
          ),
        ),
        const SizedBox(height: 18),
        Text(l.reviewText, style: text.labelMedium?.copyWith(color: tokens.textMuted)),
        const SizedBox(height: 8),
        // Clipped so the coloured diff rows follow the box's rounded corners.
        ClipRRect(
          borderRadius: BorderRadius.circular(AppTheme.radius),
          child: OutlinedBox(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (lines.every((line) => line.op == DiffOp.same))
                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: Text(l.reviewSameText, style: text.bodySmall?.copyWith(color: tokens.textFaint)),
                  ),
                for (final line in lines) _DiffRow(line),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _DiffRow extends StatelessWidget {
  const _DiffRow(this.line);

  final DiffLine line;

  @override
  Widget build(BuildContext context) {
    final tokens = AppTokens.of(context);
    final (sign, color) = switch (line.op) {
      DiffOp.added => ('+', tokens.success),
      DiffOp.removed => ('−', tokens.danger),
      DiffOp.same => (' ', tokens.textMuted),
    };
    final style = AppText.of(context).code
        .copyWith(color: line.op == DiffOp.same ? tokens.textMuted : Theme.of(context).colorScheme.onSurface);
    return Container(
      color: line.op == DiffOp.same ? null : color.withValues(alpha: AppTheme.tintSoft),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 1),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 16,
            child: Text(sign, style: style.copyWith(color: color)),
          ),
          Expanded(child: SelectableText(line.text, style: style)),
        ],
      ),
    );
  }
}
