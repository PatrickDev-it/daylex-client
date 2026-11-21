import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/foundation.dart';

import '../../core/platform/browser_runtime.dart' as browser;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/app_localizations.dart';

import '../document/export/document_export.dart';
import '../document/model/document.dart';
import '../document/model/document_review.dart';
import '../document/render/page_fit.dart';
import '../document/render/pdf_renderer.dart';
import '../storage/local_store.dart';
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

/// The files this app exported on this computer, oldest first: the only paths an export card looks at, opens or
/// shows in their folder. A path a chat carries from anywhere else — the server, the model's text, a chat saved
/// by an older version — is never touched. Kept across launches, the oldest dropped past [ExportedFiles.kept].
final exportedFilesProvider = NotifierProvider<ExportedFiles, List<String>>(
  ExportedFiles.new,
);

class ExportedFiles extends Notifier<List<String>> {
  static const kept = 200;

  @override
  List<String> build() => [
    for (final path
        in ref.read(localStoreProvider)?.readExports()?['paths'] as List? ??
            const [])
      if (path is String) path,
  ];

  void add(String path) {
    final paths = [...state.where((p) => p != path), path];
    state = paths.length > kept ? paths.sublist(paths.length - kept) : paths;
    final store = ref.read(localStoreProvider);
    if (store == null) return;
    try {
      store.writeExports({'paths': state});
    } on FileSystemException catch (e) {
      store.saveFailed(e);
    }
  }
}

final exportServiceProvider = Provider((ref) => ExportService(ref));

/// The bytes of a document in a format other than the PDF, off the interface thread ([compute]).
Uint8List _encode((PaperDocument, ExportFormat) job) =>
    encodeDocument(job.$1, job.$2);

class ExportService {
  ExportService(this._ref);

  final Ref _ref;

  /// Asks for a location and writes [doc] in [format]: the PDF the renderer draws, or a file written from the same
  /// document (rfc/051). Every format passes the same review, made on the PDF. Returns the path, or null if the
  /// user cancelled.
  Future<String?> export(
    PaperDocument doc, {
    ExportFormat format = ExportFormat.pdf,
  }) async {
    final pdf = await _ref.read(documentPdfBytesProvider(doc).future);
    // Fresh pre-export check; an earlier draft's report never authorises these bytes.
    final review = await _ref
        .read(documentReviewerProvider)
        .reviewDocument(doc, pdf: pdf);
    review.requireExport(_ref.read(confirmedTermsProvider));
    if (!identical(_ref.read(workspaceProvider).documents[doc.id], doc)) {
      throw const DocumentReviewFailure(
        'Il documento è stato modificato durante la verifica. Ripeti l’esportazione.',
      );
    }
    final bytes = format == ExportFormat.pdf
        ? pdf
        : await compute(_encode, (doc, format));
    final name = format.fileNameOf(doc);
    if (kIsWeb) {
      browser.download(bytes, name, format.mimeType);
      return name;
    }
    final location = await getSaveLocation(
      suggestedName: name,
      acceptedTypeGroups: [
        XTypeGroup(label: format.label, extensions: [format.extension]),
      ],
    );
    if (location == null) return null;
    final path = location.path.toLowerCase().endsWith('.${format.extension}')
        ? location.path
        : '${location.path}.${format.extension}';
    if (!identical(_ref.read(workspaceProvider).documents[doc.id], doc)) {
      throw const DocumentReviewFailure(
        'Il documento è stato modificato. Ripeti l’esportazione della versione aggiornata.',
      );
    }
    await File(path).writeAsBytes(bytes, flush: true);
    _ref.read(exportedFilesProvider.notifier).add(path);
    return path;
  }
}
