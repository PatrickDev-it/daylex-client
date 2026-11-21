/// XLSX: ISO/IEC 29500 Transitional SpreadsheetML, one sheet per table, typed cells, a bold frozen header.
library;

import 'dart:typed_data';

import '../model/document.dart';
import 'cell_value.dart';
import 'export_model.dart';
import 'export_sheets.dart';
import 'export_text.dart';
import 'opc.dart';
import 'zip_package.dart';

const _ns = 'xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main"';
const _nsR = 'xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships"';
const _sml = 'application/vnd.openxmlformats-officedocument.spreadsheetml';

/// The number formats the typed cells take: an amount, a date, a percentage.
const _currencyFormat = r'#,##0.00\ "€"';
const _dateFormat = 'dd/mm/yyyy';
const _percentFormat = '0.00%';

/// The `cellXfs` indexes in [_styles].
const _xfHeader = 1, _xfText = 2, _xfCurrency = 3, _xfDate = 4, _xfPercent = 5, _xfNumber = 6, _xfBold = 7, _xfCaption = 8;

/// Excel's limit on the characters of one cell.
const _maxCell = 32767;

Uint8List encodeXlsx(PaperDocument doc) {
  final (doc: d, :sheets) = exportSheets(doc);
  final strings = _SharedStrings();
  final xml = [for (final (i, s) in sheets.indexed) _sheet(s, selected: i == 0, strings: strings)];

  final zip = ZipPackage(d.modified)
    ..addText(
      '[Content_Types].xml',
      contentTypes(
        defaults: {'rels': 'application/vnd.openxmlformats-package.relationships+xml', 'xml': 'application/xml'},
        overrides: {
          '/xl/workbook.xml': '$_sml.sheet.main+xml',
          for (var i = 1; i <= sheets.length; i++) '/xl/worksheets/sheet$i.xml': '$_sml.worksheet+xml',
          '/xl/styles.xml': '$_sml.styles+xml',
          '/xl/sharedStrings.xml': '$_sml.sharedStrings+xml',
          '/docProps/core.xml': kCoreContentType,
          '/docProps/app.xml': kAppContentType,
        },
      ),
    )
    ..addText(
      '_rels/.rels',
      relationships([
        ('rId1', relType('officeDocument'), 'xl/workbook.xml'),
        ('rId2', kCoreRelType, 'docProps/core.xml'),
        ('rId3', relType('extended-properties'), 'docProps/app.xml'),
      ]),
    )
    ..addText('xl/workbook.xml', _workbook(sheets))
    ..addText(
      'xl/_rels/workbook.xml.rels',
      relationships([
        for (var i = 1; i <= sheets.length; i++) ('rId$i', relType('worksheet'), 'worksheets/sheet$i.xml'),
        ('rId${sheets.length + 1}', relType('styles'), 'styles.xml'),
        ('rId${sheets.length + 2}', relType('sharedStrings'), 'sharedStrings.xml'),
      ]),
    );
  for (final (i, x) in xml.indexed) {
    zip.addText('xl/worksheets/sheet${i + 1}.xml', x);
  }
  zip
    ..addText('xl/styles.xml', _styles(d))
    ..addText('xl/sharedStrings.xml', strings.xml())
    ..addText('docProps/core.xml', coreProperties(d))
    ..addText('docProps/app.xml', appProperties(d));
  return zip.toBytes();
}

/// The strings of the workbook, each stored once.
class _SharedStrings {
  final _index = <String, int>{};
  var _refs = 0;

  int of(String s) {
    _refs++;
    return _index.putIfAbsent(s, () => _index.length);
  }

  String xml() =>
      '$kXmlDecl<sst $_ns count="$_refs" uniqueCount="${_index.length}">'
      '${_index.keys.map((s) => '<si><t xml:space="preserve">${xmlEscape(_literalEscapes(s))}</t></si>').join()}</sst>';

  /// Excel reads `_x0041_` in a string as the character U+0041: a literal one is written with its underscore escaped.
  static String _literalEscapes(String s) => s.replaceAllMapped(RegExp(r'_(x[0-9A-Fa-f]{4}_)'), (m) => '_x005F_${m[1]}');
}

String _colName(int i) {
  var n = i + 1;
  var s = '';
  while (n > 0) {
    s = String.fromCharCode(65 + (n - 1) % 26) + s;
    n = (n - 1) ~/ 26;
  }
  return s;
}

String _workbook(List<ExSheet> sheets) {
  String quoted(String name) => "'${name.replaceAll("'", "''")}'";
  final titles = [
    for (final (i, s) in sheets.indexed)
      if (s.hasHeader) '<definedName name="_xlnm.Print_Titles" localSheetId="$i">${xmlEscape(quoted(s.name))}!\$1:\$1</definedName>',
  ];
  return '$kXmlDecl<workbook $_ns $_nsR><workbookPr/><bookViews><workbookView activeTab="0"/></bookViews><sheets>'
      '${[for (final (i, s) in sheets.indexed) '<sheet name="${xmlEscape(s.name, attribute: true)}" sheetId="${i + 1}" r:id="rId${i + 1}"/>'].join()}</sheets>'
      '${titles.isEmpty ? '' : '<definedNames>${titles.join()}</definedNames>'}<calcPr calcId="191029"/></workbook>';
}

String _sheet(ExSheet s, {required bool selected, required _SharedStrings strings}) {
  final rows = StringBuffer();
  var r = 0;

  String str(int col, int row, String text, int style) {
    final t = text.length > _maxCell ? text.substring(0, _maxCell) : text;
    return '<c r="${_colName(col)}$row" s="$style" t="s"><v>${strings.of(t)}</v></c>';
  }

  void writeRow(List<String> cells) {
    r++;
    rows.write('<row r="$r">${cells.join()}</row>');
  }

  if (s.hasHeader) {
    final row = r + 1;
    writeRow([for (var c = 0; c < s.header.length; c++) str(c, row, s.header[c], _xfHeader)]);
  }
  for (final (i, cells) in s.rows.indexed) {
    final row = r + 1;
    writeRow([
      for (var c = 0; c < cells.length; c++)
        if (cells[c].isNotEmpty)
          if (s.isText) str(c, row, cells[c], s.boldRows.contains(i) ? _xfBold : _xfText) else _typed(c, row, cells[c], str),
    ]);
  }
  if (s.caption.isNotEmpty) {
    r++; // a blank row between the table and its caption
    final row = r + 1;
    writeRow([str(0, row, s.caption, _xfCaption)]);
  }

  final widths = s.isText ? const [110.0] : s.columnChars();
  final last = '${_colName(widths.length - 1)}${r == 0 ? 1 : r}';
  final pane = s.hasHeader
      ? '<pane ySplit="1" topLeftCell="A2" activePane="bottomLeft" state="frozen"/><selection pane="bottomLeft" activeCell="A2" sqref="A2"/>'
      : '';
  return '$kXmlDecl<worksheet $_ns $_nsR><sheetPr><pageSetUpPr fitToPage="1"/></sheetPr><dimension ref="A1:$last"/>'
      '<sheetViews><sheetView${selected ? ' tabSelected="1"' : ''} workbookViewId="0">$pane</sheetView></sheetViews>'
      '<sheetFormatPr defaultRowHeight="12.75"/>'
      '<cols>${[for (final (i, w) in widths.indexed) '<col min="${i + 1}" max="${i + 1}" width="$w" customWidth="1"/>'].join()}</cols>'
      '<sheetData>$rows</sheetData>'
      '<pageMargins left="0.7" right="0.7" top="0.75" bottom="0.75" header="0.3" footer="0.3"/>'
      '<pageSetup paperSize="9" orientation="portrait" fitToHeight="0"/></worksheet>';
}

/// A body cell of a table, typed: a number, an amount, a date or a percentage is a value, the rest a string.
String _typed(int col, int row, String text, String Function(int, int, String, int) str) {
  final v = parseCell(text);
  final ref = '${_colName(col)}$row';
  return switch (v.kind) {
    CellKind.text => str(col, row, text, _xfText),
    CellKind.number => '<c r="$ref" s="$_xfNumber"><v>${v.decimal}</v></c>',
    CellKind.currency => '<c r="$ref" s="$_xfCurrency"><v>${v.decimal}</v></c>',
    CellKind.percent => '<c r="$ref" s="$_xfPercent"><v>${v.decimal}</v></c>',
    CellKind.date => '<c r="$ref" s="$_xfDate"><v>${v.serial}</v></c>',
  };
}

String _styles(ExportDoc d) {
  const face = '<name val="Arial"/><family val="2"/>';
  String xf(int numFmt, {int font = 0, int fill = 0, int border = 0, String align = ''}) =>
      '<xf numFmtId="$numFmt" fontId="$font" fillId="$fill" borderId="$border" xfId="0"${numFmt == 0 ? '' : ' applyNumberFormat="1"'}'
      '${font == 0 ? '' : ' applyFont="1"'}${fill == 0 ? '' : ' applyFill="1"'}${border == 0 ? '' : ' applyBorder="1"'}'
      '${align.isEmpty ? '/>' : ' applyAlignment="1"><alignment $align/></xf>'}';

  const top = 'vertical="top"';
  return '$kXmlDecl<styleSheet $_ns>'
      '<numFmts count="3"><numFmt numFmtId="164" formatCode="${xmlEscape(_currencyFormat, attribute: true)}"/>'
      '<numFmt numFmtId="165" formatCode="$_dateFormat"/><numFmt numFmtId="166" formatCode="$_percentFormat"/></numFmts>'
      '<fonts count="4"><font><sz val="10"/>$face</font><font><b/><sz val="10"/>$face</font>'
      '<font><i/><sz val="9"/><color rgb="FF${ExColors.muted}"/>$face</font><font><b/><sz val="10"/><color rgb="FF${d.accentHex}"/>$face</font></fonts>'
      '<fills count="3"><fill><patternFill patternType="none"/></fill><fill><patternFill patternType="gray125"/></fill>'
      '<fill><patternFill patternType="solid"><fgColor rgb="FF${d.tintHex}"/><bgColor indexed="64"/></patternFill></fill></fills>'
      '<borders count="2"><border><left/><right/><top/><bottom/><diagonal/></border>'
      '<border><left/><right/><top/><bottom style="thin"><color rgb="FF${ExColors.hairline}"/></bottom><diagonal/></border></borders>'
      '<cellStyleXfs count="1"><xf numFmtId="0" fontId="0" fillId="0" borderId="0"/></cellStyleXfs>'
      '<cellXfs count="9">'
      '${xf(0)}'
      '${xf(0, font: 3, fill: 2, border: 1, align: 'vertical="center" wrapText="1"')}'
      '${xf(0, align: '$top wrapText="1"')}'
      '${xf(164, align: top)}${xf(165, align: top)}${xf(166, align: top)}${xf(0, align: top)}'
      '${xf(0, font: 1, align: '$top wrapText="1"')}'
      '${xf(0, font: 2, align: top)}'
      '</cellXfs><cellStyles count="1"><cellStyle name="Normal" xfId="0" builtinId="0"/></cellStyles>'
      '<dxfs count="0"/><tableStyles count="0" defaultTableStyle="TableStyleMedium2" defaultPivotStyle="PivotStyleLight16"/></styleSheet>';
}
