import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:paper_agent/features/document/render/page_images.dart';
import 'package:paper_agent/features/workspace/pdf_export.dart';

import 'demo_fixture.dart';

/// A chat card's page is rendered once while shown, kept a little after it leaves the screen, then let go
/// with its PDF: every edit of a live thumbnail is a new version, and none may stay in memory for good.
void main() {
  late ProviderContainer container;
  late SnapshotStore store;
  late List<String> renders;

  // Inside each test, not in setUp: the container's timers must run on the test's fake clock.
  void start() {
    renders = [];
    store = SnapshotStore();
    container = ProviderContainer(
      overrides: [
        snapshotStoreProvider.overrideWithValue(store),
        pdfRenderProvider.overrideWithValue((doc) async {
          renders.add(doc.title);
          return Uint8List(1);
        }),
        pageRasterProvider.overrideWithValue((pdf, page) async => Uint8List(2)),
      ],
    );
    addTearDown(container.dispose);
  }

  /// Lets [by] pass on the fake clock, and the container's own zero-delay timers with it.
  Future<void> tick(WidgetTester tester, [Duration by = Duration.zero]) =>
      tester.pump(by + const Duration(milliseconds: 1));

  testWidgets('a page nobody shows is let go, its PDF with it, once the cache window has passed', (tester) async {
    start();
    final id = store.put(buildQ3Proposal());
    final page = pageImageProvider((id, 0));
    final shown = container.listen(page, (_, _) {});
    await tick(tester);
    expect(container.read(page).hasValue, isTrue);

    shown.close();
    await tick(tester, pageCacheFor ~/ 2);
    expect(container.exists(snapshotPdfProvider(id)), isTrue, reason: 'kept a while after it leaves the screen');
    await tick(tester, pageCacheFor);
    expect(container.exists(page), isFalse);
    expect(container.exists(snapshotPdfProvider(id)), isFalse);
  });

  testWidgets('a page shown again within the window is not rendered again', (tester) async {
    start();
    final id = store.put(buildQ3Proposal());
    final page = pageImageProvider((id, 0));
    container.listen(page, (_, _) {}).close();
    await tick(tester);
    await tick(tester, pageCacheFor ~/ 2);
    container.listen(page, (_, _) {});
    await tick(tester, pageCacheFor * 2);
    expect(container.read(page).hasValue, isTrue);
    expect(renders, hasLength(1));
  });

  testWidgets('the pages of one version share its single render', (tester) async {
    start();
    final id = store.put(buildQ3Proposal());
    container.listen(pageImageProvider((id, 0)), (_, _) {});
    container.listen(pageImageProvider((id, 1)), (_, _) {});
    await tick(tester);
    expect(renders, hasLength(1));
  });
}
