import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:paper_agent/features/document/model/document.dart';
import 'package:paper_agent/features/workspace/pdf_export.dart';
import 'package:paper_agent/features/workspace/workspace_state.dart';

import 'demo_fixture.dart';

class _Active extends Notifier<PaperDocument?> {
  @override
  PaperDocument? build() => null;

  void open(PaperDocument? doc) => state = doc;
}

final _active = NotifierProvider<_Active, PaperDocument?>(_Active.new);

/// The preview renders a document just opened at once, an edited one once its edits settle, and keeps
/// the last good pages, marked as failed, when a render fails.
void main() {
  late ProviderContainer container;
  late List<String> renders;
  late bool failing;

  // Inside each test, not in setUp: the container's timers must run on the test's fake clock.
  void start() {
    renders = [];
    failing = false;
    container = ProviderContainer(
      overrides: [
        activeDocumentProvider.overrideWith((ref) => ref.watch(_active)),
        pdfRenderProvider.overrideWithValue((doc) async {
          renders.add(doc.title);
          if (failing) throw StateError('font missing');
          return Uint8List(0);
        }),
      ],
    );
    addTearDown(container.dispose);
    container.listen(renderedPdfProvider, (_, _) {});
  }

  /// Lets [by] pass on the fake clock, and the container's own zero-delay rebuild timer with it.
  Future<void> tick(WidgetTester tester, [Duration by = Duration.zero]) =>
      tester.pump(by + const Duration(milliseconds: 1));

  AsyncValue<RenderedPdf?> rendered() => container.read(renderedPdfProvider);
  void open(PaperDocument doc) => container.read(_active.notifier).open(doc);
  PaperDocument titled(PaperDocument doc, String title) => doc.copyWith(metadata: doc.metadata.copyWith(title: title));

  testWidgets('a document just opened renders at once', (tester) async {
    start();
    final doc = buildQ3Proposal();
    open(doc);
    await tick(tester);
    expect(renders, [doc.title]);
    expect(rendered().value?.documentId, doc.id);
  });

  testWidgets('a burst of edits renders once, the last, keeping the previous pages meanwhile', (tester) async {
    start();
    final doc = buildQ3Proposal();
    open(doc);
    await tick(tester);
    for (var i = 1; i <= 5; i++) {
      open(titled(doc, 'edit $i'));
      await tick(tester, previewSettle ~/ 3);
      expect(rendered().value?.documentId, doc.id, reason: 'the pages already shown stay while editing');
    }
    await tick(tester, previewSettle);
    expect(renders, [doc.title, 'edit 5']);
    expect(rendered().hasError, isFalse);
  });

  testWidgets('another document renders at once, without waiting', (tester) async {
    start();
    final first = buildQ3Proposal();
    final second = buildTeamOnePager();
    open(first);
    await tick(tester);
    open(second);
    expect(rendered().value?.documentId, first.id);
    expect(rendered().pagesOf(second.id), isNull, reason: "the first document's pages are never shown for the second");
    expect(rendered().status, PreviewStatus.rendering);
    await tick(tester);
    expect(renders, [first.title, second.title]);
    expect(rendered().status, PreviewStatus.upToDate);
    expect(rendered().value?.documentId, second.id);
  });

  testWidgets('a failed render keeps the last pages and says it failed', (tester) async {
    start();
    final doc = buildQ3Proposal();
    open(doc);
    await tick(tester);
    failing = true;
    open(titled(doc, 'broken'));
    await tick(tester, previewSettle * 2);
    expect(rendered().pagesOf(doc.id), isNotNull, reason: 'the last good pages stay');
    expect(rendered().status, PreviewStatus.outdated, reason: 'and say they are out of date');
  });
}
