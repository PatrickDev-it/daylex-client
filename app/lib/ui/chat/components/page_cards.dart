import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/theme/app_theme.dart';
import '../../../features/document/render/page_images.dart';
import '../../../features/document/render/pdf_renderer.dart'
    show kA4AspectRatio;
import '../../../features/workspace/workspace_state.dart';
import '../../../l10n/l10n.dart';
import '../../../l10n/labels.dart';
import '../../app_actions.dart';
import '../../common/widgets.dart';
import 'card_chrome.dart';
import 'card_props.dart';

/// A rendered page of a document snapshot, rasterised from the real PDF.
class PageThumbnail extends ConsumerWidget {
  const PageThumbnail({
    super.key,
    required this.snapshot,
    required this.page,
    this.width = 200,
    this.onTap,
  });

  final String snapshot;

  /// 1-based.
  final int page;
  final double width;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = AppTokens.of(context);
    final image = ref.watch(pageImageProvider((snapshot, page - 1)));
    final paper = Container(
      width: width,
      decoration: BoxDecoration(
        // A sheet of paper: white in both themes, like the PDF it shows.
        color: AppTheme.paper,
        borderRadius: BorderRadius.circular(AppTheme.radiusXs),
        border: Border.all(color: tokens.border),
        boxShadow: [
          BoxShadow(
            color: AppTheme.pageShadow,
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: AspectRatio(
        aspectRatio: kA4AspectRatio,
        child: switch (image) {
          AsyncData(:final value) => Image.memory(
            value,
            fit: BoxFit.cover,
            filterQuality: FilterQuality.medium,
            gaplessPlayback: true,
          ),
          AsyncError() => Center(
            child: Icon(LucideIcons.fileWarning, color: tokens.textFaint),
          ),
          _ => const Padding(
            padding: EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Skeleton(width: 50, height: 6),
                SizedBox(height: 14),
                Skeleton(height: 10),
                SizedBox(height: 8),
                Skeleton(height: 5),
                SizedBox(height: 5),
                Skeleton(height: 5),
                SizedBox(height: 5),
                Skeleton(width: 70, height: 5),
              ],
            ),
          ),
        },
      ),
    );
    if (onTap == null) return paper;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(onTap: onTap, child: paper),
    );
  }
}

/// Thumbnail of the current version of a document.
class LivePageThumbnail extends ConsumerWidget {
  const LivePageThumbnail({
    super.key,
    required this.documentId,
    this.page = 1,
    this.width = 200,
    this.onTap,
  });

  final String documentId;
  final int page;
  final double width;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final doc = ref.watch(
      workspaceProvider.select((s) => s.documents[documentId]),
    );
    if (doc == null) return SizedBox(width: width);
    final snapshot = ref.read(snapshotStoreProvider).put(doc);
    return PageThumbnail(
      snapshot: snapshot,
      page: page.clamp(1, doc.pages.length),
      width: width,
      onTap: onTap,
    );
  }
}

/// Resolves the snapshot of a component: the one in props, or the current
/// version of its document (or of the chat's document).
String? resolveSnapshot(WidgetRef ref, Map<String, dynamic> props) {
  final snapshot = propString(props['snapshot']);
  if (snapshot != null) return snapshot;
  final ws = ref.watch(workspaceProvider);
  final id = propString(props['documentId']) ?? ws.activeThread?.documentId;
  final doc = id == null ? null : ws.documents[id];
  return doc == null ? null : ref.read(snapshotStoreProvider).put(doc);
}

/// `pdf_page`: one page, with a shortcut to open it in the preview.
class PdfPageCard extends ConsumerWidget {
  const PdfPageCard({super.key, required this.props});

  final Map<String, dynamic> props;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = AppTokens.of(context);
    final text = Theme.of(context).textTheme;
    final l = context.l10n;
    final snapshot = resolveSnapshot(ref, props);
    final doc = snapshot == null
        ? null
        : ref.read(snapshotStoreProvider).get(snapshot);
    if (doc == null || doc.pages.isEmpty) {
      return _Missing(l.cardPageUnavailable);
    }
    final page = (propIntOrNull(props['page']) ?? 1).clamp(1, doc.pages.length);
    final p = doc.pages[page - 1];
    final actions = AppActions(ref);

    return CardWidth(
      maxWidth: CardWidth.narrow,
      child: ComponentFrame(
        icon: LucideIcons.fileText,
        title: '${l.pageNumber(page)} · ${p.title}',
        subtitle:
            propString(props['caption']) ??
            (propBool(props['added']) ? l.reviewNewPage : null),
        actions: [
          ComponentButton(
            label: l.cardOpen,
            icon: LucideIcons.panelRightOpen,
            onPressed: () => actions.showPage(doc.id, page),
          ),
        ],
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            PageThumbnail(
              snapshot: snapshot!,
              page: page,
              width: 190,
              onTap: () => actions.showPage(doc.id, page),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(doc.title, style: text.labelLarge),
                  const SizedBox(height: 10),
                  _Fact(l.cardFactLayout, l.layout(p.layout)),
                  _Fact(l.cardFactWords, '${p.wordCount}'),
                  _Fact(l.cardFactBlocks, '${p.blocks.length}'),
                  _Fact(l.cardFactPage, l.cardPageOf(page, doc.pages.length)),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 4,
                    runSpacing: 4,
                    children: [
                      for (final kind in {for (final b in p.blocks) b.kind})
                        Pill(l.blockKind(kind)),
                    ],
                  ),
                  if (p.blocks.isEmpty)
                    Text(
                      l.cardEmptyPage,
                      style: text.bodySmall?.copyWith(color: tokens.textFaint),
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

/// `pdf_diff`: before and after of the page a tool changed.
class PdfDiffCard extends ConsumerWidget {
  const PdfDiffCard({super.key, required this.props});

  final Map<String, dynamic> props;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = AppTokens.of(context);
    final text = Theme.of(context).textTheme;
    final l = context.l10n;
    final before = propString(props['before']);
    final after = propString(props['after']);
    final documentId = propString(props['documentId']);
    if (before == null || after == null) {
      return _Missing(l.cardNothingToCompare);
    }
    final page = propIntOrNull(props['page']) ?? 1;
    final pageBefore = propIntOrNull(props['pageBefore']) ?? page;
    final wordsBefore = propIntOrNull(props['wordsBefore']) ?? 0;
    final wordsAfter = propIntOrNull(props['wordsAfter']) ?? 0;
    final delta = wordsAfter - wordsBefore;
    final actions = AppActions(ref);

    Widget side(String label, String snapshot, int n, String layout) =>
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(label, style: text.labelMedium),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      l.layoutValue(layout),
                      style: text.labelSmall?.copyWith(color: tokens.textFaint),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              LayoutBuilder(
                builder: (context, c) => PageThumbnail(
                  snapshot: snapshot,
                  page: n,
                  width: c.maxWidth.clamp(120, 260),
                  onTap: documentId == null
                      ? null
                      : () => actions.showPage(documentId, page),
                ),
              ),
            ],
          ),
        );

    return CardWidth(
      maxWidth: CardWidth.medium,
      child: ComponentFrame(
        icon: LucideIcons.gitCompare,
        title: '${l.pageNumber(page)} · ${props['title'] ?? ''}',
        actions: [
          if (delta != 0)
            Padding(
              padding: const EdgeInsets.only(right: 6),
              child: Pill(
                delta > 0
                    ? l.cardWordsAdded(delta)
                    : l.cardWordsRemoved(-delta),
                color: delta > 0 ? tokens.success : tokens.danger,
              ),
            ),
          if (documentId != null)
            ComponentButton(
              label: l.cardOpen,
              icon: LucideIcons.panelRightOpen,
              onPressed: () => actions.showPage(documentId, page),
            ),
        ],
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Stable wire values and older saved labels share one localized presentation.
            side(
              l.cardBefore,
              before,
              pageBefore,
              propString(props['layoutBefore']) ?? '',
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 120, 10, 0),
              child: Icon(
                LucideIcons.arrowRight,
                size: 16,
                color: tokens.textFaint,
              ),
            ),
            side(
              l.cardAfter,
              after,
              page,
              propString(props['layoutAfter']) ?? '',
            ),
          ],
        ),
      ),
    );
  }
}

class _Fact extends StatelessWidget {
  const _Fact(this.label, this.value);

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final tokens = AppTokens.of(context);
    final text = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          SizedBox(
            width: 84,
            child: Text(
              label,
              style: text.labelSmall?.copyWith(color: tokens.textFaint),
            ),
          ),
          Text(value, style: text.labelMedium),
        ],
      ),
    );
  }
}

class _Missing extends StatelessWidget {
  const _Missing(this.message);

  final String message;

  @override
  Widget build(BuildContext context) => Text(
    message,
    style: Theme.of(context).textTheme.bodySmall
        ?.copyWith(color: AppTokens.of(context).textFaint),
  );
}
