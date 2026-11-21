import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:paper_agent/features/document/export/export_model.dart';
import 'package:paper_agent/features/document/export/export_sheets.dart';
import 'package:paper_agent/features/document/export/xlsx_writer.dart';
import 'package:paper_agent/features/document/model/document.dart';
import 'package:xml/xml.dart';

import 'export_fixture.dart';
import 'export_readers.dart';

/// A cell as the file holds it: reference, type, style index, and the value (a shared string resolved to its text).
typedef _Cell = ({String ref, String? type, int style, String value});

List<String> _sharedStrings(Map<String, Uint8List> parts) => [
  for (final si in elements(xmlOf(parts, 'xl/sharedStrings.xml'), 'si')) si.innerText,
];

/// The cells of sheet [n] (1-based), row by row.
List<List<_Cell>> _rows(Map<String, Uint8List> parts, int n) {
  final strings = _sharedStrings(parts);
  return [
    for (final row in elements(xmlOf(parts, 'xl/worksheets/sheet$n.xml'), 'row'))
      [
        for (final c in row.childElements)
          (
            ref: c.getAttribute('r')!,
            type: c.getAttribute('t'),
            style: int.parse(c.getAttribute('s') ?? '0'),
            value: c.getAttribute('t') == 's' ? strings[int.parse(c.getElement('v')!.innerText)] : c.getElement('v')?.innerText ?? '',
          ),
      ],
  ];
}

/// The number format code of cell style [style]: a custom one by id, or the id of a built-in one.
String _format(Map<String, Uint8List> parts, int style) {
  final sheet = xmlOf(parts, 'xl/styles.xml');
  final xf = elements(sheet, 'cellXfs').single.childElements.elementAt(style);
  final id = xf.getAttribute('numFmtId')!;
  final custom = elements(sheet, 'numFmt').where((n) => n.getAttribute('numFmtId') == id);
  return custom.isEmpty ? 'builtin:$id' : custom.single.getAttribute('formatCode')!;
}

bool _bold(Map<String, Uint8List> parts, int style) {
  final sheet = xmlOf(parts, 'xl/styles.xml');
  final xf = elements(sheet, 'cellXfs').single.childElements.elementAt(style);
  final font = elements(sheet, 'fonts').single.childElements.elementAt(int.parse(xf.getAttribute('fontId')!));
  return font.getElement('b') != null;
}

List<String> _sheetNames(Map<String, Uint8List> parts) => [for (final s in elements(xmlOf(parts, 'xl/workbook.xml'), 'sheet')) s.getAttribute('name')!];

void main() {
  group('XLSX', () {
    final parts = unzip(encodeXlsx(fixtureDocument()));

    test('has every part Excel writes, each well-formed, in a consistent package', () {
      expect(parts.keys, containsAll([
        '[Content_Types].xml',
        '_rels/.rels',
        'xl/workbook.xml',
        'xl/_rels/workbook.xml.rels',
        'xl/styles.xml',
        'xl/sharedStrings.xml',
        'xl/worksheets/sheet1.xml',
        'xl/worksheets/sheet2.xml',
        'xl/worksheets/sheet3.xml',
        'docProps/core.xml',
        'docProps/app.xml',
      ]));
      expectWellFormed(parts);
      expectConsistentOpc(parts);
    });

    test('has one sheet per table, named after the heading before it, then the text', () {
      expect(_sheetNames(parts), ['Importi e scadenze', 'Elenco parti', 'Testo']);
    });

    test('types the cells: a euro amount is a number with the euro format', () {
      final rows = _rows(parts, 1);
      final amount = rows[1][1];
      expect(amount.ref, 'B2');
      expect(amount.type, isNull, reason: 'a number, not a string');
      expect(amount.value, '1234.56');
      expect(_format(parts, amount.style), r'#,##0.00\ "€"');
      expect(rows[2][1].value, '99', reason: 'EUR 99,00');
      expect(rows[3][1].value, '-10.5', reason: '-€ 10,50');
      expect(_format(parts, rows[3][1].style), r'#,##0.00\ "€"');
    });

    test('types the cells: a date is its serial number with dd/mm/yyyy', () {
      final rows = _rows(parts, 1);
      expect(rows[1][2].value, '45363', reason: '12/03/2024 is 45363 days after 1899-12-30');
      expect(_format(parts, rows[1][2].style), 'dd/mm/yyyy');
      expect(rows[2][2].value, '45658', reason: '1 gennaio 2025');
      expect(rows[3][2].value, '46022', reason: '31/12/2025');
    });

    test('types the cells: a percentage is a fraction with 0.00%, a plain number is general', () {
      final rows = _rows(parts, 1);
      expect(rows[1][3].value, '0.185');
      expect(_format(parts, rows[1][3].style), '0.00%');
      expect(rows[2][3].value, '0.05');
      expect(rows[3][3].value, '0');
      expect(rows[4][1].value, '1234', reason: '1.234 is one thousand two hundred thirty-four');
      expect(rows[4][1].type, isNull);
      expect(rows[4][3].value, '12.5');
      expect(_format(parts, rows[4][3].style), 'builtin:0');
    });

    test('leaves text as text: codes, formulas, notes', () {
      final rows = _rows(parts, 1);
      expect(rows[4][2], (ref: 'C5', type: 's', style: rows[4][2].style, value: '0123'));
      expect(rows[4][4].type, 's');
      expect(rows[4][4].value, '=SUM(A1)', reason: 'a formula stays a string: it is not run');
      expect(rows[1][4].value, 'Prima rata | saldo');
      expect(rows[3][4].value, 'riga\ncon a capo');
    });

    test('makes the header bold and frozen, and sizes the columns', () {
      final rows = _rows(parts, 1);
      expect([for (final c in rows[0]) c.value], ['Voce', 'Importo', 'Scadenza', 'Quota', 'Note']);
      for (final c in rows[0]) {
        expect(_bold(parts, c.style), isTrue, reason: c.ref);
      }
      expect(_bold(parts, rows[1][0].style), isFalse);
      final sheet = xmlOf(parts, 'xl/worksheets/sheet1.xml');
      final pane = elements(sheet, 'pane').single;
      expect(pane.getAttribute('ySplit'), '1');
      expect(pane.getAttribute('state'), 'frozen');
      expect(pane.getAttribute('topLeftCell'), 'A2');
      final cols = elements(sheet, 'col').toList();
      expect(cols, hasLength(5));
      for (final c in cols) {
        expect(double.parse(c.getAttribute('width')!), inInclusiveRange(8, 60));
        expect(c.getAttribute('customWidth'), '1');
      }
    });

    test('puts the caption under the table, after a blank row', () {
      final rows = _rows(parts, 1);
      expect(rows, hasLength(6), reason: 'header, four rows, the caption: the blank row between is not written');
      expect(rows.last.single.value, 'Importi in euro, IVA esclusa.');
      expect(rows.last.single.ref, 'A7');
    });

    test('has cells in order, rows in order, references that match their place', () {
      for (final n in [1, 2, 3]) {
        final sheet = xmlOf(parts, 'xl/worksheets/sheet$n.xml');
        var previousRow = 0;
        for (final row in elements(sheet, 'row')) {
          final r = int.parse(row.getAttribute('r')!);
          expect(r, greaterThan(previousRow));
          previousRow = r;
          var previousCol = -1;
          for (final c in row.childElements) {
            final ref = c.getAttribute('r')!;
            expect(ref, endsWith('$r'));
            final col = _columnIndex(ref);
            expect(col, greaterThan(previousCol), reason: ref);
            previousCol = col;
          }
        }
        expect(elements(sheet, 'dimension').single.getAttribute('ref'), matches(RegExp(r'^A1:[A-Z]+\d+$')));
      }
    });

    test('keeps the text, in the shared strings and the Testo sheet', () {
      final strings = _sharedStrings(parts).join('\n');
      expectWords(strings, fixtureWords.where((w) => !const ['€ 1.234,56', '12/03/2024', '18,5%'].contains(w)), reason: 'sharedStrings');
      expect(forbiddenChars.hasMatch(textOf(parts, 'xl/sharedStrings.xml')), isFalse);
      final testo = _rows(parts, 3).map((r) => r.single.value).toList();
      expect(testo.first, 'Parere pro veritate — Società Rossi & Figli S.r.l.');
      expect(testo, contains('• Primo punto: àèéìòù'));
      expect(testo, contains('Valore della causa: € 125.000,00 (+12%)'));
      expect(testo, contains('[Immagine: Planimetria & rilievo]'));
      expect(_bold(parts, _rows(parts, 3).first.single.style), isTrue, reason: 'the title row is bold');
    });

    test('names the application, the author and the dates in the properties', () {
      final core = textOf(parts, 'docProps/core.xml');
      expect(core, contains('<dc:creator>Avv. Mario Bianchi</dc:creator>'));
      expect(core, contains('2026-11-20T14:05:00Z'));
      expect(textOf(parts, 'docProps/app.xml'), contains('<Application>Daylex</Application>'));
    });

    test('names the header row as the print title of its sheet', () {
      final names = elements(xmlOf(parts, 'xl/workbook.xml'), 'definedName');
      expect(names.map((n) => n.innerText), ["'Importi e scadenze'!\$1:\$1", "'Elenco parti'!\$1:\$1"]);
    });

    test('never lets a string be read as an escape, or run past the cell limit', () {
      final doc = PaperDocument(
        id: 'x',
        projectId: 'p',
        metadata: DocMetadata(title: 'Limiti', createdAt: fixtureCreated, updatedAt: fixtureUpdated),
        pages: [
          DocPage(
            id: 'p',
            blocks: [
              TableBlock(
                id: 't',
                columns: const ['Codice', 'Lungo'],
                rows: [
                  ['_x0041_', 'x' * 40000],
                ],
              ),
            ],
          ),
        ],
      );
      final p = unzip(encodeXlsx(doc));
      final rows = _rows(p, 1);
      expect(textOf(p, 'xl/sharedStrings.xml'), contains('_x005F_x0041_'), reason: 'a literal _x0041_ is escaped so Excel keeps it');
      expect(rows[1][1].value.length, 32767);
    });

    test('writes a document with no table as one Testo sheet', () {
      final p = unzip(encodeXlsx(textOnlyDocument()));
      expect(_sheetNames(p), ['Testo']);
      expectWellFormed(p);
      expectConsistentOpc(p);
      final values = _rows(p, 1).map((r) => r.isEmpty ? '' : r.single.value).toList();
      expect(values, containsAll(['Solo testo', 'Titolo del paragrafo', 'Primo paragrafo; con punto e virgola.', 'Secondo "paragrafo"\ncon a capo.', '=1+1']));
      expect(elements(xmlOf(p, 'xl/worksheets/sheet1.xml'), 'pane'), isEmpty);
    });

    test('writes an empty document', () {
      final p = unzip(encodeXlsx(emptyDocument()));
      expectWellFormed(p);
      expectConsistentOpc(p);
      expect(_sheetNames(p), ['Testo']);
    });
  });

  group('sheet names', () {
    List<String> names(List<String> headings) =>
        buildSheets(buildExportDoc(sheetNamesDocument(headings))).where((s) => !s.isText).map((s) => s.name).toList();

    test('drop the characters Excel forbids', () {
      expect(names([r'a[b]c:d*e?f/g\h']), ['a b c d e f g h']);
    });

    test('are at most 31 characters, never cut an emoji in two', () {
      final n = names(['x' * 40, '${'y' * 30}😀z']);
      expect(n[0], 'x' * 31);
      expect(n[1].length, lessThanOrEqualTo(31));
      expect(n[1], 'y' * 30, reason: 'the pair that would straddle the limit is dropped whole');
    });

    test('are unique without regard to case, with a counter that keeps them short', () {
      final n = names(['Dati', 'dati', 'DATI', 'z' * 31, 'z' * 31]);
      expect(n, ['Dati', 'dati (2)', 'DATI (3)', 'z' * 31, '${'z' * 27} (2)']);
      expect({for (final x in n) x.toLowerCase()}, hasLength(n.length));
      expect(n.every((x) => x.length <= 31), isTrue);
    });

    test('never are History, and never start or end with an apostrophe', () {
      final n = names(['History', "'Parti'", "L'atto"]);
      expect(n[0], 'History (2)');
      expect(n[1], 'Parti');
      expect(n[2], "L'atto");
    });

    test('fall back to Tabella N when no heading names the table, and keep Testo for the text', () {
      final n = names(['', '', 'Testo']);
      expect(n, ['Tabella 1', 'Tabella 2', 'Testo (2)']);
    });
  });
}

int _columnIndex(String ref) {
  var n = 0;
  for (final c in ref.codeUnits.takeWhile((c) => c >= 65 && c <= 90)) {
    n = n * 26 + (c - 64);
  }
  return n;
}
