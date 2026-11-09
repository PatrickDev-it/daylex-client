import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:printing/printing.dart';

import '../../storage/local_store.dart';
import '../../workspace/pdf_export.dart';
import '../model/document.dart';

/// Immutable document versions referenced by chat components.
///
/// A card in the conversation must keep showing the version it was created
/// for, even after later edits, so components refer to a snapshot id instead
/// of the live document. Documents are immutable and every edit bumps
/// `updatedAt`, which makes `id@updatedAt` a stable content key.
///
/// With a [LocalStore] each version is also written to disk once (it never changes) and read back on
/// demand, so the cards of a chat reopened after a restart still show their version.
class SnapshotStore {
  SnapshotStore([this._disk]);

  final LocalStore? _disk;
  final _docs = <String, PaperDocument>{};

  String put(PaperDocument doc) {
    final id = '${doc.id}@${doc.metadata.updatedAt.microsecondsSinceEpoch}';
    if (_docs.containsKey(id)) return id;
    _docs[id] = doc;
    final disk = _disk;
    if (disk != null && !disk.hasSnapshot(id)) {
      try {
        disk.writeSnapshot(id, doc.toJson());
      } on FileSystemException catch (e) {
        debugPrint('PaperAgent: could not save version $id: $e');
      }
    }
    return id;
  }

  PaperDocument? get(String id) {
    final known = _docs[id];
    if (known != null) return known;
    final saved = _disk?.readSnapshot(id);
    return saved == null ? null : _docs[id] = PaperDocument.fromJson(saved);
  }
}

final snapshotStoreProvider = Provider((ref) => SnapshotStore(ref.read(localStoreProvider)));

/// Keeps [ref]'s value for [pageCacheFor] after its last listener has gone, then lets it go.
void _keepAWhile(Ref ref) {
  final link = ref.keepAlive();
  Timer? release;
  ref.onCancel(() => release = Timer(pageCacheFor, link.close));
  ref.onResume(() => release?.cancel());
  ref.onDispose(() => release?.cancel());
}

/// PDF bytes of a snapshot, rendered once on a background isolate and kept while any of its pages is.
final snapshotPdfProvider = FutureProvider.autoDispose.family<Uint8List, String>((ref, id) async {
  _keepAWhile(ref);
  final doc = ref.read(snapshotStoreProvider).get(id);
  if (doc == null) throw StateError('Unknown snapshot $id');
  return ref.read(pdfRenderProvider)(doc);
});

/// One page (0-based) of PDF bytes as PNG, at screen resolution.
final pageRasterProvider = Provider<Future<Uint8List> Function(Uint8List pdf, int page)>(
  (_) =>
      (pdf, page) async => (await Printing.raster(pdf, pages: [page], dpi: 96).first).toPng(),
);

/// How long a page left the screen is kept before it is let go, so a card scrolled out and back is not
/// rendered again.
const pageCacheFor = Duration(minutes: 1);

/// One page of a snapshot as PNG. Key: (snapshot id, 0-based page index).
///
/// Every edit of a live thumbnail is a new snapshot, so a page is let go once nothing has shown it for
/// [pageCacheFor]: kept for good, the versions of a long session would pile up in memory.
final pageImageProvider = FutureProvider.autoDispose.family<Uint8List, (String, int)>((ref, key) async {
  _keepAWhile(ref);
  final (snapshot, page) = key;
  final pdf = await ref.watch(snapshotPdfProvider(snapshot).future);
  return ref.read(pageRasterProvider)(pdf, page);
});
