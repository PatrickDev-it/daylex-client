/// ODT: OpenDocument 1.3 text: a named style per role of the document's style (what a block sets apart in an automatic
/// style of its own), lists, a repeating header row, and master pages that carry each page's header and footer, the
/// first page's apart.
library;

import 'dart:typed_data';

import '../model/document.dart';
import '../model/inline.dart';
import 'export_model.dart';
import 'export_text.dart';
import 'odf_common.dart';

Uint8List encodeOdt(PaperDocument doc) {
  final d = buildExportDoc(doc);
  final body = _Body(d);
  final masters = _Masters(d, body.pictures);
  final content = body.content(masters);
  return odfPackage(
    d,
    mediaType: kOdtMime,
    content: content,
    styles: _styles(d, masters),
    pictures: body.pictures.list,
  );
}

/// The named paragraph style of each role.
const _styleNames = {
  StyleRole.body: 'Standard',
  StyleRole.heading1: 'Heading_20_1',
  StyleRole.heading2: 'Heading_20_2',
  StyleRole.heading3: 'Heading_20_3',
  StyleRole.bullets: 'List_20_Bullet',
  StyleRole.table: 'Table_20_Contents',
  StyleRole.tableHeader: 'Table_20_Heading',
  StyleRole.quote: 'Quote',
  StyleRole.callout: 'Callout',
  StyleRole.caption: 'Caption',
  StyleRole.metrics: 'Metrics',
};

String _pt(double v) => ptLength(v);

String _hex(int argb) => '#${hex6(argb)}';

String _generic(FontKind k) => switch (k) {
  FontKind.serif => 'roman',
  FontKind.sans => 'swiss',
  FontKind.mono => 'modern',
};

final _fontFaces = DocFont.values
    .map((f) => '<style:font-face style:name="${f.family}" svg:font-family="&apos;${f.family}&apos;" '
        'style:font-family-generic="${_generic(f.kind)}" style:font-pitch="${f.kind == FontKind.mono ? 'fixed' : 'variable'}"/>')
    .join();

/// `style:text-properties` attributes of [s]: all of them when [only] is null (a named style), else what [only] names.
String _textProps(ResolvedStyle s, Set<String>? only) {
  bool has(String f) => only == null || only.contains(f);
  return [
    if (has('font')) 'style:font-name="${s.font.family}"',
    if (has('size')) 'fo:font-size="${_pt(s.size)}"',
    if (has('bold')) 'fo:font-weight="${s.bold ? 'bold' : 'normal'}"',
    if (has('italic')) 'fo:font-style="${s.italic ? 'italic' : 'normal'}"',
    if (has('underline'))
      s.underline
          ? 'style:text-underline-style="solid" style:text-underline-width="auto" style:text-underline-color="font-color"'
          : 'style:text-underline-style="none"',
    if (has('caps')) 'fo:text-transform="${s.caps ? 'uppercase' : 'none'}"',
    if (has('color')) 'fo:color="${_hex(s.color)}"',
  ].join(' ');
}

/// `style:paragraph-properties` attributes of [s], as [_textProps] picks them; [boxed] false leaves the box out (a
/// table cell, whose box is the table's).
String _paraProps(ResolvedStyle s, Set<String>? only, {bool boxed = true, bool spaced = true}) {
  bool has(String f) => only == null || only.contains(f);
  final box = boxed && ['border', 'borderColor', 'borderWidth', 'padding', 'background'].any(has);
  return [
    if (spaced && has('spaceBefore')) 'fo:margin-top="${_pt(s.spaceBefore)}"',
    if (spaced && has('spaceAfter')) 'fo:margin-bottom="${_pt(s.spaceAfter)}"',
    if (!spaced && only == null) 'fo:margin-top="0pt" fo:margin-bottom="0pt"',
    if (has('lineHeight')) 'fo:line-height="${(s.lineHeight * 100).round()}%"',
    if (has('align'))
      'fo:text-align="${switch (s.align) {
        BlockAlign.left => 'start',
        BlockAlign.center => 'center',
        BlockAlign.right => 'end',
        BlockAlign.justify => 'justify',
      }}"',
    if (boxed && has('indent')) 'fo:margin-left="${_pt(s.indent)}"',
    if (has('firstLineIndent')) 'fo:text-indent="${_pt(s.firstLineIndent)}"',
    if (box) _box(s),
  ].join(' ');
}

/// The box of [s]: its sides, padding and background, each written (a block can drop its role's box).
String _box(ResolvedStyle s) {
  final drawn = s.borderWidth > 0 && s.border != BlockBorder.none;
  final line = '${_pt(s.borderWidth)} solid ${_hex(s.lineColor)}';
  String side(String name, BlockBorder b) =>
      'fo:border-$name="${drawn && (s.border == BlockBorder.box || s.border == b) ? line : 'none'}"';
  return '${side('top', BlockBorder.top)} ${side('left', BlockBorder.left)} ${side('bottom', BlockBorder.bottom)} '
      '${side('right', BlockBorder.box)} fo:padding="${_pt(s.padding)}" '
      'fo:background-color="${s.background == null ? 'transparent' : _hex(s.background!)}"';
}

/// The common text style of a run's emphasis: `Emph_b`, `Emph_bi`, ... (defined in styles.xml).
String? _emphasis(ExRun r, {bool bold = false}) {
  final name = '${r.bold || bold ? 'b' : ''}${r.italic ? 'i' : ''}${r.underline ? 'u' : ''}';
  return name.isEmpty ? null : 'Emph_$name';
}

/// [text] as paragraph content, its emphasis in spans; with [fields], the page fields of a header or footer.
String _spans(String text, {bool bold = false, bool fields = false}) => [
  for (final r in runsOf(text, fields: fields))
    () {
      final inner = switch (r.field) {
        ExField.page => '<text:page-number text:select-page="current">1</text:page-number>',
        ExField.pages => '<text:page-count>1</text:page-count>',
        null => odfText(r.text),
      };
      final style = _emphasis(r, bold: bold);
      return style == null ? inner : '<text:span text:style-name="$style">$inner</text:span>';
    }(),
].join();

/// The pictures of the package, each written once however many places show it.
class _Pictures {
  final list = <({String path, Uint8List bytes, String mime})>[];
  final _paths = Map<Uint8List, String>.identity();

  String add(Uint8List bytes, String extension, String mime) => _paths.putIfAbsent(bytes, () {
    final path = 'Pictures/image${list.length + 1}.$extension';
    list.add((path: path, bytes: bytes, mime: mime));
    return path;
  });
}

/// The master pages: one per distinct header and footer, page 1's own when it differs, each on a page layout that
/// leaves the header and the footer their room.
class _Masters {
  _Masters(this.d, this.pictures) {
    for (final p in d.pages) {
      _name(p);
    }
    if (d.firstDiffers) _masters['first'] = ('First', d.first, _name(d.pages.first));
  }

  final ExportDoc d;
  final _Pictures pictures;
  final _masters = <String, (String, ExPageRegions, String?)>{};
  final _layouts = <String>{};
  var _frames = 0;

  String _name(ExPageRegions r) {
    final existing = _masters[r.key];
    if (existing != null) return existing.$1;
    final name = _masters.isEmpty ? 'Standard' : 'Pagina_${_masters.length + 1}';
    _masters[r.key] = (name, r, null);
    return name;
  }

  /// The master page that page [i] of the document starts.
  String of(int i) => i == 0 && d.firstDiffers ? 'First' : _name(d.pages[i]);

  /// Page layouts and the region paragraph styles (styles.xml's automatic styles), and the master pages.
  (String, String) write() {
    final auto = StringBuffer();
    final masters = StringBuffer();
    for (final (name, r, next) in _masters.values) {
      final header = !r.header.isEmpty, footer = !r.footer.isEmpty;
      final layout = 'pm_${header ? 'h' : ''}${footer ? 'f' : ''}';
      if (_layouts.add(layout)) auto.write(_layout(layout, header: header, footer: footer));
      masters.write('<style:master-page style:name="$name" style:page-layout-name="$layout"${next == null ? '' : ' style:next-style-name="$next"'}>'
          '${header ? '<style:header>${_region(r.header, auto, footer: false)}</style:header>' : ''}'
          '${footer ? '<style:footer>${_region(r.footer, auto, footer: true)}</style:footer>' : ''}</style:master-page>');
    }
    return (auto.toString(), masters.toString());
  }

  /// A page layout: the page, and the header and footer each as far from the edge as the document says, the text
  /// pushed down by a header taller than its margin (as Word does).
  String _layout(String name, {required bool header, required bool footer}) {
    final p = d.page;
    final top = header ? p.headerTwips : p.topTwips, bottom = footer ? p.footerTwips : p.bottomTwips;
    String room(int margin, int edge) => cm((margin - edge).clamp(0, margin));
    return '<style:page-layout style:name="$name"><style:page-layout-properties fo:page-width="${cm(p.widthTwips)}" fo:page-height="${cm(p.heightTwips)}" '
        'style:print-orientation="${p.landscape ? 'landscape' : 'portrait'}" fo:margin-top="${cm(top)}" fo:margin-bottom="${cm(bottom)}" '
        'fo:margin-left="${cm(p.leftTwips)}" fo:margin-right="${cm(p.rightTwips)}" style:writing-mode="lr-tb"/>'
        '${header ? '<style:header-style><style:header-footer-properties fo:min-height="${room(p.topTwips, p.headerTwips)}" fo:margin-bottom="0cm" style:dynamic-spacing="false"/></style:header-style>' : ''}'
        '${footer ? '<style:footer-style><style:header-footer-properties fo:min-height="${room(p.bottomTwips, p.footerTwips)}" fo:margin-top="0cm" style:dynamic-spacing="false"/></style:footer-style>' : ''}'
        '</style:page-layout>';
  }

  /// [r]'s content: one part as paragraphs, two or three side by side in a table; its line between it and the page.
  String _region(ExRegion r, StringBuffer auto, {required bool footer}) {
    final s = r.style!;
    final parent = footer ? 'Footer' : 'Header';
    String paragraph(BlockAlign align) {
      final name = 'R${auto.length}_${align.name}';
      auto.write('<style:style style:name="$name" style:family="paragraph" style:parent-style-name="$parent">'
          '<style:paragraph-properties ${_paraProps(s, const {'lineHeight'})} fo:margin-top="0pt" fo:margin-bottom="0pt" '
          'fo:margin-left="0pt" fo:text-indent="0pt" fo:text-align="${switch (align) {
            BlockAlign.center => 'center',
            BlockAlign.right => 'end',
            _ => 'start',
          }}"/><style:text-properties ${_textProps(s, null)}/></style:style>');
      return name;
    }

    String part(({String text, BlockAlign align, ExLogo? logo}) p) {
      final style = paragraph(p.align);
      final logo = p.logo;
      final picture = logo == null
          ? ''
          : '<text:p text:style-name="$style"><draw:frame draw:style-name="Frame" draw:name="Logo ${++_frames}" text:anchor-type="as-char" '
              'svg:width="${cmFromPt(logo.widthPt)}" svg:height="${cmFromPt(logo.heightPt)}" draw:z-index="0">'
              '<draw:image xlink:href="${pictures.add(logo.bytes, logo.header!.format.extension, logo.header!.format.mime)}" xlink:type="simple" xlink:show="embed" xlink:actuate="onLoad"/>'
              '<svg:title>Logo</svg:title></draw:frame></text:p>';
      return '$picture${p.text.isEmpty ? '' : '<text:p text:style-name="$style">${_spans(p.text, fields: true)}</text:p>'}';
    }

    final shown = r.parts;
    final String content;
    if (shown.length == 1) {
      content = part(shown.single);
    } else {
      final name = 'RT${auto.length}';
      final width = d.page.textWidthTwips ~/ shown.length;
      auto.write('<style:style style:name="$name" style:family="table"><style:table-properties style:width="${cm(width * shown.length)}" table:align="left"/></style:style>'
          '<style:style style:name="$name.A" style:family="table-column"><style:table-column-properties style:column-width="${cm(width)}"/></style:style>'
          '<style:style style:name="$name.C" style:family="table-cell"><style:table-cell-properties fo:padding="0cm" fo:border="none"/></style:style>');
      content = '<table:table table:name="$name" table:style-name="$name"><table:table-column table:style-name="$name.A" table:number-columns-repeated="${shown.length}"/>'
          '<table:table-row>${shown.map((p) => '<table:table-cell table:style-name="$name.C" office:value-type="string">${part(p)}</table:table-cell>').join()}</table:table-row></table:table>';
    }
    if (!r.line || s.borderWidth <= 0) return content;
    final name = 'RL${auto.length}';
    auto.write('<style:style style:name="$name" style:family="paragraph" style:parent-style-name="$parent"><style:paragraph-properties '
        'fo:margin-top="0pt" fo:margin-bottom="0pt" fo:line-height="100%" fo:border-${footer ? 'bottom' : 'top'}="${_pt(s.borderWidth)} solid ${_hex(s.lineColor)}" '
        'fo:padding-${footer ? 'bottom' : 'top'}="${_pt(s.padding)}"/><style:text-properties fo:font-size="2pt"/></style:style>');
    final line = '<text:p text:style-name="$name"/>';
    return footer ? '$line$content' : '$content$line';
  }
}

class _Body {
  _Body(this.d);

  final ExportDoc d;
  final out = StringBuffer();
  final pictures = _Pictures();

  /// Automatic styles made on the way, keyed by what they say so that equal ones are one.
  final _auto = <String, String>{};
  final _autoXml = StringBuffer();
  final _lists = <String, String>{};
  var _page = 0;
  var _pageStart = true;
  var _tables = 0;
  var _frames = 0;
  late _Masters _masters;

  void walk() {
    for (final b in d.blocks) {
      switch (b) {
        case ExHeading(:final level, :final text, :final style):
          out.write('<text:h text:style-name="${_style(style)}" text:outline-level="$level">${_spans(text)}</text:h>');
        case ExParagraph(:final text, :final style):
          _p(text, style);
        case ExBullets():
          _bullets(b);
        case ExTable():
          _table(b);
        case ExMetrics():
          _table(b.asTable());
        case ExQuote(:final text, :final author, :final style, :final authorStyle):
          _p(text, style);
          if (author.isNotEmpty) {
            // The author stands in the quote's box, in the caption's type.
            final q = style.resolved;
            final box = '${_box(q)} fo:margin-left="${_pt(q.indent)}" fo:text-indent="0pt"';
            out.write('<text:p text:style-name="${_style(authorStyle, extra: box)}">${_spans('— $author')}</text:p>');
          }
        case ExCallout(:final title, :final text, :final style):
          if (title.isNotEmpty) out.write('<text:p text:style-name="${_style(style)}">${_spans(title, bold: true)}</text:p>');
          if (text.isNotEmpty) _p(text, style);
        case ExImage():
          _image(b);
        case ExPageBreak():
          _startPage(); // a page with nothing on it still is one
          _page++;
          _pageStart = true;
      }
    }
  }

  void _p(String text, ExStyle st) => out.write('<text:p text:style-name="${_style(st)}">${_spans(text)}</text:p>');

  /// The style a paragraph of [st] takes: its role's named style, or an automatic one over it carrying what the block
  /// sets apart ([extra] paragraph properties too) and, on the first paragraph of a page, the page's master.
  String _style(ExStyle st, {String extra = '', bool cell = false, bool right = false}) {
    final parent = _styleNames[st.role]!;
    final master = _takeMaster();
    final own = right ? st.own.difference(const {'align'}) : st.own;
    final pProps = [_paraProps(st.resolved, own, boxed: !cell, spaced: !cell), extra, if (right) 'fo:text-align="end"']
        .where((p) => p.isNotEmpty)
        .join(' ');
    final tProps = _textProps(st.resolved, st.own);
    if (pProps.isEmpty && tProps.isEmpty && master == null) return parent;
    return _autoStyle('paragraph', parent, master, pProps.isEmpty ? '' : '<style:paragraph-properties $pProps/>', tProps.isEmpty ? '' : '<style:text-properties $tProps/>');
  }

  String _autoStyle(String family, String? parent, String? master, String paragraph, String text) {
    final key = '$family|$parent|$master|$paragraph|$text';
    return _auto.putIfAbsent(key, () {
      final name = 'P${_auto.length + 1}';
      _autoXml.write('<style:style style:name="$name" style:family="$family"${parent == null ? '' : ' style:parent-style-name="$parent"'}'
          '${master == null ? '' : ' style:master-page-name="$master"'}>$paragraph$text</style:style>');
      return name;
    });
  }

  /// The master page to name on the element that starts a page, once per page (the first page only when its own
  /// differs from the rest; a master change starts a page).
  String? _takeMaster() {
    if (!_pageStart) return null;
    _pageStart = false;
    return _page == 0 && !d.firstDiffers ? null : _masters.of(_page);
  }

  /// An empty paragraph that starts the page before what cannot name a master itself (a list).
  void _startPage() {
    if (!_pageStart) return;
    final master = _takeMaster();
    if (master != null) out.write('<text:p text:style-name="${_autoStyle('paragraph', 'Standard', master, '', '')}"/>');
  }

  void _bullets(ExBullets b) {
    _startPage();
    final s = b.style.resolved;
    final marker = s.markerWidth;
    final list = _lists.putIfAbsent('${s.marker.name}|$marker', () {
      final name = 'L${_lists.length + 1}';
      final position = cmFromPt(marker);
      final props = '<style:list-level-properties text:list-level-position-and-space-mode="label-alignment">'
          '<style:list-level-label-alignment text:label-followed-by="listtab" text:list-tab-stop-position="$position" '
          'fo:text-indent="-$position" fo:margin-left="$position"/></style:list-level-properties>';
      final level = switch (s.marker) {
        ListMarker.number => '<text:list-level-style-number text:level="1" style:num-format="1" style:num-suffix=".">$props</text:list-level-style-number>',
        ListMarker.letter => '<text:list-level-style-number text:level="1" style:num-format="a" style:num-suffix=")">$props</text:list-level-style-number>',
        ListMarker.none => '<text:list-level-style-bullet text:level="1" text:bullet-char=" ">$props</text:list-level-style-bullet>',
        _ => '<text:list-level-style-bullet text:level="1" text:bullet-char="${s.marker == ListMarker.dash ? '–' : '•'}">$props</text:list-level-style-bullet>',
      };
      _autoXml.write('<text:list-style style:name="$name">$level</text:list-style>');
      return name;
    });
    final own = b.style.own.difference({'indent'});
    final style = _style(ExStyle(b.style.role, s, own));
    out.write('<text:list text:style-name="$list">');
    for (final i in b.items) {
      out.write('<text:list-item><text:p text:style-name="$style">${_spans(i)}</text:p></text:list-item>');
    }
    out.write('</text:list>');
  }

  void _table(ExTable t) {
    final n = ++_tables;
    final name = 'Tabella$n';
    final s = t.style.resolved;
    final total = d.page.textWidthTwips - (s.indent * 20).round();
    final widths = t.widths(total);
    final master = _takeMaster();
    _autoXml
      ..write('<style:style style:name="$name" style:family="table"${master == null ? '' : ' style:master-page-name="$master"'}>'
          '<style:table-properties style:width="${cm(total)}" table:align="left" fo:margin-left="${_pt(s.indent)}" fo:margin-top="0cm" fo:margin-bottom="0cm"/></style:style>')
      ..writeAll([
        for (final (c, w) in widths.indexed)
          '<style:style style:name="$name.${_columnLetter(c)}" style:family="table-column"><style:table-column-properties style:column-width="${cm(w)}"/></style:style>',
      ]);

    // The table's lines (between rows, every cell or none), padding and fills, as cell styles of its own.
    final line = s.borderWidth > 0 ? '${_pt(s.borderWidth)} solid ${_hex(s.lineColor)}' : 'none';
    final all = s.grid == TableGrid.all, rows = s.grid != TableGrid.none;
    final borders = 'fo:border-top="${all ? line : 'none'}" fo:border-left="${all ? line : 'none'}" '
        'fo:border-bottom="${rows ? line : 'none'}" fo:border-right="${all ? line : 'none'}"';
    String cellStyle(String suffix, int? fill) {
      _autoXml.write('<style:style style:name="$name.$suffix" style:family="table-cell"><style:table-cell-properties '
          'fo:padding="${_pt(s.padding)}" $borders fo:background-color="${fill == null ? 'transparent' : _hex(fill)}"/></style:style>');
      return '$name.$suffix';
    }

    final headCell = cellStyle('H', t.headerStyle.resolved.background ?? s.background);
    final evenCell = cellStyle('E', s.background), oddCell = cellStyle('O', s.stripe ?? s.background);

    String cell(String text, int c, ExStyle st, String cellStyle) {
      final para = _style(st, cell: true, right: t.numeric[c]);
      final lines = text.isEmpty ? '<text:p text:style-name="$para"/>' : '<text:p text:style-name="$para">${_spans(text)}</text:p>';
      return '<table:table-cell table:style-name="$cellStyle" office:value-type="string">$lines</table:table-cell>';
    }

    out.write('<table:table table:name="$name" table:style-name="$name">'
        '${[for (var c = 0; c < t.width; c++) '<table:table-column table:style-name="$name.${_columnLetter(c)}"/>'].join()}');
    if (t.hasHeader) {
      // The header row repeats on every page the table runs onto.
      out.write('<table:table-header-rows><table:table-row>${[for (var c = 0; c < t.width; c++) cell(t.header[c], c, t.headerStyle, headCell)].join()}</table:table-row></table:table-header-rows>');
    }
    for (final (r, row) in t.rows.indexed) {
      out.write('<table:table-row>${[for (var c = 0; c < t.width; c++) cell(row[c], c, t.style, r.isOdd ? oddCell : evenCell)].join()}</table:table-row>');
    }
    out.write('</table:table>');
    if (t.caption.isNotEmpty) _p(t.caption, t.captionStyle);
  }

  /// `A`, `B`, ... `Z`, `AA`: the way a column style is named.
  static String _columnLetter(int c) => c < 26 ? String.fromCharCode(65 + c) : '${_columnLetter(c ~/ 26 - 1)}${_columnLetter(c % 26)}';

  void _image(ExImage img) {
    final header = img.header;
    if (header == null) {
      out.write('<text:p text:style-name="${_style(img.style)}"><text:span text:style-name="Emph_i">${odfText(img.marker)}</text:span></text:p>');
      return;
    }
    final path = pictures.add(img.bytes!, header.format.extension, header.format.mime);
    final (w, h) = img.fit(d.page.textWidthPt, d.page.textHeightPt * 0.8);
    final alt = img.caption.isEmpty ? 'Immagine' : plainInline(img.caption);
    out.write('<text:p text:style-name="${_style(img.style)}">'
        '<draw:frame draw:style-name="Frame" draw:name="Immagine ${++_frames}" text:anchor-type="as-char" svg:width="${cmFromPt(w)}" svg:height="${cmFromPt(h)}" draw:z-index="0">'
        '<draw:image xlink:href="$path" xlink:type="simple" xlink:show="embed" xlink:actuate="onLoad"/>'
        '<svg:title>${xmlEscape(alt)}</svg:title></draw:frame></text:p>');
    if (img.caption.isNotEmpty) _p(img.caption, img.captionStyle);
  }

  /// content.xml, written with the masters each page starts.
  String content(_Masters masters) {
    _masters = masters;
    walk();
    if (out.isEmpty) out.write('<text:p text:style-name="Standard"/>');
    return '$kOdfDecl<office:document-content $kOdfNamespaces office:version="$kOdfVersion">'
        '<office:font-face-decls>$_fontFaces</office:font-face-decls>'
        '<office:automatic-styles>$_autoXml</office:automatic-styles>'
        '<office:body><office:text>$out</office:text></office:body></office:document-content>';
  }
}

String _styles(ExportDoc d, _Masters masters) {
  ResolvedStyle role(StyleRole r) => d.roles[r]!;

  String para(
    String name,
    ResolvedStyle s, {
    String parent = 'Standard',
    String? next,
    String? display,
    String? cls,
    int? outline,
    bool boxed = true,
    bool spaced = true,
    String extra = '',
  }) =>
      '<style:style style:name="$name" style:family="paragraph"${parent.isEmpty ? '' : ' style:parent-style-name="$parent"'}'
      '${next == null ? '' : ' style:next-style-name="$next"'}${display == null ? '' : ' style:display-name="$display"'}'
      '${outline == null ? '' : ' style:default-outline-level="$outline"'}${cls == null ? '' : ' style:class="$cls"'}>'
      '<style:paragraph-properties ${_paraProps(s, null, boxed: boxed, spaced: spaced)}$extra/>'
      '<style:text-properties ${_textProps(s, null)}/></style:style>';

  String heading(int level, StyleRole r) => para(
    'Heading_20_$level',
    role(r),
    parent: 'Heading',
    next: 'Standard',
    display: 'Heading $level',
    outline: level,
    cls: 'text',
    extra: ' fo:keep-with-next="always"',
  );

  String emphasis(String name) =>
      '<style:style style:name="Emph_$name" style:family="text"><style:text-properties'
      '${name.contains('b') ? ' fo:font-weight="bold"' : ''}${name.contains('i') ? ' fo:font-style="italic"' : ''}'
      '${name.contains('u') ? ' style:text-underline-style="solid" style:text-underline-width="auto" style:text-underline-color="font-color"' : ''}/></style:style>';

  final (auto, masterPages) = masters.write();
  final body = role(StyleRole.body);
  return '$kOdfDecl<office:document-styles $kOdfNamespaces office:version="$kOdfVersion">'
      '<office:font-face-decls>$_fontFaces</office:font-face-decls>'
      '<office:styles>'
      '<style:default-style style:family="paragraph"><style:paragraph-properties style:tab-stop-distance="1.25cm"/>'
      '<style:text-properties style:font-name="${body.font.family}" fo:font-size="${_pt(body.size)}" fo:language="it" fo:country="IT"/></style:default-style>'
      '<style:default-style style:family="table-cell"><style:text-properties style:font-name="${body.font.family}" fo:font-size="${_pt(body.size)}" fo:language="it" fo:country="IT"/></style:default-style>'
      '${para('Standard', body, parent: '', cls: 'text')}'
      '${['b', 'i', 'u', 'bi', 'bu', 'iu', 'biu'].map(emphasis).join()}'
      '<style:style style:name="Heading" style:family="paragraph" style:parent-style-name="Standard" style:next-style-name="Standard" style:class="text">'
      '<style:paragraph-properties fo:keep-with-next="always"/></style:style>'
      '${heading(1, StyleRole.heading1)}${heading(2, StyleRole.heading2)}${heading(3, StyleRole.heading3)}'
      '${para('Quote', role(StyleRole.quote), cls: 'html')}'
      '${para('Callout', role(StyleRole.callout))}'
      '${para('List_20_Bullet', role(StyleRole.bullets), display: 'List Bullet', cls: 'list', boxed: false)}'
      '${para('Caption', role(StyleRole.caption), cls: 'extra')}'
      '${para('Illustration', body, cls: 'extra')}'
      '${para('Table_20_Contents', role(StyleRole.table), display: 'Table Contents', cls: 'extra', boxed: false, spaced: false)}'
      '${para('Table_20_Heading', role(StyleRole.tableHeader), parent: 'Table_20_Contents', display: 'Table Heading', cls: 'extra', boxed: false, spaced: false)}'
      '${para('Metrics', role(StyleRole.metrics), cls: 'extra', boxed: false, spaced: false)}'
      '${para('Header', body, cls: 'extra', boxed: false, spaced: false)}'
      '${para('Footer', body, cls: 'extra', boxed: false, spaced: false)}'
      '<style:style style:name="Graphics" style:family="graphic"><style:graphic-properties text:anchor-type="paragraph" svg:x="0cm" svg:y="0cm" style:wrap="none" style:vertical-pos="top" style:vertical-rel="baseline" style:horizontal-pos="left" style:horizontal-rel="paragraph"/></style:style>'
      '<style:style style:name="Frame" style:family="graphic" style:parent-style-name="Graphics"><style:graphic-properties style:vertical-pos="top" style:vertical-rel="baseline" fo:padding="0cm" fo:border="none"/></style:style>'
      '</office:styles>'
      '<office:automatic-styles>$auto</office:automatic-styles>'
      '<office:master-styles>$masterPages</office:master-styles></office:document-styles>';
}
