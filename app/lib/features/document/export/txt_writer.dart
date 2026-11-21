/// TXT: UTF-8 without a byte order mark, CRLF line ends. The text without its styling (rfc/055): headings underlined,
/// lists with their markers, tables as aligned columns.
library;

import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';

import '../model/document.dart';
import 'export_model.dart';

/// The widest a table row is allowed to run before its cells wrap.
const _tableWidth = 100;

/// The widest a callout box is.
const _boxWidth = 78;

Uint8List encodeTxt(PaperDocument doc) {
  final lines = _Txt(buildExportDoc(doc, plain: true)).build();
  return Uint8List.fromList(utf8.encode(lines.map((l) => '$l\r\n').join()));
}

int _len(String s) => s.runes.length;

/// Greedy word wrap of [text] to [width], keeping its own line breaks; a word longer than a line is cut.
List<String> _wrap(String text, int width) {
  final out = <String>[];
  for (final raw in text.split('\n')) {
    var line = '';
    for (final word in raw.split(' ')) {
      var w = word;
      while (_len(w) > width) {
        if (line.isNotEmpty) {
          out.add(line);
          line = '';
        }
        final runes = w.runes.toList();
        out.add(String.fromCharCodes(runes.take(width)));
        w = String.fromCharCodes(runes.skip(width));
      }
      if (line.isEmpty) {
        line = w;
      } else if (_len(line) + 1 + _len(w) <= width) {
        line = '$line $w';
      } else {
        out.add(line);
        line = w;
      }
    }
    out.add(line);
  }
  return out;
}

class _Txt {
  _Txt(this.d);

  final ExportDoc d;
  final _out = <String>[];

  /// One blank line between blocks.
  void _gap() {
    if (_out.isNotEmpty && _out.last.isNotEmpty) _out.add('');
  }

  void _block(Iterable<String> lines) {
    _gap();
    _out.addAll(lines);
  }

  List<String> build() {
    for (final b in d.blocks) {
      switch (b) {
        case ExHeading(:final level, :final text):
          _block([...text.split('\n'), (const ['=', '-', '~'][level - 1]) * _longest(text)]);
        case ExParagraph(:final text):
          _block(text.split('\n'));
        case ExBullets(:final items, :final style):
          _gap();
          for (final (n, i) in items.indexed) {
            final marker = listMarker(style.resolved.marker, n);
            final lines = i.split('\n');
            _out.add(marker.isEmpty ? lines.first : '$marker ${lines.first}');
            _out.addAll(lines.skip(1).map((l) => '${' ' * (marker.isEmpty ? 0 : _len(marker) + 1)}$l'));
          }
        case ExTable():
          _table(b);
        case ExMetrics():
          _table(b.asTable());
        case ExQuote(:final text, :final author):
          _block([...text.split('\n').map((l) => '    $l'), if (author.isNotEmpty) '    — $author']);
        case ExCallout(:final title, :final text):
          _callout(title, text);
        case ExImage():
          _block([b.marker]);
        case ExPageBreak():
          _block(['* * *']);
      }
    }
    return _out;
  }

  static int _longest(String s) => s.split('\n').map(_len).fold(1, math.max);

  void _callout(String title, String text) {
    final inner = _boxWidth - 4;
    final lines = [..._wrap(title, inner), if (text.isNotEmpty) ..._wrap(text, inner)];
    final width = lines.map(_len).fold(0, math.max);
    final rule = '+${'-' * (width + 2)}+';
    _block([rule, for (final l in lines) '| $l${' ' * (width - _len(l))} |', rule]);
  }

  void _table(ExTable t) {
    final natural = [
      for (var c = 0; c < t.width; c++) [if (t.hasHeader) t.header[c], for (final r in t.rows) r[c]].map(_longest).fold(1, math.max),
    ];
    final widths = _fit(natural);

    List<String> rowLines(List<String> cells) {
      final wrapped = [for (var c = 0; c < t.width; c++) _wrap(cells[c], widths[c])];
      final height = wrapped.map((w) => w.length).fold(1, math.max);
      return [
        for (var i = 0; i < height; i++)
          [
            for (var c = 0; c < t.width; c++)
              () {
                final cell = i < wrapped[c].length ? wrapped[c][i] : '';
                final pad = ' ' * (widths[c] - _len(cell));
                return t.numeric[c] ? '$pad$cell' : '$cell$pad';
              }(),
          ].join('  ').trimRight(),
      ];
    }

    _gap();
    if (t.hasHeader) {
      _out
        ..addAll(rowLines(t.header))
        ..add([for (final w in widths) '-' * w].join('  '));
    }
    for (final r in t.rows) {
      _out.addAll(rowLines(r));
    }
    if (t.caption.isNotEmpty) _out.addAll(t.caption.split('\n'));
  }

  /// The column widths when the natural ones overflow [_tableWidth]: the widest columns give way first.
  static List<int> _fit(List<int> natural) {
    final gaps = 2 * (natural.length - 1);
    int total(int cap) => natural.map((w) => math.min(w, cap)).fold(0, (a, b) => a + b) + gaps;
    var cap = natural.fold(1, math.max);
    while (cap > 8 && total(cap) > _tableWidth) {
      cap--;
    }
    return [for (final w in natural) math.min(w, cap)];
  }
}
