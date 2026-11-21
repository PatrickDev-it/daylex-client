/// CSV: RFC 4180 with the Italian conventions of Excel: UTF-8 with a byte order mark, `;` between fields, CRLF.
/// Numbers stay as the lawyer reads them (`1.234,56`), so Excel in Italian parses them as its own.
library;

import 'dart:convert';
import 'dart:typed_data';

import '../model/document.dart';
import 'cell_value.dart';
import 'export_sheets.dart';

const _bom = [0xEF, 0xBB, 0xBF];
const _delimiter = ';';

/// Every record has as many fields as the widest table: a reader that wants a rectangle gets one. A document with
/// tables gives its tables (the data); one without gives its text, a paragraph per record.
Uint8List encodeCsv(PaperDocument doc) {
  final sheets = exportSheets(doc).sheets;
  final tables = sheets.where((s) => !s.isText).toList();
  final records = tables.isEmpty ? sheets.first.rows : _tableRecords(tables);

  final width = records.fold(1, (w, r) => r.length > w ? r.length : w);
  final text = StringBuffer();
  for (final r in records) {
    text
      ..write(_record([...r, for (var i = r.length; i < width; i++) '']))
      ..write('\r\n');
  }
  return Uint8List.fromList([..._bom, ...utf8.encode(text.toString())]);
}

/// Each table: its title, its header, its rows, its caption, then an empty record before the next table.
List<List<String>> _tableRecords(List<ExSheet> tables) {
  final out = <List<String>>[];
  for (final (i, t) in tables.indexed) {
    if (i > 0) out.add(const []);
    out.add([t.title]);
    if (t.hasHeader) out.add(t.header);
    out.addAll(t.rows);
    if (t.caption.isNotEmpty) out.add([t.caption]);
  }
  return out;
}

String _record(List<String> fields) {
  // A record of one empty field would be a blank line, which a reader may skip: it is written as an empty string.
  if (fields.length == 1 && fields.first.isEmpty) return '""';
  return fields.map(_field).join(_delimiter);
}

String _field(String raw) {
  final text = _guard(raw);
  final special = text.contains(_delimiter) || text.contains('"') || text.contains('\n') || text.contains('\r');
  return special ? '"${text.replaceAll('"', '""')}"' : text;
}

/// A spreadsheet runs a cell that starts with `=`, `+`, `-`, `@`, a tab or a return as a formula. What is written here
/// came out of a document, so such a cell is made plain text with a leading apostrophe, unless it is a number, an
/// amount, a date or a percentage: those are the data, and a minus sign is part of them.
String _guard(String s) {
  if (s.isEmpty || !'=+-@\t\r'.contains(s[0])) return s;
  return parseCell(s).isText ? "'$s" : s;
}
