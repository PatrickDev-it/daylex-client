import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:daylex/features/document/export/csv_writer.dart';

import 'export_fixture.dart';
import 'export_readers.dart';

void main() {
  group('CSV', () {
    final bytes = encodeCsv(fixtureDocument());
    final text = utf8.decode(bytes.sublist(3));
    final records = parseCsv(text);

    test('starts with the UTF-8 byte order mark, and has it once', () {
      expect(bytes.take(3), [0xEF, 0xBB, 0xBF]);
      expect(text.contains('\uFEFF'), isFalse);
    });

    test('ends every record with CRLF, and no line feed is bare outside a quoted field', () {
      expect(text.endsWith('\r\n'), isTrue);
      expect(text.contains(RegExp(r'\r(?!\n)')), isFalse);
      // Take out the quoted fields: what is left has CRLF as its only line break.
      final outside = text.replaceAll(RegExp(r'"(?:[^"]|"")*"'), '""');
      expect(outside.contains(RegExp(r'(?<!\r)\n')), isFalse);
    });

    test('has the same number of fields in every record', () {
      expect(records, isNotEmpty);
      final widths = records.map((r) => r.length).toSet();
      expect(widths, {5}, reason: 'the widest table has five columns');
    });

    test('has each table under its title, then its header, rows and caption, an empty record between tables', () {
      expect(records[0], ['Importi e scadenze', '', '', '', '']);
      expect(records[1], ['Voce', 'Importo', 'Scadenza', 'Quota', 'Note']);
      expect(records[2], ['Onorari', '€ 1.234,56', '12/03/2024', '18,5%', 'Prima rata | saldo']);
      expect(records[3], ['Spese', 'EUR 99,00', '1 gennaio 2025', '5%', 'a|b; c "d"']);
      expect(records[4][4], 'riga\ncon a capo', reason: 'a line break inside a field survives, quoted');
      expect(records[6], ['Importi in euro, IVA esclusa.', '', '', '', '']);
      expect(records[7], ['', '', '', '', ''], reason: 'an empty record separates the tables');
      expect(records[8], ['Elenco parti', '', '', '', '']);
      expect(records[9], ['Parte', 'Ruolo', '', '', '']);
      expect(records.last, ['Verdi', 'Convenuto', '', '', '']);
    });

    test('keeps numbers as the lawyer sees them, and quotes only what needs it', () {
      expect(text, contains('\r\nOnorari;€ 1.234,56;12/03/2024;18,5%;Prima rata | saldo\r\n'));
      expect(text, contains(';"a|b; c ""d"""\r\n'), reason: 'the delimiter and the quotes make a field quoted, a quote is doubled');
      expect(text, contains('Rimborso;-€ 10,50;31/12/2025;0%;"riga\ncon a capo"'));
    });

    test('makes a cell that a spreadsheet would run as a formula plain text', () {
      expect(records[5][4], "'=SUM(A1)");
      expect(records[4][1], '-€ 10,50', reason: 'a negative amount is data, not a formula');
    });

    test('has a single column of paragraphs when there are no tables', () {
      final b = encodeCsv(textOnlyDocument());
      final r = parseCsv(utf8.decode(b.sublist(3)));
      expect(r.every((x) => x.length == 1), isTrue);
      expect(r.map((x) => x.single), containsAll(['Titolo del paragrafo', 'Primo paragrafo; con punto e virgola.', 'Secondo "paragrafo"\ncon a capo.', "'=1+1"]));
      expect(utf8.decode(b.sublist(3)), contains('"Primo paragrafo; con punto e virgola."\r\n'));
    });

    test('writes an empty record as an empty quoted field when it is the only one', () {
      final r = parseCsv(utf8.decode(encodeCsv(textOnlyDocument()).sublist(3)));
      expect(r.map((x) => x.length).toSet(), {1});
      expect(utf8.decode(encodeCsv(textOnlyDocument()).sublist(3)), contains('""\r\n'));
    });

    test('carries no character a spreadsheet cannot', () {
      expect(forbiddenChars.hasMatch(text.replaceAll('\r', '')), isFalse);
    });

    test('writes an empty document as no record at all', () {
      final bytes = encodeCsv(emptyDocument());
      expect(bytes.take(3), [0xEF, 0xBB, 0xBF]);
      expect(parseCsv(utf8.decode(bytes.sublist(3))), isEmpty);
    });
  });
}
