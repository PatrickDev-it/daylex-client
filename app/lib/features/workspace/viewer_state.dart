import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';

import 'workspace_state.dart';

class ViewerState {
  const ViewerState({
    this.page = 1,
    this.pageCount = 0,
    this.zoom = 1.0,
    this.revealRequest = 0,
  });

  /// 1-based page currently shown.
  final int page;
  final int pageCount;
  final double zoom;

  /// Bumped when something (usually the agent) asks to reveal [page].
  final int revealRequest;

  ViewerState copyWith({
    int? page,
    int? pageCount,
    double? zoom,
    int? revealRequest,
  }) => ViewerState(
    page: page ?? this.page,
    pageCount: pageCount ?? this.pageCount,
    zoom: zoom ?? this.zoom,
    revealRequest: revealRequest ?? this.revealRequest,
  );
}

final pdfViewerControllerProvider = Provider<PdfViewerController>((ref) {
  final controller = PdfViewerController();
  ref.onDispose(controller.dispose);
  return controller;
});

final viewerProvider = NotifierProvider<ViewerNotifier, ViewerState>(
  ViewerNotifier.new,
);

class ViewerNotifier extends Notifier<ViewerState> {
  static const zoomLevels = [0.5, 0.75, 1.0, 1.25, 1.5, 2.0, 3.0];

  /// Zoom values closer than this are the same level (the viewer reports its zoom as a double).
  static const _zoomEpsilon = 0.01;

  PdfViewerController get _controller => ref.read(pdfViewerControllerProvider);

  /// Page and zoom of documents that are not on screen, restored when their
  /// preview comes back.
  final _memory = <String, ViewerState>{};
  String? _documentId;

  @override
  ViewerState build() {
    _documentId = ref.read(activeDocumentProvider)?.id;
    ref.listen<String?>(
      activeDocumentProvider.select((d) => d?.id),
      (previous, next) {
        _documentId = next;
        if (previous != null) _memory[previous] = state;
        final saved = next == null ? null : _memory[next];
        state = saved == null
            ? const ViewerState()
            : ViewerState(page: saved.page, zoom: saved.zoom);
      },
    );
    return const ViewerState();
  }

  /// Called by the viewer widget.
  void onPageChanged(int page) => state = state.copyWith(page: page);

  void onLoaded(int pageCount) => state = state.copyWith(
    pageCount: pageCount,
    page: state.page.clamp(1, pageCount),
  );

  void onZoomChanged(double zoom) => state = state.copyWith(zoom: zoom);

  /// Asks the preview to show [page] (1-based), e.g. after an agent edit.
  void reveal(int page) => state = state.copyWith(
    page: page,
    revealRequest: state.revealRequest + 1,
  );

  /// Like [reveal], for a document that may not be on screen yet: its
  /// preview opens on [page] when it comes up.
  void revealFor(String documentId, int page) {
    if (documentId == _documentId) return reveal(page);
    final saved = _memory[documentId] ?? const ViewerState();
    _memory[documentId] = saved.copyWith(page: page);
  }

  void goTo(int page) {
    if (state.pageCount == 0) return;
    final target = page.clamp(1, state.pageCount);
    _controller.jumpToPage(target);
    state = state.copyWith(page: target);
  }

  void next() => goTo(state.page + 1);

  void previous() => goTo(state.page - 1);

  void setZoom(double zoom) {
    final z = zoom.clamp(zoomLevels.first, zoomLevels.last);
    _controller.zoomLevel = z;
    state = state.copyWith(zoom: z);
  }

  void zoomIn() => setZoom(
    zoomLevels.firstWhere((z) => z > state.zoom + _zoomEpsilon, orElse: () => zoomLevels.last),
  );

  void zoomOut() => setZoom(
    zoomLevels.lastWhere((z) => z < state.zoom - _zoomEpsilon, orElse: () => zoomLevels.first),
  );
}
