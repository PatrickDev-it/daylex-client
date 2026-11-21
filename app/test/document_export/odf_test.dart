import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:paper_agent/features/document/export/ods_writer.dart';
import 'package:paper_agent/features/document/export/odt_writer.dart';
import 'package:xml/xml.dart';

import 'export_fixture.dart';
import 'export_readers.dart';

/// What both OpenDocument writers keep: the package rules of ODF 1.3 and a consistent set of styles.
void _expectOdfPackage(Uint8List bytes, String mime) {
  final parts = unzip(bytes);
  final first = firstZipEntry(bytes);
  expect(first.name, 'mimetype', reason: 'mimetype is the first entry');
  expect(first.method, 0, reason: 'mimetype is stored, not deflated');
  expect(first.extra, 0, reason: 'mimetype has no extra field');
  expect(utf8.decode(first.data), mime, reason: 'mimetype holds the media type and nothing else');
  expect(parts.keys.first, 'mimetype');

  expectWellFormed(parts);
  for (final name in ['content.xml', 'styles.xml', 'meta.xml', 'META-INF/manifest.xml']) {
    expect(xmlOf(parts, name).rootElement.getAttribute('office:version') ?? xmlOf(parts, name).rootElement.getAttribute('manifest:version'), '1.3', reason: name);
  }

  final manifest = xmlOf(parts, 'META-INF/manifest.xml');
  final entries = {for (final e in elements(manifest, 'manifest:file-entry')) e.getAttribute('manifest:full-path')!: e.getAttribute('manifest:media-type')!};
  expect(entries['/'], mime);
  for (final name in parts.keys.where((n) => n != 'mimetype' && n != 'META-INF/manifest.xml')) {
    expect(entries.containsKey(name), isTrue, reason: '$name is not in the manifest');
  }
  for (final name in entries.keys.where((n) => n != '/')) {
    expect(parts.containsKey(name), isTrue, reason: 'the manifest names $name, which is not in the package');
  }

  // Every style a body element names is defined, in the content's own automatic styles or in styles.xml.
  final content = xmlOf(parts, 'content.xml');
  final styles = xmlOf(parts, 'styles.xml');
  final defined = {
    for (final doc in [content, styles])
      for (final s in doc.descendantElements.where((e) => const ['style:style', 'text:list-style', 'number:currency-style', 'number:date-style', 'number:percentage-style', 'number:number-style'].contains(e.name.qualified)))
        s.getAttribute('style:name')!,
  };
  final body = content.rootElement.getElement('office:body')!;
  const refs = ['text:style-name', 'table:style-name', 'draw:style-name', 'table:default-cell-style-name'];
  for (final e in body.descendantElements) {
    for (final a in refs) {
      final v = e.getAttribute(a);
      if (v != null) expect(defined.contains(v), isTrue, reason: '${e.name.qualified} $a="$v" is not defined');
    }
  }
  for (final e in content.rootElement.getElement('office:automatic-styles')!.descendantElements) {
    for (final a in ['style:parent-style-name', 'style:data-style-name']) {
      final v = e.getAttribute(a);
      if (v != null) expect(defined.contains(v), isTrue, reason: '$a="$v" is not defined');
    }
  }
}

void main() {
  group('ODT', () {
    final bytes = encodeOdt(fixtureDocument());
    final parts = unzip(bytes);
    final content = xmlOf(parts, 'content.xml');

    test('is an ODF 1.3 package: mimetype first and stored, manifest complete, styles defined', () {
      _expectOdfPackage(bytes, 'application/vnd.oasis.opendocument.text');
    });

    test('keeps the text of every block, accents and metacharacters included', () {
      final text = elements(content, 'text:p').followedBy(elements(content, 'text:h')).map((p) => p.innerText).join('\n');
      expectWords(text, fixtureWords, reason: 'content.xml');
      for (final e in parts.entries.where((e) => e.key.endsWith('.xml'))) {
        expect(forbiddenChars.hasMatch(textOf(parts, e.key)), isFalse, reason: e.key);
      }
    });

    test('has outline headings, a bullet list, real tables with a header row and the picture', () {
      expect(elements(content, 'text:h').map((h) => h.getAttribute('text:outline-level')).toSet(), containsAll(['1', '2', '3']));
      expect(elements(content, 'text:list'), isNotEmpty);
      expect(elements(content, 'table:table'), hasLength(3), reason: 'the metrics are a small table, then the two tables');
      expect(elements(content, 'table:table-header-rows'), hasLength(3));
      final image = elements(content, 'draw:image').single.getAttribute('xlink:href')!;
      expect(parts.containsKey(image), isTrue);
      expect(elements(content, 'text:p').map((p) => p.innerText), contains('[Immagine: Senza immagine]'));
    });

    test('has a page footer with the page number, A4', () {
      final styles = xmlOf(parts, 'styles.xml');
      expect(elements(styles, 'text:page-number'), isNotEmpty);
      final layout = elements(styles, 'style:page-layout-properties').single;
      expect(layout.getAttribute('fo:page-width'), '21cm');
      expect(layout.getAttribute('fo:page-height'), '29.7cm');
    });

    test('writes the metadata', () {
      final meta = textOf(parts, 'meta.xml');
      expect(meta, contains('<dc:title>Parere pro veritate — Società Rossi &amp; Figli S.r.l.</dc:title>'));
      expect(meta, contains('<dc:language>it-IT</dc:language>'));
    });

    test('writes an empty document', () {
      final empty = encodeOdt(emptyDocument());
      _expectOdfPackage(empty, 'application/vnd.oasis.opendocument.text');
    });
  });

  group('ODS', () {
    final bytes = encodeOds(fixtureDocument());
    final parts = unzip(bytes);
    final content = xmlOf(parts, 'content.xml');
    final tables = elements(content, 'table:table').toList();

    test('is an ODF 1.3 package: mimetype first and stored, manifest complete, styles defined', () {
      _expectOdfPackage(bytes, 'application/vnd.oasis.opendocument.spreadsheet');
      expect(parts.containsKey('settings.xml'), isTrue);
    });

    test('has one sheet per table, then the text', () {
      expect(tables.map((t) => t.getAttribute('table:name')), ['Importi e scadenze', 'Elenco parti', 'Testo']);
    });

    test('types the cells: float, currency in EUR, date, percentage; the rest is text', () {
      List<XmlElement> row(int sheet, int index) => elements(tables[sheet], 'table:table-row').elementAt(index).childElements.toList();
      // Row 0 is the header (inside table:table-header-rows), row 1 the first body row.
      final first = row(0, 1);
      expect(first[0].getAttribute('office:value-type'), 'string');
      expect(first[1].getAttribute('office:value-type'), 'currency');
      expect(first[1].getAttribute('office:currency'), 'EUR');
      expect(first[1].getAttribute('office:value'), '1234.56');
      expect(first[2].getAttribute('office:value-type'), 'date');
      expect(first[2].getAttribute('office:date-value'), '2024-03-12');
      expect(first[3].getAttribute('office:value-type'), 'percentage');
      expect(first[3].getAttribute('office:value'), '0.185');
      expect(first[4].getAttribute('office:value-type'), 'string');

      final second = row(0, 2);
      expect(second[1].getAttribute('office:value'), '99');
      expect(second[2].getAttribute('office:date-value'), '2025-01-01');
      final third = row(0, 3);
      expect(third[1].getAttribute('office:value'), '-10.5');
      final totals = row(0, 4);
      expect(totals[1].getAttribute('office:value-type'), 'float');
      expect(totals[1].getAttribute('office:value'), '1234');
      expect(totals[2].getAttribute('office:value-type'), 'string', reason: '0123 is a code, not a number');
      expect(totals[3].getAttribute('office:value'), '12.5');
      expect(totals[4].getAttribute('office:value-type'), 'string', reason: 'a formula is text');
    });

    test('has the data styles the typed cells point at', () {
      final names = elements(content, 'number:currency-style').followedBy(elements(content, 'number:date-style')).followedBy(elements(content, 'number:percentage-style'));
      expect(names, hasLength(3));
      expect(elements(content, 'number:currency-symbol').single.innerText, '€');
    });

    test('repeats the header row and keeps it in view', () {
      expect(elements(tables.first, 'table:table-header-rows'), hasLength(1));
      final settings = textOf(parts, 'settings.xml');
      expect(settings, contains('VerticalSplitPosition'));
      expect(settings, contains('Importi e scadenze'));
    });

    test('keeps the text', () {
      final text = elements(content, 'text:p').map((p) => p.innerText).join('\n');
      expectWords(text, fixtureWords, reason: 'content.xml');
    });

    test('writes an empty document', () {
      _expectOdfPackage(encodeOds(emptyDocument()), 'application/vnd.oasis.opendocument.spreadsheet');
    });
  });
}
