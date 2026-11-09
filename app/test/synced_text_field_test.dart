import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:paper_agent/ui/document/outline_editor.dart';

import 'test_app.dart';

void main() {
  testWidgets('text typed just before the field goes away is committed, not dropped', (tester) async {
    final commits = <String>[];
    final show = ValueNotifier(true);
    await tester.pumpWidget(
      testApp(
        Scaffold(
          body: ValueListenableBuilder(
            valueListenable: show,
            builder: (_, visible, _) =>
                visible ? SyncedTextField(value: 'Titolo', onCommit: commits.add) : const SizedBox(),
          ),
        ),
      ),
    );

    await tester.enterText(find.byType(TextField), 'Titolo nuovo');
    show.value = false; // e.g. the user switched chat within the debounce
    await tester.pump();

    expect(commits, ['Titolo nuovo']);
    await tester.pump(const Duration(seconds: 1)); // the cancelled debounce does not commit twice
    expect(commits, ['Titolo nuovo']);
  });
}
