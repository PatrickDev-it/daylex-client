import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/theme/app_theme.dart';
import '../../../features/document/model/document.dart';
import '../../../features/document/render/page_images.dart';
import '../../../features/workspace/workspace_state.dart';
import '../../../l10n/l10n.dart';
import '../../../l10n/labels.dart';
import '../../app_actions.dart';
import '../../common/widgets.dart';
import 'card_chrome.dart';
import 'card_props.dart';
import 'page_cards.dart';

PaperDocument? _resolve(WidgetRef ref, Map<String, dynamic> props) {
  final snapshot = resolveSnapshot(ref, props);
  return snapshot == null ? null : ref.read(snapshotStoreProvider).get(snapshot);
}

/// `document_card`: a document the agent created or opened.
class DocumentCardComponent extends ConsumerWidget {
  const DocumentCardComponent({super.key, required this.props});

  final Map<String, dynamic> props;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final text = Theme.of(context).textTheme;
    final l = context.l10n;
    final doc = _resolve(ref, props);
    if (doc == null) return const SizedBox.shrink();
    final snapshot = resolveSnapshot(ref, props)!;
    final project = ref.watch(workspaceProvider.select((s) => s.projectOf(doc)));
    final exists = ref.watch(workspaceProvider.select((s) => s.documents.containsKey(doc.id)));
    final actions = AppActions(ref);
    final words = doc.pages.fold(0, (sum, p) => sum + p.wordCount);

    return CardWidth(
      maxWidth: CardWidth.compact,
      child: CardBox(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            PageThumbnail(
              snapshot: snapshot,
              page: 1,
              width: 120,
              onTap: exists ? () => actions.showPage(doc.id, 1) : null,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(color: Color(doc.theme.accent), shape: BoxShape.circle),
                      ),
                      const SizedBox(width: 6),
                      Text(doc.theme.brandName.isEmpty ? l.cardDocument : doc.theme.brandName, style: text.labelSmall),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(doc.title, style: text.titleMedium),
                  if (doc.metadata.subtitle.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(doc.metadata.subtitle, style: text.bodySmall),
                    ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      Pill(l.pageCount(doc.pages.length), icon: LucideIcons.files),
                      Pill(l.wordCount(words), icon: LucideIcons.type),
                      if (doc.metadata.client.isNotEmpty) Pill(doc.metadata.client, icon: LucideIcons.building2),
                      if (project != null) Pill(project.name, icon: LucideIcons.folder),
                      DocStatusPill(doc.metadata.status),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      ComponentButton(
                        label: l.cardOpenPreview,
                        icon: LucideIcons.panelRightOpen,
                        primary: true,
                        onPressed: exists ? () => actions.showPage(doc.id, 1) : null,
                      ),
                      const SizedBox(width: 6),
                      ComponentButton(
                        label: l.cardExport,
                        icon: LucideIcons.download,
                        onPressed: exists ? () => actions.exportDocument(doc.id) : null,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// `document_outline`: pages with layout and how much text each carries.
class DocumentOutlineCard extends ConsumerWidget {
  const DocumentOutlineCard({super.key, required this.props});

  final Map<String, dynamic> props;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = AppTokens.of(context);
    final text = Theme.of(context).textTheme;
    final l = context.l10n;
    final doc = _resolve(ref, props);
    if (doc == null) return const SizedBox.shrink();
    final actions = AppActions(ref);
    final words = [for (final p in doc.pages) p.wordCount];
    final most = words.fold(1, (a, b) => a > b ? a : b);

    return CardWidth(
      maxWidth: CardWidth.medium,
      child: ComponentFrame(
        icon: LucideIcons.listTree,
        title: l.cardOutline,
        subtitle: '${doc.title} · ${l.pageCount(doc.pages.length)}',
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Column(
          children: [
            for (final (i, p) in doc.pages.indexed)
              InkWell(
                onTap: () => actions.showPage(doc.id, i + 1),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 22,
                        child: Text('${i + 1}', style: text.labelMedium?.copyWith(color: tokens.textFaint)),
                      ),
                      Expanded(
                        flex: 5,
                        child: Text(p.title, style: text.bodyMedium, overflow: TextOverflow.ellipsis),
                      ),
                      SizedBox(width: 96, child: Pill(l.layout(p.layout))),
                      Expanded(
                        flex: 4,
                        child: Row(
                          children: [
                            Expanded(
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(AppTheme.radiusXs),
                                child: LinearProgressIndicator(
                                  value: p.wordCount / most,
                                  minHeight: 5,
                                  backgroundColor: tokens.hover,
                                  color: Color(doc.theme.accent).withValues(alpha: 0.75),
                                ),
                              ),
                            ),
                            SizedBox(
                              width: 44,
                              child: Text('${p.wordCount}', textAlign: TextAlign.right, style: text.labelSmall),
                            ),
                          ],
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

/// `chart`: horizontal bars, `{title, unit, series: [{label, value}]}`.
class ChartCard extends StatelessWidget {
  const ChartCard({super.key, required this.props});

  final Map<String, dynamic> props;

  @override
  Widget build(BuildContext context) {
    final tokens = AppTokens.of(context);
    final text = Theme.of(context).textTheme;
    final primary = Theme.of(context).colorScheme.primary;
    final series = [for (final e in propMaps(props['series'])) (e['label']?.toString() ?? '', propDouble(e['value']))];
    if (series.isEmpty) return const SizedBox.shrink();
    final max = series.map((e) => e.$2).reduce((a, b) => a > b ? a : b);
    final unit = propString(props['unit']) ?? '';

    return CardWidth(
      maxWidth: CardWidth.medium,
      child: ComponentFrame(
        icon: LucideIcons.chartBar,
        title: propString(props['title']) ?? context.l10n.cardChart,
        subtitle: unit.isEmpty ? null : unit,
        child: Column(
          children: [
            for (final (label, value) in series)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    SizedBox(
                      width: 170,
                      child: Text(label, style: text.labelMedium, overflow: TextOverflow.ellipsis),
                    ),
                    Expanded(
                      child: LayoutBuilder(
                        builder: (context, c) => Align(
                          alignment: Alignment.centerLeft,
                          child: TweenAnimationBuilder<double>(
                            tween: Tween(begin: 0, end: max == 0 ? 0 : value / max),
                            duration: AppTheme.slow,
                            curve: Curves.easeOutCubic,
                            builder: (context, f, _) => Container(
                              width: (c.maxWidth * f).clamp(2, c.maxWidth),
                              height: 14,
                              decoration: BoxDecoration(
                                color: value == max ? primary : primary.withValues(alpha: 0.35),
                                borderRadius: BorderRadius.circular(AppTheme.radiusXs),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    SizedBox(
                      width: 52,
                      child: Text(
                        value == value.roundToDouble() ? '${value.round()}' : value.toStringAsFixed(1),
                        textAlign: TextAlign.right,
                        style: text.labelMedium?.copyWith(
                          color: value == max ? null : tokens.textMuted,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
