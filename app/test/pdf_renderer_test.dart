import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:paper_agent/features/document/data/doc_templates.dart';
import 'package:paper_agent/features/document/model/document.dart';
import 'package:paper_agent/features/document/render/pdf_renderer.dart';

import 'demo_fixture.dart';

/// Counts `/Type /Page` objects (excluding the `/Pages` tree node).
int pdfPageCount(List<int> bytes) =>
    RegExp(r'/Type\s*/Page(?!s)').allMatches(latin1.decode(bytes)).length;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late PdfRenderer renderer;

  setUpAll(() async => renderer = PdfRenderer(await PdfFontSet.load()));

  test('renders the demo proposal with one PDF page per model page', () async {
    final doc = buildQ3Proposal();
    final bytes = await renderer.render(doc);

    expect(latin1.decode(bytes.sublist(0, 5)), '%PDF-');
    expect(pdfPageCount(bytes), doc.pages.length);
    final visualPath = Platform.environment['DAYLEX_PDF_VISUAL_PATH'];
    if (visualPath != null) File(visualPath).writeAsBytesSync(bytes);
  });

  test('renders every template and layout', () async {
    for (final t in docTemplates) {
      final doc = t.build('p');
      final bytes = await renderer.render(doc);
      expect(pdfPageCount(bytes), doc.pages.length, reason: t.name);
    }
  });

  test('overflowing content cannot produce a silently truncated PDF', () async {
    final doc = buildQ3Proposal();
    final long = doc.pages[2].copyWith(
      blocks: [for (var i = 0; i < 60; i++) p('Long paragraph $i ' * 20)],
    );
    await expectLater(
      () => renderer.render(doc.copyWith(pages: [doc.pages.first, long])),
      throwsA(isA<Exception>()),
    );
  });

  test('renders on a background isolate', () async {
    final bytes = await renderer.renderInBackground(buildTeamOnePager());
    expect(pdfPageCount(bytes), 1);
  });

  test('exports 1001 pages without losing the final page', () async {
    final doc = buildQ3Proposal();
    final pages = [
      for (var i = 1; i <= 1001; i++)
        DocPage(
          id: 'scale-$i',
          title: 'Unita $i',
          layout: PageLayout.values.first,
          blocks: [
            p(
              'Riscontro documentale SCALEPAGE$i. Contenuto verificabile della pagina $i.',
            ),
          ],
        ),
    ];
    final watch = Stopwatch()..start();
    final bytes = await renderer.render(doc.copyWith(pages: pages));
    expect(pdfPageCount(bytes), 1001);
    final path = Platform.environment['DAYLEX_PDF_SCALE_PATH'];
    if (path != null) {
      File(path).writeAsBytesSync(bytes);
      File('$path.metrics.json').writeAsStringSync(
        jsonEncode({
          'pages': 1001,
          'bytes': bytes.length,
          'seconds': watch.elapsedMilliseconds / 1000,
          'processPeakRssBytes': ProcessInfo.maxRss,
          'mode': 'Flutter test, in-memory rendering',
        }),
      );
    }
  });

  test(
    'every layout refuses overflowing text with the affected page number',
    () async {
      final doc = buildQ3Proposal();
      for (final layout in PageLayout.values) {
        final page = doc.pages[1].copyWith(
          layout: layout,
          blocks: [
            for (var i = 0; i < 80; i++)
              p('Contenuto da conservare integralmente. ' * 10),
          ],
        );
        await expectLater(
          () => renderer.render(doc.copyWith(pages: [page])),
          throwsA(isA<PdfLayoutException>().having((e) => e.page, 'page', 1)),
        );
      }
    },
  );

  test('document survives a JSON round trip', () {
    final doc = buildQ3Proposal();
    final copy = PaperDocument.fromJson(
      jsonDecode(jsonEncode(doc.toJson())) as Map<String, dynamic>,
    );
    expect(jsonEncode(copy.toJson()), jsonEncode(doc.toJson()));
  });
}
