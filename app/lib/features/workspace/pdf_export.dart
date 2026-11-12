import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/foundation.dart';

import '../../core/platform/browser_runtime.dart' as browser;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/app_localizations.dart';

import '../document/model/document.dart';
import '../document/model/document_review.dart';
import '../document/render/page_fit.dart';
import '../document/render/pdf_renderer.dart';
import 'workspace_state.dart';
import 'document_review.dart';

final pdfFontsProvider = FutureProvider<PdfFontSet>((_) => PdfFontSet.load());

class RenderedPdf {
  RenderedPdf(this.documentId, this.bytes) : revision = _next++;

  static int _next = 0;

  final String documentId;
  final Uint8List bytes;

  /// Unique per render; used to reload the viewer.
  final int revision;
}

/// A document as PDF bytes, with the app's fonts, on a background isolate: the preview, the chat's page
/// cards and the export all render through it.
final pdfRenderProvider = Provider<Future<Uint8List> Function(PaperDocument)>(
  (ref) =>
      (doc) async =>
          PdfRenderer(await ref.read(pdfFontsProvider.future))
              .renderInBackground(doc),
);

/// Never retried: the same document always renders the same way, so a failed render ([PdfLayoutException])
/// only fails again — and every attempt would re-run what depends on it, the server's language review included.
final documentPdfBytesProvider = FutureProvider.autoDispose
    .family<Uint8List, PaperDocument>(
      (ref, doc) => ref.watch(pdfRenderProvider)(doc),
      retry: (_, _) => null,
    );

/// A document with its overlong pages split so the PDF can hold them ([PageFitter]), on a background isolate.
final pageFitProvider =
    Provider<Future<FittedDocument> Function(PaperDocument)>(
      (ref) =>
          (doc) async =>
              PageFitter(PdfRenderer(await ref.read(pdfFontsProvider.future)))
                  .fitInBackground(doc),
    );

/// How long the preview waits for the document to stop changing before rendering it again: an agent run
/// applies its edits in bursts, and each render is the whole document on an isolate that cannot be stopped.
const previewSettle = Duration(milliseconds: 300);

/// PDF bytes for the active document. A document just opened renders at once; one being edited renders
/// again once its edits settle, the previous bytes staying available meanwhile (and after a failed render,
/// which the preview then shows as out of date).
final renderedPdfProvider =
    AsyncNotifierProvider<RenderedPdfNotifier, RenderedPdf?>(
      RenderedPdfNotifier.new,
    );

class RenderedPdfNotifier extends AsyncNotifier<RenderedPdf?> {
  @override
  Future<RenderedPdf?> build() async {
    // This build's own ref: the notifier's `ref` is always the latest build's, so it would stay mounted.
    final ref = this.ref;
    final doc = ref.watch(activeDocumentProvider);
    if (doc == null) return null;
    if (state.value?.documentId == doc.id) {
      await Future<void>.delayed(previewSettle);
      if (!ref.mounted) {
        return null; // a later edit took over: its build renders
      }
    }
    return RenderedPdf(
      doc.id,
      await ref.watch(documentPdfBytesProvider(doc).future),
    );
  }
}

/// Where the preview stands, as both the preview and its status bar tell it.
enum PreviewStatus { rendering, outdated, upToDate }

extension RenderedPdfView on AsyncValue<RenderedPdf?> {
  /// [documentId]'s own pages, or null: another document's, kept from before a switch, are never shown for it.
  RenderedPdf? pagesOf(String? documentId) =>
      value?.documentId == documentId ? value : null;

  /// A render is running; or the last one failed, so the pages shown are older than the document; or neither.
  PreviewStatus get status => isLoading
      ? PreviewStatus.rendering
      : hasError
      ? PreviewStatus.outdated
      : PreviewStatus.upToDate;
}

/// What the lawyer reads when the PDF cannot be made, by preview or export: what to do about it, never a stack
/// trace.
String describePdfFailure(AppLocalizations l, Object? error) =>
    switch (error) {
      PdfLayoutException(:final page) => l.pdfPageTooLong(page),
      DocumentReviewFailure(:final message) => message,
      _ => l.failureUnexpected,
    };

final exportServiceProvider = Provider((ref) => ExportService(ref));

class ExportService {
  ExportService(this._ref);

  final Ref _ref;

  /// Asks for a location and writes the PDF. Returns the path, or null if
  /// the user cancelled.
  Future<String?> export(PaperDocument doc) async {
    final bytes = await _ref.read(documentPdfBytesProvider(doc).future);
    // Fresh pre-export check; an earlier draft's report never authorises these bytes.
    final review = await _ref
        .read(documentReviewerProvider)
        .reviewDocument(doc, pdf: bytes);
    review.requireExport(_ref.read(confirmedTermsProvider));
    if (!identical(_ref.read(workspaceProvider).documents[doc.id], doc)) {
      throw const DocumentReviewFailure(
        'Il documento è stato modificato durante la verifica. Ripeti l’esportazione.',
      );
    }
    if (kIsWeb) {
      browser.download(bytes, doc.fileName, 'application/pdf');
      return doc.fileName;
    }
    final location = await getSaveLocation(
      suggestedName: doc.fileName,
      acceptedTypeGroups: const [
        XTypeGroup(label: 'PDF', extensions: ['pdf']),
      ],
    );
    if (location == null) return null;
    final path = location.path.toLowerCase().endsWith('.pdf')
        ? location.path
        : '${location.path}.pdf';
    if (!identical(_ref.read(workspaceProvider).documents[doc.id], doc)) {
      throw const DocumentReviewFailure(
        'Il documento è stato modificato. Ripeti l’esportazione della versione aggiornata.',
      );
    }
    await File(path).writeAsBytes(bytes, flush: true);
    return path;
  }
}
