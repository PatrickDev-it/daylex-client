/// RTF 1.9, in the subset every reader takes: a font table, a colour table, a stylesheet with one style per role of the
/// document's style, real tables with a repeating header row, headers and footers with page fields (page 1's apart),
/// and PNG or JPEG pictures as hex. The file is pure ASCII: everything else is `\uN?`.
library;

import 'dart:convert';
import 'dart:typed_data';

import '../model/document.dart';
import 'export_model.dart';
import 'image_info.dart';

Uint8List encodeRtf(PaperDocument doc) => ascii.encode(_Rtf(buildExportDoc(doc)).build());

/// Escapes [s] for RTF: `\ { }` get a backslash, a newline is `\line`, a tab `\tab`, and what is not ASCII is `\uN?`
/// with N the UTF-16 unit as a signed 16-bit number (an emoji is two units, as Word writes it).
String rtfEscape(String s) {
  final out = StringBuffer();
  for (final u in s.codeUnits) {
    switch (u) {
      case 0x5C || 0x7B || 0x7D:
        out
          ..write(r'\')
          ..writeCharCode(u);
      case 0x0A:
        out.write(r'\line ');
      case 0x09:
        out.write(r'\tab ');
      case >= 0x20 && < 0x7F:
        out.writeCharCode(u);
      case >= 0x7F:
        out.write('\\u${u > 0x7FFF ? u - 0x10000 : u}?');
    }
  }
  return out.toString();
}

/// The stylesheet number of each role's style.
const _styleNumbers = {
  StyleRole.body: 0,
  StyleRole.heading1: 1,
  StyleRole.heading2: 2,
  StyleRole.heading3: 3,
  StyleRole.bullets: 4,
  StyleRole.table: 5,
  StyleRole.tableHeader: 6,
  StyleRole.quote: 7,
  StyleRole.callout: 8,
  StyleRole.caption: 9,
  StyleRole.metrics: 10,
};

const _styleNames = {
  StyleRole.body: 'Normal',
  StyleRole.heading1: 'heading 1',
  StyleRole.heading2: 'heading 2',
  StyleRole.heading3: 'heading 3',
  StyleRole.bullets: 'List Paragraph',
  StyleRole.table: 'Table Text',
  StyleRole.tableHeader: 'Table Header',
  StyleRole.quote: 'Quote',
  StyleRole.callout: 'Callout',
  StyleRole.caption: 'caption',
  StyleRole.metrics: 'Metrics',
};

int _tw(double pt) => (pt * 20).round();

String _fontClass(FontKind k) => switch (k) {
  FontKind.serif => r'\froman',
  FontKind.sans => r'\fswiss',
  FontKind.mono => r'\fmodern',
};

class _Rtf {
  _Rtf(this.d);

  final ExportDoc d;
  final _body = StringBuffer();

  /// The colour table, filled as colours are used: index 0 is the reader's automatic colour.
  final _colors = <int, int>{};
  var _pendingBreak = false;
  var _page = 0;

  /// The colour table index of [argb].
  int _cf(int argb) => _colors.putIfAbsent(argb & 0xFFFFFF, () => _colors.length + 1);

  /// Character formatting of [s], with the emphasis of [run] (or a forced [bold]) on top: RTF repeats it on every
  /// paragraph, so a reader that ignores the stylesheet still shows the page.
  String _chars(ResolvedStyle s, {ExRun? run, bool bold = false}) =>
      '\\f${s.font.index}\\fs${(s.size * 2).round()}\\cf${_cf(s.color)}'
      '${s.bold || bold || (run?.bold ?? false) ? r'\b' : r'\b0'}${s.italic || (run?.italic ?? false) ? r'\i' : r'\i0'}'
      '${s.underline || (run?.underline ?? false) ? r'\ul' : r'\ulnone'}${s.caps ? r'\caps' : r'\caps0'}';

  /// The box of [s]: its sides and background.
  String _box(ResolvedStyle s) {
    final out = StringBuffer();
    if (s.borderWidth > 0 && s.border != BlockBorder.none) {
      final line = '\\brdrs\\brdrw${_tw(s.borderWidth).clamp(1, 75)}\\brsp${_tw(s.padding)}\\brdrcf${_cf(s.lineColor)}';
      if (s.border == BlockBorder.box) {
        out.write('\\box$line');
      } else {
        out.write('\\brdr${switch (s.border) {
          BlockBorder.left => 'l',
          BlockBorder.top => 't',
          _ => 'b',
        }}$line');
      }
    }
    if (s.background != null) out.write('\\cbpat${_cf(s.background!)}');
    return out.toString();
  }

  static String _align(BlockAlign a) => switch (a) {
    BlockAlign.left => r'\ql',
    BlockAlign.center => r'\qc',
    BlockAlign.right => r'\qr',
    BlockAlign.justify => r'\qj',
  };

  /// Paragraph formatting of [s] under its role's style number; the named values override.
  String _para(
    StyleRole role,
    ResolvedStyle s, {
    bool boxed = true,
    double? before,
    double? after,
    String? indent,
    String? align,
    String box = '',
    bool keepNext = false,
  }) =>
      '\\s${_styleNumbers[role]}${keepNext ? r'\keepn' : ''}${_isHeading(role) ? '\\keepn\\outlinelevel${_styleNumbers[role]! - 1}' : ''}'
      '\\sb${_tw(before ?? s.spaceBefore)}\\sa${_tw(after ?? s.spaceAfter)}\\sl${(s.lineHeight * 240).round()}\\slmult1'
      '${align ?? _align(s.align)}${indent ?? '\\li${_tw(boxed ? s.indent : 0)}\\fi${_tw(s.firstLineIndent)}'}'
      '${boxed ? _box(s) : ''}$box';

  static bool _isHeading(StyleRole r) => r == StyleRole.heading1 || r == StyleRole.heading2 || r == StyleRole.heading3;

  String _start(String para) {
    final pb = _pendingBreak ? r'\pagebb' : '';
    _pendingBreak = false;
    return '\\pard\\plain$pb$para ';
  }

  /// [text]'s runs in [s], each in a group of its own formatting.
  String _runs(String text, ResolvedStyle s, {bool bold = false, bool fields = false}) => [
    for (final r in runsOf(text, fields: fields))
      r.field == null
          ? '{${_chars(s, run: r, bold: bold)} ${rtfEscape(r.text)}}'
          : '{${_chars(s, run: r)} {\\field{\\*\\fldinst ${r.field == ExField.page ? 'PAGE' : 'NUMPAGES'}}{\\fldrslt 1}}}',
  ].join();

  void _p(String text, ExStyle st, {bool bold = false, String box = '', String? indent, bool keepNext = false}) {
    final s = st.resolved;
    _body.writeln('${_start(_para(st.role, s, box: box, indent: indent, keepNext: keepNext))}${_runs(text, s, bold: bold)}\\par');
  }

  String build() {
    for (final b in d.blocks) {
      switch (b) {
        case ExHeading(:final text, :final style) || ExParagraph(:final text, :final style):
          _p(text, style);
        case ExBullets():
          _bullets(b);
        case ExTable():
          _table(b);
        case ExMetrics():
          _table(b.asTable());
        case ExQuote(:final text, :final author, :final style, :final authorStyle):
          _p(text, style, keepNext: author.isNotEmpty);
          // The author stands in the quote's box, in the caption's type.
          if (author.isNotEmpty) {
            _p('— $author', authorStyle, box: _box(style.resolved), indent: '\\li${_tw(style.resolved.indent)}\\fi0');
          }
        case ExCallout(:final title, :final text, :final style):
          if (title.isNotEmpty) _p(title, style, bold: true, keepNext: text.isNotEmpty);
          if (text.isNotEmpty) _p(text, style);
        case ExImage():
          _image(b);
        case ExPageBreak():
          // A page with nothing on it still is one.
          if (_pendingBreak) _body.writeln('${_start('')}\\par');
          if (d.perPage) {
            // Each page of the document is a section with its own header and footer; a section starts a page.
            _page++;
            _body.writeln('\\sect${_section(_page)}');
          } else {
            _pendingBreak = true;
          }
      }
    }
    final p = d.page;
    final section = _section(0);
    final styles = [
      for (final role in StyleRole.values)
        '{${_para(role, d.roles[role]!, boxed: role != StyleRole.table && role != StyleRole.tableHeader && role != StyleRole.metrics)}'
            '${_chars(d.roles[role]!)}${role == StyleRole.body ? '' : '\\sbasedon0\\snext0'} ${_styleNames[role]};}',
    ].join();
    return '{\\rtf1\\ansi\\ansicpg1252\\uc1\\deff${d.roles[StyleRole.body]!.font.index}\\deflang1040\\deflangfe1040\n'
        '{\\fonttbl${DocFont.values.map((f) => '{\\f${f.index}${_fontClass(f.kind)}\\fcharset0 ${f.family};}').join()}}\n'
        '{\\colortbl;${_colors.keys.map((c) => '\\red${(c >> 16) & 0xFF}\\green${(c >> 8) & 0xFF}\\blue${c & 0xFF};').join()}}\n'
        '{\\*\\generator Daylex;}\n'
        '{\\stylesheet$styles}\n'
        '{\\info{\\title ${rtfEscape(d.title)}}${d.subtitle.isEmpty ? '' : '{\\subject ${rtfEscape(d.subtitle)}}'}{\\author ${rtfEscape(d.creator)}}'
        '${d.brand.isEmpty ? '' : '{\\*\\company ${rtfEscape(d.brand)}}'}{\\creatim${_time(d.created)}}{\\revtim${_time(d.modified)}}}\n'
        '\\paperw${p.widthTwips}\\paperh${p.heightTwips}${p.landscape ? r'\landscape' : ''}\\margl${p.leftTwips}\\margr${p.rightTwips}'
        '\\margt${p.topTwips}\\margb${p.bottomTwips}\\widowctrl\n'
        '$section\n'
        '$_body}';
  }

  /// The section of page [i]: the page set-up and its header and footer, page 1's own when it differs.
  String _section(int i) {
    final p = d.page;
    final first = i == 0 && d.firstDiffers;
    final r = d.pages[i];
    final out = StringBuffer('\\sectd\\sbkpage\\pgwsxn${p.widthTwips}\\pghsxn${p.heightTwips}${p.landscape ? r'\lndscpsxn' : ''}'
        '\\marglsxn${p.leftTwips}\\margrsxn${p.rightTwips}\\margtsxn${p.topTwips}\\margbsxn${p.bottomTwips}'
        '\\headery${p.headerTwips}\\footery${p.footerTwips}${first ? r'\titlepg' : ''}\n');
    // Every section says its header and footer, empty ones too: a section that does not would repeat the last.
    out
      ..write('{\\header ${_region(r.header, footer: false)}}\n')
      ..write('{\\footer ${_region(r.footer, footer: true)}}\n');
    if (first) {
      out
        ..write('{\\headerf ${_region(d.first.header, footer: false)}}\n')
        ..write('{\\footerf ${_region(d.first.footer, footer: true)}}\n');
    }
    return out.toString();
  }

  /// [r]'s content: one part as paragraphs, two or three side by side in a borderless row; its line between it and
  /// the page.
  String _region(ExRegion r, {required bool footer}) {
    if (r.isEmpty) return r'\pard\plain\par';
    final s = r.style!;
    String part(({String text, BlockAlign align, ExLogo? logo}) p, {String end = r'\par'}) {
      final para = '\\pard\\plain\\sb0\\sa0\\sl${(s.lineHeight * 240).round()}\\slmult1${_align(p.align)}';
      final logo = p.logo;
      return [
        if (logo != null) '$para${_picture(logo.bytes, logo.header!, logo.widthPt, logo.heightPt)}${p.text.isEmpty ? end : r'\par'}',
        if (p.text.isNotEmpty) '$para ${_runs(p.text, s, fields: true)}$end',
      ].join('\n');
    }

    final shown = r.parts;
    final row = shown.length > 1;
    final width = d.page.textWidthTwips ~/ shown.length;
    final content = row
        ? '\\trowd\\trgaph0\\trleft0${[for (var c = 1; c <= shown.length; c++) '\\cellx${width * c}'].join()}\n'
              '${shown.map((p) => part(p, end: r'\cell').replaceAll(r'\pard\plain', r'\pard\plain\intbl')).join('\n')}\n\\row'
        : part(shown.single);
    final line = r.line && s.borderWidth > 0
        ? '\\pard\\plain\\sb0\\sa0\\sl20\\slmult0\\brdr${footer ? 'b' : 't'}\\brdrs\\brdrw${_tw(s.borderWidth).clamp(1, 75)}'
              '\\brsp${_tw(s.padding)}\\brdrcf${_cf(s.lineColor)}\\fs4\\par'
        : null;
    // The line stands between the region and the page; a region that would end on a row ends on a paragraph of its
    // own, or some readers run the row into the page.
    const end = r'\pard\plain\sb0\sa0\sl-20\slmult0\fs2\par';
    return [
      if (footer && line != null) line,
      content,
      if (!footer && line != null) line else if (row) end,
    ].join('\n');
  }

  static String _time(DateTime t) {
    final u = t.toUtc();
    return '\\yr${u.year}\\mo${u.month}\\dy${u.day}\\hr${u.hour}\\min${u.minute}\\sec${u.second}';
  }

  /// A thin paragraph after a table: Word needs one, and two tables would run together without it.
  void _spacer() => _body.writeln('${_start(r'\sa0\sl-20\slmult0')}{\\fs4}\\par');

  void _bullets(ExBullets b) {
    final s = b.style.resolved;
    final marker = _tw(s.markerWidth);
    final markerChars = '\\f${s.font.index}\\fs${(s.size * 2).round()}\\cf${_cf(s.color)}\\b0\\i0\\ulnone\\caps0';
    for (final (i, item) in b.items.indexed) {
      // The marker is written out: every reader shows it, numbered lists restart with each list.
      final para = _para(b.style.role, s, before: i == 0 ? null : 0, indent: '\\li$marker\\fi-$marker\\tx$marker');
      _body.writeln('${_start(para)}{$markerChars ${rtfEscape(listMarker(s.marker, i))}\\tab}${_runs(item, s)}\\par');
    }
  }

  void _table(ExTable t) {
    if (_pendingBreak) _spacer();
    final s = t.style.resolved;
    final indent = _tw(s.indent);
    final widths = t.widths(d.page.textWidthTwips - indent);
    var edge = indent;
    final edges = [for (final w in widths) edge += w];
    final line = s.borderWidth > 0 ? '\\brdrs\\brdrw${_tw(s.borderWidth).clamp(1, 75)}\\brdrcf${_cf(s.lineColor)}' : '';
    final all = s.grid == TableGrid.all, rows = s.grid != TableGrid.none;
    final borders = line.isEmpty
        ? ''
        : '${all ? '\\clbrdrt$line\\clbrdrl$line\\clbrdrr$line' : ''}${rows ? '\\clbrdrb$line' : ''}';
    final pad = _tw(s.padding);

    String row(int? fill, {required bool header}) =>
        '\\trowd\\trgaph$pad\\trleft$indent\\trpaddl$pad\\trpaddr$pad\\trpaddt$pad\\trpaddb$pad\\trpaddfl3\\trpaddfr3\\trpaddft3\\trpaddfb3'
        '\\trkeep${header ? r'\trhdr' : ''}'
        '${[for (final e in edges) '\\clvertalt$borders${fill == null ? '' : '\\clcbpat${_cf(fill)}'}\\cellx$e'].join()}';

    String cells(List<String> texts, ExStyle st) => [
      for (var c = 0; c < t.width; c++)
        '${_start('${_para(st.role, st.resolved, boxed: false, before: 0, after: 0, align: t.numeric[c] ? r'\qr' : null)}\\intbl')}'
            '${_runs(texts[c], st.resolved)}\\cell',
    ].join('\n');

    if (t.hasHeader) {
      _body.writeln('${row(t.headerStyle.resolved.background ?? s.background, header: true)}\n${cells(t.header, t.headerStyle)}\n\\row');
    }
    for (final (r, texts) in t.rows.indexed) {
      _body.writeln('${row(r.isOdd ? (s.stripe ?? s.background) : s.background, header: false)}\n${cells(texts, t.style)}\n\\row');
    }
    if (t.caption.isEmpty) {
      _spacer();
    } else {
      _p(t.caption, t.captionStyle);
    }
  }

  /// A PNG or JPEG as hex, at [w] by [h] points.
  static String _picture(Uint8List bytes, ImageHeader header, double w, double h) {
    final blip = header.format == ImageFormat.png ? 'pngblip' : 'jpegblip';
    final hex = StringBuffer();
    for (var i = 0; i < bytes.length; i++) {
      hex.write(bytes[i].toRadixString(16).padLeft(2, '0'));
      if (i % 64 == 63) hex.write('\n');
    }
    return '{\\pict\\$blip\\picw${header.width}\\pich${header.height}'
        '\\picwgoal${_tw(w)}\\pichgoal${_tw(h)}\\picscalex100\\picscaley100\n$hex}';
  }

  void _image(ExImage img) {
    final header = img.header;
    // RTF carries PNG and JPEG pictures; a GIF or an unreadable image is named instead.
    if (header == null || header.format == ImageFormat.gif) {
      final s = img.style.resolved;
      _body.writeln('${_start(_para(img.style.role, s))}{${_chars(s)}\\i ${rtfEscape(img.marker)}}\\par');
      return;
    }
    final (w, h) = img.fit(d.page.textWidthPt, d.page.textHeightPt * 0.8);
    _body.writeln('${_start(_para(img.style.role, img.style.resolved, keepNext: img.caption.isNotEmpty))}${_picture(img.bytes!, header, w, h)}\\par');
    if (img.caption.isNotEmpty) _p(img.caption, img.captionStyle);
  }
}
