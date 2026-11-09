import '../model/document.dart';

enum PageChangeKind { added, removed, edited }

/// How one page differs between two versions of a document.
class PageChange {
  const PageChange({
    required this.kind,
    required this.title,
    this.beforeIndex,
    this.afterIndex,
    this.before,
    this.after,
  });

  final PageChangeKind kind;
  final String title;

  /// 0-based positions in the old and new version.
  final int? beforeIndex;
  final int? afterIndex;
  final DocPage? before;
  final DocPage? after;

  int get wordsBefore => before?.wordCount ?? 0;
  int get wordsAfter => after?.wordCount ?? 0;

  /// Line-level text diff of the page content.
  List<DiffLine> get lines => diffLines(pageLines(before), pageLines(after));

  bool get layoutChanged =>
      before != null && after != null && before!.layout != after!.layout;
}

/// Compares pages by id: new ids are additions, missing ids removals, and
/// pages whose content changed are edits. Unchanged pages are left out.
List<PageChange> comparePages(PaperDocument before, PaperDocument after) {
  final oldById = {for (final (i, p) in before.pages.indexed) p.id: (i, p)};
  final newIds = {for (final p in after.pages) p.id};
  final changes = <PageChange>[];

  for (final (i, page) in after.pages.indexed) {
    final old = oldById[page.id];
    if (old == null) {
      changes.add(PageChange(kind: PageChangeKind.added, title: page.title, afterIndex: i, after: page));
    } else if (!_samePage(old.$2, page)) {
      changes.add(PageChange(
        kind: PageChangeKind.edited,
        title: page.title,
        beforeIndex: old.$1,
        afterIndex: i,
        before: old.$2,
        after: page,
      ));
    }
  }
  for (final (i, page) in before.pages.indexed) {
    if (!newIds.contains(page.id)) {
      changes.add(PageChange(kind: PageChangeKind.removed, title: page.title, beforeIndex: i, before: page));
    }
  }
  // Theme and details show on every page (cover, headers), so surface them
  // as an edit of the first page when nothing else touched it.
  final detailsChanged = before.theme.accent != after.theme.accent ||
      before.theme.brandName != after.theme.brandName ||
      before.title != after.title ||
      before.metadata.subtitle != after.metadata.subtitle ||
      before.metadata.client != after.metadata.client;
  if (detailsChanged &&
      after.pages.isNotEmpty &&
      before.pages.isNotEmpty &&
      !changes.any((c) => c.afterIndex == 0)) {
    changes.insert(0, PageChange(
      kind: PageChangeKind.edited,
      title: after.pages.first.title,
      beforeIndex: 0,
      afterIndex: 0,
      before: before.pages.first,
      after: after.pages.first,
    ));
  }
  changes.sort((a, b) => (a.afterIndex ?? a.beforeIndex!).compareTo(b.afterIndex ?? b.beforeIndex!));
  return changes;
}

bool _samePage(DocPage a, DocPage b) =>
    a.title == b.title &&
    a.layout == b.layout &&
    a.blocks.length == b.blocks.length &&
    [for (var i = 0; i < a.blocks.length; i++) _sameBlock(a.blocks[i], b.blocks[i])].every((x) => x);

bool _sameBlock(DocBlock a, DocBlock b) =>
    identical(a, b) || a.toJson().toString() == b.toJson().toString();

/// Readable text lines of a page, one or more per block.
List<String> pageLines(DocPage? page) {
  if (page == null) return const [];
  return [
    for (final b in page.blocks)
      ...switch (b) {
        HeadingBlock(:final text, :final level) => ['${'#' * level} $text'],
        BulletListBlock(:final items) => [for (final i in items) '• $i'],
        TableBlock(:final columns, :final rows) => [
          columns.join(' | '),
          for (final r in rows) r.join(' | '),
        ],
        MetricsBlock(:final items) => [
          for (final m in items) '${m.label}: ${m.value}${m.delta.isEmpty ? '' : ' (${m.delta})'}',
        ],
        QuoteBlock(:final text, :final author) => ['“$text” — $author'],
        CalloutBlock(:final title, :final text) => ['[$title] $text'],
        ImageBlock(:final caption) => ['[image] $caption'],
        _ => [b.plainText],
      },
  ];
}

enum DiffOp { same, added, removed }

class DiffLine {
  const DiffLine(this.op, this.text);
  final DiffOp op;
  final String text;
}

/// Longest-common-subsequence line diff; pages are short, so O(n·m) is fine.
List<DiffLine> diffLines(List<String> a, List<String> b) {
  final n = a.length, m = b.length;
  final lcs = List.generate(n + 1, (_) => List.filled(m + 1, 0));
  for (var i = n - 1; i >= 0; i--) {
    for (var j = m - 1; j >= 0; j--) {
      lcs[i][j] = a[i] == b[j]
          ? lcs[i + 1][j + 1] + 1
          : (lcs[i + 1][j] > lcs[i][j + 1] ? lcs[i + 1][j] : lcs[i][j + 1]);
    }
  }
  final out = <DiffLine>[];
  var i = 0, j = 0;
  while (i < n && j < m) {
    if (a[i] == b[j]) {
      out.add(DiffLine(DiffOp.same, a[i]));
      i++;
      j++;
    } else if (lcs[i + 1][j] >= lcs[i][j + 1]) {
      out.add(DiffLine(DiffOp.removed, a[i++]));
    } else {
      out.add(DiffLine(DiffOp.added, b[j++]));
    }
  }
  while (i < n) {
    out.add(DiffLine(DiffOp.removed, a[i++]));
  }
  while (j < m) {
    out.add(DiffLine(DiffOp.added, b[j++]));
  }
  return out;
}
