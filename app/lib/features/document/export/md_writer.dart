/// MD: CommonMark with GFM tables, UTF-8, LF. The text without its styling (rfc/055): every metacharacter is
/// escaped, so the file renders as the document reads, and a heading keeps its level.
library;

import 'dart:convert';
import 'dart:typed_data';

import '../model/document.dart';
import 'export_model.dart';

Uint8List encodeMd(PaperDocument doc) =>
    Uint8List.fromList(utf8.encode('${_Md(buildExportDoc(doc, plain: true)).build().join('\n')}\n'));

final _entity = RegExp(r'^&(?:#\d+|#[xX][0-9a-fA-F]+|[A-Za-z][A-Za-z0-9]*);');

/// One line of text with its metacharacters escaped. [cell] also escapes `|`, which ends a table cell.
String mdEscapeLine(String line, {bool cell = false}) {
  final b = StringBuffer();
  for (var i = 0; i < line.length; i++) {
    final ch = line[i];
    switch (ch) {
      case r'\' || '`' || '*' || '_' || '[' || ']' || '<' || '~':
        b.write('\\$ch');
      case '|' when cell:
        b.write(r'\|');
      case '&' when _entity.hasMatch(line.substring(i)):
        b.write(r'\&');
      default:
        b.write(ch);
    }
  }
  var s = b.toString().replaceFirst(RegExp(r'^[ \t]+'), '').replaceFirst(RegExp(r'[ \t]+$'), '');
  // What only means something at the start of a line: a heading, a list, a quote, a rule, a setext underline.
  s = s.replaceFirstMapped(RegExp(r'^(#{1,6})(?=\s|$)'), (m) => '\\${m[1]}');
  s = s.replaceFirstMapped(RegExp(r'^([+>-])(?=\s|$)|^>'), (m) => '\\${m[0]}');
  s = s.replaceFirstMapped(RegExp(r'^(\d{1,9})([.)])(?=\s|$)'), (m) => '${m[1]}\\${m[2]}');
  if (RegExp(r'^[-=][-=\s]*$').hasMatch(s)) s = '\\$s';
  return s;
}

/// Text that may run over several lines: a hard break is a backslash, a blank line starts a new paragraph.
String _paragraph(String text) {
  final out = StringBuffer();
  final lines = text.split('\n');
  for (var i = 0; i < lines.length; i++) {
    final line = mdEscapeLine(lines[i]);
    out.write(line);
    if (i + 1 == lines.length) break;
    final next = lines[i + 1].trim();
    if (line.isEmpty || next.isEmpty) {
      out.write('\n');
    } else {
      out.write('\\\n');
    }
  }
  return out.toString().replaceAll(RegExp(r'\n{3,}'), '\n\n').trim();
}

String _flat(String text) => text.split('\n').map(mdEscapeLine).where((l) => l.isNotEmpty).join(' ');

class _Md {
  _Md(this.d);

  final ExportDoc d;
  final _out = <String>[];

  void _block(String text) {
    if (_out.isNotEmpty) _out.add('');
    _out.add(text);
  }

  /// A blockquote: every line, blank ones included, carries the marker.
  String _quote(String body) => body.split('\n').map((l) => l.isEmpty ? '>' : '> $l').join('\n');

  List<String> build() {
    for (final b in d.blocks) {
      switch (b) {
        case ExHeading(:final level, :final text):
          _block('${'#' * level} ${_flat(text).replaceFirstMapped(RegExp(r'#+$'), (m) => '\\${m[0]}')}');
        case ExParagraph(:final text):
          _block(_paragraph(text));
        case ExBullets(:final items, :final style):
          // A numbered list stays one; every other marker is a bullet.
          final numbered = style.resolved.marker == ListMarker.number;
          _block([
            for (final (n, i) in items.indexed)
              () {
                final marker = numbered ? '${n + 1}.' : '-';
                return '$marker ${i.split('\n').map(mdEscapeLine).where((l) => l.isNotEmpty).join('\\\n${' ' * (marker.length + 1)}')}'.trimRight();
              }(),
          ].join('\n'));
        case ExTable():
          _table(b);
        case ExMetrics():
          _table(b.asTable());
        case ExQuote(:final text, :final author):
          _block(_quote([_paragraph(text), if (author.isNotEmpty) '\n— ${_flat(author)}'].join('\n')));
        case ExCallout(:final title, :final text):
          final parts = [if (title.trim().isNotEmpty) '**${_flat(title)}**', if (text.trim().isNotEmpty) _paragraph(text)];
          if (parts.isNotEmpty) _block(_quote(parts.join('\n\n')));
        case ExImage():
          _block(b.markerWith(_flat));
        case ExPageBreak():
          _block('---');
      }
    }
    return _out;
  }

  void _table(ExTable t) {
    String cell(String s) => s.split('\n').map((l) => mdEscapeLine(l, cell: true)).where((l) => l.isNotEmpty).join('<br>');
    String row(List<String> cells) => '| ${cells.map(cell).join(' | ')} |';

    final lines = [
      row(t.hasHeader ? t.header : List.filled(t.width, '')),
      '| ${[for (var c = 0; c < t.width; c++) t.numeric[c] ? '---:' : '---'].join(' | ')} |',
      for (final r in t.rows) row(r),
    ];
    _block(lines.join('\n'));
    if (t.caption.isNotEmpty) _block('*${_flat(t.caption)}*');
  }
}
