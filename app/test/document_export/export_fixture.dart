import 'dart:io' show ZLibCodec;
import 'dart:typed_data';

import 'package:archive/archive.dart' show getCrc32;
import 'package:daylex/features/document/model/document.dart';

/// Characters that break a naive writer: XML and HTML metacharacters, quotes, accents, an emoji (two UTF-16 units),
/// and control characters no format can carry.
const specials = '&<>"\'';
const accents = 'àèéìòù ÀÈÉÌÒÙ perché città';
const emoji = '😀';

/// A PNG (a gradient) built from nothing, so the images in the fixtures are real and need no asset.
Uint8List gradientPng({int width = 48, int height = 32}) {
  final raw = BytesBuilder();
  for (var y = 0; y < height; y++) {
    raw.addByte(0); // filter: none
    for (var x = 0; x < width; x++) {
      raw
        ..addByte(x * 255 ~/ (width - 1))
        ..addByte(y * 255 ~/ (height - 1))
        ..addByte(160);
    }
  }
  Uint8List chunk(String type, List<int> data) {
    final body = [...type.codeUnits, ...data];
    final out = BytesBuilder()
      ..add(_u32(data.length))
      ..add(body)
      ..add(_u32(getCrc32(body)));
    return out.toBytes();
  }

  return (BytesBuilder()
        ..add(const [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A])
        ..add(chunk('IHDR', [..._u32(width), ..._u32(height), 8, 2, 0, 0, 0]))
        ..add(chunk('IDAT', ZLibCodec().encode(raw.toBytes())))
        ..add(chunk('IEND', const [])))
      .toBytes();
}

Uint8List _u32(int v) => Uint8List(4)..buffer.asByteData().setUint32(0, v);

final fixtureCreated = DateTime.utc(2026, 3, 12, 9, 30);
final fixtureUpdated = DateTime.utc(2026, 11, 20, 14, 5);

/// A document with every kind of block, two pages (the first a cover), two tables (typed cells among the text), a
/// picture, a placeholder picture, every awkward character, a word in bold, a paragraph with a look of its own, and a
/// header and a footer that print the document's details and page numbers on every page but the cover.
PaperDocument fixtureDocument() => PaperDocument(
  id: 'doc-1',
  projectId: 'project-1',
  metadata: DocMetadata(
    title: 'Parere pro veritate — Società Rossi & Figli S.r.l.',
    subtitle: 'Perché è così: $accents',
    author: 'Avv. Mario Bianchi',
    client: 'Società "Rossi" <info@rossi.it>',
    status: DocumentStatus.review,
    createdAt: fixtureCreated,
    updatedAt: fixtureUpdated,
  ),
  theme: const DocTheme(
    accent: 0xFF3B5BDB,
    brandName: 'Studio Bianchi',
    regions: {
      RegionSlot.header: PageRegion(left: '**{studio}**', right: '{sezione}', line: true),
      RegionSlot.footer: PageRegion(left: '{titolo} · {cliente}', right: 'Pagina {pagina} di {pagine}'),
    },
  ),
  pages: [
    const DocPage(
      id: 'page-1',
      title: 'Premessa',
      layout: PageLayout.cover,
      blocks: [
        HeadingBlock(id: 'b1', text: 'Premessa', level: 1),
        ParagraphBlock(id: 'b2', text: 'Perché è così? Sì: città, università. Simboli $specials e $emoji con un controllo\u0001 nascosto\u0008.'),
        HeadingBlock(id: 'b3', text: 'Sintesi dei fatti', level: 2),
        BulletListBlock(id: 'b4', items: ['Primo punto: àèéìòù', 'Secondo punto con & e <tag>', 'Terzo con "virgolette" e \'apici\'']),
        HeadingBlock(id: 'b5', text: 'Dettaglio', level: 3),
        MetricsBlock(
          id: 'b6',
          items: [
            Metric(label: 'Valore della causa', value: '€ 125.000,00', delta: '+12%'),
            Metric(label: 'Termine', value: '45 giorni', delta: '-5 giorni'),
          ],
        ),
        QuoteBlock(id: 'b7', text: 'La legge è uguale per tutti.', author: 'Aula di tribunale'),
        CalloutBlock(id: 'b8', title: 'Attenzione', text: 'Il termine scade il 12/03/2024: verificare.'),
      ],
    ),
    DocPage(
      id: 'page-2',
      title: 'Allegati e importi',
      blocks: [
        const HeadingBlock(id: 'b9', text: 'Importi e scadenze', level: 1),
        const TableBlock(
          id: 'b10',
          columns: ['Voce', 'Importo', 'Scadenza', 'Quota', 'Note'],
          rows: [
            ['Onorari', '€ 1.234,56', '12/03/2024', '18,5%', 'Prima rata | saldo'],
            ['Spese', 'EUR 99,00', '1 gennaio 2025', '5%', 'a|b; c "d"'],
            ['Rimborso', '-€ 10,50', '31/12/2025', '0%', 'riga\ncon a capo'],
            ['Totale', '1.234', '0123', '12,5', '=SUM(A1)'],
          ],
          caption: 'Importi in euro, IVA esclusa.',
        ),
        ParagraphBlock(id: 'b11', text: 'Fine della **tabella**.', style: BlockStyle.fromJson({'align': 'center', 'size': 14})),
        ImageBlock(id: 'b12', bytes: gradientPng(), caption: 'Planimetria & rilievo', height: 120),
        const ImageBlock(id: 'b13', caption: 'Senza immagine'),
        const HeadingBlock(id: 'b14', text: 'Elenco parti', level: 1),
        const TableBlock(
          id: 'b15',
          columns: ['Parte', 'Ruolo'],
          rows: [
            ['Rossi S.r.l.', 'Attore'],
            ['Verdi', 'Convenuto'],
          ],
        ),
      ],
    ),
  ],
);

/// Text every format must carry from the pages of [fixtureDocument]: nothing here may be lost, escaped or cut. The
/// details (title, client) are not here: like the PDF, a file prints them only where its header or footer says so.
const fixtureWords = [
  'Premessa',
  'Perché è così? Sì: città, università. Simboli &<>"\' e 😀 con un controllo nascosto.',
  'Sintesi dei fatti',
  'Primo punto: àèéìòù',
  'Secondo punto con & e <tag>',
  'Terzo con "virgolette" e \'apici\'',
  'Dettaglio',
  'Valore della causa',
  '€ 125.000,00',
  '+12%',
  'La legge è uguale per tutti.',
  'Aula di tribunale',
  'Attenzione',
  'Il termine scade il 12/03/2024: verificare.',
  'Importi e scadenze',
  'Onorari',
  '€ 1.234,56',
  '12/03/2024',
  '18,5%',
  'Prima rata | saldo',
  'a|b; c "d"',
  'con a capo',
  'Importi in euro, IVA esclusa.',
  'Fine della tabella.',
  'Elenco parti',
  'Rossi S.r.l.',
  'Convenuto',
];

/// What the header and the footer of [fixtureDocument] print on its second page, the emphasis markers gone.
const fixtureRegionWords = [
  'Studio Bianchi',
  'Allegati e importi',
  'Parere pro veritate — Società Rossi & Figli S.r.l. · Società "Rossi" <info@rossi.it>',
];

/// A document with nothing in it.
PaperDocument emptyDocument() => PaperDocument(
  id: 'empty',
  projectId: 'project-1',
  metadata: DocMetadata(title: '', createdAt: fixtureCreated, updatedAt: fixtureUpdated),
);

/// A document of text only, no table.
PaperDocument textOnlyDocument() => PaperDocument(
  id: 'text',
  projectId: 'project-1',
  metadata: DocMetadata(title: 'Solo testo', createdAt: fixtureCreated, updatedAt: fixtureUpdated),
  pages: const [
    DocPage(
      id: 'p',
      blocks: [
        HeadingBlock(id: 'h', text: 'Titolo del paragrafo'),
        ParagraphBlock(id: 'a', text: 'Primo paragrafo; con punto e virgola.'),
        ParagraphBlock(id: 'b', text: 'Secondo "paragrafo"\ncon a capo.'),
        ParagraphBlock(id: 'c', text: '=1+1'),
        ParagraphBlock(id: 'd', text: ''),
      ],
    ),
  ],
);

/// A document whose headings make the awkward sheet names: forbidden characters, too long, repeated, reserved.
/// An empty heading gives a table with no heading before it.
PaperDocument sheetNamesDocument(List<String> headings) => PaperDocument(
  id: 'sheets',
  projectId: 'project-1',
  metadata: DocMetadata(title: 'Fogli', createdAt: fixtureCreated, updatedAt: fixtureUpdated),
  pages: [
    DocPage(
      id: 'p',
      blocks: [
        for (final (i, h) in headings.indexed) ...[
          if (h.isNotEmpty) HeadingBlock(id: 'h$i', text: h),
          TableBlock(
            id: 't$i',
            columns: const ['A', 'B'],
            rows: [
              ['$i', 'x'],
            ],
          ),
        ],
      ],
    ),
  ],
);
