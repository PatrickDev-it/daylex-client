import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/theme/app_theme.dart';
import '../../features/document/model/document.dart';
import '../../features/document/model/operations.dart';
import '../../features/document/service/document_service.dart';
import '../../features/workspace/ui_state.dart';
import '../../features/workspace/viewer_state.dart';
import '../../features/workspace/workspace_state.dart';
import '../../l10n/l10n.dart';
import '../../l10n/labels.dart';
import '../app_actions.dart';
import '../common/widgets.dart';
import 'block_editors.dart';
import 'synced_text_field.dart';

export 'synced_text_field.dart';

/// How long a field waits after the last keystroke before it commits: long enough not to make an undo step
/// per letter, short enough that the preview follows the typing.

/// Structured editor for the active document. Every change is a
/// [DocOperation], exactly like the agent's edits, so both share undo/redo.
class OutlineEditor extends ConsumerWidget {
  const OutlineEditor({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final doc = ref.watch(activeDocumentProvider);
    if (doc == null) return const SizedBox();
    final tokens = AppTokens.of(context);
    final l = context.l10n;

    return ColoredBox(
      color: tokens.canvas,
      child: ListView(
        padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 24),
        children: [
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 760),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _DetailsCard(doc: doc),
                  for (final (i, page) in doc.pages.indexed) ...[
                    const SizedBox(height: 16),
                    _PageCard(
                      key: ValueKey(page.id),
                      documentId: doc.id,
                      page: page,
                      index: i,
                      pageCount: doc.pages.length,
                    ),
                  ],
                  const SizedBox(height: 16),
                  OutlinedButton.icon(
                    onPressed: () => _apply(ref, doc.id, [
                      AddPage(
                        DocPage(
                          id: newId(),
                          title: l.editorNewSection,
                          blocks: [
                            HeadingBlock(id: newId(), text: l.editorNewSection),
                            ParagraphBlock(id: newId(), text: ''),
                          ],
                        ),
                      ),
                    ]),
                    icon: const Icon(LucideIcons.plus, size: 15),
                    label: Text(l.editorAddPage),
                  ),
                  const SizedBox(height: 48),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Applies [ops] to [documentId], named by the widget that was built for it:
/// a field committing as it unmounts (the user switched chat while typing)
/// must still edit the document it showed, not whichever is active by then.
void _apply(WidgetRef ref, String documentId, List<DocOperation> ops, {String? label}) {
  // Read now: from a field's dispose the widget behind [ref] is still mounted, after the frame it may not be.
  final workspace = ref.read(workspaceProvider.notifier);
  void run() {
    try {
      workspace.apply(ops, documentId: documentId, label: label);
    } on DocumentOperationException catch (e) {
      toast(e.localized(ref.read(l10nProvider)));
    }
  }

  // Mid-frame (that same dispose) the tree is locked against rebuilds: the edit lands right after it.
  if (SchedulerBinding.instance.schedulerPhase == SchedulerPhase.persistentCallbacks) {
    SchedulerBinding.instance.addPostFrameCallback((_) => run());
  } else {
    run();
  }
}

// ---------------------------------------------------------------------------
// Document details
// ---------------------------------------------------------------------------

class _DetailsCard extends ConsumerWidget {
  const _DetailsCard({required this.doc});

  final PaperDocument doc;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = AppTokens.of(context);
    final text = Theme.of(context).textTheme;
    final l = context.l10n;
    final meta = doc.metadata;

    Widget field(String label, String value, void Function(String) commit) => Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: text.labelSmall),
        const SizedBox(height: 4),
        SyncedTextField(value: value, onCommit: commit, boxed: true),
      ],
    );

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Text(l.editorDetailsTitle, style: text.titleSmall),
                const Spacer(),
                PopupMenuButton<DocumentStatus>(
                  tooltip: l.editorStatus,
                  onSelected: (s) => _apply(ref, doc.id, [UpdateMetadata(status: s)]),
                  itemBuilder: (_) => [
                    for (final s in DocumentStatus.values)
                      PopupMenuItem(value: s, height: AppTheme.controlHeight, child: Text(l.docStatus(s))),
                  ],
                  child: Pill(
                    l.docStatus(meta.status),
                    icon: LucideIcons.chevronDown,
                    color: DocStatusPill.colorOf(context, meta.status),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            field(l.editorFieldTitle, meta.title, (v) => _apply(ref, doc.id, [UpdateMetadata(title: v)])),
            const SizedBox(height: 12),
            field(l.editorFieldSubtitle, meta.subtitle, (v) => _apply(ref, doc.id, [UpdateMetadata(subtitle: v)])),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: field(
                    l.editorFieldClient,
                    meta.client,
                    (v) => _apply(ref, doc.id, [UpdateMetadata(client: v)]),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: field(
                    l.editorFieldBrand,
                    doc.theme.brandName,
                    (v) => _apply(ref, doc.id, [SetTheme(doc.theme.copyWith(brandName: v))]),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            // On the cover as "Prepared by" when set.
            field(l.editorFieldAuthor, meta.author, (v) => _apply(ref, doc.id, [UpdateMetadata(author: v)])),
            const SizedBox(height: 16),
            Text(l.editorAccent, style: text.labelSmall),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final c in kDocAccentPalette)
                  Tooltip(
                    message: '#${(c & 0xFFFFFF).toRadixString(16).toUpperCase()}',
                    child: InkWell(
                      customBorder: const CircleBorder(),
                      onTap: () => _apply(ref, doc.id, [SetTheme(doc.theme.copyWith(accent: c))]),
                      child: AnimatedContainer(
                        duration: AppTheme.normal,
                        width: 22,
                        height: 22,
                        decoration: BoxDecoration(
                          color: Color(c),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: doc.theme.accent == c
                                ? Theme.of(context).colorScheme.onSurface
                                : tokens.borderStrong,
                            width: doc.theme.accent == c ? 2 : 1,
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Pages
// ---------------------------------------------------------------------------

class _PageCard extends ConsumerWidget {
  const _PageCard({
    super.key,
    required this.documentId,
    required this.page,
    required this.index,
    required this.pageCount,
  });

  final String documentId;
  final DocPage page;
  final int index;
  final int pageCount;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = AppTokens.of(context);
    final text = Theme.of(context).textTheme;
    final l = context.l10n;

    return Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 8, 10),
            child: Row(
              children: [
                Text(
                  l.pageNumber(index + 1).toUpperCase(),
                  style: text.labelSmall?.copyWith(letterSpacing: 0.8, fontWeight: FontWeight.w600),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: SyncedTextField(
                    value: page.title,
                    hint: l.editorSectionTitleHint,
                    style: text.titleSmall,
                    onCommit: (v) => _apply(ref, documentId, [UpdatePage(index, title: v)]),
                  ),
                ),
                PopupMenuButton<PageLayout>(
                  tooltip: l.editorLayout,
                  onSelected: (layout) => _apply(ref, documentId, [UpdatePage(index, layout: layout)]),
                  itemBuilder: (_) => [
                    for (final layout in PageLayout.values)
                      CheckedPopupMenuItem(
                        value: layout,
                        checked: layout == page.layout,
                        height: AppTheme.controlHeight,
                        child: Text(l.layout(layout)),
                      ),
                  ],
                  child: Pill(l.layout(page.layout), icon: LucideIcons.layout),
                ),
                const SizedBox(width: 4),
                ToolbarButton(
                  icon: LucideIcons.eye,
                  tooltip: l.editorShowInPreview,
                  onPressed: () {
                    ref.read(uiProvider.notifier).setEditorMode(EditorMode.preview);
                    ref.read(viewerProvider.notifier).reveal(index + 1);
                  },
                ),
                ToolbarButton(
                  icon: LucideIcons.arrowUp,
                  tooltip: l.editorMoveUp,
                  onPressed: index > 0 ? () => _apply(ref, documentId, [MovePage(index, index - 1)]) : null,
                ),
                ToolbarButton(
                  icon: LucideIcons.arrowDown,
                  tooltip: l.editorMoveDown,
                  onPressed: index < pageCount - 1 ? () => _apply(ref, documentId, [MovePage(index, index + 1)]) : null,
                ),
                ToolbarButton(
                  icon: LucideIcons.trash2,
                  tooltip: l.editorDeletePage,
                  onPressed: pageCount > 1 ? () => _apply(ref, documentId, [DeletePage(index)]) : null,
                ),
              ],
            ),
          ),
          Divider(color: tokens.border),
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final (i, block) in page.blocks.indexed)
                  _BlockRow(
                    key: ValueKey(block.id),
                    documentId: documentId,
                    block: block,
                    isFirst: i == 0,
                    isLast: i == page.blocks.length - 1,
                  ),
                _AddBlockButton(documentId: documentId, pageIndex: index),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AddBlockButton extends ConsumerWidget {
  const _AddBlockButton({required this.documentId, required this.pageIndex});

  final String documentId;
  final int pageIndex;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    return Align(
      alignment: Alignment.centerLeft,
      child: PopupMenuButton<BlockKind>(
        tooltip: l.editorAddBlock,
        onSelected: (kind) => _apply(ref, documentId, [InsertBlock(pageIndex, _emptyBlock(l, kind))]),
        itemBuilder: (_) => [
          for (final kind in BlockKind.values)
            PopupMenuItem(
              value: kind,
              height: AppTheme.controlHeight,
              child: Row(
                children: [Icon(_blockIcon(kind), size: 15), const SizedBox(width: 10), Text(l.blockKind(kind))],
              ),
            ),
        ],
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(LucideIcons.plus, size: 14, color: AppTokens.of(context).textMuted),
              const SizedBox(width: 6),
              Text(l.editorAddBlock, style: Theme.of(context).textTheme.bodySmall),
            ],
          ),
        ),
      ),
    );
  }
}

/// A new block of [kind], with placeholder text in the lawyer's language.
DocBlock _emptyBlock(AppLocalizations l, BlockKind kind) => switch (kind) {
  BlockKind.heading => HeadingBlock(id: newId(), text: l.blockHeading, level: 2),
  BlockKind.paragraph => ParagraphBlock(id: newId(), text: ''),
  BlockKind.bullets => BulletListBlock(id: newId(), items: [l.editorNewBulletItem]),
  BlockKind.table => TableBlock(
    id: newId(),
    columns: [l.editorNewTableItem, l.editorNewTableValue],
    rows: const [
      ['', ''],
    ],
  ),
  BlockKind.metrics => MetricsBlock(
    id: newId(),
    items: [for (var i = 0; i < 3; i++) Metric(label: l.editorNewMetric, value: '0')],
  ),
  BlockKind.quote => QuoteBlock(id: newId(), text: l.blockQuote),
  BlockKind.callout => CalloutBlock(id: newId(), title: l.editorNewCallout),
  BlockKind.image => ImageBlock(id: newId(), caption: l.blockImage),
};

IconData _blockIcon(BlockKind kind) => switch (kind) {
  BlockKind.heading => LucideIcons.heading,
  BlockKind.paragraph => LucideIcons.type,
  BlockKind.bullets => LucideIcons.list,
  BlockKind.table => LucideIcons.table,
  BlockKind.metrics => LucideIcons.barChart3,
  BlockKind.quote => LucideIcons.quote,
  BlockKind.callout => LucideIcons.info,
  BlockKind.image => LucideIcons.image,
};

// ---------------------------------------------------------------------------
// Blocks
// ---------------------------------------------------------------------------

class _BlockRow extends ConsumerStatefulWidget {
  const _BlockRow({
    super.key,
    required this.documentId,
    required this.block,
    required this.isFirst,
    required this.isLast,
  });

  final String documentId;
  final DocBlock block;
  final bool isFirst;
  final bool isLast;

  @override
  ConsumerState<_BlockRow> createState() => _BlockRowState();
}

class _BlockRowState extends ConsumerState<_BlockRow> {
  void _update(DocBlock block) => _apply(ref, widget.documentId, [UpdateBlock(block)]);

  @override
  Widget build(BuildContext context) {
    final tokens = AppTokens.of(context);
    final l = context.l10n;
    final block = widget.block;
    return HoverBuilder(
      builder: (context, hover) => AnimatedContainer(
        duration: AppTheme.fast,
        margin: const EdgeInsets.only(bottom: 2),
        padding: const EdgeInsets.symmetric(vertical: 4),
        decoration: BoxDecoration(
          color: hover ? tokens.hover.withValues(alpha: AppTheme.hoverFade) : null,
          borderRadius: BorderRadius.circular(AppTheme.radius),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 32,
              child: Padding(
                padding: const EdgeInsets.only(top: 9),
                child: Tooltip(
                  message: l.blockKind(block.kind),
                  child: Icon(_blockIcon(block.kind), size: 14, color: tokens.textFaint),
                ),
              ),
            ),
            Expanded(child: _editorFor(block)),
            AnimatedOpacity(
              duration: AppTheme.fast,
              opacity: hover ? 1 : 0,
              child: Row(
                children: [
                  ToolbarButton(
                    icon: LucideIcons.arrowUp,
                    tooltip: l.editorMoveUp,
                    onPressed: widget.isFirst ? null : () => _apply(ref, widget.documentId, [MoveBlock(block.id, -1)]),
                  ),
                  ToolbarButton(
                    icon: LucideIcons.arrowDown,
                    tooltip: l.editorMoveDown,
                    onPressed: widget.isLast ? null : () => _apply(ref, widget.documentId, [MoveBlock(block.id, 1)]),
                  ),
                  ToolbarButton(
                    icon: LucideIcons.trash2,
                    tooltip: l.editorRemoveBlock,
                    onPressed: () => _apply(ref, widget.documentId, [RemoveBlock(block.id)]),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _editorFor(DocBlock block) {
    final text = Theme.of(context).textTheme;
    final l = context.l10n;
    final muted = text.bodySmall;
    switch (block) {
      case HeadingBlock():
        final style = switch (block.level) {
          1 => text.headlineSmall,
          2 => text.titleLarge,
          _ => text.titleSmall,
        };
        return SyncedTextField(
          value: block.text,
          style: style,
          hint: l.blockHeading,
          onCommit: (v) => _update(block.copyWith(text: v)),
        );
      case ParagraphBlock():
        return SyncedTextField(
          value: block.text,
          multiline: true,
          hint: l.editorParagraphHint,
          onCommit: (v) => _update(block.copyWith(text: v)),
        );
      case BulletListBlock():
        return SyncedTextField(
          value: block.items.map((i) => '• $i').join('\n'),
          multiline: true,
          hint: l.editorBulletsHint,
          onCommit: (v) => _update(
            block.copyWith(
              items: v
                  .split('\n')
                  .map((line) => line.replaceFirst(RegExp(r'^\s*[•\-*]\s*'), '').trim())
                  .where((line) => line.isNotEmpty)
                  .toList(),
            ),
          ),
        );
      case QuoteBlock():
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SyncedTextField(
              value: block.text,
              multiline: true,
              style: text.titleMedium?.copyWith(fontWeight: FontWeight.w500),
              onCommit: (v) => _update(block.copyWith(text: v)),
            ),
            SyncedTextField(
              value: block.author,
              hint: l.editorQuoteAuthorHint,
              style: muted,
              onCommit: (v) => _update(block.copyWith(author: v)),
            ),
          ],
        );
      case CalloutBlock():
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SyncedTextField(
              value: block.title,
              style: text.titleSmall,
              hint: l.editorCalloutTitleHint,
              onCommit: (v) => _update(block.copyWith(title: v)),
            ),
            SyncedTextField(
              value: block.text,
              multiline: true,
              hint: l.editorCalloutTextHint,
              onCommit: (v) => _update(block.copyWith(text: v)),
            ),
          ],
        );
      case MetricsBlock():
        return MetricsEditor(block: block, onChanged: _update);
      case TableBlock():
        return TableEditor(block: block, onChanged: _update);
      case ImageBlock():
        return ImageEditor(block: block, onChanged: _update);
    }
  }
}
