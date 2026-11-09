import 'package:deskify/deskify.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/theme/app_theme.dart';
import '../../features/document/data/doc_templates.dart';
import '../../features/document/model/document.dart';
import '../../features/workspace/workspace_state.dart';
import '../../l10n/l10n.dart';
import '../app_actions.dart';
import '../chat/components/page_cards.dart';
import '../common/time_format.dart';
import '../common/widgets.dart';

/// Documents of the chat's project, the other projects and the templates.
/// Clicking a document opens it in a preview tab.
class LibraryTab extends ConsumerWidget {
  const LibraryTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final text = Theme.of(context).textTheme;
    final tokens = AppTokens.of(context);
    final l = context.l10n;
    final ws = ref.watch(workspaceProvider);
    final thread = ws.activeThread;
    final actions = AppActions(ref);
    final here = thread == null ? const <PaperDocument>[] : ws.documentsIn(thread.projectId);
    final others = ws.documents.values.where((d) => d.projectId != thread?.projectId).toList();

    Widget heading(String label) => Padding(
      padding: const EdgeInsets.fromLTRB(0, 4, 0, 10),
      child: Text(label, style: text.labelMedium?.copyWith(color: tokens.textMuted)),
    );

    Widget grid(List<PaperDocument> docs) =>
        Wrap(spacing: 14, runSpacing: 16, children: [for (final d in docs) _DocTile(doc: d)]);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (thread != null) ...[
          heading(ws.project(thread.projectId)?.name ?? l.libraryThisProject),
          if (here.isEmpty) Text(l.libraryNoDocuments, style: text.bodySmall) else grid(here),
          const SizedBox(height: 24),
        ],
        if (others.isNotEmpty) ...[heading(l.libraryOtherProjects), grid(others), const SizedBox(height: 24)],
        heading(l.libraryTemplates),
        for (final t in docTemplates)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: TemplateTile(template: t, onTap: () => actions.createFromTemplate(t)),
          ),
      ],
    );
  }
}

class _DocTile extends ConsumerWidget {
  const _DocTile({required this.doc});

  final PaperDocument doc;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final text = Theme.of(context).textTheme;
    final l = context.l10n;
    final ws = ref.read(workspaceProvider.notifier);
    final actions = AppActions(ref);
    final open = ref.watch(activeThreadProvider.select((t) => t?.documentId == doc.id));

    return DeskRightClickMenu(
      items: [
        DeskContextMenuItem(
          label: l.libraryOpenPreview,
          icon: LucideIcons.panelRightOpen,
          onTap: () => actions.openDocument(doc.id),
        ),
        DeskContextMenuItem(
          label: l.exportPdf,
          icon: LucideIcons.download,
          onTap: () => actions.exportDocument(doc.id),
        ),
        DeskContextMenuItem(label: l.libraryDuplicate, icon: LucideIcons.copy, onTap: () => ws.duplicate(doc.id)),
        DeskContextMenuItem.divider(),
        DeskContextMenuItem(label: l.delete, icon: LucideIcons.trash2, onTap: () => actions.deleteDocument(doc.id)),
      ],
      child: SizedBox(
        width: 132,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              decoration: open
                  ? BoxDecoration(
                      borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                      border: Border.all(color: Theme.of(context).colorScheme.primary, width: 2),
                    )
                  : null,
              padding: EdgeInsets.all(open ? 2 : 4),
              child: LivePageThumbnail(documentId: doc.id, width: 124, onTap: () => actions.openDocument(doc.id)),
            ),
            const SizedBox(height: 6),
            Text(doc.title, style: text.labelMedium, maxLines: 2, overflow: TextOverflow.ellipsis),
            Text(
              '${l.pageCount(doc.pages.length)} · ${relativeTime(l, doc.metadata.updatedAt, DateTime.now())}',
              style: text.labelSmall,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}
