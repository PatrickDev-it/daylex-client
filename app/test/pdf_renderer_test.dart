import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:daylex/features/document/data/doc_templates.dart';
import 'package:daylex/features/document/model/document.dart';
import 'package:daylex/features/document/render/pdf_renderer.dart';

import 'demo_fixture.dart';
import 'document_export/export_fixture.dart' show gradientPng;

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

  test('renders every style the agent can set (rfc/055)', () async {
    final theme = DocTheme.legal
        .patchStyle({
          'page': {
            'orientation': 'landscape',
            'margins': {'left': 3},
          },
          'styles': {
            'body': {'font': 'garamond', 'size': 12},
            'heading1': {'font': 'arial', 'caps': true, 'underline': true},
            'quote': {'font': 'courier'},
            'callout': {'font': 'calibri', 'background': 'accent/10'},
            'table': {'font': 'times', 'grid': 'all', 'stripe': '#f1f5f9'},
            'bullets': {'font': 'inter', 'marker': 'letter'},
          },
        })
        .withRegion(
          RegionSlot.firstHeader,
          const PageRegion(
            center: '**Studio Legale Neri**\n*Via Roma 1, Milano*',
            line: true,
          ).withLogo(
            RegionLogo(
              bytes: gradientPng(),
              height: 30,
              align: BlockAlign.center,
            ),
          ),
        )
        .withRegion(
          RegionSlot.footer,
          const PageRegion(
            left: '{titolo} · {cliente}',
            right: 'pag. {pagina} di {pagine}',
          ),
        );
    BlockStyle s(Map<String, Object> values) => BlockStyle.of(values);
    final doc = buildQ3Proposal().copyWith(
      theme: theme,
      pages: [
        DocPage(
          id: 'a',
          title: 'Parere',
          blocks: [
            HeadingBlock(
              id: 'h',
              text: 'Parere',
              style: s({'align': 'center'}),
            ),
            ParagraphBlock(
              id: 'p',
              text: 'Con **grassetto**, *corsivo* e __sottolineato__.',
              style: s({
                'firstLineIndent': 1.25,
                'lineHeight': 2,
                'align': 'justify',
              }),
            ),
            BulletListBlock(
              id: 'l',
              items: const ['uno', 'due'],
              style: s({'marker': 'number'}),
            ),
            QuoteBlock(
              id: 'q',
              text: 'Art. 1218 c.c.',
              author: 'Codice civile',
              style: s({'border': 'left'}),
            ),
            CalloutBlock(
              id: 'c',
              title: 'Nota',
              text: 'Termine: 30 giorni.',
              style: s({'padding': 12}),
            ),
            TableBlock(
              id: 't',
              columns: const ['Voce', 'Importo'],
              rows: const [
                ['Capitale', '1.000 €'],
                ['Interessi', '45 €'],
              ],
              style: s({'border': 'bottom', 'borderWidth': 1}),
            ),
          ],
        ),
        DocPage(
          id: 'b',
          title: 'Conclusioni',
          blocks: [
            MetricsBlock(
              id: 'm',
              items: const [Metric(label: 'Totale', value: '1.045 €')],
              style: s({'size': 20}),
            ),
            ParagraphBlock(
              id: 'z',
              text: 'Fine.',
              style: s({'caps': true, 'color': '#7a1f1f'}),
            ),
          ],
        ),
      ],
    );
    final bytes = await renderer.render(doc);
    expect(pdfPageCount(bytes), 2);
    final box = RegExp(
      r'/MediaBox\s*\[\s*0\s+0\s+([\d.]+)\s+([\d.]+)',
    ).firstMatch(latin1.decode(bytes))!;
    expect(
      double.parse(box[1]!),
      greaterThan(double.parse(box[2]!)),
      reason: 'landscape',
    );
  });

  test('document survives a JSON round trip', () {
    final doc = buildQ3Proposal();
    final copy = PaperDocument.fromJson(
      jsonDecode(jsonEncode(doc.toJson())) as Map<String, dynamic>,
    );
    expect(jsonEncode(copy.toJson()), jsonEncode(doc.toJson()));
  });
}
