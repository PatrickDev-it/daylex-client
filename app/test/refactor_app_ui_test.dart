import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:paper_agent/ui/chat/components/action_cards.dart';
import 'package:paper_agent/ui/chat/components/document_cards.dart';
import 'package:paper_agent/ui/chat/components/legal_cards.dart';
import 'package:paper_agent/ui/chat/components/progress_cards.dart';

import 'test_app.dart';

import 'package:paper_agent/ui/chat/components/card_props.dart';

/// Every `.dart` file under lib/ui with its text, for the "one definition" guards.
Map<String, String> _uiSources() => {
  for (final f in Directory(
    'lib/ui',
  ).listSync(recursive: true).whereType<File>())
    if (f.path.endsWith('.dart')) f.path: f.readAsStringSync(),
};

void main() {
  test(
    'card props: maps skip what is not a map, text is trimmed with a fallback',
    () {
      expect(
        propMaps([
          {'a': 1},
          'x',
          null,
          {'b': 2},
        ]),
        [
          {'a': 1},
          {'b': 2},
        ],
      );
      expect(propMaps(null), isEmpty);
      expect(propStr('  hi '), 'hi');
      expect(propStr('   ', 'fallback'), 'fallback');
      expect(propStr(null), '');
      expect(propStr(42), '42');
    },
  );

  test('the card prop readers, the card expansion and the copy feedback have one definition each', () {
    final sources = _uiSources();
    int defs(Pattern p) => sources.values.where((s) => s.contains(p)).length;
    expect(
      defs(
        RegExp(r'^List<Map<String, dynamic>> _?\w*[mM]aps\(', multiLine: true),
      ),
      1,
    );
    expect(defs(RegExp(r'^String _?\w*[sS]tr\(Object\?', multiLine: true)), 1);
    expect(
      defs('ExpansionTile('),
      1,
      reason: 'cards expand through CardExpansion',
    );
    expect(
      defs('Clipboard.setData'),
      2,
      reason: 'CopyFeedback, and the log tab copying a whole log',
    );
  });

  test(
    'code backgrounds are defined by both theme variants, never by a card',
    () {
      final theme = File('lib/core/theme/app_theme.dart').readAsStringSync();
      expect(
        RegExp(r'codeBackground:\s*Color\(0x[0-9A-Fa-f]{8}\)')
            .allMatches(theme)
            .length,
        2,
      );
      expect(
        _uiSources().values.any(
          (s) => s.contains('0xFFF7F8FA') || s.contains('0xFF101111'),
        ),
        isFalse,
      );
    },
  );

  group('a card with a malformed prop skips it instead of crashing', () {
    const malformed = <String, Map<String, dynamic>>{
      'progress': {'steps': 'x'},
      'matrix': {
        'sections': [
          {'title': 'A', 'items': 'x'},
          'not a map',
        ],
        'pages': 7,
      },
      'norms': {'norms': 'x', 'discarded': 5},
      'case analysis': {
        'links': [{}],
        'strategies': [
          {'title': 'S', 'links': 'x'},
        ],
        'norms': 'x',
        'dropped': 'x',
        'parties': 'x',
      },
      'change summary': {
        'pages': [
          'x',
          {'wordsAfter': 'many', 'kind': 'added'},
        ],
        'seconds': 'x',
        'tools': 'x',
      },
      'chart': {'series': 'x'},
    };
    const cards = <String, Widget Function(Map<String, dynamic>)>{
      'progress': _progress,
      'matrix': _matrix,
      'norms': _norms,
      'case analysis': _caseAnalysis,
      'change summary': _changeSummary,
      'chart': _chart,
    };
    for (final entry in malformed.entries) {
      testWidgets(entry.key, (tester) async {
        await tester.pumpWidget(
          ProviderScope(
            child: testApp(
              Scaffold(
                body: SingleChildScrollView(
                  child: cards[entry.key]!(entry.value),
                ),
              ),
            ),
          ),
        );
        expect(tester.takeException(), isNull);
      });
    }
  });
}

Widget _progress(Map<String, dynamic> p) => ProgressCard(props: p);
Widget _matrix(Map<String, dynamic> p) => MatrixCard(props: p);
Widget _norms(Map<String, dynamic> p) => NormsCard(props: p);
Widget _caseAnalysis(Map<String, dynamic> p) => CaseAnalysisCard(props: p);
Widget _changeSummary(Map<String, dynamic> p) => ChangeSummaryCard(props: p);
Widget _chart(Map<String, dynamic> p) => ChartCard(props: p);
