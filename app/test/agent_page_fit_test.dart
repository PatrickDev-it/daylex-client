import 'package:flutter_test/flutter_test.dart';
import 'package:paper_agent/features/agent/domain/agent_protocol.dart';
import 'package:paper_agent/features/agent/domain/document_tools.dart';
import 'package:paper_agent/features/document/render/page_fit.dart';
import 'package:paper_agent/features/document/render/pdf_renderer.dart';

import 'agent_test.dart' show FakeHost;
import 'demo_fixture.dart';
import 'pdf_renderer_test.dart' show pdfPageCount;

/// The page an agent wrote on 2026-11-12 for the CEO's appeal, in size: far more than one A4 page.
Map<String, dynamic> longPage() => {
  'title': 'Motivi di appello',
  'blocks': [
    {'type': 'heading', 'text': 'Primo motivo', 'level': 2},
    for (var i = 0; i < 9; i++)
      {
        'type': 'paragraph',
        'text':
            'Il Tribunale ha ritenuto provato il fatto senza alcun riscontro documentale. ' *
            12,
      },
  ],
};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late PdfRenderer renderer;
  late PageFitter fitter;

  setUpAll(() async {
    renderer = PdfRenderer(await PdfFontSet.load());
    fitter = PageFitter(renderer);
  });

  Future<ToolResult> call(
    FakeHost host,
    String name,
    Map<String, dynamic> args,
  ) =>
      DocumentToolExecutor(host)
          .execute(AgentToolCall(id: 'c', name: name, arguments: args));

  test('an overlong update_page is split in the same undo step and the agent is told the new numbering', () async {
    final host = FakeHost(buildQ3Proposal(), fitter: fitter);
    final pages = host.activeDocument!.pages.length;

    final result = await call(host, ToolNames.updatePage, {
      'page': 2,
      ...longPage(),
    });

    expect(result.ok, isTrue, reason: result.summary);
    final doc = host.activeDocument!;
    expect(doc.pages.length, greaterThan(pages));
    expect(host.labels, hasLength(1));
    expect(
      result.summary,
      startsWith(
        'Aggiornata la pagina 2. Attenzione: il contenuto della pagina 2 supera',
      ),
    );
    expect(
      result.summary,
      contains('il documento ora ha ${doc.pages.length} pagine'),
    );
    expect(pdfPageCount(await renderer.render(doc)), doc.pages.length);
  });

  test('create_document opens a document whose every page renders', () async {
    final host = FakeHost(null, fitter: fitter);

    final result = await call(host, ToolNames.createDocument, {
      'title': 'Atto di appello',
      'pages': [longPage()],
    });

    expect(result.ok, isTrue, reason: result.summary);
    final doc = host.activeDocument!;
    expect(doc.pages.length, greaterThan(1));
    expect(
      result.summary,
      startsWith(
        'Creato un documento di ${doc.pages.length} pagine. Attenzione:',
      ),
    );
    expect(pdfPageCount(await renderer.render(doc)), doc.pages.length);
  });

  test('an edit that fits is reported exactly as before', () async {
    final host = FakeHost(buildQ3Proposal(), fitter: fitter);
    final result = await call(host, ToolNames.updatePage, {
      'page': 2,
      'title': 'Sintesi',
    });
    expect(result.summary, 'Aggiornata la pagina 2');
  });

  test('a block no page can hold is refused and nothing is applied', () async {
    final before = buildQ3Proposal();
    final host = FakeHost(before, fitter: fitter);

    final result = await call(host, ToolNames.addImage, {
      'page': 2,
      'caption': 'Planimetria',
      'height': 2000,
    });

    expect(result.ok, isFalse);
    expect(result.summary, contains('Modifica non applicata: a pagina 2'));
    expect(identical(host.activeDocument, before), isTrue);
    expect(host.labels, isEmpty);
  });
}
