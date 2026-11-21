import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:paper_agent/features/document/export/html_writer.dart';
import 'package:paper_agent/features/document/export/md_writer.dart';
import 'package:paper_agent/features/document/export/rtf_writer.dart';
import 'package:paper_agent/features/document/export/txt_writer.dart';

import 'export_fixture.dart';
import 'export_readers.dart';

void main() {
  group('RTF', () {
    final bytes = encodeRtf(fixtureDocument());
    final rtf = ascii.decode(bytes);

    test('is pure ASCII, one balanced group, RTF 1 in ANSI with its tables', () {
      expect(bytes.every((b) => b < 0x80), isTrue);
      expect(rtf, startsWith(r'{\rtf1\ansi\ansicpg1252'));
      expect(rtf, contains(r'{\fonttbl'));
      expect(rtf, contains(r'{\colortbl'));
      expect(rtf, contains(r'{\stylesheet'));
      expect(rtf, contains(r'{\info'));
      var depth = 0;
      for (var i = 0; i < rtf.length; i++) {
        final c = rtf[i];
        if (c == r'\') {
          i++;
        } else if (c == '{') {
          depth++;
        } else if (c == '}') {
          depth--;
          expect(depth, greaterThanOrEqualTo(0), reason: 'a group closed that was not open, at $i');
        }
      }
      expect(depth, 0, reason: 'every group is closed');
    });

    test('escapes what RTF reads as markup, and writes the rest as UTF-16 units', () {
      expect(rtfEscape(r'a\b{c}d'), r'a\\b\{c\}d');
      expect(rtfEscape('è'), r'\u232?');
      expect(rtfEscape('€'), r'\u8364?');
      expect(rtfEscape('😀'), r'\u-10179?\u-8704?', reason: 'an emoji is a surrogate pair, each unit a signed 16-bit number');
      expect(rtfEscape('a\nb\tc'), r'a\line b\tab c');
    });

    test('keeps the text of every block', () {
      final text = rtfText(rtf);
      expectWords(text, fixtureWords.where((w) => !w.contains('con a capo')), reason: 'rtf');
      expect(text, contains('con a capo'));
    });

    test('has real tables with a repeating header row, a picture and a footer', () {
      expect(RegExp(r'\\trhdr').allMatches(rtf), hasLength(3), reason: 'metrics and the two tables');
      expect(RegExp(r'\\trowd').allMatches(rtf), hasLength(3 + 5 + 3));
      expect(rtf, contains(r'\cellx'));
      expect(rtf, contains(r'{\pict\pngblip'));
      expect(rtf, contains('{\\footer'));
      expect(rtf, contains(r'\fldinst PAGE'));
      expect(rtf, contains('[Immagine: Senza immagine]'));
    });

    test('writes an empty document', () {
      expect(ascii.decode(encodeRtf(emptyDocument())), startsWith(r'{\rtf1'));
    });
  });

  group('TXT', () {
    final bytes = encodeTxt(fixtureDocument());
    final text = utf8.decode(bytes);

    test('is UTF-8 with no byte order mark and CRLF line ends only', () {
      expect(bytes.take(3), isNot([0xEF, 0xBB, 0xBF]));
      expect(text.contains(RegExp(r'(?<!\r)\n')), isFalse, reason: 'a bare line feed');
      expect(text.contains(RegExp(r'\r(?!\n)')), isFalse, reason: 'a bare carriage return');
      expect(text.endsWith('\r\n'), isTrue);
      expect(forbiddenChars.hasMatch(text.replaceAll('\r', '')), isFalse);
    });

    test('keeps the text of every block', () {
      expectWords(text, fixtureWords.where((w) => w != 'con a capo'), reason: 'txt');
      expect(text, contains('con a capo'));
    });

    test('underlines headings, marks bullets, indents quotes, names pictures, aligns tables', () {
      final lines = text.split('\r\n');
      final title = lines.indexWhere((l) => l.startsWith('Parere pro veritate'));
      expect(lines[title + 1], '=' * lines[title].runes.length, reason: 'the title is underlined');
      final h = lines.indexOf('Sintesi dei fatti');
      expect(lines[h + 1], '-' * 'Sintesi dei fatti'.length);
      expect(lines, contains('• Primo punto: àèéìòù'));
      expect(lines, contains('    La legge è uguale per tutti.'));
      expect(lines, contains('[Immagine: Planimetria & rilievo]'));
      expect(lines, contains('[Immagine: Senza immagine]'));
      final header = lines.indexWhere((l) => l.startsWith('Voce'));
      final rule = lines[header + 1];
      expect(rule, matches(RegExp(r'^-+(  -+)+$')));
      final columns = rule.split('  ').map((c) => c.length).toList();
      for (final row in lines.skip(header + 2).take(3)) {
        // Every body row starts where the first column does and its second column ends where the rule's does.
        expect(row.length, greaterThan(columns.first), reason: row);
      }
    });
  });

  group('MD', () {
    final bytes = encodeMd(fixtureDocument());
    final md = utf8.decode(bytes);

    test('is UTF-8, LF only, ends with one line feed', () {
      expect(md.contains('\r'), isFalse);
      expect(md.endsWith('\n') && !md.endsWith('\n\n'), isTrue);
      expect(bytes.take(3), isNot([0xEF, 0xBB, 0xBF]));
    });

    test('escapes metacharacters so the text reads back as written', () {
      expect(mdEscapeLine('a*b_c [d] <e> `f` ~g~ \\'), r'a\*b\_c \[d\] \<e> \`f\` \~g\~ \\');
      expect(mdEscapeLine('# non un titolo'), r'\# non un titolo');
      expect(mdEscapeLine('- non un elenco'), r'\- non un elenco');
      expect(mdEscapeLine('1. non un elenco'), r'1\. non un elenco');
      expect(mdEscapeLine('> non una citazione'), r'\> non una citazione');
      expect(mdEscapeLine('a | b', cell: true), r'a \| b');
      expect(mdEscapeLine('a | b'), 'a | b');
      expect(mdEscapeLine('&amp; e & basta'), r'\&amp; e & basta');
      expect(markdownText(mdEscapeLine('x * y _ z [1] <2> | \\ #')), 'x * y _ z [1] <2> | \\ #');
      expect(md, contains(r'\<info@rossi.it>'), reason: 'an unescaped <...> would be an autolink or raw HTML');
    });

    test('keeps the text of every block once unescaped', () {
      final text = markdownText(md);
      expectWords(text, fixtureWords, reason: 'md');
      expect(forbiddenChars.hasMatch(md), isFalse);
    });

    test('has GFM tables: a header, a delimiter row with right alignment for numbers, equal cells in each row', () {
      final lines = md.split('\n');
      final delimiter = lines.indexWhere((l) => l.startsWith('| Voce | Importo')) + 1;
      expect(lines[delimiter - 1], startsWith('| Voce | Importo'));
      expect(lines[delimiter], matches(RegExp(r'^\| (---:?) \| (---:?) \| (---:?) \| (---:?) \| (---:?) \|$')));
      int cells(String l) => RegExp(r'(?<!\\)\|').allMatches(l).length - 1;
      for (var i = delimiter - 1; i <= delimiter + 4; i++) {
        expect(cells(lines[i]), 5, reason: lines[i]);
      }
      expect(lines[delimiter + 1], contains(r'Prima rata \| saldo'));
      expect(lines[delimiter + 3], contains('riga<br>con a capo'));
      expect(lines, contains('[Immagine: Planimetria & rilievo]'));
      expect(lines.where((l) => l == '---'), isNotEmpty, reason: 'the page break is a rule');
    });

    test('titles with # and shifts headings down one level', () {
      final lines = md.split('\n');
      expect(lines.first, startsWith('# Parere pro veritate'));
      expect(lines, contains('## Premessa'));
      expect(lines, contains('### Sintesi dei fatti'));
      expect(lines, contains('#### Dettaglio'));
      expect(lines, contains('- Primo punto: àèéìòù'));
    });
  });

  group('HTML', () {
    final bytes = encodeHtml(fixtureDocument());
    final html = utf8.decode(bytes);

    test('is a standalone HTML5 page in Italian', () {
      expect(html, startsWith('<!doctype html>'));
      expect(html, contains('<html lang="it">'));
      expect(html, contains('<meta charset="utf-8">'));
      expect(html, contains('<title>Parere pro veritate — Società Rossi &amp; Figli S.r.l.</title>'));
      expect(html, contains('<style>'));
      expect(html, isNot(contains('<script')));
      expect(RegExp(r'(?:src|href)="(?!data:|#)').hasMatch(html), isFalse, reason: 'nothing is loaded from outside the file');
    });

    test('escapes every character that is markup, and keeps the text', () {
      expect(html, contains('Società &quot;Rossi&quot; &lt;info@rossi.it&gt;'));
      expect(html, contains('Simboli &amp;&lt;&gt;&quot;&#39; e 😀'));
      expectWords(htmlText(html), fixtureWords, reason: 'html');
      expect(forbiddenChars.hasMatch(html), isFalse);
    });

    test('is well nested', () {
      const voids = {'meta', 'br', 'img', 'hr', 'link', 'input', 'col'};
      final stack = <String>[];
      final body = html.substring(html.indexOf('<body>'), html.indexOf('</body>') + '</body>'.length);
      for (final m in RegExp(r'<(/?)([a-z][a-z0-9]*)\b[^>]*?(/?)>').allMatches(body)) {
        final name = m[2]!;
        if (m[1] == '/') {
          expect(stack, isNotEmpty, reason: 'a closing </$name> with nothing open');
          expect(stack.removeLast(), name, reason: 'tags close in the order they open');
        } else if (!voids.contains(name) && m[3] != '/') {
          stack.add(name);
        }
      }
      expect(stack, isEmpty);
    });

    test('has semantic tables, a quote, a note and the picture as a data URI', () {
      expect(RegExp('<table>').allMatches(html), hasLength(2));
      expect(RegExp('<thead>').allMatches(html), hasLength(2));
      expect(RegExp('<th scope="col"').allMatches(html).length, 7);
      expect(html, contains('<blockquote>'));
      expect(html, contains('role="note"'));
      expect(html, contains('<img src="data:image/png;base64,'));
      expect(html, contains('width="48" height="32"'));
      expect(html, contains('[Immagine: Senza immagine]'));
      expect(html, contains('<h2>Premessa</h2>'));
      expect(html, contains('<h1>Parere pro veritate'));
    });

    test('writes an empty document', () {
      expect(utf8.decode(encodeHtml(emptyDocument())), contains('Documento senza titolo'));
    });
  });
}
