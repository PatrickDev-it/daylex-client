import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:paper_agent/features/document/model/document.dart';
import 'package:paper_agent/features/document/model/document_review.dart';
import 'package:paper_agent/features/workspace/document_review.dart';
import 'package:paper_agent/features/workspace/pdf_export.dart';
import 'package:paper_agent/features/workspace/workspace_state.dart';
import 'package:paper_agent/ui/panel/document_review_strip.dart';
import 'package:paper_agent/l10n/app_localizations.dart';
import 'package:paper_agent/core/theme/app_theme.dart';

import 'demo_fixture.dart';
import 'test_app.dart';

DocumentReview report(String revision, {bool pdf = true, bool issue = false}) =>
    DocumentReview.fromJson({
      'revision': revision,
      'complete': true,
      'issues': [
        if (issue)
          {
            'page': 1,
            'text': 'rilettuto',
            'message': 'Possibile errore di battitura.',
            'blocking': true,
            'spelling': true,
            'protected': false,
          },
      ],
      'pdf': pdf ? {'complete': true, 'issues': <String>[]} : null,
    });

class Reviewer implements DocumentReviewer {
  final phases = <String>[];
  final blocked = Completer<DocumentReview>();
  bool delayOld = false;

  @override
  Future<DocumentReview> reviewDocument(
    PaperDocument document, {
    Uint8List? pdf,
  }) async {
    phases.add('${document.title}:${pdf == null ? 'text' : 'pdf'}');
    if (delayOld && document.title == 'Vecchia versione' && pdf != null) {
      return blocked.future;
    }
    return report(
      document.title,
      pdf: pdf != null,
      issue: document.title == 'Errore',
    );
  }
}

void main() {
  test(
    'each committed edit starts review even before the next UI frame',
    () async {
      final seen = <String>[];
      final container = ProviderContainer(
        overrides: [
          documentReviewProvider.overrideWith((ref, doc) async {
            seen.add(doc.title);
            return report(doc.title);
          }),
        ],
      );
      addTearDown(container.dispose);
      final workspace = container.read(workspaceProvider.notifier);
      final original = buildQ3Proposal();
      workspace.addDocument(original);
      workspace.restore(
        original.copyWith(
          metadata: original.metadata.copyWith(title: 'Prima modifica'),
        ),
        label: 'Prima',
      );
      workspace.restore(
        original.copyWith(
          metadata: original.metadata.copyWith(title: 'Seconda modifica'),
        ),
        label: 'Seconda',
      );
      await Future<void>.delayed(Duration.zero);
      expect(
        seen,
        containsAllInOrder([
          original.title,
          'Prima modifica',
          'Seconda modifica',
        ]),
      );
    },
  );
  test('text-only, incomplete and flagged reports cannot authorise export', () {
    expect(
      report('a', pdf: false).requireExport,
      throwsA(isA<DocumentReviewFailure>()),
    );
    expect(
      report('a', issue: true).requireExport,
      throwsA(isA<DocumentReviewFailure>()),
    );
    expect(report('a').requireExport, returnsNormally);
  });

  test('confirming a term authorises only that exact document revision', () {
    final first = report('old', issue: true);
    final confirmed = {'old:${first.issues.single.key}'};
    expect(() => first.requireExport(confirmed), returnsNormally);
    expect(
      () => report('new', issue: true).requireExport(confirmed),
      throwsA(isA<DocumentReviewFailure>()),
    );
  });

  test('creation and editing review text before rendering; late old result cannot clear new issues', () async {
    final engine = Reviewer()..delayOld = true;
    final container = ProviderContainer(
      overrides: [
        documentReviewerProvider.overrideWithValue(engine),
        pdfRenderProvider.overrideWithValue((doc) async {
          engine.phases.add('${doc.title}:render');
          return Uint8List.fromList([1, 2]);
        }),
      ],
    );
    addTearDown(container.dispose);
    final original = buildQ3Proposal();
    final old = original.copyWith(
      metadata: original.metadata.copyWith(title: 'Vecchia versione'),
    );
    final next = original.copyWith(
      metadata: original.metadata.copyWith(title: 'Errore'),
    );
    final keepOld = container.listen(documentReviewProvider(old), (_, _) {});
    final keepNext = container.listen(documentReviewProvider(next), (_, _) {});
    addTearDown(keepOld.close);
    addTearDown(keepNext.close);
    final current = await container.read(documentReviewProvider(next).future);
    expect(current.canExport, isFalse);
    engine.blocked.complete(report(old.title));
    await container.read(documentReviewProvider(old).future);
    expect(
      container.read(documentReviewProvider(next)).value!.canExport,
      isFalse,
    );
    expect(
      engine.phases.indexOf('Errore:text'),
      lessThan(engine.phases.indexOf('Errore:render')),
    );
    expect(
      engine.phases.indexOf('Errore:render'),
      lessThan(engine.phases.indexOf('Errore:pdf')),
    );
  });

  testWidgets('findings stay readable at a narrow panel width', (tester) async {
    await loadAppFonts();
    final icons = FontLoader('MaterialIcons')
      ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
    await icons.load();
    final original = buildQ3Proposal();
    final doc = original.copyWith(
      metadata: original.metadata.copyWith(title: 'Errore'),
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          documentReviewProvider(doc)
              .overrideWith((ref) async => report('x', issue: true)),
        ],
        child: MaterialApp(
          theme: AppTheme.dark(),
          locale: const Locale('it'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: Center(
              child: RepaintBoundary(
                key: const ValueKey('review-visual'),
                child: SizedBox(
                  width: 340,
                  child: DocumentReviewStrip(document: doc),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(
      find.text('Correzioni da verificare prima dell’esportazione'),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('rilettuto'), findsOneWidget);
    expect(tester.takeException(), isNull);
    final visual = Platform.environment['DAYLEX_REVIEW_VISUAL_PATH'];
    if (visual != null) {
      final boundary = tester.renderObject<RenderRepaintBoundary>(
        find.byKey(const ValueKey('review-visual')),
      );
      await tester.runAsync(() async {
        final image = await boundary.toImage(pixelRatio: 2);
        final data = await image.toByteData(format: ui.ImageByteFormat.png);
        await File(visual).writeAsBytes(data!.buffer.asUint8List());
        image.dispose();
      });
    }
  });
}
