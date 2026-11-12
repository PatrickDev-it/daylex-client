import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:paper_agent/ui/chat/chat_view.dart';
import 'package:paper_agent/ui/chat/components/typed_reply.dart';

import 'test_app.dart';

const sentence =
    'Il termine per proporre opposizione al decreto ingiuntivo è di quaranta giorni dalla notifica. ';

/// The text on screen: plain while it streams, selectable once complete.
String shown(WidgetTester tester) => [
  ...tester
      .widgetList<RichText>(find.byType(RichText))
      .map((r) => r.text.toPlainText()),
  ...tester
      .widgetList<EditableText>(find.byType(EditableText))
      .map((e) => e.controller.text),
].join();

Future<void> reply(
  WidgetTester tester,
  String text, {
  required bool streaming,
  bool reduceMotion = false,
}) => tester.pumpWidget(
  testApp(
    MediaQuery(
      data: MediaQueryData(disableAnimations: reduceMotion),
      child: Scaffold(
        body: SingleChildScrollView(
          child: TypedReply(text, streaming: streaming),
        ),
      ),
    ),
  ),
);

void main() {
  group('revealCut', () {
    test('cuts at the end of the word reached, never inside it', () {
      expect(revealCut('Il termine scade', 5), 'Il termine'.length);
      expect(revealCut('Il termine scade', 0), 0);
      expect(revealCut('Il termine scade', 99), 'Il termine scade'.length);
    });

    test('never cuts inside a source reference, a link, bold, code or math', () {
      const text =
          'Vedi [Decreto ingiuntivo, p. 3] e [Cass.](https://a.it/x y) poi **molto importante** e `art. 641` e \$x+y\$ fine';
      for (var count = 0; count <= text.length; count++) {
        final cut = revealCut(text, count);
        for (final span in [
          '[Decreto ingiuntivo, p. 3]',
          '[Cass.](https://a.it/x y)',
          '**molto importante**',
          '`art. 641`',
          r'$x+y$',
        ]) {
          final start = text.indexOf(span);
          expect(
            cut <= start || cut >= start + span.length,
            isTrue,
            reason: 'cut $cut falls inside $span',
          );
        }
      }
    });
  });

  group('TypedReply', () {
    testWidgets('a streamed sentence appears a word at a time, then whole', (
      tester,
    ) async {
      await reply(tester, sentence, streaming: true);
      expect(shown(tester), isEmpty);
      await tester.pump(const Duration(milliseconds: 16));
      await tester.pump(const Duration(milliseconds: 250));
      final partial = shown(tester);
      expect(partial, isNotEmpty);
      expect(sentence.startsWith(partial.trimRight()), isTrue);
      expect(partial.length, lessThan(sentence.trim().length));
      await tester.pump(TypedReply.catchUp);
      expect(shown(tester), sentence.trim());
    });

    testWidgets(
      'a long backlog is caught up within catchUp, not at a fixed typing speed',
      (tester) async {
        final text = List.filled(8, sentence).join();
        await reply(tester, text, streaming: true);
        await tester.pump(const Duration(milliseconds: 16));
        await tester.pump(
          TypedReply.catchUp + const Duration(milliseconds: 100),
        );
        expect(shown(tester), text.trim());
      },
    );

    testWidgets(
      'a reply that arrives complete (an earlier turn) appears whole at once',
      (tester) async {
        await reply(tester, sentence, streaming: false);
        expect(shown(tester), sentence.trim());
      },
    );

    testWidgets('with reduced motion the text appears as it arrives', (
      tester,
    ) async {
      await reply(tester, sentence, streaming: true, reduceMotion: true);
      expect(shown(tester), sentence.trim());
    });

    testWidgets('a reply that ends mid-reveal keeps revealing what is left', (
      tester,
    ) async {
      await reply(tester, sentence, streaming: true);
      await tester.pump(const Duration(milliseconds: 16));
      await tester.pump(const Duration(milliseconds: 100));
      await reply(tester, sentence, streaming: false);
      expect(shown(tester).length, lessThan(sentence.trim().length));
      await tester.pump(TypedReply.catchUp);
      expect(shown(tester), sentence.trim());
    });
  });

  test('the chat column grows with the window between its bounds', () {
    expect(chatColumnWidth(600), chatColumnMinWidth);
    expect(chatColumnWidth(1000), 1000 - 2 * chatColumnMargin);
    expect(chatColumnWidth(2560), chatColumnMaxWidth);
  });
}
