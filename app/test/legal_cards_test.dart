import 'package:flutter/material.dart';
import 'package:flutter_gen_ai_chat_ui/flutter_gen_ai_chat_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:paper_agent/features/agent/agent_controller.dart';
import 'package:paper_agent/ui/chat/components/legal_cards.dart';

import 'test_app.dart';

const _norm = {
  'ref': 'art. 1495 c.c.',
  'rubrica': "Termini e condizioni per l'azione",
  'act': 'Codice civile',
  'origin': 'individuata dai fatti degli allegati',
  'summary': 'Il compratore decade dalla garanzia se non denunzia i vizi entro otto giorni dalla scoperta.',
  'link': 'La PEC del 12/03/2026 arriva 20 giorni dopo la consegna del 20/02/2026: oltre gli otto giorni.',
  'why': "È la norma sul termine di denuncia della vendita; l'art. 1667 c.c. riguarda l'appalto.",
  'fit': 'full',
  'text': 'Il compratore decade dal diritto alla garanzia, se non denunzia i vizi al venditore entro otto giorni...',
  'vigenza': '2026-05-30',
  'url': 'https://www.normattiva.it/uri-res/N2Ls?urn:nir:stato:regio.decreto:1942-03-16;262~art1495',
};

Widget _host(Widget child) =>
    testApp(Scaffold(body: SingleChildScrollView(child: child)));

void main() {
  testWidgets(
    'the norms card opens an article on its explanation and official text',
    (tester) async {
      await tester.pumpWidget(
        _host(
          const NormsCard(
            props: {
              'title': 'Norme utilizzate',
              'norms': [_norm],
              'discarded': [
                {
                  'ref': 'art. 1667 c.c.',
                  'rubrica': 'Difformità e vizi',
                  'reason': "Riguarda l'appalto, non la vendita.",
                },
              ],
            },
          ),
        ),
      );
      expect(find.text('art. 1495 c.c.'), findsOneWidget);
      expect(find.text('Pertinente'), findsOneWidget);
      expect(find.text('Come si collega al caso'), findsNothing);

      await tester.tap(find.text('art. 1495 c.c.'));
      await tester.pumpAndSettle();
      expect(find.text('Come si collega al caso'), findsOneWidget);
      expect(find.text('Perché questa norma'), findsOneWidget);
      expect(find.text('individuata dai fatti degli allegati'), findsNothing);
      expect(find.text(_norm['text']!), findsOneWidget);
      expect(
        find.textContaining('testo vigente al 30/05/2026'),
        findsOneWidget,
      );
      expect(
        find.text('Norme vicine considerate e scartate (1)'),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'the analysis card groups links by degree and strategies by side',
    (tester) async {
      tester.view.physicalSize = const Size(1400, 2400);
      addTearDown(tester.view.resetPhysicalSize);
      await tester.pumpWidget(
        _host(
          const CaseAnalysisCard(
            props: {
              'parties': {
                'client': 'Mario Rossi',
                'opponent': 'Edilnord S.r.l.',
              },
              'links': [
                {
                  'id': 'C1',
                  'degree': 1,
                  'title': 'Clausola sui vizi',
                  'effect': 'favorevole',
                  'reasoning': 'Il contratto ripete il termine di otto giorni.',
                  'elements': [
                    {
                      'kind': 'fact',
                      'doc': 1,
                      'name': 'Contratto.pdf',
                      'page': 1,
                      'quote': 'entro otto giorni dalla consegna',
                    },
                    {
                      'kind': 'norm',
                      'ref': 'art. 1495 c.c.',
                      'rubrica': "Termini e condizioni per l'azione",
                      'url': '',
                    },
                  ],
                },
                {
                  'id': 'C2',
                  'degree': 3,
                  'title': 'Denuncia tardiva',
                  'effect': 'favorevole',
                  'reasoning': 'Consegna, clausola e PEC insieme: 20 giorni, oltre gli otto.',
                  'elements': [
                    {
                      'kind': 'fact',
                      'doc': 2,
                      'name': 'DDT.pdf',
                      'page': 1,
                      'quote': 'Data di consegna: 20/02/2026',
                    },
                    {
                      'kind': 'fact',
                      'doc': 4,
                      'name': 'PEC.pdf',
                      'page': 1,
                      'quote': 'contestiamo la fornitura',
                    },
                    {
                      'kind': 'fact',
                      'doc': 1,
                      'name': 'Contratto.pdf',
                      'page': 1,
                      'quote': 'a pena di decadenza',
                    },
                  ],
                },
              ],
              'strategies': [
                {
                  'party': 'assistito',
                  'kind': 'attacco',
                  'title': 'Decreto ingiuntivo',
                  'move': 'Chiedere il pagamento.',
                  'links': ['C2'],
                  'counter': 'Edilnord dirà che i vizi erano occulti.',
                },
                {
                  'party': 'controparte',
                  'kind': 'difesa',
                  'title': 'Vizi occulti',
                  'move': 'Sostenere la scoperta tardiva.',
                  'links': ['C2'],
                  'counter': 'Il DDT è firmato senza riserve.',
                },
              ],
              'norms': [_norm],
              'dropped': [
                'Collegamento inventato: elementi non trovati negli atti',
              ],
            },
          ),
        ),
      );
      expect(find.textContaining('Riscontri diretti'), findsOneWidget);
      expect(find.textContaining('Tesi da approfondire'), findsOneWidget);
      expect(
        find.textContaining('Collegamenti tra fatti e norme'),
        findsNothing,
      );
      expect(find.text('Nostro assistito · Mario Rossi'), findsOneWidget);
      expect(find.text('Controparte · Edilnord S.r.l.'), findsOneWidget);
      expect(find.textContaining('1 collegamento scartato'), findsOneWidget);

      await tester.tap(
        find.textContaining('Denuncia tardiva', findRichText: true),
      );
      await tester.pumpAndSettle();
      expect(find.text('Elementi (3)'), findsOneWidget);
      expect(find.text('DDT, pagina 1'), findsOneWidget);

      await tester.tap(find.text('Vizi occulti'));
      await tester.pumpAndSettle();
      expect(find.text('Nostra contromossa'), findsOneWidget);
    },
  );

  test('the history goes to the server oldest first, one turn per reply, with the card digests', () {
    final t = DateTime(2026, 10, 5, 10);
    ChatMessage msg(
      String text,
      ChatUser who,
      int minute, [
      Map<String, dynamic>? extra,
    ]) => ChatMessage(
      text: text,
      user: who,
      createdAt: t.add(Duration(minutes: minute)),
      customProperties: {'id': 'm$minute', ...?extra},
    );
    // Newest first, as the chat controller keeps them.
    final messages = [
      msg('norms', AgentController.agent, 3, {
        'resultKind': 'norms',
        'resultData': {'digest': '[Norme spiegate: art. 1495 c.c.]'},
      }),
      msg('Sì, la denuncia è tardiva.', AgentController.agent, 2),
      msg('La denuncia è tardiva?', AgentController.user, 1),
      msg('Analizza il fascicolo', AgentController.user, 0),
    ];
    final turns = AgentController.historyOf(messages);
    expect(turns.map((t) => t.role), ['user', 'user', 'assistant']);
    expect(turns.first.text, 'Analizza il fascicolo');
    expect(
      turns.last.text,
      'Sì, la denuncia è tardiva.\n\n[Norme spiegate: art. 1495 c.c.]',
    );
  });
}
