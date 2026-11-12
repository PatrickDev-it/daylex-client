import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:paper_agent/features/document/model/document_review.dart';
import 'package:paper_agent/features/document/render/pdf_renderer.dart';
import 'package:paper_agent/features/workspace/pdf_export.dart';
import 'package:paper_agent/l10n/app_localizations_it.dart';

import 'demo_fixture.dart';

void main() {
  final l = AppLocalizationsIt();

  test(
    'a page too long for A4 reads as such, even passed on by a provider',
    () async {
      final render = FutureProvider<int>(
        (ref) => throw const PdfLayoutException(2),
        retry: (_, _) => null,
      );
      final preview = FutureProvider<int>(
        (ref) => ref.watch(render.future),
        retry: (_, _) => null,
      );
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final error = await container
          .read(preview.future)
          .then<Object?>((_) => null, onError: (Object e) => e);

      // Awaited through `.future`, the renderer's own exception reaches the preview.
      expect(error, isA<PdfLayoutException>());
      expect(describePdfFailure(l, error), l.pdfPageTooLong(2));
    },
  );

  test(
    'a review refusal keeps its own words; anything else is never shown raw',
    () {
      expect(
        describePdfFailure(
          l,
          const DocumentReviewFailure('Verifica occupata.'),
        ),
        'Verifica occupata.',
      );
      expect(
        describePdfFailure(l, StateError('internal')),
        l.failureUnexpected,
      );
    },
  );

  test('a failed render is not retried', () async {
    var renders = 0;
    final container = ProviderContainer(
      overrides: [
        pdfRenderProvider.overrideWithValue((_) async {
          renders++;
          throw const PdfLayoutException(1);
        }),
      ],
    );
    addTearDown(container.dispose);
    final doc = buildQ3Proposal();
    final sub = container.listen(documentPdfBytesProvider(doc), (_, _) {});
    addTearDown(sub.close);

    // Riverpod's default would have retried at 0.2, 0.6 and 1.4 s.
    await Future<void>.delayed(const Duration(milliseconds: 1600));

    expect(renders, 1);
    expect(
      container.read(documentPdfBytesProvider(doc)).error,
      isA<PdfLayoutException>(),
    );
  });
}
