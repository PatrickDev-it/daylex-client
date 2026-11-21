/// How a document becomes sheets, for the three spreadsheet formats (XLSX, ODS, CSV): decided once, here.
library;

import 'dart:math' as math;

import '../model/document.dart';
import 'export_model.dart';

/// One sheet: a table, or the document's text (one paragraph per row).
class ExSheet {
  const ExSheet({
    required this.title,
    required this.name,
    this.header = const [],
    required this.rows,
    this.caption = '',
    this.isText = false,
    this.boldRows = const {},
  });

  /// What names it, as written (the nearest heading, `Tabella N`, `Testo`): the title row of the CSV.
  final String title;

  /// The tab name: at most 31 characters, none of `[]:*?/\`, unique without regard to case.
  final String name;
  final List<String> header;
  final List<List<String>> rows;
  final String caption;
  final bool isText;

  /// Rows of a text sheet that are headings.
  final Set<int> boldRows;

  bool get hasHeader => header.isNotEmpty;
  int get width => hasHeader ? header.length : rows.fold(1, (w, r) => math.max(w, r.length));

  /// The column widths in characters, from the longest line of each column, between 8 and 60.
  List<double> columnChars() => [
    for (var c = 0; c < width; c++)
      math
          .min(
            60,
            math.max(
              8,
              [if (hasHeader) header[c], for (final r in rows) if (c < r.length) r[c]]
                      .map((s) => s.split('\n').map((l) => l.runes.length).fold(0, math.max))
                      .fold(0, math.max) +
                  2,
            ),
          )
          .toDouble(),
  ];
}

/// The longest text one spreadsheet cell holds (Excel's limit): longer paragraphs continue on the next row.
const kCellLimit = 32000;

/// [doc] as the spreadsheets take it: its text without the styling (rfc/055), and its sheets.
({ExportDoc doc, List<ExSheet> sheets}) exportSheets(PaperDocument doc) {
  final d = buildExportDoc(doc, plain: true);
  return (doc: d, sheets: buildSheets(d));
}

/// The sheets of [doc]: one per table, named after the nearest heading; then `Testo` with everything that is not
/// a table, when there is anything (always, in a document without tables).
List<ExSheet> buildSheets(ExportDoc doc) {
  final text = _textRows(doc);
  final hasText = doc.tables.isEmpty || doc.blocks.any((b) => b is! ExTable && b is! ExPageBreak);

  final names = _SheetNames();
  final textName = hasText ? names.take('Testo') : '';
  return [
    for (final t in doc.tables)
      ExSheet(title: t.title, name: names.take(t.title, fallback: 'Tabella ${t.number}'), header: t.header, rows: t.rows, caption: t.caption),
    if (hasText)
      ExSheet(title: 'Testo', name: textName, rows: [for (final r in text.rows) [r]], isText: true, boldRows: text.bold),
  ];
}

({List<String> rows, Set<int> bold}) _textRows(ExportDoc doc) {
  final rows = <String>[];
  final bold = <int>{};
  void add(String s, {bool heading = false}) {
    var rest = s;
    while (rest.length > kCellLimit) {
      var cut = kCellLimit;
      if (rest.codeUnitAt(cut - 1) >= 0xD800 && rest.codeUnitAt(cut - 1) <= 0xDBFF) cut--;
      if (heading) bold.add(rows.length);
      rows.add(rest.substring(0, cut));
      rest = rest.substring(cut);
    }
    if (heading) bold.add(rows.length);
    rows.add(rest);
  }

  for (final b in doc.blocks) {
    switch (b) {
      case ExHeading(:final text):
        add(text, heading: true);
      case ExParagraph(:final text):
        add(text);
      case ExBullets(:final items, :final style):
        for (final (n, i) in items.indexed) {
          final marker = listMarker(style.resolved.marker, n);
          add(marker.isEmpty ? i : '$marker $i');
        }
      case ExMetrics(:final items):
        for (final m in items) {
          add('${m.label}: ${m.value}${m.delta.isEmpty ? '' : ' (${m.delta})'}');
        }
      case ExQuote(:final text, :final author):
        add(text);
        if (author.isNotEmpty) add('— $author');
      case ExCallout(:final title, :final text):
        add(title, heading: true);
        if (text.isNotEmpty) add(text);
      case ExImage():
        add(b.marker);
      case ExTable() || ExPageBreak():
        break;
    }
  }
  return (rows: rows, bold: bold);
}

/// Hands out sheet names that obey the rules of Excel and LibreOffice and never repeat.
class _SheetNames {
  // Excel reserves "History"; names are unique without regard to case.
  final _taken = <String>{'history'};

  static final _forbidden = RegExp(r'[\[\]:*?/\\]');

  String take(String raw, {String fallback = 'Foglio'}) {
    var base = _clean(raw);
    if (base.isEmpty) base = _clean(fallback);
    var name = base;
    for (var n = 2; _taken.contains(name.toLowerCase()); n++) {
      final suffix = ' ($n)';
      name = _cut(base, 31 - suffix.length) + suffix;
    }
    _taken.add(name.toLowerCase());
    return name;
  }

  static String _clean(String raw) {
    final flat = raw.replaceAll(_forbidden, ' ').replaceAll(RegExp(r'\s+'), ' ').trim();
    return _cut(flat, 31);
  }

  /// At most [max] UTF-16 units, never splitting a pair, with no apostrophe or space at either end.
  static String _cut(String s, int max) {
    var out = s;
    if (out.length > max) {
      var end = max;
      if (out.codeUnitAt(end - 1) >= 0xD800 && out.codeUnitAt(end - 1) <= 0xDBFF) end--;
      out = out.substring(0, end);
    }
    return out.replaceAll(RegExp(r"^['\s]+|['\s]+$"), '');
  }
}
