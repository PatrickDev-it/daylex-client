import '../../../l10n/app_localizations.dart';
import '../model/document.dart';
import '../model/operations.dart';

/// Why an operation was refused. The model reads [DocumentOperationException.message] (Italian, as it always has);
/// the user reads [DocumentOperationException.localized], in the app language.
enum DocumentFailure { lastPage, noPage, noBlock, emptySearch, noDocument }

class DocumentOperationException implements Exception {
  const DocumentOperationException(this.failure, this.message, [this.args = const []]);

  const DocumentOperationException.lastPage() : this(DocumentFailure.lastPage, lastPageMessage);

  DocumentOperationException.noPage(int page, int count)
    : this(
        DocumentFailure.noPage,
        'La pagina $page non esiste (il documento ne ha $count).',
        [page, count],
      );

  DocumentOperationException.noBlock(String blockId)
    : this(DocumentFailure.noBlock, 'Blocco $blockId non trovato.', [blockId]);

  const DocumentOperationException.emptySearch()
    : this(DocumentFailure.emptySearch, 'Il testo da cercare è vuoto.');

  const DocumentOperationException.noDocument()
    : this(DocumentFailure.noDocument, 'Nessun documento aperto.');

  /// Said to the agent and to the user when a document would be left without pages.
  static const lastPageMessage = 'Un documento deve avere almeno una pagina.';

  final DocumentFailure failure;

  /// What the model is told: Italian, byte-stable.
  final String message;
  final List<Object> args;

  String localized(AppLocalizations l) => switch (failure) {
    DocumentFailure.lastPage => l.docErrorLastPage,
    DocumentFailure.noPage => l.docErrorNoPage(args[0] as int, args[1] as int),
    DocumentFailure.noBlock => l.docErrorNoBlock(args[0] as String),
    DocumentFailure.emptySearch => l.docErrorEmptySearch,
    DocumentFailure.noDocument => l.docErrorNoDocument,
  };

  @override
  String toString() => message;
}

/// Pure functions that apply [DocOperation]s to a [PaperDocument].
///
/// Documents are immutable: every call returns a new instance, which is what
/// makes undo/redo a simple stack of snapshots.
class DocumentService {
  const DocumentService();

  PaperDocument applyAll(PaperDocument doc, Iterable<DocOperation> ops) =>
      ops.fold(doc, apply);

  PaperDocument apply(PaperDocument doc, DocOperation op) {
    final next = switch (op) {
      AddPage(:final page, :final index) => _withPages(doc, (pages) {
        final at = (index ?? pages.length).clamp(0, pages.length);
        pages.insert(at, page);
      }),
      DeletePage(:final pageIndex) => _withPages(doc, (pages) {
        _checkPage(pages, pageIndex);
        if (pages.length == 1) {
          throw const DocumentOperationException.lastPage();
        }
        pages.removeAt(pageIndex);
      }),
      MovePage(:final from, :final to) => _withPages(doc, (pages) {
        _checkPage(pages, from);
        final page = pages.removeAt(from);
        pages.insert(to.clamp(0, pages.length), page);
      }),
      UpdatePage(:final pageIndex, :final title, :final layout, :final blocks) =>
        _withPages(doc, (pages) {
          _checkPage(pages, pageIndex);
          pages[pageIndex] = pages[pageIndex].copyWith(
            title: title,
            layout: layout,
            blocks: blocks,
          );
        }),
      ReplaceText(:final find, :final replace, :final pageIndex) =>
        _replaceText(doc, find, replace, pageIndex),
      InsertBlock(:final pageIndex, :final block, :final index) =>
        _withPages(doc, (pages) {
          _checkPage(pages, pageIndex);
          final blocks = [...pages[pageIndex].blocks];
          blocks.insert((index ?? blocks.length).clamp(0, blocks.length), block);
          pages[pageIndex] = pages[pageIndex].copyWith(blocks: blocks);
        }),
      UpdateBlock(:final block) => _mapBlock(doc, block.id, (_) => block),
      RemoveBlock(:final blockId) => _withPages(doc, (pages) {
        final (p, b) = _locate(pages, blockId);
        pages[p] = pages[p].copyWith(
          blocks: [...pages[p].blocks]..removeAt(b),
        );
      }),
      MoveBlock(:final blockId, :final delta) => _withPages(doc, (pages) {
        final (p, b) = _locate(pages, blockId);
        final blocks = [...pages[p].blocks];
        final target = (b + delta).clamp(0, blocks.length - 1);
        blocks.insert(target, blocks.removeAt(b));
        pages[p] = pages[p].copyWith(blocks: blocks);
      }),
      SetTheme(:final theme) => doc.copyWith(theme: theme),
      UpdateMetadata(:final title, :final subtitle, :final client, :final author, :final status) =>
        doc.copyWith(
          metadata: doc.metadata.copyWith(
            title: title,
            subtitle: subtitle,
            client: client,
            author: author,
            status: status,
          ),
        ),
    };
    return next.copyWith(
      metadata: next.metadata.copyWith(updatedAt: DateTime.now()),
    );
  }

  PaperDocument _withPages(
    PaperDocument doc,
    void Function(List<DocPage> pages) mutate,
  ) {
    final pages = [...doc.pages];
    mutate(pages);
    return doc.copyWith(pages: List.unmodifiable(pages));
  }

  void _checkPage(List<DocPage> pages, int index) {
    if (index < 0 || index >= pages.length) {
      throw DocumentOperationException.noPage(index + 1, pages.length);
    }
  }

  (int, int) _locate(List<DocPage> pages, String blockId) {
    for (var p = 0; p < pages.length; p++) {
      final b = pages[p].blocks.indexWhere((x) => x.id == blockId);
      if (b >= 0) return (p, b);
    }
    throw DocumentOperationException.noBlock(blockId);
  }

  PaperDocument _mapBlock(
    PaperDocument doc,
    String blockId,
    DocBlock Function(DocBlock) map,
  ) => _withPages(doc, (pages) {
    final (p, b) = _locate(pages, blockId);
    final blocks = [...pages[p].blocks];
    blocks[b] = map(blocks[b]);
    pages[p] = pages[p].copyWith(blocks: blocks);
  });

  PaperDocument _replaceText(
    PaperDocument doc,
    String find,
    String replace,
    int? pageIndex,
  ) {
    if (find.isEmpty) {
      throw const DocumentOperationException.emptySearch();
    }
    final next = _withPages(doc, (pages) {
      if (pageIndex != null) _checkPage(pages, pageIndex);
      for (var i = 0; i < pages.length; i++) {
        if (pageIndex != null && i != pageIndex) continue;
        final page = pages[i];
        pages[i] = page.copyWith(
          title: page.title.replaceAll(find, replace),
          blocks: [for (final b in page.blocks) b.replaceText(find, replace)],
        );
      }
    });
    if (pageIndex != null) return next;
    // A document-wide replace also covers the details shown on the cover
    // and in the library, so renaming or anonymising a party is complete.
    final meta = next.metadata;
    return next.copyWith(
      metadata: meta.copyWith(
        title: meta.title.replaceAll(find, replace),
        subtitle: meta.subtitle.replaceAll(find, replace),
        client: meta.client.replaceAll(find, replace),
      ),
    );
  }

  /// Number of occurrences of [find], used to report replace results.
  int countOccurrences(PaperDocument doc, String find, {int? pageIndex}) {
    if (find.isEmpty) return 0;
    var count = 0;
    if (pageIndex == null) {
      final meta = doc.metadata;
      for (final t in [meta.title, meta.subtitle, meta.client]) {
        count += find.allMatches(t).length;
      }
    }
    for (var i = 0; i < doc.pages.length; i++) {
      if (pageIndex != null && i != pageIndex) continue;
      final page = doc.pages[i];
      final text = [page.title, ...page.blocks.map((b) => b.plainText)];
      for (final t in text) {
        count += find.allMatches(t).length;
      }
    }
    return count;
  }
}
