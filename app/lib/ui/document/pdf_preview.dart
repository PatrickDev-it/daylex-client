import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:syncfusion_flutter_core/theme.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';

import '../../core/theme/app_theme.dart';
import '../../features/document/render/pdf_renderer.dart';
import '../../features/workspace/viewer_state.dart';
import '../../features/workspace/pdf_export.dart';
import '../../features/workspace/workspace_state.dart';
import '../../l10n/l10n.dart';
import '../common/widgets.dart';
import '../shortcuts.dart';

/// Live PDF preview of the active document.
///
/// Every render gets a new viewer (keyed by revision) that opens on the page
/// the user — or the agent — was last looking at.
class PdfPreview extends ConsumerWidget {
  const PdfPreview({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = AppTokens.of(context);
    final l = context.l10n;
    final rendered = ref.watch(renderedPdfProvider);
    final active = ref.watch(activeDocumentProvider.select((d) => d?.id));
    final controller = ref.watch(pdfViewerControllerProvider);
    final viewer = ref.read(viewerProvider.notifier);

    ref.listen(viewerProvider.select((v) => v.revealRequest), (_, _) {
      final page = ref.read(viewerProvider).page;
      if (controller.pageCount >= page) controller.jumpToPage(page);
    });

    final pdf = rendered.pagesOf(active);
    final Widget body;
    if (pdf == null) {
      body = rendered.hasError
          ? EmptyState(icon: LucideIcons.alertTriangle, title: l.previewRenderFailed, message: '${rendered.error}')
          : const _PageSkeleton();
    } else {
      final state = ref.read(viewerProvider);
      body = SfPdfViewerTheme(
        data: SfPdfViewerThemeData(
          backgroundColor: tokens.canvas,
          progressBarColor: Theme.of(context).colorScheme.primary,
        ),
        child: SfPdfViewer.memory(
          pdf.bytes,
          key: ValueKey(pdf.revision),
          controller: controller,
          initialPageNumber: state.page,
          initialZoomLevel: state.zoom,
          pageSpacing: 16,
          canShowScrollHead: false,
          canShowScrollStatus: false,
          canShowPaginationDialog: false,
          canShowPageLoadingIndicator: false,
          onDocumentLoaded: (d) => viewer.onLoaded(d.document.pages.count),
          onPageChanged: (d) => viewer.onPageChanged(d.newPageNumber),
          onZoomLevelChanged: (d) => viewer.onZoomChanged(d.newZoomLevel),
        ),
      );
    }

    return ColoredBox(
      color: tokens.canvas,
      child: Stack(
        children: [
          Positioned.fill(
            child: AnimatedSwitcher(
              duration: AppTheme.normal,
              child: KeyedSubtree(key: ValueKey(pdf == null ? 'loading' : 'ready'), child: body),
            ),
          ),
          if (pdf != null && rendered.status == PreviewStatus.rendering)
            Positioned(top: 12, right: 16, child: Pill(l.previewRendering, busy: true, outlined: true))
          else if (pdf != null && rendered.status == PreviewStatus.outdated)
            Positioned(
              top: 12,
              right: 16,
              child: Tooltip(
                message: '${rendered.error}',
                child: Pill(l.previewOutdated, icon: LucideIcons.alertTriangle, color: tokens.warning, outlined: true),
              ),
            ),
          if (pdf != null) const Positioned(left: 0, right: 0, bottom: 16, child: Center(child: _ViewerControls())),
        ],
      ),
    );
  }
}

class _ViewerControls extends ConsumerWidget {
  const _ViewerControls();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = AppTokens.of(context);
    final scheme = Theme.of(context).colorScheme;
    final v = ref.watch(viewerProvider);
    final n = ref.read(viewerProvider.notifier);
    final text = Theme.of(context).textTheme.labelMedium;
    final l = context.l10n;

    Widget divider() =>
        Container(width: 1, height: 18, margin: const EdgeInsets.symmetric(horizontal: 4), color: tokens.border);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 3),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        border: Border.all(color: tokens.border),
        boxShadow: [BoxShadow(color: AppTheme.pageShadow, blurRadius: 16, offset: const Offset(0, 4))],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          ToolbarButton(
            icon: LucideIcons.chevronLeft,
            tooltip: AppShortcut.previousPage.label(l),
            shortcut: AppShortcut.previousPage,
            onPressed: v.page > 1 ? n.previous : null,
          ),
          SizedBox(
            width: 64,
            child: Text(
              v.pageCount == 0 ? '–' : '${v.page} / ${v.pageCount}',
              textAlign: TextAlign.center,
              style: text?.copyWith(fontFeatures: const [FontFeature.tabularFigures()]),
            ),
          ),
          ToolbarButton(
            icon: LucideIcons.chevronRight,
            tooltip: AppShortcut.nextPage.label(l),
            shortcut: AppShortcut.nextPage,
            onPressed: v.page < v.pageCount ? n.next : null,
          ),
          divider(),
          ToolbarButton(
            icon: LucideIcons.zoomOut,
            tooltip: AppShortcut.zoomOut.label(l),
            shortcut: AppShortcut.zoomOut,
            onPressed: v.zoom > 0.5 ? n.zoomOut : null,
          ),
          Tooltip(
            message: '${AppShortcut.zoomReset.label(l)}  ·  ${AppShortcut.zoomReset.keys}',
            child: InkWell(
              borderRadius: BorderRadius.circular(AppTheme.radiusSm),
              onTap: () => n.setZoom(1),
              child: SizedBox(
                width: 52,
                height: 32,
                child: Center(
                  child: Text(
                    '${(v.zoom * 100).round()}%',
                    style: text?.copyWith(fontFeatures: const [FontFeature.tabularFigures()]),
                  ),
                ),
              ),
            ),
          ),
          ToolbarButton(
            icon: LucideIcons.zoomIn,
            tooltip: AppShortcut.zoomIn.label(l),
            shortcut: AppShortcut.zoomIn,
            onPressed: v.zoom < 3 ? n.zoomIn : null,
          ),
        ],
      ),
    );
  }
}

/// A4-shaped placeholder shown before the first render completes.
class _PageSkeleton extends StatelessWidget {
  const _PageSkeleton();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: AspectRatio(
        aspectRatio: kA4AspectRatio,
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: OutlinedBox(
            padding: const EdgeInsets.all(40),
            radius: AppTheme.radiusXs,
            color: Theme.of(context).colorScheme.surface,
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Skeleton(width: 90, height: 8),
                SizedBox(height: 36),
                Skeleton(width: 220, height: 20),
                SizedBox(height: 20),
                Skeleton(height: 8),
                SizedBox(height: 8),
                Skeleton(height: 8),
                SizedBox(height: 8),
                Skeleton(width: 180, height: 8),
                SizedBox(height: 28),
                Row(
                  children: [
                    Expanded(child: Skeleton(height: 56, radius: AppTheme.radiusSm)),
                    SizedBox(width: 10),
                    Expanded(child: Skeleton(height: 56, radius: AppTheme.radiusSm)),
                    SizedBox(width: 10),
                    Expanded(child: Skeleton(height: 56, radius: AppTheme.radiusSm)),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
