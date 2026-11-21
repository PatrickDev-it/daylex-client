import 'package:flutter_test/flutter_test.dart';
import 'package:daylex/features/document/export/docx_writer.dart';
import 'package:xml/xml.dart';

import 'export_fixture.dart';
import 'export_readers.dart';

void main() {
  group('DOCX', () {
    final parts = unzip(encodeDocx(fixtureDocument()));
    final doc = xmlOf(parts, 'word/document.xml');

    test('has every part Word writes, each well-formed, in a consistent package', () {
      expect(parts.keys, containsAll([
        '[Content_Types].xml',
        '_rels/.rels',
        'word/document.xml',
        'word/_rels/document.xml.rels',
        'word/styles.xml',
        'word/numbering.xml',
        'word/settings.xml',
        'word/fontTable.xml',
        'docProps/core.xml',
        'docProps/app.xml',
        'word/media/image1.png',
      ]));
      expect(parts.keys.first, '[Content_Types].xml');
      expectWellFormed(parts);
      expectConsistentOpc(parts);
    });

    test('keeps the text of every block, accents and metacharacters included', () {
      final text = elements(doc, 'w:p').map((p) => elements(p, 'w:t').map((t) => t.innerText).join()).join('\n');
      expectWords(text, fixtureWords, reason: 'document.xml');
    });

    test('carries no character XML cannot', () {
      for (final e in parts.entries.where((e) => e.key.endsWith('.xml'))) {
        expect(forbiddenChars.hasMatch(textOf(parts, e.key)), isFalse, reason: e.key);
      }
    });

    test('is Italian, A4, compatibility mode 15', () {
      expect(textOf(parts, 'word/styles.xml'), contains('w:lang w:val="it-IT"'));
      for (final pg in elements(doc, 'w:pgSz')) {
        expect(pg.getAttribute('w:w'), '11906');
        expect(pg.getAttribute('w:h'), '16838');
      }
      final compat = elements(xmlOf(parts, 'word/settings.xml'), 'w:compatSetting').where((e) => e.getAttribute('w:name') == 'compatibilityMode');
      expect(compat.single.getAttribute('w:val'), '15');
    });

    test('defines the styles the body uses', () {
      final styles = xmlOf(parts, 'word/styles.xml');
      final defined = {for (final s in elements(styles, 'w:style')) s.getAttribute('w:styleId')!};
      expect(defined, containsAll(['Normal', 'Heading1', 'Heading2', 'Heading3', 'Quote', 'ListParagraph', 'Header', 'Footer', 'DaylexTable']));
      expect(defined, isNot(contains('Title')), reason: 'no front matter of its own (rfc/055)');
      final used = {
        for (final e in doc.descendantElements.where((e) => const ['w:pStyle', 'w:rStyle', 'w:tblStyle'].contains(e.name.qualified))) e.getAttribute('w:val')!,
      };
      expect(defined.containsAll(used), isTrue, reason: 'styles used but not defined: ${used.difference(defined)}');
    });

    test('writes real tables with a repeating header row', () {
      final tables = elements(doc, 'w:tbl').toList();
      expect(tables, hasLength(3), reason: 'the metrics are a small table, then the two tables of the document');
      for (final t in tables) {
        final rows = elements(t, 'w:tr').toList();
        expect(elements(rows.first, 'w:tblHeader'), isNotEmpty);
        expect(elements(rows.last, 'w:tblHeader'), isEmpty);
        final grid = elements(t, 'w:gridCol').length;
        for (final r in rows) {
          expect(elements(r, 'w:tc').length, grid, reason: 'a row has as many cells as the grid has columns');
        }
        for (final c in elements(t, 'w:tc')) {
          expect(c.childElements.last.name.qualified, 'w:p', reason: 'a cell ends with a paragraph');
        }
      }
      expect(elements(tables[0], 'w:tr'), hasLength(3), reason: 'metrics: header and two rows');
      expect(elements(tables[1], 'w:tr'), hasLength(5));
    });

    test('puts the picture inline, from word/media, and names the one without bytes', () {
      expect(elements(doc, 'wp:inline'), hasLength(1));
      expect(elements(doc, 'w:drawing'), hasLength(1));
      final rid = elements(doc, 'a:blip').single.getAttribute('r:embed')!;
      final rels = {for (final r in elements(xmlOf(parts, 'word/_rels/document.xml.rels'), 'Relationship')) r.getAttribute('Id')!: r.getAttribute('Target')!};
      expect(rels[rid], 'media/image1.png');
      final text = elements(doc, 'w:t').map((t) => t.innerText).join('\n');
      expect(text, contains('[Immagine: Senza immagine]'));
    });

    test('makes bullets a list, quotes and callouts paragraph styles', () {
      expect(elements(doc, 'w:numId'), isNotEmpty);
      final styles = elements(doc, 'w:pStyle').map((e) => e.getAttribute('w:val')).toSet();
      expect(styles, containsAll(['ListParagraph', 'Quote', 'Callout', 'Heading1', 'Heading2', 'Heading3']));
    });

    test('gives each page its own section when the pages differ: the cover shows nothing, page 2 its details', () {
      final sections = elements(doc, 'w:sectPr').toList();
      expect(sections, hasLength(2), reason: 'the cover and page 2 show different headers ({sezione}, and none on a cover)');
      final rels = {for (final r in elements(xmlOf(parts, 'word/_rels/document.xml.rels'), 'Relationship')) r.getAttribute('Id')!: r.getAttribute('Target')!};
      String part(XmlElement section, String kind) =>
          'word/${rels[elements(section, 'w:${kind}Reference').firstWhere((e) => e.getAttribute('w:type') == 'default').getAttribute('r:id')]}';
      String words(String name) => elements(xmlOf(parts, name), 'w:t').map((t) => t.innerText).join();
      expect(words(part(sections[0], 'header')), isEmpty, reason: 'a cover has no header');
      expect(words(part(sections[0], 'footer')), isEmpty, reason: 'a cover has no footer');
      final header = part(sections[1], 'header'), footer = part(sections[1], 'footer');
      expectWords(words(header) + words(footer), fixtureRegionWords, reason: 'header and footer');
      final bold = elements(xmlOf(parts, header), 'w:r').where((r) => elements(r, 'w:b').isNotEmpty).map((r) => elements(r, 'w:t').map((t) => t.innerText).join());
      expect(bold, contains('Studio Bianchi'), reason: '**{studio}** is bold');
      final fields = elements(xmlOf(parts, footer), 'w:fldSimple').map((f) => f.getAttribute('w:instr')!.trim()).toList();
      expect(fields, ['PAGE', 'NUMPAGES']);
      expect(words(footer), contains('Pagina '));
      expect(words(footer), isNot(contains('{pagina}')));
    });

    test('writes the emphasis as runs, and the look a block sets itself on its paragraph', () {
      final p = elements(doc, 'w:p').firstWhere((p) => elements(p, 'w:t').map((t) => t.innerText).join() == 'Fine della tabella.');
      final bold = elements(p, 'w:r').where((r) => elements(r, 'w:b').isNotEmpty).map((r) => elements(r, 'w:t').single.innerText);
      expect(bold, ['tabella']);
      expect(elements(p, 'w:jc').single.getAttribute('w:val'), 'center');
      expect(elements(p, 'w:sz').map((s) => s.getAttribute('w:val')).toSet(), {'28'}, reason: '14 pt in half-points, on every run');
      expect(elements(p, 'w:pStyle'), isEmpty, reason: 'a body paragraph stays Normal; only the look it sets itself is direct');
    });

    test('sets the document properties', () {
      final core = textOf(parts, 'docProps/core.xml');
      expect(core, contains('<dc:title>Parere pro veritate — Società Rossi &amp; Figli S.r.l.</dc:title>'));
      expect(core, contains('<dc:creator>Avv. Mario Bianchi</dc:creator>'));
      expect(core, contains('2026-11-20T14:05:00Z'));
    });

    test('writes an empty document', () {
      final empty = unzip(encodeDocx(emptyDocument()));
      expectWellFormed(empty);
      expectConsistentOpc(empty);
      expect(textOf(empty, 'docProps/core.xml'), contains('Documento senza titolo'));
      expect(textOf(empty, 'word/document.xml'), isNot(contains('Documento senza titolo')), reason: 'no front matter of its own');
    });
  });
}
