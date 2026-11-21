/// ODS: OpenDocument 1.3 spreadsheet, one sheet per table, typed cells (float, currency, date, percentage), a bold
/// header that repeats and stays in view.
library;

import 'dart:typed_data';

import '../model/document.dart';
import 'cell_value.dart';
import 'export_model.dart';
import 'export_sheets.dart';
import 'export_text.dart';
import 'odf_common.dart';

Uint8List encodeOds(PaperDocument doc) {
  final (doc: d, :sheets) = exportSheets(doc);
  return odfPackage(
    d,
    mediaType: kOdsMime,
    content: _content(d, sheets),
    styles: _styles(d),
    settings: _settings(sheets),
  );
}

String _attr(String s) => xmlEscape(s, attribute: true);

const _fontFace = '<style:font-face style:name="Arial" svg:font-family="Arial" style:font-family-generic="swiss" style:font-pitch="variable"/>';

/// The cell styles, by the name the cells use.
const _header = 'CellHeader', _text = 'CellText', _number = 'CellNumber', _bold = 'CellBold', _caption = 'CellCaption';
const _currency = 'CellCurrency', _date = 'CellDate', _percent = 'CellPercent';

/// A column of [chars] characters is this wide (an Arial 10 pt digit is about 0.19 cm).
String _width(double chars) => cm(chars * 108);

String _content(ExportDoc d, List<ExSheet> sheets) {
  // One column style per distinct width, in the order they are met.
  final columns = <String, String>{};
  String columnStyle(double chars) => columns.putIfAbsent(_width(chars), () => 'co${columns.length + 1}');

  final body = StringBuffer();
  for (final s in sheets) {
    body.write(_sheet(s, columnStyle));
  }

  final data = '<number:currency-style style:name="NCurrency"><number:number number:decimal-places="2" number:min-integer-digits="1" number:grouping="true"/>'
      '<number:text> </number:text><number:currency-symbol number:language="it" number:country="IT">€</number:currency-symbol></number:currency-style>'
      '<number:date-style style:name="NDate"><number:day number:style="long"/><number:text>/</number:text><number:month number:style="long"/>'
      '<number:text>/</number:text><number:year number:style="long"/></number:date-style>'
      '<number:percentage-style style:name="NPercent"><number:number number:decimal-places="2" number:min-integer-digits="1"/><number:text>%</number:text></number:percentage-style>';

  String cell(String name, String cellProps, {String text = ''}) =>
      '<style:style style:name="$name" style:family="table-cell" style:parent-style-name="Default">'
      '<style:table-cell-properties $cellProps/>${text.isEmpty ? '' : '<style:text-properties $text/>'}</style:style>';

  return '$kOdfDecl<office:document-content $kOdfNamespaces office:version="$kOdfVersion"><office:scripts/>'
      '<office:font-face-decls>$_fontFace</office:font-face-decls><office:automatic-styles>'
      '$data'
      '${columns.entries.map((e) => '<style:style style:name="${e.value}" style:family="table-column"><style:table-column-properties fo:break-before="auto" style:column-width="${e.key}"/></style:style>').join()}'
      '<style:style style:name="ro1" style:family="table-row"><style:table-row-properties style:row-height="0.45cm" fo:break-before="auto" style:use-optimal-row-height="true"/></style:style>'
      '<style:style style:name="ta1" style:family="table" style:master-page-name="Default"><style:table-properties table:display="true" style:writing-mode="lr-tb"/></style:style>'
      '${cell(_header, 'fo:background-color="#${d.tintHex}" fo:wrap-option="wrap" style:vertical-align="middle" fo:border-bottom="0.5pt solid #${ExColors.hairline}" fo:border-top="none" fo:border-left="none" fo:border-right="none"', text: 'fo:font-weight="bold" fo:color="#${d.accentHex}"')}'
      '${cell(_text, 'fo:wrap-option="wrap" style:vertical-align="top"')}'
      '${cell(_number, 'style:vertical-align="top"')}'
      '${cell(_bold, 'fo:wrap-option="wrap" style:vertical-align="top"', text: 'fo:font-weight="bold"')}'
      '${cell(_caption, 'fo:wrap-option="no-wrap" style:vertical-align="top"', text: 'fo:font-style="italic" fo:font-size="9pt" fo:color="#${ExColors.muted}"')}'
      '<style:style style:name="$_currency" style:family="table-cell" style:parent-style-name="Default" style:data-style-name="NCurrency"><style:table-cell-properties style:vertical-align="top"/></style:style>'
      '<style:style style:name="$_date" style:family="table-cell" style:parent-style-name="Default" style:data-style-name="NDate"><style:table-cell-properties style:vertical-align="top"/></style:style>'
      '<style:style style:name="$_percent" style:family="table-cell" style:parent-style-name="Default" style:data-style-name="NPercent"><style:table-cell-properties style:vertical-align="top"/></style:style>'
      '</office:automatic-styles><office:body><office:spreadsheet>$body</office:spreadsheet></office:body></office:document-content>';
}

String _sheet(ExSheet s, String Function(double) columnStyle) {
  final width = s.isText ? 1 : s.width;
  final chars = s.isText ? const [90.0] : s.columnChars();

  String string(String text, String style) {
    final lines = text.split('\n');
    return '<table:table-cell table:style-name="$style" office:value-type="string">'
        '${lines.map((l) => '<text:p>${odfText(l)}</text:p>').join()}</table:table-cell>';
  }

  String typed(String text) {
    final v = parseCell(text);
    final shown = '<text:p>${odfText(v.text)}</text:p>';
    return switch (v.kind) {
      CellKind.text => string(text, _text),
      CellKind.number => '<table:table-cell table:style-name="$_number" office:value-type="float" office:value="${v.decimal}">$shown</table:table-cell>',
      CellKind.currency =>
        '<table:table-cell table:style-name="$_currency" office:value-type="currency" office:currency="EUR" office:value="${v.decimal}">$shown</table:table-cell>',
      CellKind.percent =>
        '<table:table-cell table:style-name="$_percent" office:value-type="percentage" office:value="${v.decimal}">$shown</table:table-cell>',
      CellKind.date => '<table:table-cell table:style-name="$_date" office:value-type="date" office:date-value="${v.isoDate}">$shown</table:table-cell>',
    };
  }

  String row(String cells) => '<table:table-row table:style-name="ro1">$cells</table:table-row>';
  String padded(List<String> cells) => [...cells, for (var i = cells.length; i < width; i++) '<table:table-cell/>'].join();
  String empty(String text, String Function(String) cell) => text.isEmpty ? '<table:table-cell/>' : cell(text);

  final out = StringBuffer('<table:table table:name="${_attr(s.name)}" table:style-name="ta1">');
  out.write([for (final c in chars) '<table:table-column table:style-name="${columnStyle(c)}" table:default-cell-style-name="Default"/>'].join());
  if (s.hasHeader) {
    out.write('<table:table-header-rows>${row([for (final h in s.header) string(h, _header)].join())}</table:table-header-rows>');
  }
  for (final (i, cells) in s.rows.indexed) {
    final style = s.boldRows.contains(i) ? _bold : _text;
    out.write(row(padded([for (final c in cells) empty(c, (t) => s.isText ? string(t, style) : typed(t))])));
  }
  if (s.caption.isNotEmpty) {
    out
      ..write(row(padded(const [])))
      ..write(row(padded([string(s.caption, _caption)])));
  }
  out.write('</table:table>');
  return out.toString();
}

String _styles(ExportDoc d) {
  final p = d.page;
  return '$kOdfDecl<office:document-styles $kOdfNamespaces office:version="$kOdfVersion">'
      '<office:font-face-decls>$_fontFace</office:font-face-decls>'
      '<office:styles>'
      '<style:default-style style:family="table-cell"><style:paragraph-properties style:tab-stop-distance="1.25cm"/>'
      '<style:text-properties style:font-name="Arial" fo:font-size="10pt" fo:language="it" fo:country="IT"/></style:default-style>'
      '<style:style style:name="Default" style:family="table-cell"/>'
      '</office:styles>'
      '<office:automatic-styles><style:page-layout style:name="Mpm1"><style:page-layout-properties fo:page-width="${cm(p.widthTwips)}" '
      'fo:page-height="${cm(p.heightTwips)}" style:print-orientation="${p.landscape ? 'landscape' : 'portrait'}" fo:margin-top="${cm(p.topTwips)}" '
      'fo:margin-bottom="${cm(p.bottomTwips)}" fo:margin-left="${cm(p.leftTwips)}" fo:margin-right="${cm(p.rightTwips)}" style:writing-mode="lr-tb"/>'
      '<style:footer-style><style:header-footer-properties fo:min-height="0.5cm" fo:margin-top="0.3cm"/></style:footer-style></style:page-layout></office:automatic-styles>'
      '<office:master-styles><style:master-page style:name="Default" style:page-layout-name="Mpm1"><style:footer>'
      '<text:p>${odfText(d.title)} — pagina <text:page-number text:select-page="current">1</text:page-number> di <text:page-count>1</text:page-count></text:p>'
      '</style:footer></style:master-page></office:master-styles></office:document-styles>';
}

/// `settings.xml`: the first sheet is the one shown, and a sheet with a header keeps it in view when scrolling.
String _settings(List<ExSheet> sheets) {
  String item(String name, String type, String value) => '<config:config-item config:name="$name" config:type="$type">$value</config:config-item>';

  final tables = sheets.map((s) {
    final frozen = s.hasHeader;
    return '<config:config-item-map-entry config:name="${_attr(s.name)}">'
        '${item('HorizontalSplitMode', 'short', '0')}${item('VerticalSplitMode', 'short', frozen ? '2' : '0')}'
        '${item('HorizontalSplitPosition', 'int', '0')}${item('VerticalSplitPosition', 'int', frozen ? '1' : '0')}'
        '${item('ActiveSplitRange', 'short', frozen ? '2' : '0')}${item('PositionLeft', 'int', '0')}${item('PositionRight', 'int', '0')}'
        '${item('PositionTop', 'int', '0')}${item('PositionBottom', 'int', frozen ? '1' : '0')}</config:config-item-map-entry>';
  }).join();

  return '$kOdfDecl<office:document-settings xmlns:office="urn:oasis:names:tc:opendocument:xmlns:office:1.0" '
      'xmlns:config="urn:oasis:names:tc:opendocument:xmlns:config:1.0" office:version="$kOdfVersion"><office:settings>'
      '<config:config-item-set config:name="ooo:view-settings"><config:config-item-map-indexed config:name="Views"><config:config-item-map-entry>'
      '${item('ViewId', 'string', 'view1')}<config:config-item-map-named config:name="Tables">$tables</config:config-item-map-named>'
      '<config:config-item config:name="ActiveTable" config:type="string">${xmlEscape(sheets.first.name)}</config:config-item>'
      '</config:config-item-map-entry></config:config-item-map-indexed></config:config-item-set></office:settings></office:document-settings>';
}
