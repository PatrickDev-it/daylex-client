import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/theme/app_theme.dart';
import '../../features/document/model/document.dart';
import '../../features/workspace/ui_state.dart';
import '../../features/workspace/viewer_state.dart';
import '../../features/workspace/pdf_export.dart';
import '../../features/workspace/workspace_state.dart';
import '../../l10n/l10n.dart';
import '../app_actions.dart';
import '../common/time_format.dart';
import '../common/widgets.dart';
import '../document/outline_editor.dart';
import '../document/pdf_preview.dart';
import '../shortcuts.dart';
import 'document_review_strip.dart';

/// Below this width the toolbar's title area keeps the title and drops the status pill rather than overflow.
const _kStatusPillMinWidth = 140.0;

/// The status bar under the preview: a single line of small labels.
const _kStatusBarHeight = 28.0;

/// The tooltip of a control that has a global shortcut: what it does, then its keys.
String _withKeys(String label, AppShortcut s) => '$label  ·  ${s.keys}';

/// Live preview (or outline editor) of the chat's document. Re-renders as
/// the agent edits it.
class PreviewTab extends ConsumerWidget {
  const PreviewTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final doc = ref.watch(activeDocumentProvider);
    final mode = ref.watch(uiProvider.select((s) => s.editorMode));
    if (doc == null) {
      return EmptyState(
        icon: LucideIcons.fileText,
        title: l.previewNotFoundTitle,
        message: l.previewNotFoundMessage,
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Toolbar(doc: doc, mode: mode),
        DocumentReviewStrip(document: doc),
        const Divider(),
        Expanded(
          child: AnimatedSwitcher(
            duration: AppTheme.normal,
            child: mode == EditorMode.preview
                ? const PdfPreview(key: ValueKey('preview'))
                : const OutlineEditor(key: ValueKey('edit')),
          ),
        ),
        const Divider(),
        _StatusBar(doc: doc),
      ],
    );
  }
}

class _Toolbar extends ConsumerWidget {
  const _Toolbar({required this.doc, required this.mode});

  final PaperDocument doc;
  final EditorMode mode;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final text = Theme.of(context).textTheme;
    final actions = AppActions(ref);
    final history = ref.watch(
      workspaceProvider.select((s) => s.historyOf(doc.id)),
    );

    return PanelToolbar(
      children: [
        SegmentedButton<EditorMode>(
          showSelectedIcon: false,
          style: const ButtonStyle(visualDensity: VisualDensity.compact),
          segments: [
            ButtonSegment(
              value: EditorMode.preview,
              icon: const Icon(LucideIcons.eye, size: 14),
              label: Text(l.previewModePreview),
              tooltip: _withKeys(
                AppShortcut.preview.label(l),
                AppShortcut.preview,
              ),
            ),
            ButtonSegment(
              value: EditorMode.edit,
              icon: const Icon(LucideIcons.pencil, size: 14),
              label: Text(l.previewModeEdit),
              tooltip: _withKeys(AppShortcut.edit.label(l), AppShortcut.edit),
            ),
          ],
          selected: {mode},
          onSelectionChanged: (s) => actions.setMode(s.first),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: LayoutBuilder(
            builder: (context, c) => Row(
              children: [
                Flexible(
                  child: Text(
                    doc.title,
                    style: text.labelLarge,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (c.maxWidth >= _kStatusPillMinWidth) ...[
                  const SizedBox(width: 8),
                  DocStatusPill(doc.metadata.status),
                ],
              ],
            ),
          ),
        ),
        ToolbarButton(
          icon: LucideIcons.undo2,
          tooltip: history.undo.isEmpty
              ? AppShortcut.undo.label(l)
              : l.previewUndoStep(history.undo.last.$2),
          shortcut: AppShortcut.undo,
          onPressed: history.undo.isEmpty ? null : actions.undo,
        ),
        ToolbarButton(
          icon: LucideIcons.redo2,
          tooltip: history.redo.isEmpty
              ? AppShortcut.redo.label(l)
              : l.previewRedoStep(history.redo.last.$2),
          shortcut: AppShortcut.redo,
          onPressed: history.redo.isEmpty ? null : actions.redo,
        ),
        const SizedBox(width: 4),
        Tooltip(
          message: _withKeys(l.exportPdf, AppShortcut.export),
          child: FilledButton.icon(
            onPressed: () => actions.exportDocument(doc.id),
            style: FilledButton.styleFrom(visualDensity: VisualDensity.compact),
            icon: const Icon(LucideIcons.download, size: 14),
            label: Text(l.previewExport),
          ),
        ),
      ],
    );
  }
}

class _StatusBar extends ConsumerWidget {
  const _StatusBar({required this.doc});

  final PaperDocument doc;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final tokens = AppTokens.of(context);
    final style = Theme.of(context).textTheme.labelSmall;
    final words = doc.pages.fold(0, (sum, p) => sum + p.wordCount);
    final status = ref.watch(renderedPdfProvider.select((r) => r.status));
    final viewer = ref.watch(viewerProvider);

    Widget item(IconData icon, String label) => Padding(
      padding: const EdgeInsets.only(right: 14),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: tokens.textFaint),
          const SizedBox(width: 5),
          Text(label, style: style),
        ],
      ),
    );

    return Container(
      height: _kStatusBarHeight,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      color: tokens.panel,
      child: Row(
        children: [
          item(
            LucideIcons.files,
            l.previewPageOf(viewer.page, doc.pages.length),
          ),
          item(LucideIcons.type, l.wordCount(words)),
          item(LucideIcons.zoomIn, '${(viewer.zoom * 100).round()}%'),
          const Spacer(),
          switch (status) {
            PreviewStatus.rendering => item(
              LucideIcons.loaderCircle,
              l.previewRendering,
            ),
            PreviewStatus.outdated => item(
              LucideIcons.alertTriangle,
              l.previewOutdated,
            ),
            PreviewStatus.upToDate => item(
              LucideIcons.circleCheck,
              l.previewUpToDate(
                relativeTime(l, doc.metadata.updatedAt, DateTime.now()),
              ),
            ),
          },
        ],
      ),
    );
  }
}
