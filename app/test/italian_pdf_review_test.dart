import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:paper_agent/features/document/model/document.dart';
import 'package:paper_agent/features/document/render/pdf_renderer.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('Italian legal draft renders all layouts with the source for independent PDF inspection', () async {
    final doc = PaperDocument.fromJson({
      'id': 'legal-review-fixture',
      'projectId': 'test',
      'metadata': {
        'title': 'Istanza di fissazione dell’udienza',
        'author': 'Studio legale',
      },
      'theme': {'brandName': 'Studio legale'},
      'pages': [
        for (final layout in PageLayout.values)
          {
            'id': layout.name,
            'title': 'Richiesta e documenti',
            'layout': layout.name,
            'blocks': [
              {
                'id': '${layout.name}-h',
                'type': 'heading',
                'text': 'Premesse',
                'level': 1,
              },
              {
                'id': '${layout.name}-p',
                'type': 'paragraph',
                'text': 'Il ricorrente chiede la fissazione dell’udienza. Le parti hanno sottoscritto il contratto. Il presente documento contiene dati sintetici per la verifica dell’impaginazione.',
              },
              if (layout != PageLayout.cover) {
                'id': '${layout.name}-t',
                'type': 'table',
                'columns': ['Documento', 'Esito'],
                'rows': [
                  ['Ricorso', 'Depositato'],
                  ['Contratto', 'Sottoscritto'],
                ],
              },
              if (layout != PageLayout.cover) {
                'id': '${layout.name}-q',
                'type': 'quote',
                'text': 'Le parti confermano il contenuto del contratto.',
                'author': 'Documento allegato',
              },
              if (layout != PageLayout.cover) {
                'id': '${layout.name}-b',
                'type': 'bullets',
                'items': [
                  'Esaminare gli allegati.',
                  'Verificare le comunicazioni.',
                ],
              },
            ],
          },
      ],
    });
    final renderer = PdfRenderer(await PdfFontSet.load());
    final bytes = await renderer.render(doc);
    expect(bytes.length, greaterThan(1000));
    final folder = Platform.environment['DAYLEX_ITALIAN_PDF_DIR'];
    if (folder != null) {
      await Directory(folder).create(recursive: true);
      await File('$folder/italiano.pdf').writeAsBytes(bytes);
      await File('$folder/italiano.json')
          .writeAsString(jsonEncode(doc.toJson()));
    }
  });
}
