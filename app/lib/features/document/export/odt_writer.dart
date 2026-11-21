/// ODT: OpenDocument 1.3 text, with named styles, a list style, a repeating header row and a footer with page numbers.
library;

import 'dart:typed_data';

import '../model/document.dart';
import 'export_model.dart';
import 'export_text.dart';
import 'odf_common.dart';

Uint8List encodeOdt(PaperDocument doc) {
  final d = buildExportDoc(doc);
  final body = _Body(d)..walk();
  return odfPackage(
    d,
    mediaType: kOdtMime,
    content: body.content(),
    styles: _styles(d),
    pictures: body.pictures,
  );
}

class _Body {
  _Body(this.d);

  final ExportDoc d;
  final out = StringBuffer();
  final pictures = <({String path, Uint8List bytes, String mime})>[];

  /// Automatic styles made on the way: a paragraph style that starts a page, one per parent style used.
  final _breakStyles = <String>{};
  final _tableStyles = StringBuffer();
  var _pendingBreak = false;
  var _tables = 0;
  var _frames = 0;

  void walk() {
    for (final b in d.blocks) {
      switch (b) {
        case ExTitle(:final text):
          _p(text, 'Title');
        case ExSubtitle(:final text):
          _p(text, 'Subtitle');
        case ExFact(:final label, :final value):
          _raw('Detail', '<text:span text:style-name="Strong">${odfText('$label: ')}</text:span>${odfText(value)}');
        case ExSectionLabel(:final text):
          _p(text, 'Section_20_Label');
        case ExHeading(:final level, :final text):
          final style = _style('Heading_20_$level');
          out.write('<text:h text:style-name="$style" text:outline-level="$level">${odfText(text)}</text:h>');
        case ExParagraph(:final text):
          _p(text, 'Standard');
        case ExBullets(:final items):
          _takeBreakAsSpacer();
          out.write('<text:list text:style-name="Bullets">');
          for (final i in items) {
            out.write('<text:list-item><text:p text:style-name="List_20_Bullet">${odfText(i)}</text:p></text:list-item>');
          }
          out.write('</text:list>');
        case ExTable():
          _table(b);
        case ExMetrics():
          _table(b.asTable());
        case ExQuote(:final text, :final author):
          _p(text, 'Quote');
          if (author.isNotEmpty) _p('— $author', 'Quote_20_Author');
        case ExCallout(:final title, :final text):
          _raw('Callout', '<text:span text:style-name="Strong">${odfText(title)}</text:span>');
          if (text.isNotEmpty) _p(text, 'Callout');
        case ExImage():
          _image(b);
        case ExPageBreak():
          _pendingBreak = true;
      }
    }
  }

  /// The paragraph style to use now: [name], or its twin that starts a page when a break is pending.
  String _style(String name) {
    if (!_pendingBreak) return name;
    _pendingBreak = false;
    _breakStyles.add(name);
    return 'PB_$name';
  }

  void _p(String text, String style) => _raw(style, odfText(text));

  void _raw(String style, String inner) {
    out.write('<text:p text:style-name="${_style(style)}">$inner</text:p>');
  }

  /// A page break that falls before something with no paragraph of its own (a list, a table).
  void _takeBreakAsSpacer() {
    if (!_pendingBreak) return;
    out.write('<text:p text:style-name="${_style('Standard')}"/>');
  }

  void _table(ExTable t) {
    _takeBreakAsSpacer();
    final n = ++_tables;
    final name = 'Tabella$n';
    final widths = t.widths(d.page.textWidthTwips);
    _tableStyles
      ..write('<style:style style:name="$name" style:family="table"><style:table-properties style:width="${cm(d.page.textWidthTwips)}" table:align="left" fo:margin-top="0.1cm" fo:margin-bottom="0.3cm"/></style:style>')
      ..writeAll([
        for (final (c, w) in widths.indexed)
          '<style:style style:name="$name.${_columnLetter(c)}" style:family="table-column"><style:table-column-properties style:column-width="${cm(w)}"/></style:style>',
      ]);

    String cell(String text, int c, {required bool header}) {
      final para = t.numeric[c] ? (header ? 'Table_20_Heading_20_End' : 'Table_20_Contents_20_End') : (header ? 'Table_20_Heading' : 'Table_20_Contents');
      final lines = text.isEmpty ? '<text:p text:style-name="$para"/>' : '<text:p text:style-name="$para">${odfText(text)}</text:p>';
      return '<table:table-cell table:style-name="${header ? 'CellHeader' : 'CellBody'}" office:value-type="string">$lines</table:table-cell>';
    }

    out.write('<table:table table:name="$name" table:style-name="$name">'
        '${[for (var c = 0; c < t.width; c++) '<table:table-column table:style-name="$name.${_columnLetter(c)}"/>'].join()}');
    if (t.hasHeader) {
      // The header row repeats on every page the table runs onto.
      out.write('<table:table-header-rows><table:table-row>${[for (var c = 0; c < t.width; c++) cell(t.header[c], c, header: true)].join()}</table:table-row></table:table-header-rows>');
    }
    for (final r in t.rows) {
      out.write('<table:table-row>${[for (var c = 0; c < t.width; c++) cell(r[c], c, header: false)].join()}</table:table-row>');
    }
    out.write('</table:table>');
    if (t.caption.isNotEmpty) _p(t.caption, 'Caption');
  }

  /// `A`, `B`, ... `Z`, `AA`: the way a column style is named.
  static String _columnLetter(int c) => c < 26 ? String.fromCharCode(65 + c) : '${_columnLetter(c ~/ 26 - 1)}${_columnLetter(c % 26)}';

  void _image(ExImage img) {
    final header = img.header;
    if (header == null) {
      _p(img.marker, 'Detail');
      return;
    }
    final n = pictures.length + 1;
    final path = 'Pictures/image$n.${header.format.extension}';
    pictures.add((path: path, bytes: img.bytes!, mime: header.format.mime));
    final (w, h) = img.fit(d.page.textWidthPt, d.page.textHeightPt * 0.8);
    final alt = img.caption.isEmpty ? 'Immagine' : img.caption;
    _raw(
      'Illustration',
      '<draw:frame draw:style-name="Frame" draw:name="Immagine ${++_frames}" text:anchor-type="as-char" svg:width="${cmFromPt(w)}" svg:height="${cmFromPt(h)}" draw:z-index="0">'
      '<draw:image xlink:href="$path" xlink:type="simple" xlink:show="embed" xlink:actuate="onLoad"/>'
      '<svg:title>${xmlEscape(alt)}</svg:title></draw:frame>',
    );
    if (img.caption.isNotEmpty) _p(img.caption, 'Caption');
  }

  String content() {
    final breaks = [
      for (final parent in _breakStyles)
        '<style:style style:name="PB_$parent" style:family="paragraph" style:parent-style-name="$parent"><style:paragraph-properties fo:break-before="page"/></style:style>',
    ];
    return '$kOdfDecl<office:document-content $kOdfNamespaces office:version="$kOdfVersion">'
        '<office:font-face-decls>$_fontFace</office:font-face-decls>'
        '<office:automatic-styles>${breaks.join()}$_tableStyles'
        '<style:style style:name="CellHeader" style:family="table-cell"><style:table-cell-properties fo:background-color="#${d.tintHex}" fo:padding="0.1cm" fo:border="0.5pt solid #${ExColors.hairline}"/></style:style>'
        '<style:style style:name="CellBody" style:family="table-cell"><style:table-cell-properties fo:padding="0.1cm" fo:border="0.5pt solid #${ExColors.hairline}"/></style:style>'
        '</office:automatic-styles><office:body><office:text>$out</office:text></office:body></office:document-content>';
  }
}

const _fontFace = '<style:font-face style:name="Arial" svg:font-family="Arial" style:font-family-generic="swiss" style:font-pitch="variable"/>';

String _styles(ExportDoc d) {
  final accent = '#${d.accentHex}';
  final tint = '#${d.tintHex}', strong = '#${d.tintStrongHex}';
  final textWidth = cm(d.page.textWidthTwips);
  const ink = '#${ExColors.ink}', muted = '#${ExColors.muted}';

  String para(
    String name, {
    String parent = 'Standard',
    String? next,
    String? display,
    String? cls,
    int? outline,
    String pProps = '',
    String tProps = '',
    String children = '',
  }) =>
      '<style:style style:name="$name" style:family="paragraph"${parent.isEmpty ? '' : ' style:parent-style-name="$parent"'}'
      '${next == null ? '' : ' style:next-style-name="$next"'}${display == null ? '' : ' style:display-name="$display"'}'
      '${outline == null ? '' : ' style:default-outline-level="$outline"'}${cls == null ? '' : ' style:class="$cls"'}>'
      '${pProps.isEmpty && children.isEmpty ? '' : '<style:paragraph-properties $pProps>$children</style:paragraph-properties>'}'
      '${tProps.isEmpty ? '' : '<style:text-properties $tProps/>'}</style:style>';

  String heading(int level, String size, String color, String before, String after) => para(
    'Heading_20_$level',
    parent: 'Heading',
    next: 'Standard',
    display: 'Heading $level',
    outline: level,
    cls: 'text',
    pProps: 'fo:margin-top="$before" fo:margin-bottom="$after"',
    tProps: 'fo:font-size="$size" fo:font-weight="bold" fo:color="$color"',
  );

  final mx = cm(d.page.marginXTwips), my = cm(ExPageSetup.marginYTwips);
  return '$kOdfDecl<office:document-styles $kOdfNamespaces office:version="$kOdfVersion">'
      '<office:font-face-decls>$_fontFace</office:font-face-decls>'
      '<office:styles>'
      '<style:default-style style:family="paragraph"><style:paragraph-properties style:tab-stop-distance="1.25cm"/>'
      '<style:text-properties style:font-name="Arial" fo:font-size="11pt" fo:language="it" fo:country="IT"/></style:default-style>'
      '<style:default-style style:family="table-cell"><style:text-properties style:font-name="Arial" fo:font-size="11pt" fo:language="it" fo:country="IT"/></style:default-style>'
      '${para('Standard', parent: '', cls: 'text', pProps: 'fo:margin-top="0cm" fo:margin-bottom="0.212cm" fo:line-height="130%"')}'
      '<style:style style:name="Strong" style:family="text" style:display-name="Strong"><style:text-properties fo:font-weight="bold"/></style:style>'
      '${para('Title', next: 'Subtitle', cls: 'chapter', pProps: 'fo:margin-bottom="0.28cm" fo:keep-with-next="always"', tProps: 'fo:font-size="30pt" fo:font-weight="bold" fo:color="$ink"')}'
      '${para('Subtitle', next: 'Standard', cls: 'chapter', pProps: 'fo:margin-bottom="0.35cm"', tProps: 'fo:font-size="14pt" fo:color="$muted"')}'
      '${para('Heading', next: 'Standard', cls: 'text', pProps: 'fo:keep-with-next="always"')}'
      '${heading(1, '22pt', ink, '0.63cm', '0.21cm')}${heading(2, '14pt', ink, '0.49cm', '0.18cm')}${heading(3, '11pt', accent, '0.35cm', '0.14cm')}'
      '${para('Quote', cls: 'html', pProps: 'fo:margin-left="0.6cm" fo:margin-top="0.21cm" fo:margin-bottom="0.1cm" fo:border-left="2.25pt solid $accent" fo:padding-left="0.3cm" fo:border-top="none" fo:border-bottom="none" fo:border-right="none"', tProps: 'fo:font-size="13pt" fo:font-style="italic" fo:color="$ink"')}'
      '${para('Quote_20_Author', display: 'Quote Author', pProps: 'fo:margin-left="0.6cm" fo:margin-bottom="0.28cm" fo:border-left="2.25pt solid $accent" fo:padding-left="0.3cm" fo:border-top="none" fo:border-bottom="none" fo:border-right="none"', tProps: 'fo:font-size="8.5pt" fo:color="$muted"')}'
      '${para('Callout', pProps: 'fo:margin-left="0.1cm" fo:margin-right="0.1cm" fo:margin-top="0.1cm" fo:margin-bottom="0.1cm" fo:padding="0.25cm" fo:background-color="$tint" fo:border="0.5pt solid $strong"', tProps: 'fo:font-size="10pt"')}'
      '${para('List_20_Bullet', display: 'List Bullet', cls: 'list', pProps: 'fo:margin-bottom="0.1cm"')}'
      '${para('Caption', cls: 'extra', pProps: 'fo:margin-top="0.1cm" fo:margin-bottom="0.35cm"', tProps: 'fo:font-size="8.5pt" fo:color="$muted"')}'
      '${para('Detail', pProps: 'fo:margin-bottom="0.07cm"', tProps: 'fo:font-size="10pt" fo:color="$muted"')}'
      '${para('Section_20_Label', display: 'Section Label', next: 'Standard', pProps: 'fo:margin-bottom="0.2cm" fo:keep-with-next="always"', tProps: 'fo:font-size="8pt" fo:font-weight="bold" fo:color="$accent" fo:text-transform="uppercase" fo:letter-spacing="0.05cm"')}'
      '${para('Illustration', cls: 'extra', pProps: 'fo:margin-bottom="0.1cm"')}'
      '${para('Table_20_Contents', display: 'Table Contents', cls: 'extra', pProps: 'fo:margin-top="0cm" fo:margin-bottom="0cm" fo:line-height="100%"', tProps: 'fo:font-size="9pt"')}'
      '${para('Table_20_Contents_20_End', parent: 'Table_20_Contents', display: 'Table Contents End', pProps: 'fo:text-align="end"')}'
      '${para('Table_20_Heading', parent: 'Table_20_Contents', display: 'Table Heading', pProps: 'fo:keep-with-next="always"', tProps: 'fo:font-size="8.5pt" fo:font-weight="bold" fo:color="$accent"')}'
      '${para('Table_20_Heading_20_End', parent: 'Table_20_Heading', display: 'Table Heading End', pProps: 'fo:text-align="end"')}'
      '${para('Footer', cls: 'extra', pProps: 'fo:margin-bottom="0cm"', tProps: 'fo:font-size="8pt" fo:color="$muted"', children: '<style:tab-stops><style:tab-stop style:position="$textWidth" style:type="right"/></style:tab-stops>')}'
      '<style:style style:name="Graphics" style:family="graphic"><style:graphic-properties text:anchor-type="paragraph" svg:x="0cm" svg:y="0cm" style:wrap="none" style:vertical-pos="top" style:vertical-rel="baseline" style:horizontal-pos="left" style:horizontal-rel="paragraph"/></style:style>'
      '<style:style style:name="Frame" style:family="graphic" style:parent-style-name="Graphics"><style:graphic-properties style:vertical-pos="top" style:vertical-rel="baseline" fo:padding="0cm" fo:border="none"/></style:style>'
      '<text:list-style style:name="Bullets">${_bulletLevels(accent)}</text:list-style>'
      '</office:styles>'
      '<office:automatic-styles><style:page-layout style:name="pm1"><style:page-layout-properties fo:page-width="21cm" fo:page-height="29.7cm" style:print-orientation="portrait" '
      'fo:margin-top="$my" fo:margin-bottom="$my" fo:margin-left="$mx" fo:margin-right="$mx" style:writing-mode="lr-tb"/>'
      '<style:footer-style><style:header-footer-properties fo:min-height="0.5cm" fo:margin-top="0.3cm"/></style:footer-style></style:page-layout></office:automatic-styles>'
      '<office:master-styles><style:master-page style:name="Standard" style:page-layout-name="pm1"><style:footer>'
      '<text:p text:style-name="Footer">${odfText(d.footerText)}<text:tab/>Pagina <text:page-number text:select-page="current">1</text:page-number> di <text:page-count>1</text:page-count></text:p>'
      '</style:footer></style:master-page></office:master-styles></office:document-styles>';
}

String _bulletLevels(String accent) {
  const marks = ['•', '–', '▪'];
  return [
    for (var i = 0; i < 10; i++)
      '<text:list-level-style-bullet text:level="${i + 1}" text:bullet-char="${marks[i % 3]}">'
          '<style:list-level-properties text:list-level-position-and-space-mode="label-alignment">'
          '<style:list-level-label-alignment text:label-followed-by="listtab" text:list-tab-stop-position="${(1.27 * (i + 1)).toStringAsFixed(2)}cm" '
          'fo:text-indent="-0.635cm" fo:margin-left="${(1.27 * (i + 1)).toStringAsFixed(2)}cm"/></style:list-level-properties>'
          '<style:text-properties style:font-name="Arial" fo:color="$accent"/></text:list-level-style-bullet>',
  ].join();
}
