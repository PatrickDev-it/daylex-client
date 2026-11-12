import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:paper_agent/features/document/data/doc_templates.dart';
import 'package:paper_agent/features/document/model/document.dart';
import 'package:paper_agent/features/document/render/page_fit.dart';
import 'package:paper_agent/features/document/render/pdf_renderer.dart';
import 'package:paper_agent/features/document/service/document_service.dart';

import 'demo_fixture.dart';
import 'pdf_renderer_test.dart' show pdfPageCount;

/// All the visible text, without whitespace: what a split must keep exactly. A table cut in two repeats its
/// header on the next page, so its rows are what counts.
String text(PaperDocument doc) => [
  for (final page in doc.pages)
    for (final b in page.blocks)
      b is TableBlock
          ? [b.caption, for (final r in b.rows) r.join()].join()
          : b.plainText,
].join().replaceAll(RegExp(r'\s+'), '');

/// About as much as one update_page of the CEO's appeal on 2026-11-12 (2274 tokens): one page, far beyond A4.
DocPage appeal({PageLayout layout = PageLayout.standard}) => page('Motivi', [
  h2('Primo motivo'),
  for (var i = 0; i < 6; i++)
    p(
      List.generate(
        12,
        (s) =>
            'Il giudice di primo grado ha omesso di valutare la prova numero ${i * 12 + s}, decisiva ai fini della causa.',
      ).join(' '),
    ),
  h2('Secondo motivo'),
  for (var i = 0; i < 4; i++)
    p('Paragrafo $i: la motivazione è apparente e contraddittoria. ' * 9),
], layout);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late PdfRenderer renderer;
  late PageFitter fitter;

  setUpAll(() async {
    renderer = PdfRenderer(await PdfFontSet.load());
    fitter = PageFitter(renderer);
  });

  test('a document that fits is left as it is', () async {
    final doc = buildQ3Proposal();
    final fitted = await fitter.fit(doc);
    expect(fitted.changed, isFalse);
    expect(fitted.operations, isEmpty);
    expect(identical(fitted.document, doc), isTrue);
  });

  test('an overflowing page becomes consecutive pages that render, keeping every word', () async {
    final doc = buildQ3Proposal();
    final before = doc.copyWith(pages: [doc.pages[0], appeal(), doc.pages[1]]);
    await expectLater(
      () => renderer.render(before),
      throwsA(isA<PdfLayoutException>()),
    );

    final watch = Stopwatch()..start();
    final fitted = await fitter.fit(before);
    // ignore: avoid_print
    print(
      'fit: ${watch.elapsedMilliseconds} ms, ${fitted.document.pages.length} pages',
    );

    final split = fitted.splits.single;
    expect(split.page, 2);
    expect(split.first, 2);
    expect(split.count, greaterThan(1));
    expect(fitted.overflowing, isEmpty);
    expect(fitted.document.pages.length, before.pages.length + split.count - 1);
    final bytes = await renderer.render(fitted.document);
    expect(pdfPageCount(bytes), fitted.document.pages.length);
    expect(text(fitted.document), text(before));
    // The split page keeps its id and title; the pages around it are untouched.
    expect(fitted.document.pages[1].id, before.pages[1].id);
    expect(fitted.document.pages.last.id, before.pages.last.id);
    expect(fitted.document.pages[2].title, 'Motivi');
  });

  test('its operations turn the document into the fitted one', () async {
    final doc = buildQ3Proposal();
    final before = doc.copyWith(pages: [appeal(), doc.pages[1], appeal()]);
    final fitted = await fitter.fit(before);
    expect(fitted.splits.length, 2);
    final applied = const DocumentService().applyAll(before, fitted.operations);
    expect(
      jsonEncode(applied.toJson()['pages']),
      jsonEncode(fitted.document.toJson()['pages']),
    );
  });

  test('one sentence longer than a page is cut between words', () async {
    final doc = buildQ3Proposal();
    final before = doc.copyWith(
      pages: [
        page('Unico', [p('parola ' * 1500)]),
      ],
    );
    final fitted = await fitter.fit(before);
    expect(fitted.overflowing, isEmpty);
    expect(
      pdfPageCount(await renderer.render(fitted.document)),
      fitted.document.pages.length,
    );
    expect(text(fitted.document), text(before));
  });

  test('every layout is fitted; a cover continues on standard pages', () async {
    final doc = buildQ3Proposal();
    for (final layout in PageLayout.values) {
      final before = doc.copyWith(pages: [appeal(layout: layout)]);
      final fitted = await fitter.fit(before);
      expect(fitted.overflowing, isEmpty, reason: layout.name);
      expect(
        pdfPageCount(await renderer.render(fitted.document)),
        fitted.document.pages.length,
        reason: layout.name,
      );
      expect(text(fitted.document), text(before), reason: layout.name);
      expect(fitted.document.pages.first.layout, layout);
      expect(fitted.document.pages.skip(1).map((p) => p.layout).toSet(), {
        layout == PageLayout.cover ? PageLayout.standard : layout,
      });
    }
  });

  test('lists and tables are split between items and rows', () async {
    final doc = buildQ3Proposal();
    final before = doc.copyWith(
      pages: [
        page('Elenco', [
          BulletListBlock(
            id: newId(),
            items: [
              for (var i = 0; i < 90; i++)
                'Documento allegato numero $i, depositato in cancelleria',
            ],
          ),
          TableBlock(
            id: newId(),
            columns: const ['Atto', 'Data'],
            rows: [
              for (var i = 0; i < 60; i++) ['Atto $i', '1/1/2026'],
            ],
          ),
        ]),
      ],
    );
    final fitted = await fitter.fit(before);
    expect(fitted.overflowing, isEmpty);
    expect(
      pdfPageCount(await renderer.render(fitted.document)),
      fitted.document.pages.length,
    );
    expect(text(fitted.document), text(before));
  });

  test('a block that cannot be cut is reported, not looped on', () async {
    final doc = buildQ3Proposal();
    final before = doc.copyWith(
      pages: [
        page('Figura', [
          p('Introduzione.'),
          ImageBlock(id: newId(), caption: 'Mappa', height: 2000),
        ]),
      ],
    );
    final fitted = await fitter.fit(before);
    expect(fitted.overflowing, [1]);
    expect(text(fitted.document), text(before));
  });

  test('fits on a background isolate', () async {
    final doc = buildQ3Proposal();
    final fitted = await fitter.fitInBackground(
      doc.copyWith(pages: [appeal()]),
    );
    expect(fitted.changed, isTrue);
    expect(
      pdfPageCount(await renderer.render(fitted.document)),
      fitted.document.pages.length,
    );
  });
}
