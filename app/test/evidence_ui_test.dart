import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:paper_agent/ui/chat/components/evidence_card.dart';

import 'test_app.dart';

void main() {
  for (final missing in [false, true]) {
    testWidgets('evidence distinguishes resolvable passage from missing source: $missing', (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(testApp(Scaffold(body: SingleChildScrollView(child: EvidenceCard(props: {
        'claims': [{'claim': 'Il pagamento risulta dichiarato.', 'status': 'traceable', 'source_ids': ['s1'], 'citation_ids': ['c1']}],
        'pack': {
          'sources': missing ? [] : [{'source_id': 's1', 'name': 'Articolo di prova', 'voice': 'legislatore', 'effective_on': '2026-11-04'}],
          'citations': [{'id': 'c1', 'source_id': 's1', 'quote': 'Il pagamento risulta dichiarato.', 'structural_verdict': 'verified'}],
        },
      })))));
      await tester.tap(find.text('Fonti e riscontri'));
      await tester.pumpAndSettle();
      expect(find.text(missing ? 'Collegamento alla fonte incompleto' : 'Passaggio della fonte disponibile'), findsOneWidget);
      await tester.tap(find.text('Il pagamento risulta dichiarato.'));
      await tester.pumpAndSettle();
      expect(find.textContaining('valutazione giuridica'), findsWidgets);
      expect(find.textContaining('verified'), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }
}
