import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:daylex/features/document/export/document_export.dart';

import 'export_fixture.dart';
import 'export_readers.dart';

/// The formats a lawyer can pick, and the one function that writes them.
void main() {
  group('ExportFormat', () {
    test('names every format once, with its extension, media type and Italian label', () {
      expect(ExportFormat.values.map((f) => f.name), ['pdf', 'docx', 'odt', 'rtf', 'txt', 'md', 'html', 'xlsx', 'ods', 'csv']);
      expect({for (final f in ExportFormat.values) f.extension}, hasLength(10));
      expect({for (final f in ExportFormat.values) f.mimeType}, hasLength(10));
      expect({for (final f in ExportFormat.values) f.label}, hasLength(10));
      for (final f in ExportFormat.values) {
        expect(f.extension, f.name);
        expect(f.extension, isNot(startsWith('.')));
        expect(f.mimeType, matches(RegExp(r'^[a-z]+/[a-z0-9.+\-]+(; charset=utf-8)?$')));
        expect(f.label, isNotEmpty);
      }
      expect(ExportFormat.docx.mimeType, 'application/vnd.openxmlformats-officedocument.wordprocessingml.document');
      expect(ExportFormat.xlsx.mimeType, 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet');
      expect(ExportFormat.odt.mimeType, 'application/vnd.oasis.opendocument.text');
      expect(ExportFormat.ods.mimeType, 'application/vnd.oasis.opendocument.spreadsheet');
      expect(ExportFormat.csv.mimeType, 'text/csv; charset=utf-8');
      expect(ExportFormat.pdf.mimeType, 'application/pdf');
    });

    test('names the file after the PDF, with its own extension', () {
      final doc = fixtureDocument();
      expect(ExportFormat.pdf.fileNameOf(doc), doc.fileName);
      expect(ExportFormat.docx.fileNameOf(doc), 'Parere pro veritate — Società Rossi & Figli S.r.l..docx');
      expect(ExportFormat.csv.fileNameOf(emptyDocument()), 'document.csv');
    });
  });

  group('encodeDocument', () {
    test('refuses the PDF, which the page renderer draws', () {
      expect(() => encodeDocument(fixtureDocument(), ExportFormat.pdf), throwsArgumentError);
    });

    for (final format in ExportFormat.values.where((f) => f != ExportFormat.pdf)) {
      test('writes ${format.name}: bytes, the same ones every time, for every kind of document', () {
        for (final doc in [fixtureDocument(), emptyDocument(), textOnlyDocument()]) {
          final bytes = encodeDocument(doc, format);
          expect(bytes, isNotEmpty);
          expect(encodeDocument(doc, format), bytes, reason: 'the same document gives the same file');
        }
      });
    }

    test('writes every ZIP-based format as a ZIP that opens and whose XML parts parse', () {
      for (final f in [ExportFormat.docx, ExportFormat.odt, ExportFormat.xlsx, ExportFormat.ods]) {
        final parts = unzip(encodeDocument(fixtureDocument(), f));
        expect(parts, isNotEmpty);
        expectWellFormed(parts);
      }
    });
  });

  // `EXPORT_SAMPLES_DIR=<folder> flutter test test/document_export/formats_test.dart --plain-name samples` writes one
  // file per format, for the official validators (OOXML SDK, the ODF validator, LibreOffice); see validate.py.
  test(
    'writes the sample of every format to EXPORT_SAMPLES_DIR',
    () {
      final dir = Directory(Platform.environment['EXPORT_SAMPLES_DIR']!)..createSync(recursive: true);
      for (final f in ExportFormat.values.where((f) => f != ExportFormat.pdf)) {
        File('${dir.path}/fixture.${f.extension}').writeAsBytesSync(encodeDocument(fixtureDocument(), f));
        File('${dir.path}/text-only.${f.extension}').writeAsBytesSync(encodeDocument(textOnlyDocument(), f));
        File('${dir.path}/empty.${f.extension}').writeAsBytesSync(encodeDocument(emptyDocument(), f));
      }
    },
    skip: Platform.environment['EXPORT_SAMPLES_DIR'] == null ? 'set EXPORT_SAMPLES_DIR to write the samples' : false,
  );
}
