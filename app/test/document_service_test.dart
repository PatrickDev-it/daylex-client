import 'package:flutter_test/flutter_test.dart';
import 'package:paper_agent/features/document/model/document.dart';
import 'package:paper_agent/features/document/model/operations.dart';
import 'package:paper_agent/features/document/service/document_service.dart';

import 'demo_fixture.dart';

void main() {
  const service = DocumentService();
  late PaperDocument doc;

  setUp(() => doc = buildQ3Proposal());

  test('add, move and delete pages', () {
    final added = service.apply(
      doc,
      AddPage(DocPage(id: 'p-new', title: 'Appendix', blocks: const []), index: 1),
    );
    expect(added.pages.length, doc.pages.length + 1);
    expect(added.pages[1].title, 'Appendix');

    final moved = service.apply(added, const MovePage(1, 3));
    expect(moved.pages[3].title, 'Appendix');

    final deleted = service.apply(moved, const DeletePage(3));
    expect(deleted.pages.map((p) => p.id), doc.pages.map((p) => p.id));
  });

  test('rejects invalid pages and deleting the last page', () {
    expect(
      () => service.apply(doc, DeletePage(doc.pages.length)),
      throwsA(isA<DocumentOperationException>()),
    );
    final single = buildTeamOnePager();
    expect(
      () => service.apply(single, const DeletePage(0)),
      throwsA(isA<DocumentOperationException>()),
    );
  });

  test('replace text is scoped to a page when requested', () {
    final total = service.countOccurrences(doc, 'Acme');
    expect(total, greaterThan(1));

    final onPage = service.countOccurrences(doc, 'Acme', pageIndex: 1);
    final replaced = service.apply(doc, const ReplaceText('Acme', 'Globex', pageIndex: 1));
    expect(service.countOccurrences(replaced, 'Acme'), total - onPage);
    expect(service.countOccurrences(replaced, 'Globex', pageIndex: 1), onPage);
  });

  test('block operations keep the rest of the document intact', () {
    final block = ParagraphBlock(id: 'b-test', text: 'Hello');
    final inserted = service.apply(doc, InsertBlock(2, block, index: 0));
    expect(inserted.pages[2].blocks.first.id, 'b-test');

    final updated = service.apply(inserted, UpdateBlock(ParagraphBlock(id: 'b-test', text: 'Hi')));
    expect(updated.pages[2].blocks.first.plainText, 'Hi');

    final movedDown = service.apply(updated, const MoveBlock('b-test', 1));
    expect(movedDown.pages[2].blocks[1].id, 'b-test');

    final removed = service.apply(movedDown, const RemoveBlock('b-test'));
    expect(removed.toJson()['pages'], isNot(contains('b-test')));
    expect(removed.pages[2].blocks.length, doc.pages[2].blocks.length);
    expect(removed.pages[0], same(doc.pages[0]));
  });

  test('metadata and theme updates', () {
    final next = service.applyAll(doc, [
      const UpdateMetadata(title: 'Q4 Plan', status: DocumentStatus.review),
      SetTheme(doc.theme.copyWith(accent: 0xFF2F9E44)),
    ]);
    expect(next.title, 'Q4 Plan');
    expect(next.metadata.status, DocumentStatus.review);
    expect(next.theme.accent, 0xFF2F9E44);
    expect(doc.title, 'Q3 Business Proposal', reason: 'operations are pure');
  });
}
