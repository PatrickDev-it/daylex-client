import 'dart:isolate';

import 'package:flutter/foundation.dart' show kIsWeb;

import '../model/document.dart';
import '../model/operations.dart';
import 'pdf_renderer.dart';

/// A page that held more than one A4 page, and where its content went.
class PageSplit {
  const PageSplit({
    required this.page,
    required this.first,
    required this.count,
  });

  /// 1-based number of the page in the document as it was.
  final int page;

  /// 1-based number of the first of the pages it became, in the fitted document.
  final int first;

  /// How many pages it became.
  final int count;
}

/// A document whose pages each fit one A4 page, as far as cutting allows.
class FittedDocument {
  const FittedDocument(
    this.document, {
    this.splits = const [],
    this.overflowing = const [],
  });

  final PaperDocument document;

  /// The pages that were split, in page order.
  final List<PageSplit> splits;

  /// 1-based numbers, in the document as it was, of the pages that cannot be made to fit: one block too large
  /// for a page by itself (a heading, a figure, an image, a single word) that cannot be cut.
  final List<int> overflowing;

  bool get changed => splits.isNotEmpty;

  /// The operations that turn the document as it was into [document]: each split page keeps its id and takes
  /// its first part, the rest follow it as new pages. Applied after the edit that made the pages, so the two are
  /// one undo step.
  List<DocOperation> get operations => [
    for (final s in splits.reversed) ...[
      UpdatePage(
        s.page - 1,
        layout: document.pages[s.first - 1].layout,
        blocks: document.pages[s.first - 1].blocks,
      ),
      for (var j = 1; j < s.count; j++)
        AddPage(document.pages[s.first - 1 + j], index: s.page - 1 + j),
    ],
  ];
}

/// Splits the pages the renderer cannot hold into consecutive pages it can, never dropping or rewording text:
/// whole blocks first, then a block cut between sentences (between words when one sentence is longer than a
/// page), list items or table rows. Whether a page fits is asked of [PdfRenderer] itself, so this can never
/// disagree with the PDF; one model page stays one PDF page.
class PageFitter {
  const PageFitter(this.renderer);

  final PdfRenderer renderer;

  /// [fit] on a background isolate, as [PdfRenderer.renderInBackground] renders.
  Future<FittedDocument> fitInBackground(PaperDocument doc) {
    if (kIsWeb) return fit(doc);
    final fonts = renderer.fonts;
    return Isolate.run(() => PageFitter(PdfRenderer(fonts)).fit(doc));
  }

  Future<FittedDocument> fit(PaperDocument doc) async {
    final int from;
    try {
      await renderer.render(doc);
      return FittedDocument(doc);
    } on PdfLayoutException catch (e) {
      from = e.page - 1; // every page before it fits
    }
    final pages = [...doc.pages.take(from)];
    final splits = <PageSplit>[];
    final overflowing = <int>[];
    for (var i = from; i < doc.pages.length; i++) {
      final (parts, fits) = await _split(doc, doc.pages[i]);
      if (parts.length > 1) {
        splits.add(
          PageSplit(page: i + 1, first: pages.length + 1, count: parts.length),
        );
      }
      pages.addAll(parts);
      if (!fits) overflowing.add(i + 1);
    }
    return FittedDocument(
      doc.copyWith(pages: pages),
      splits: splits,
      overflowing: overflowing,
    );
  }

  Future<bool> _fits(PaperDocument doc, DocPage page) async {
    try {
      await renderer.render(doc.copyWith(pages: [page]));
      return true;
    } on PdfLayoutException {
      return false;
    }
  }

  /// [page] as pages that each fit, and whether the last one does.
  Future<(List<DocPage>, bool)> _split(PaperDocument doc, DocPage page) async {
    final parts = <DocPage>[];
    var rest = page;
    while (!await _fits(doc, rest)) {
      final head = await _head(doc, rest);
      if (head == null) return ([...parts, rest], false);
      parts.add(head.$1);
      rest = head.$2;
    }
    return ([...parts, rest], true);
  }

  /// The most of [page] that fits one page, and the page that continues it; null when not even the start of
  /// its first block fits.
  Future<(DocPage, DocPage)?> _head(PaperDocument doc, DocPage page) async {
    final blocks = page.blocks;
    // Leading whole blocks that fit: the page as a whole does not, so fewer than all of them.
    final whole = await _largest(
      1,
      blocks.length - 1,
      (k) => _fits(doc, page.copyWith(blocks: blocks.sublist(0, k))),
    );
    final kept = blocks.sublist(0, whole);
    final cut = whole < blocks.length
        ? await _cut(doc, page, kept, blocks[whole])
        : null;
    var taken = whole;
    if (cut == null && whole > 1 && kept.last is HeadingBlock) {
      taken--; // a heading goes with what it introduces
      kept.removeLast();
    }
    if (kept.isEmpty && cut == null) return null;
    return (
      page.copyWith(blocks: [...kept, ?cut?.$1]),
      DocPage(
        id: newId(),
        title: page.title,
        layout: page.layout == PageLayout.cover
            ? PageLayout.standard
            : page.layout,
        blocks: [?cut?.$2, ...blocks.sublist(cut == null ? taken : taken + 1)],
      ),
    );
  }

  /// [block] cut in two so that the first part fits after [before] on [page]; null when no part does.
  Future<(DocBlock, DocBlock)?> _cut(
    PaperDocument doc,
    DocPage page,
    List<DocBlock> before,
    DocBlock block,
  ) async {
    final pieces = _Pieces.of(block);
    if (pieces == null) return null;
    final n = await _largest(
      1,
      pieces.length - 1,
      (m) => _fits(doc, page.copyWith(blocks: [...before, pieces.head(m)])),
    );
    return n == 0 ? null : (pieces.head(n), pieces.tail(n));
  }

  /// The largest k in [low, high] for which [fits] holds, assuming it holds for every smaller k; 0 when it holds
  /// for none.
  static Future<int> _largest(
    int low,
    int high,
    Future<bool> Function(int) fits,
  ) async {
    var best = 0;
    while (low <= high) {
      final mid = (low + high) ~/ 2;
      if (await fits(mid)) {
        best = mid;
        low = mid + 1;
      } else {
        high = mid - 1;
      }
    }
    return best;
  }
}

/// The places a block can be cut: [length] pieces, of which [head] keeps the first m and [tail] the rest under a
/// new id. Headings, figures and images are never cut.
class _Pieces {
  _Pieces(this.length, this.head, this.tail);

  final int length;
  final DocBlock Function(int m) head;
  final DocBlock Function(int m) tail;

  static _Pieces? of(DocBlock block) {
    final pieces = switch (block) {
      ParagraphBlock(:final text) => _text(
        text,
        (t) => block.copyWith(text: t),
        (t) => ParagraphBlock(id: newId(), text: t),
      ),
      QuoteBlock(:final text, :final author) => _text(
        text,
        (t) => block.copyWith(text: t, author: ''),
        (t) => QuoteBlock(id: newId(), text: t, author: author),
      ),
      CalloutBlock(:final title, :final text) => _text(
        text,
        (t) => block.copyWith(text: t),
        (t) => CalloutBlock(id: newId(), title: title, text: t),
      ),
      BulletListBlock(:final items) when items.length > 1 => _Pieces(
        items.length,
        (m) => block.copyWith(items: items.sublist(0, m)),
        (m) => BulletListBlock(id: newId(), items: items.sublist(m)),
      ),
      BulletListBlock(:final items) when items.length == 1 => _text(
        items.single,
        (t) => block.copyWith(items: [t]),
        (t) => BulletListBlock(id: newId(), items: [t]),
      ),
      TableBlock(:final columns, :final rows) when rows.length > 1 => _Pieces(
        rows.length,
        (m) => block.copyWith(rows: rows.sublist(0, m)),
        (m) => TableBlock(id: newId(), columns: columns, rows: rows.sublist(m)),
      ),
      _ => null,
    };
    return pieces != null && pieces.length > 1 ? pieces : null;
  }

  /// Text cut after a sentence (or a line) when it has more than one, else between words. The text itself is
  /// kept exactly; only the whitespace at the cut goes.
  static _Pieces _text(
    String text,
    DocBlock Function(String) first,
    DocBlock Function(String) rest,
  ) {
    var ends = _ends(text, _sentenceEnd);
    if (ends.length < 2) ends = _ends(text, _space);
    return _Pieces(
      ends.length,
      (m) => first(text.substring(0, ends[m - 1]).trimRight()),
      (m) => rest(text.substring(ends[m - 1]).trimLeft()),
    );
  }

  /// Where each piece ends: after every match of [cut], and at the end of [text].
  static List<int> _ends(String text, RegExp cut) => [
    for (final m in cut.allMatches(text))
      if (m.end < text.length && m.start > 0) m.end,
    text.length,
  ];

  static final _sentenceEnd = RegExp(r'[.!?;:]["»”’)\]]*\s+|\n\s*');
  static final _space = RegExp(r'\s+');
}
