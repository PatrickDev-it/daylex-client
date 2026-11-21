import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:daylex/features/agent/domain/document_tools.dart';
import 'package:daylex/features/document/model/document.dart';
import 'package:daylex/features/document/model/inline.dart';

/// The style of rfc/055: what the agent may set (the tools' schema and the fields of a style and of the page, generated
/// from the server) and what the app reads (style.dart) are two declarations of one rule, so each value the server
/// names is tried against the app.
void main() {
  Map<String, dynamic> properties(String tool, [List<String> path = const []]) {
    var node = toolSpec(tool)!.parameters;
    for (final key in path) {
      node = ((node['properties'] as Map)[key] as Map).cast<String, dynamic>();
    }
    return (node['properties'] as Map).cast<String, dynamic>();
  }

  final refused = throwsA(isA<StyleException>());

  group('the tools and the style read the same values', () {
    final fields = styleFieldSpecs['block']!;

    test('the server names the fields the style reads, in its order', () {
      expect(fields.keys, blockStyleFields);
    });

    for (final MapEntry(:key, :value) in fields.entries) {
      test('$key: what its schema allows is read, what it does not is refused', () {
        BlockStyle set(Object v) => BlockStyle.empty.patch({key: v});
        switch (value) {
          case {'type': 'number', 'minimum': final num min, 'maximum': final num max}:
            expect(set(min).toJson()[key], min.toDouble());
            expect(set(max).toJson()[key], max.toDouble());
            expect(() => set(min - 0.01), refused);
            expect(() => set(max + 0.01), refused);
            expect(() => set('$max'), refused);
          case {'type': 'boolean'}:
            expect(set(true).toJson()[key], isTrue);
            expect(set(false).toJson()[key], isFalse);
            expect(() => set('true'), refused);
          case {'type': 'string', 'enum': final List values}:
            for (final v in values) {
              expect(set(v as Object).toJson()[key], v);
            }
            expect(() => set('altro'), throwsA(predicate((e) => '$e'.contains(values.join(', ')))));
          case {'type': 'string'}:
            expect(set('#1F3A5F').toJson()[key], '#1f3a5f');
            expect(set('1f3a5f').toJson()[key], '#1f3a5f');
            for (final v in ['accent', 'accent/1', 'accent/100', 'none']) {
              expect(set(v).toJson()[key], v);
            }
            for (final v in ['blu', 'accent/0', 'accent/101', '#12345', '#1f3a5g']) {
              expect(() => set(v), refused, reason: v);
            }
          default:
            fail('no rule for the schema of $key: $value');
        }
      });
    }

    test('set_style names the bases, the server the page fields the page reads', () {
      final style = properties(ToolNames.setStyle);
      expect((style['base'] as Map)['enum'], [for (final b in StyleBase.values) b.name]);
      final page = styleFieldSpecs['page']!;
      expect(page.keys, ['orientation', for (final side in PageSetup.sides) 'margins.$side', 'header', 'footer']);
      expect((page['orientation'] as Map)['enum'], [for (final o in PageOrientation.values) o.name]);
      for (final MapEntry(:key, :value) in page.entries.where((e) => e.key != 'orientation')) {
        final (min, max) = ((value as Map)['minimum'] as num, value['maximum'] as num);
        Object patch(num v) => key.startsWith('margins.')
            ? {
                'margins': {key.substring('margins.'.length): v},
              }
            : {key: v};
        expect(PageSetup.empty.patch(patch(max)).isEmpty, isFalse);
        expect(PageSetup.empty.patch(patch(min)).isEmpty, isFalse);
        expect(() => PageSetup.empty.patch(patch(max + 0.01)), refused, reason: key);
        expect(() => PageSetup.empty.patch(patch(min - 0.01)), refused, reason: key);
      }
    });

    test('set_header_footer names the regions the theme keeps', () {
      final region = properties(ToolNames.setHeaderFooter)['region'] as Map;
      expect(region['enum'], [for (final s in RegionSlot.values) s.name]);
    });
  });

  group('BlockStyle', () {
    test('a patch sets fields, a null field goes back to what is under it', () {
      final style = BlockStyle.empty.patch({'bold': true, 'size': 12});
      expect(style.patch({'size': null}).toJson(), {'bold': true});
      expect(style.patch({'bold': null, 'size': null}), BlockStyle.empty);
    });

    test('an unknown field is refused with the fields it could be', () {
      expect(
        () => BlockStyle.empty.patch({'fontSize': 12}),
        throwsA(predicate((e) => '$e'.contains('"fontSize" non è un campo di stile') && '$e'.contains('lineHeight'))),
      );
      expect(() => BlockStyle.empty.patch('grassetto'), refused);
    });

    test('a saved style keeps what it can read and leaves out the rest', () {
      final saved = BlockStyle.fromJson({'bold': true, 'size': 100, 'colour': '#000000', 'align': 'middle'});
      expect(saved.toJson(), {'bold': true});
      expect(BlockStyle.fromJson('grassetto'), BlockStyle.empty);
    });

    test('over takes from under only what it leaves unset', () {
      final over = BlockStyle.of({'bold': true}).over(BlockStyle.of({'bold': false, 'size': 10}));
      expect(over.toJson(), {'bold': true, 'size': 10.0});
    });
  });

  group('PageSetup', () {
    test('a patch changes one margin, null margins give them all back to the base', () {
      final page = PageSetup.empty.patch({
        'margins': {'top': 3, 'left': 2},
      });
      expect(page.patch({
        'margins': {'top': 4},
      }).toJson(), {
        'margins': {'top': 4.0, 'left': 2.0},
      });
      expect(page.patch({'margins': null}).isEmpty, isTrue);
    });

    test('an unknown margin is refused, a saved one is left out', () {
      expect(() => PageSetup.empty.patch({'margins': {'alto': 2}}), refused);
      expect(PageSetup.fromJson({'margins': {'alto': 2, 'top': 3}, 'orientation': 'diagonal'}).toJson(), {
        'margins': {'top': 3.0},
      });
    });
  });

  group('DocTheme', () {
    const theme = DocTheme(base: StyleBase.legal);

    test('set_style changes the base, one field of a role, and restores a role or all of them', () {
      final styled = theme.patchStyle({
        'base': 'report',
        'styles': {
          'body': {'size': 13},
          'quote': {'italic': false},
        },
      });
      expect(styled.base, StyleBase.report);
      expect(styled.styles[StyleRole.body]!.toJson(), {'size': 13.0});
      final restored = styled.patchStyle({
        'styles': {'body': null},
      });
      expect(restored.styles.keys, [StyleRole.quote]);
      expect(styled.patchStyle({'styles': null}).styles, isEmpty);
    });

    test('a role emptied field by field is no longer set', () {
      final styled = theme.patchStyle({
        'styles': {
          'body': {'size': 13},
        },
      });
      expect(styled.patchStyle({
        'styles': {
          'body': {'size': null},
        },
      }).styles.containsKey(StyleRole.body), isFalse);
    });

    test('an unknown base, role or accent is refused', () {
      expect(() => theme.patchStyle({'base': 'elegante'}), refused);
      expect(
        () => theme.patchStyle({
          'styles': {'titolo': {'bold': true}},
        }),
        throwsA(predicate((e) => '$e'.contains('"titolo" non è un ruolo'))),
      );
      expect(() => theme.patchStyle({'accent': 'blu'}), refused);
    });

    test('a region set empty hides the base\'s; a region given back is the base\'s again', () {
      final hidden = theme.withRegion(RegionSlot.footer, const PageRegion());
      expect(DocStyles(hidden).region(RegionSlot.footer).isEmpty, isTrue);
      final back = hidden.withRegion(RegionSlot.footer, null);
      expect(DocStyles(back).region(RegionSlot.footer).center, '{pagina}');
    });

    test('a first page the document does not set repeats the others', () {
      final styles = DocStyles(theme.withRegion(RegionSlot.header, const PageRegion(right: '{sezione}')));
      expect(styles.region(RegionSlot.firstHeader).right, '{sezione}');
      expect(styles.region(RegionSlot.firstFooter).center, '{pagina}', reason: "the legal base's footer");
    });

    test('a header written on a legal page clears its line, and the text clears the header', () {
      // A letterhead drew its line through the descenders of its last row, with the title 7 pt below it.
      final styles = DocStyles(theme);
      expect(styles.region(RegionSlot.header).isEmpty, isTrue, reason: 'the legal base shows no header');
      for (final slot in [RegionSlot.header, RegionSlot.firstHeader]) {
        final s = styles.resolve(styles.regionStyle(styles.region(slot)));
        expect((s.padding, s.spaceAfter), (6, 12), reason: slot.name);
      }
      final footer = styles.resolve(styles.regionStyle(styles.region(RegionSlot.footer)));
      expect((footer.padding, footer.spaceBefore), (6, 12));
    });

    test('a saved theme round-trips, and one from before rfc/055 reads as a report', () {
      final styled = theme
          .patchStyle({
            'page': {'orientation': 'landscape'},
            'styles': {
              'heading1': {'color': 'accent/40'},
            },
          })
          .withRegion(RegionSlot.firstHeader, const PageRegion(center: '**Studio**', line: true));
      final json = jsonDecode(jsonEncode(styled.toJson())) as Map<String, dynamic>;
      expect(DocTheme.fromJson(json).toJson(), styled.toJson());
      expect(DocTheme.fromJson({'accent': '#1f3a5f'}).base, StyleBase.report);
    });
  });

  group('RegionLogo', () {
    final data = base64Encode([137, 80, 78, 71]);

    test('a height that is not a number reads as the default', () {
      expect(RegionLogo.fromJson({'data': data, 'height': 'alto'})!.height, 40);
      expect(RegionLogo.fromJson({'data': data, 'height': true})!.height, 40);
    });

    test('a height is kept between 8 and 200, an alignment it does not know reads as left', () {
      expect(RegionLogo.fromJson({'data': data, 'height': 900})!.height, 200);
      expect(RegionLogo.fromJson({'data': data, 'height': 1})!.height, 8);
      expect(RegionLogo.fromJson({'data': data, 'align': 'middle'})!.align, BlockAlign.left);
    });

    test('a logo without readable data is no logo', () {
      expect(RegionLogo.fromJson({'data': '%%%'}), isNull);
      expect(RegionLogo.fromJson({'height': 30}), isNull);
    });
  });

  group('fillPlaceholders', () {
    const values = {'titolo': 'Atto', 'cliente': '', 'pagina': '3'};

    test('fills what it knows and keeps what it does not', () {
      expect(fillPlaceholders('{titolo} – pag. {pagina} {ignoto}', values), 'Atto – pag. 3 {ignoto}');
    });

    test('an empty value takes its separator with it', () {
      expect(fillPlaceholders('{titolo} · {cliente}', values), 'Atto');
      expect(fillPlaceholders('{cliente} · {titolo}', values), 'Atto');
      expect(fillPlaceholders('{titolo}\n{cliente} · {pagina}', values), 'Atto\n3');
    });
  });

  group('inline emphasis', () {
    test('reads bold, italic and underline, nested', () {
      expect(parseInline('a **b** c'), const [InlineRun('a '), InlineRun('b', bold: true), InlineRun(' c')]);
      expect(parseInline('**uno *due* tre**'), const [
        InlineRun('uno ', bold: true),
        InlineRun('due', bold: true, italic: true),
        InlineRun(' tre', bold: true),
      ]);
      expect(parseInline('__visto__'), const [InlineRun('visto', underline: true)]);
    });

    test('leaves as text what a lawyer writes without meaning emphasis', () {
      for (final text in [
        'Firma: ________',
        '***',
        'nome_del_file.pdf',
        '2 * 3 * 4',
        '**non chiuso',
        'art. 5* e 6*',
      ]) {
        expect(parseInline(text), [InlineRun(text)], reason: text);
      }
    });

    test('an escape writes the marker itself', () {
      expect(parseInline(r'\*letterale\*'), const [InlineRun('*letterale*')]);
      expect(plainInline(r'**a** \_b'), 'a _b');
    });

    test('a cut closes the emphasis open at it and opens it again after', () {
      expect(splitInline('**uno due**', 5), ('**uno**', '**due**'));
      expect(splitInline('a *b c* d', 4), ('a *b*', '*c* d'));
    });
  });

  group('a document saved before rfc/055', () {
    Map<String, dynamic> saved({String? base}) => {
      'id': 'd',
      'metadata': {
        'title': 'Ricorso',
        'subtitle': 'TAR Lazio',
        'client': 'Rossi',
        'createdAt': '2025-03-12T09:30:00Z',
        'updatedAt': '2025-03-12T09:30:00Z',
      },
      'theme': {'accent': '#1f3a5f', 'brandName': 'Studio Neri', 'base': ?base},
      'pages': [
        {
          'id': 'c',
          'title': 'Frontespizio',
          'layout': 'cover',
          'blocks': [
            {'id': 'n', 'type': 'paragraph', 'text': 'Nota'},
          ],
        },
        {
          'id': 's',
          'title': 'Fatto',
          'layout': 'standard',
          'blocks': [
            {'id': 'f', 'type': 'paragraph', 'text': 'Il fatto.'},
          ],
        },
      ],
    };

    test('gets on its cover page, as blocks, what the cover used to draw', () {
      final doc = PaperDocument.fromJson(saved());
      final cover = doc.pages.first;
      expect(cover.blocks.map((b) => b.id), ['c-studio', 'c-section', 'c-title', 'c-subtitle', 'c-facts', 'n']);
      expect((cover.blocks[2] as HeadingBlock).text, 'Ricorso');
      expect((cover.blocks[4] as ParagraphBlock).text, startsWith('Destinatario: **Rossi**  ·  Data: **'));
      expect(doc.pages[1].blocks.map((b) => b.id), ['f'], reason: 'a standard page is left as it was');
      expect(jsonEncode(PaperDocument.fromJson(saved()).toJson()), jsonEncode(doc.toJson()), reason: 'the same every load');
    });

    test('once saved with its base, it is not migrated again', () {
      final doc = PaperDocument.fromJson(saved());
      final again = PaperDocument.fromJson(jsonDecode(jsonEncode(doc.toJson())) as Map<String, dynamic>);
      expect(again.pages.first.blocks.length, doc.pages.first.blocks.length);
      expect(PaperDocument.fromJson(saved(base: 'report')).pages.first.blocks.map((b) => b.id), ['n']);
    });
  });
}
