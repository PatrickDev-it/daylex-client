import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:daylex/features/document/export/cell_value.dart';
import 'package:daylex/features/document/export/export_model.dart';
import 'package:daylex/features/document/export/export_text.dart';
import 'package:daylex/features/document/export/image_info.dart';

import 'export_fixture.dart';

/// The pieces every writer stands on: text hygiene, the typed cell, the image header, the walk.
void main() {
  group('cleanText', () {
    test('drops control characters but tab and newline, the byte order mark and lone surrogates', () {
      expect(cleanText('a\u0001b\u0008c\u000Bd\u007Fe\u0085f\uFEFFg\uFFFEh\uFFFFi'), 'abcde\nfghi');
      expect(cleanText('x\uD800y\uDC00z'), 'xyz');
      expect(cleanText('a\tb'), 'a\tb');
    });

    test('keeps what is text: accents, an emoji, symbols', () {
      expect(cleanText('perché 😀 € — “ciao”'), 'perché 😀 € — “ciao”');
    });

    test('turns every line end into a line feed', () {
      expect(cleanText('a\r\nb\rc\nd\u2028e\u2029f'), 'a\nb\nc\nd\ne\nf');
    });
  });

  group('xmlEscape', () {
    test('escapes the five characters', () {
      expect(xmlEscape('&<>"\''), '&amp;&lt;&gt;&quot;&apos;');
    });

    test('writes a tab and a newline in an attribute as character references', () {
      expect(xmlEscape('a\tb\nc', attribute: true), 'a&#9;b&#10;c');
      expect(xmlEscape('a\tb\nc'), 'a\tb\nc');
    });

    test('escapes ampersands first, so nothing is escaped twice', () {
      expect(xmlEscape('&amp;'), '&amp;amp;');
    });
  });

  group('parseCell', () {
    CellValue p(String s) => parseCell(s);

    test('reads euro amounts in every way an Italian lawyer writes them', () {
      for (final s in ['€ 1.234,56', '€1.234,56', '1.234,56 €', '1.234,56€', 'EUR 1.234,56', '1.234,56 euro', '1234,56 EUR']) {
        expect(p(s).kind, CellKind.currency, reason: s);
        expect(p(s).decimal, '1234.56', reason: s);
      }
      expect(p('-€ 10,50').decimal, '-10.5');
      expect(p('€ -10,50').decimal, '-10.5');
      expect(p('- 10,50 €').decimal, '-10.5');
      expect(p('€ 0,00').decimal, '0');
      expect(p('€ -0,00').decimal, '0', reason: 'there is no negative zero');
    });

    test('reads numbers with Italian grouping and decimals', () {
      expect(p('1.234').decimal, '1234');
      expect(p('1.234,5').decimal, '1234.5');
      expect(p('12,50').decimal, '12.5');
      expect(p('-7').decimal, '-7');
      expect(p('1.234.567,89').decimal, '1234567.89');
      expect(p('1.234').kind, CellKind.number);
    });

    test('reads percentages as fractions, without a binary float', () {
      expect(p('18,5%').decimal, '0.185');
      expect(p('5%').decimal, '0.05');
      expect(p('100%').decimal, '1');
      expect(p('0,5 %').decimal, '0.005');
      expect(p('-12%').decimal, '-0.12');
      expect(p('18,5%').kind, CellKind.percent);
    });

    test('reads dates as the serial days since 1899-12-30', () {
      expect(p('12/03/2024').serial, 45363);
      expect(p('12/03/2024').isoDate, '2024-03-12');
      expect(p('1.1.2025').serial, 45658);
      expect(p('1-1-2025').kind, CellKind.date);
      expect(p('1 gennaio 2025').isoDate, '2025-01-01');
      expect(p('12 marzo 2024').serial, 45363);
      expect(p('3 sett. 2023').isoDate, '2023-09-03');
      expect(p('29/02/2024').kind, CellKind.date);
      expect(p('01/03/1900').serial, 61);
    });

    test('leaves what could be wrong as text', () {
      for (final s in [
        '0123', // a code with a leading zero
        '1234567890123456', // more digits than a spreadsheet keeps
        '1.5', // dots are thousands separators in Italian: ambiguous
        '1,234.56', // English
        '31/02/2024', // not a day
        '12/13/2024', // not a month
        '29/02/2023', // not a leap year
        '28/02/1900', // before the serial date base is sound
        '12/03/24', // two-digit year
        'domani',
        'Prima rata',
        '12 €uro',
        '=SUM(A1)',
        '€',
        '%',
        '1.23',
        '1 gennaio',
        '--5',
        '€ 1.234,56 €',
      ]) {
        expect(p(s).isText, isTrue, reason: s);
      }
      expect(p('').isText, isTrue);
      expect(p('  ').text, '');
    });

    test('trims, and reads the typographic minus and the non-breaking space', () {
      expect(p('  € 1.234,56  ').kind, CellKind.currency);
      expect(p('\u221210').decimal, '-10');
      expect(p('€\u00A01.234,56').decimal, '1234.56');
    });
  });

  group('sniffImage', () {
    test('reads the size of a PNG', () {
      final h = sniffImage(gradientPng(width: 48, height: 32))!;
      expect((h.format, h.width, h.height), (ImageFormat.png, 48, 32));
      expect(h.format.mime, 'image/png');
      expect(h.format.extension, 'png');
    });

    test('reads a GIF and a JPEG', () {
      final gif = Uint8List.fromList([...'GIF89a'.codeUnits, 10, 0, 20, 0, 0, 0, 0]);
      expect(sniffImage(gif)!.width, 10);
      expect(sniffImage(gif)!.height, 20);
      // SOI, a APP0 segment of length 16, then SOF0 with height 40 and width 30.
      final jpeg = Uint8List.fromList([
        0xFF, 0xD8, 0xFF, 0xE0, 0, 16, ...List.filled(14, 0), //
        0xFF, 0xC0, 0, 17, 8, 0, 40, 0, 30, 3, 1, 0x22, 0, 2, 0x11, 1, 3, 0x11, 1,
      ]);
      final h = sniffImage(jpeg)!;
      expect((h.format, h.width, h.height), (ImageFormat.jpeg, 30, 40));
      expect(h.format.extension, 'jpg');
    });

    test('reads nothing from what is not an image, or is cut short', () {
      expect(sniffImage(Uint8List.fromList([1, 2, 3])), isNull);
      expect(sniffImage(Uint8List(0)), isNull);
      expect(sniffImage(gradientPng().sublist(0, 20)), isNull);
      expect(sniffImage(Uint8List.fromList('<svg xmlns="http://www.w3.org/2000/svg"/>'.codeUnits)), isNull);
    });
  });

  group('buildExportDoc', () {
    final d = buildExportDoc(fixtureDocument());

    test('opens with the title, the subtitle and the facts, then the pages', () {
      expect(d.blocks.take(d.bodyStart).map((b) => b.runtimeType), [ExTitle, ExSubtitle, ExFact, ExFact, ExFact]);
      expect((d.blocks[2] as ExFact).label, 'Destinatario');
      expect((d.blocks[4] as ExFact).value, 'novembre 2026');
      expect(d.creator, 'Avv. Mario Bianchi');
      expect(d.status, 'In revisione');
    });

    test('labels a page unless its first heading says the same', () {
      final labels = d.blocks.whereType<ExSectionLabel>().map((l) => l.text);
      expect(labels, ['Allegati e importi'], reason: 'the first page starts with the heading Premessa');
      expect(d.blocks.whereType<ExPageBreak>(), hasLength(1));
    });

    test('numbers the tables and names them after the heading before', () {
      expect(d.tables.map((t) => (t.number, t.title)), [(1, 'Importi e scadenze'), (2, 'Elenco parti')]);
      expect(d.tables.first.numeric, [false, true, false, true, false], reason: 'the amount column and the percentage column align right');
    });

    test('strips the control characters before any writer sees them', () {
      final p = d.blocks.whereType<ExParagraph>().first.text;
      expect(p, contains('con un controllo nascosto.'));
      expect(p.contains('\u0001'), isFalse);
    });

    test('gives the default creator when nobody signed', () {
      expect(buildExportDoc(emptyDocument()).creator, 'Daylex');
      expect(buildExportDoc(emptyDocument()).title, 'Documento senza titolo');
    });

    test('pads a table to its widest row', () {
      final doc = sheetNamesDocument(['x']);
      expect(buildExportDoc(doc).tables.single.rows.single, hasLength(2));
    });
  });
}
