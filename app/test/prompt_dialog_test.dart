import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:paper_agent/ui/common/prompt_dialog.dart';

import 'test_app.dart';

/// The rename prompt returns what was typed, trimmed, and closes through its whole exit animation.
void main() {
  Future<Future<String?>> open(WidgetTester tester) async {
    late Future<String?> result;
    await tester.pumpWidget(
      testApp(
        Builder(
          builder: (context) => TextButton(
            onPressed: () => result = promptForText(context, title: 'Rinomina', initial: 'Bozza'),
            child: const Text('open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    return result;
  }

  testWidgets('saving returns the text, trimmed, and the dialog closes cleanly', (tester) async {
    final result = await open(tester);
    await tester.enterText(find.byType(TextField), '  Ricorso TAR  ');
    await tester.tap(find.text(itL10n.save));
    // Frame by frame through the exit transition, where the field is still built.
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 30));
    }
    await tester.pumpAndSettle();
    expect(await result, 'Ricorso TAR');
    expect(find.byType(TextField), findsNothing);
  });

  testWidgets('cancelling returns null', (tester) async {
    final result = await open(tester);
    await tester.tap(find.text(itL10n.cancel));
    await tester.pumpAndSettle();
    expect(await result, isNull);
  });

  testWidgets('submitting only spaces returns null', (tester) async {
    final result = await open(tester);
    await tester.enterText(find.byType(TextField), '   ');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
    expect(await result, isNull);
  });
}
