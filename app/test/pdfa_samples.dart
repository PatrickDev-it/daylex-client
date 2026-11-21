import 'dart:io';
import 'dart:typed_data';

import 'package:daylex/features/document/data/doc_templates.dart';
import 'package:daylex/features/document/model/document.dart';

/// The documents the PDF/A-1b checks render: one per thing that has gone wrong in a PDF/A file before.
/// Shared by `pdfa_test.dart` (structure, in the suite) and the veraPDF run (`PDFA_SAMPLES_DIR`).

Uint8List _fixture(String name) =>
    File('test/fixtures/pdfa/$name').readAsBytesSync();

DocMetadata _meta({
  String title = 'Atto di citazione',
  String author = 'Avv. Maria Rossi',
}) {
  final now = DateTime.utc(2026, 11, 20, 9, 30);
  return DocMetadata(
    title: title,
    subtitle: 'Tribunale di Milano, sezione quinta',
    client: 'Società Alfa S.r.l.',
    author: author,
    createdAt: now,
    updatedAt: now,
  );
}

PaperDocument _doc(List<DocPage> pages, {DocMetadata? metadata}) =>
    PaperDocument(
      id: 'pdfa-sample',
      projectId: 'pdfa',
      theme: const DocTheme(accent: 0xFF3B5BDB, brandName: 'Studio Rossi'),
      metadata: metadata ?? _meta(),
      pages: pages,
    );

ImageBlock _image(String name, String caption) => ImageBlock(
  id: newId(),
  bytes: _fixture(name),
  caption: caption,
  height: 120,
);

/// Every block kind, on the four layouts, with the images PDF/A is strictest about: a PNG with
/// transparency, and RGB, grey and CMYK JPEGs.
PaperDocument everyBlockDocument() => _doc([
  page('Frontespizio', [
    p('Atto introduttivo del giudizio, redatto ai sensi dell’art. 163 c.p.c.'),
  ], PageLayout.cover),
  page('Fatti', [
    h1('Esposizione dei fatti'),
    h2('Il contratto'),
    h3('Premessa'),
    p(
      'Con scrittura privata del 12 marzo 2024 le parti concordavano la fornitura '
      'di macchinari per un corrispettivo di € 48.500,00, oltre IVA.',
    ),
    bullets([
      'Consegna entro il 30 giugno 2024',
      'Pagamento in tre rate: 30%, 30%, 40%',
      'Garanzia di dodici mesi sul funzionamento',
    ]),
    table(
      ['Voce', 'Importo', 'Scadenza'],
      [
        ['Acconto', '€ 14.550,00', '31/03/2024'],
        ['Seconda rata', '€ 14.550,00', '30/06/2024'],
        ['Saldo', '€ 19.400,00', '30/09/2024'],
      ],
      'Piano dei pagamenti',
    ),
    metrics([('Importo', '€ 48.500', '+0%'), ('Ritardo', '112 gg', '-3%')]),
  ]),
  page('Prove', [
    h2('Documenti'),
    quote(
      'La consegna non è avvenuta nei termini pattuiti.',
      'Verbale di causa',
    ),
    callout('Termine perentorio', 'Il deposito scade il 15 gennaio 2027.'),
    _image('alpha.png', 'Planimetria con sfondo trasparente'),
    _image('photo.jpg', 'Fotografia dei macchinari'),
  ]),
  page('Allegati', [
    h2('Immagini'),
    _image('gray.jpg', 'Scansione in scala di grigi'),
    _image('cmyk.jpg', 'Logo da tipografia (CMYK)'),
    ImageBlock(id: newId(), caption: 'Immagine non ancora caricata'),
  ]),
  page('Due colonne', [
    h1('Sintesi'),
    p('Primo punto della sintesi, con àèéìòù e ÀÈÉÌÒÙ. ' * 4),
    h2('Secondo'),
    p('Secondo punto della sintesi. ' * 6),
    bullets(['uno', 'due', 'tre']),
  ], PageLayout.twoColumn),
  page('Premium', [
    h1('Conclusioni'),
    p('Si chiede l’accoglimento delle conclusioni rassegnate in atti.'),
    metrics([('Valore', '€ 48.500', '')]),
  ], PageLayout.premium),
]);

/// Italian accents and punctuation, and symbols the fonts do not all have.
PaperDocument accentsDocument() => _doc([
  page('Caratteri', [
    h1('àèéìòù ÀÈÉÌÒÙ çñü'),
    p('Perché “virgolette” e ‘apici’, trattino – lungo — e ellissi…'),
    p('Simboli: § ¶ € £ ° ² ³ ½ © ® ™ × ÷ ± ≤ ≥ → ✓'),
    p('Emoji: ⚖ 😀 e caratteri CJK 法律'),
  ]),
], metadata: _meta(title: 'Perché “è” così: àèéìòù – € & <test>'));

/// Twenty text pages, the size of a long pleading.
PaperDocument longDocument({int pages = 20}) => _doc([
  page('Frontespizio', [p('Memoria difensiva')], PageLayout.cover),
  for (var i = 1; i < pages; i++)
    page('Sezione $i', [
      h2('Motivo $i'),
      p(
        'Il ricorrente deduce la violazione dell’articolo $i della legge, '
                'poiché l’amministrazione non ha motivato il provvedimento impugnato. ' *
            3,
      ),
      bullets(['Primo rilievo $i', 'Secondo rilievo $i', 'Terzo rilievo $i']),
      table(
        ['Atto', 'Data', 'Esito'],
        [
          for (var r = 0; r < 5; r++)
            ['Atto ${i}0$r', '1$r/0${r + 1}/2026', 'Depositato'],
        ],
      ),
    ]),
]);

/// What the lawyer's file has none of: no title, no author.
PaperDocument untitledDocument() => _doc([
  page('Bozza', [p('Testo.')]),
], metadata: _meta(title: '', author: ''));

/// A document per name, to render and validate.
Map<String, PaperDocument> pdfaSamples() => {
  'every-block': everyBlockDocument(),
  'accents-symbols': accentsDocument(),
  'long-20-pages': longDocument(),
  'untitled': untitledDocument(),
};
