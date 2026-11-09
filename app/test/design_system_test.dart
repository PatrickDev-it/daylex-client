import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:paper_agent/features/document/model/document.dart';
import 'package:paper_agent/l10n/labels.dart';
import 'package:paper_agent/l10n/l10n.dart';
import 'package:paper_agent/ui/common/time_format.dart';
import 'package:paper_agent/ui/shortcuts.dart';

import 'test_app.dart';

/// The rules of the design tokens and of the translations, checked on the code: a literal radius, duration, font
/// size or accent colour in the UI, a key missing in one language, a shortcut without a name.
void main() {
  final en = lookupAppLocalizations(const Locale('en'));

  group('translations', () {
    Map<String, dynamic> arb(String lang) =>
        jsonDecode(File('lib/l10n/app_$lang.arb').readAsStringSync()) as Map<String, dynamic>;
    final it = arb('it');
    final english = arb('en');
    Set<String> keys(Map<String, dynamic> m) => {
      for (final k in m.keys)
        if (!k.startsWith('@')) k,
    };

    test('Italian and English have the same keys, none empty', () {
      expect(keys(english).difference(keys(it)), isEmpty, reason: 'only in English');
      expect(keys(it).difference(keys(english)), isEmpty, reason: 'only in Italian');
      for (final k in keys(it)) {
        expect((it[k] as String).trim(), isNotEmpty, reason: k);
        expect((english[k] as String).trim(), isNotEmpty, reason: k);
      }
    });

    test('each declared placeholder is used in both languages', () {
      for (final k in keys(it)) {
        final names = ((it['@$k'] as Map?)?['placeholders'] as Map?)?.keys ?? const [];
        for (final p in names) {
          final use = RegExp('\\{$p[,}]');
          expect(use.hasMatch(it[k] as String), isTrue, reason: '$k: {$p} in Italian');
          expect(use.hasMatch(english[k] as String), isTrue, reason: '$k: {$p} in English');
        }
      }
    });

    test('every shortcut has a name in both languages', () {
      for (final s in AppShortcut.values) {
        expect(s.label(itL10n), isNotEmpty, reason: s.name);
        expect(s.label(en), isNotEmpty, reason: s.name);
      }
      expect({for (final s in AppShortcut.values) s.label(itL10n)}, hasLength(AppShortcut.values.length));
    });
  });

  group('shortcuts', () {
    test('keys are spelled the same everywhere', () {
      expect(AppShortcut.newChat.keys, 'Ctrl N');
      expect(AppShortcut.stopAgent.keys, 'Esc');
      expect(AppShortcut.redo.allKeys, 'Ctrl Shift Z / Ctrl Y');
      expect(keysOf(const SingleActivator(LogicalKeyboardKey.arrowRight, alt: true)), 'Alt →');
    });

    test('no key does two things in the same place', () {
      for (final scope in ShortcutScope.values) {
        final seen = <String, AppShortcut>{};
        for (final s in AppShortcut.values.where((s) => s.scope == scope)) {
          for (final a in s.activators) {
            final other = seen[keysOf(a)];
            if (other != s) expect(other, isNull, reason: '${keysOf(a)}: ${other?.name} and ${s.name}');
            seen[keysOf(a)] = s;
          }
        }
      }
    });
  });

  group('time format', () {
    final now = DateTime(2026, 10, 5, 18);

    test('relative times in both languages', () {
      expect(relativeTime(itL10n, now.subtract(const Duration(seconds: 20)), now), 'adesso');
      expect(relativeTime(itL10n, now.subtract(const Duration(minutes: 5)), now), '5 min fa');
      expect(relativeTime(itL10n, now.subtract(const Duration(hours: 3)), now), '3 h fa');
      expect(relativeTime(itL10n, now.subtract(const Duration(days: 1)), now), 'ieri');
      expect(relativeTime(itL10n, now.subtract(const Duration(days: 4)), now), '4 giorni fa');
      expect(relativeTime(itL10n, DateTime(2026, 9, 3), now), '3 set');
      expect(relativeTime(en, now.subtract(const Duration(days: 4)), now), '4 days ago');
      expect(relativeTime(en, DateTime(2025, 9, 3), now), 'Sep 3 2025');
    });

    test('clock and stamps', () {
      expect(clockSeconds(DateTime(2026, 1, 2, 3, 4, 5)), '03:04:05');
      expect(shortStamp(en, DateTime(2026, 10, 4, 23, 59), now), 'Yesterday 23:59');
      expect(shortStamp(en, DateTime(2026, 9, 28, 14, 32), now), 'Sep 28, 14:32');
    });
  });

  test('block kinds read back from their wire names', () {
    for (final k in BlockKind.values) {
      expect(BlockKind.parse(k.wire), k);
      expect(itL10n.blockKind(k), isNotEmpty);
    }
    expect(BlockKind.parse('nope'), isNull);
  });

  group('design tokens', () {
    final ui = [
      File('lib/app.dart'),
      ...Directory('lib/ui').listSync(recursive: true).whereType<File>().where((f) => f.path.endsWith('.dart')),
    ];

    /// Lines of the UI matching [pattern], except those [allowed] lets through, as "file:line: text".
    List<String> offending(RegExp pattern, {bool Function(String line)? allowed}) => [
      for (final f in ui)
        for (final (i, line) in f.readAsLinesSync().indexed)
          if (pattern.hasMatch(line) && !(allowed?.call(line) ?? false)) '${f.path}:${i + 1}: ${line.trim()}',
    ];

    test('radii come from AppTheme (PDF radii aside)', () {
      expect(offending(RegExp(r'Radius\.circular\(\d'), allowed: (l) => l.contains('pw.')), isEmpty);
    });

    test('font sizes come from the text theme or AppText', () {
      expect(offending(RegExp(r'fontSize:\s*\d')), isEmpty);
    });

    test('animations use AppTheme durations; other timers are named constants', () {
      expect(
        offending(
          RegExp(r'Duration\((milliseconds|seconds):'),
          allowed: (l) => RegExp(r'^\s*(static )?const _?\w+ =').hasMatch(l),
        ),
        isEmpty,
      );
    });

    test('what the lawyer reads comes from the translations (proper names aside)', () {
      expect(
        offending(
          RegExp(
            r"""(Text|tooltip:|label:|labelText:|hintText:|helperText:|message:|title:|toast)\s*\(?'[A-Za-zÀ-ú]""",
          ),
          allowed: (l) => RegExp(r"'(PDF|Normattiva|PaperAgent)'").hasMatch(l),
        ),
        isEmpty,
      );
    });

    test('the accent and the monospace font are read from the theme', () {
      expect(offending(RegExp(r'AppTheme\.accent\b|monoFont|monoFallback|0xFF4A7CFF')), isEmpty);
    });
  });
}
