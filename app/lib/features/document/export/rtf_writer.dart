/// RTF 1.9, in the subset every reader takes: a font table, a colour table, a stylesheet, a list table, real tables
/// with a repeating header row, and PNG or JPEG pictures as hex. The file is pure ASCII: everything else is `\uN?`.
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

/// The colour table's indexes: 1 ink, 2 accent, 3 tint, 4 strong tint, 5 muted, 6 hairline.
const _ink = r'\cf1', _accent = r'\cf2', _muted = r'\cf5';
const _hairlineCf = 6;

/// The paragraph styles: number, name and the formatting the style carries. A paragraph repeats the formatting
/// directly as well, so a reader that ignores the stylesheet still shows the same page.
class _Style {
  const _Style(this.n, this.name, this.props);
  final int n;
  final String name;
  final String props;
}

String _border(String side, int cf, int width, int space) => '\\brdr$side\\brdrs\\brdrw$width\\brsp$space\\brdrcf$cf';

final _styles = <String, _Style>{
  'normal': const _Style(0, 'Normal', r'\sa120\sl288\slmult1\fs22'),
  'title': _Style(1, 'Title', '\\keepn\\sa160\\b\\fs60$_ink'),
  'subtitle': _Style(2, 'Subtitle', '\\sa200\\fs28$_muted'),
  'h1': _Style(3, 'heading 1', '\\keepn\\sb360\\sa120\\outlinelevel0\\b\\fs44$_ink'),
  'h2': _Style(4, 'heading 2', '\\keepn\\sb280\\sa100\\outlinelevel1\\b\\fs28$_ink'),
  'h3': _Style(5, 'heading 3', '\\keepn\\sb200\\sa80\\outlinelevel2\\b\\fs22$_accent'),
  'detail': _Style(6, 'Detail', '\\sa40\\fs20$_muted'),
  'label': _Style(7, 'Section Label', '\\keepn\\sa120\\b\\caps\\fs16$_accent'),
  'quote': _Style(8, 'Quote', '\\sb120\\sa60\\li340${_border('l', 2, 23, 200)}\\i\\fs26$_ink'),
  'author': _Style(9, 'Quote Author', '\\sa160\\li340${_border('l', 2, 23, 200)}\\fs17$_muted'),
  'callout': _Style(
    10,
    'Callout',
    '\\sb60\\sa60\\li170\\ri170${_border('t', 4, 10, 120)}${_border('l', 4, 10, 120)}${_border('b', 4, 10, 120)}${_border('r', 4, 10, 120)}\\cbpat3\\fs20',
  ),
  'list': _Style(11, 'List Paragraph', r'\ls1\ilvl0\fi-360\li720\sa60\fs22'),
  'caption': _Style(12, 'caption', '\\sb60\\sa200\\fs17$_muted'),
  'cell': _Style(13, 'Table Text', r'\sa0\fs18'),
  'th': _Style(14, 'Table Header', '\\sa0\\keepn\\b\\fs17$_accent'),
  'footer': _Style(15, 'footer', '\\sa0\\fs15$_muted'),
};

class _Rtf {
  _Rtf(this.d);

  final ExportDoc d;
  final _body = StringBuffer();
  var _pendingBreak = false;

  String _start(String key, {String extra = ''}) {
    final s = _styles[key]!;
    final pb = _pendingBreak ? r'\pagebb' : '';
    _pendingBreak = false;
    return '\\pard\\plain\\s${s.n}$pb${s.props}$extra ';
  }

  void _p(String key, String text, {String extra = ''}) {
    _body.writeln('${_start(key, extra: extra)}${rtfEscape(text)}\\par');
  }

  String build() {
    for (final b in d.blocks) {
      switch (b) {
        case ExTitle(:final text):
          _p('title', text);
        case ExSubtitle(:final text):
          _p('subtitle', text);
        case ExFact(:final label, :final value):
          _body.writeln('${_start('detail')}{\\b ${rtfEscape('$label: ')}}${rtfEscape(value)}\\par');
        case ExSectionLabel(:final text):
          _p('label', text);
        case ExHeading(:final level, :final text):
          _p('h$level', text);
        case ExParagraph(:final text):
          _p('normal', text);
        case ExBullets(:final items):
          for (final i in items) {
            _body.writeln('${_start('list')}{\\listtext\\u8226?\\tab}${rtfEscape(i)}\\par');
          }
        case ExTable():
          _table(b);
        case ExMetrics():
          _table(b.asTable());
        case ExQuote(:final text, :final author):
          _p('quote', text);
          if (author.isNotEmpty) _p('author', '— $author');
        case ExCallout(:final title, :final text):
          _body.writeln('${_start('callout')}{\\b ${rtfEscape(title)}}\\par');
          if (text.isNotEmpty) _p('callout', text);
        case ExImage():
          _image(b);
        case ExPageBreak():
          _pendingBreak = true;
      }
    }
    return '{\\rtf1\\ansi\\ansicpg1252\\uc1\\deff0\\deflang1040\\deflangfe1040\n'
        '{\\fonttbl{\\f0\\fswiss\\fcharset0 Arial;}}\n'
        '{\\colortbl;${_colors()}}\n'
        '{\\*\\generator Daylex;}\n'
        '{\\stylesheet${_styles.values.map((s) => '{\\s${s.n}${s.props}${s.n == 0 ? '' : '\\sbasedon0\\snext0'} ${s.name};}').join()}}\n'
        '$_listTable\n'
        '{\\info{\\title ${rtfEscape(d.title)}}${d.subtitle.isEmpty ? '' : '{\\subject ${rtfEscape(d.subtitle)}}'}{\\author ${rtfEscape(d.creator)}}'
        '${d.brand.isEmpty ? '' : '{\\*\\company ${rtfEscape(d.brand)}}'}{\\creatim${_time(d.created)}}{\\revtim${_time(d.modified)}}}\n'
        '\\paperw${ExPageSetup.widthTwips}\\paperh${ExPageSetup.heightTwips}\\margl${d.page.marginXTwips}\\margr${d.page.marginXTwips}'
        '\\margt${ExPageSetup.marginYTwips}\\margb${ExPageSetup.marginYTwips}\\footery${ExPageSetup.footerTwips}\\widowctrl\n'
        '\\sectd\\sbknone\\pgwsxn${ExPageSetup.widthTwips}\\pghsxn${ExPageSetup.heightTwips}\n'
        '{\\footer${_start('footer', extra: '\\tqr\\tx${d.page.textWidthTwips}')}${rtfEscape(d.footerText)}\\tab ${rtfEscape('Pagina ')}'
        '{\\field{\\*\\fldinst PAGE}{\\fldrslt 1}}${rtfEscape(' di ')}{\\field{\\*\\fldinst NUMPAGES}{\\fldrslt 1}}\\par}\n'
        '$_body}';
  }

  String _colors() => [
    int.parse(ExColors.ink, radix: 16),
    d.accent & 0xFFFFFF,
    int.parse(d.tintHex, radix: 16),
    int.parse(d.tintStrongHex, radix: 16),
    int.parse(ExColors.muted, radix: 16),
    int.parse(ExColors.hairline, radix: 16),
  ].map((c) => '\\red${(c >> 16) & 0xFF}\\green${(c >> 8) & 0xFF}\\blue${c & 0xFF};').join();

  static String _time(DateTime t) {
    final u = t.toUtc();
    return '\\yr${u.year}\\mo${u.month}\\dy${u.day}\\hr${u.hour}\\min${u.minute}\\sec${u.second}';
  }

  /// A thin paragraph after a table: Word needs one, and two tables would run together without it.
  void _spacer() => _body.writeln('${_start('normal', extra: r'\sa0\sl-120\slmult0\fs4')}\\par');

  void _table(ExTable t) {
    if (_pendingBreak) _spacer();
    final widths = t.widths(d.page.textWidthTwips);
    var edge = 0;
    final edges = [for (final w in widths) edge += w];

    String row({required bool header}) {
      final b = [
        for (final side in ['t', 'l', 'b', 'r']) '\\clbrdr$side\\brdrs\\brdrw5\\brdrcf$_hairlineCf',
      ].join();
      return '\\trowd\\trgaph100\\trleft0\\trkeep${header ? '\\trhdr' : ''}'
          '${[for (final e in edges) '\\clvertalc$b${header ? '\\clcbpat3' : ''}\\cellx$e'].join()}';
    }

    String cells(List<String> texts, {required bool header}) => [
      for (var c = 0; c < t.width; c++)
        '${_start(header ? 'th' : 'cell', extra: '\\intbl${t.numeric[c] ? '\\qr' : ''}')}${rtfEscape(texts[c])}\\cell',
    ].join('\n');

    if (t.hasHeader) _body.writeln('${row(header: true)}\n${cells(t.header, header: true)}\n\\row');
    for (final r in t.rows) {
      _body.writeln('${row(header: false)}\n${cells(r, header: false)}\n\\row');
    }
    if (t.caption.isEmpty) {
      _spacer();
    } else {
      _p('caption', t.caption);
    }
  }

  void _image(ExImage img) {
    final header = img.header;
    // RTF carries PNG and JPEG pictures; a GIF or an unreadable image is named instead.
    if (header == null || header.format == ImageFormat.gif) {
      _p('detail', img.marker, extra: r'\i');
      return;
    }
    final (w, h) = img.fit(d.page.textWidthPt, d.page.textHeightPt * 0.8);
    final blip = header.format == ImageFormat.png ? 'pngblip' : 'jpegblip';
    final hex = StringBuffer();
    final bytes = img.bytes!;
    for (var i = 0; i < bytes.length; i++) {
      hex.write(bytes[i].toRadixString(16).padLeft(2, '0'));
      if (i % 64 == 63) hex.write('\n');
    }
    _body.writeln('${_start('normal', extra: r'\sa60')}{\\pict\\$blip\\picw${header.width}\\pich${header.height}'
        '\\picwgoal${(w * 20).round()}\\pichgoal${(h * 20).round()}\\picscalex100\\picscaley100\n$hex}\\par');
    if (img.caption.isNotEmpty) _p('caption', img.caption);
  }
}

/// One bullet list for the whole document: nine levels, the first in the accent colour's place of the PDF.
final _listTable = '{\\*\\listtable{\\list\\listtemplateid1\\listhybrid${_listLevels()}{\\listname ;}\\listid1}}\n'
    '{\\*\\listoverridetable{\\listoverride\\listid1\\listoverridecount0\\ls1}}';

String _listLevels() => [
  for (var i = 0; i < 9; i++)
    '{\\listlevel\\levelnfc23\\levelnfcn23\\leveljc0\\leveljcn0\\levelfollow0\\levelstartat1\\levelspace360\\levelindent0'
        "{\\leveltext\\leveltemplateid${i + 1}\\'01\\uc1\\u${const [8226, 8211, 9642][i % 3]}?;}{\\levelnumbers;}\\f0\\fi-360\\li${720 * (i + 1)}\\lin${720 * (i + 1)}}",
].join();
