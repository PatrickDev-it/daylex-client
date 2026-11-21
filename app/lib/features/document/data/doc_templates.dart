import '../model/document.dart';

// Short constructors keep the templates readable.
HeadingBlock h1(String t) => HeadingBlock(id: newId(), text: t);
HeadingBlock h2(String t) => HeadingBlock(id: newId(), text: t, level: 2);
HeadingBlock h3(String t) => HeadingBlock(id: newId(), text: t, level: 3);
ParagraphBlock p(String t) => ParagraphBlock(id: newId(), text: t);
BulletListBlock bullets(List<String> items) =>
    BulletListBlock(id: newId(), items: items);
CalloutBlock callout(String title, [String text = '']) =>
    CalloutBlock(id: newId(), title: title, text: text);
QuoteBlock quote(String text, [String author = '']) =>
    QuoteBlock(id: newId(), text: text, author: author);
MetricsBlock metrics(List<(String, String, String)> items) => MetricsBlock(
  id: newId(),
  items: [for (final (l, v, d) in items) Metric(label: l, value: v, delta: d)],
);
TableBlock table(List<String> columns, List<List<String>> rows, [String c = '']) =>
    TableBlock(id: newId(), columns: columns, rows: rows, caption: c);

DocPage page(String title, List<DocBlock> blocks, [PageLayout? layout]) =>
    DocPage(
      id: newId(),
      title: title,
      layout: layout ?? PageLayout.standard,
      blocks: blocks,
    );

// Accents of the templates, all from [kDocAccentPalette].
const _blue = 0xFF3B5BDB;
const _violet = 0xFF7C3AED;
const _teal = 0xFF0F766E;

/// A template leaves the author empty: it is the lawyer's to fill.
DocMetadata _meta(String title, {String subtitle = '', String client = '', String author = ''}) {
  final now = DateTime.now();
  return DocMetadata(
    title: title,
    subtitle: subtitle,
    client: client,
    author: author,
    createdAt: now,
    updatedAt: now,
  );
}

// ---------------------------------------------------------------------------
// Templates
// ---------------------------------------------------------------------------

class DocTemplate {
  const DocTemplate({
    required this.id,
    required this.name,
    required this.description,
    required this.pageCount,
    required this.accent,
    required this.build,
  });

  final String id;
  final String name;
  final String description;
  final int pageCount;
  final int accent;

  /// A new document in the studio's [style] (rfc/055), with the template's accent.
  final PaperDocument Function(String projectId, [DocTheme style]) build;
}

PaperDocument _fromTemplate(
  String projectId,
  DocTheme style,
  String title,
  int accent,
  List<DocPage> pages, {
  String subtitle = '',
}) => PaperDocument(
  id: newId(),
  projectId: projectId,
  theme: style.copyWith(accent: accent),
  metadata: _meta(title, subtitle: subtitle),
  pages: pages,
);

/// The opening of a document without a header: its title, large, and what follows it.
List<DocBlock> _opening(String title, String subtitle, String note) => [
  HeadingBlock(id: newId(), text: title, style: BlockStyle.of({'size': 30, 'align': 'left', 'spaceAfter': 10})),
  ParagraphBlock(id: newId(), text: subtitle, style: BlockStyle.of({'size': 14, 'spaceAfter': 28})),
  p(note),
];

final docTemplates = <DocTemplate>[
  DocTemplate(
    id: 'blank',
    name: 'Documento vuoto',
    description: 'Una pagina vuota da cui iniziare.',
    pageCount: 1,
    accent: kDefaultDocAccent,
    build: (projectId, [style = DocTheme.legal]) => _fromTemplate(projectId, style, 'Documento senza titolo', kDefaultDocAccent, [
      page('Pagina 1', [h1('Documento senza titolo'), p('Inizia a scrivere oppure chiedi all’agente di preparare questa pagina.')]),
    ]),
  ),
  DocTemplate(
    id: 'proposal',
    name: 'Proposta di consulenza',
    description: 'Apertura, sintesi, metodo, compensi e prossimi passi.',
    pageCount: 5,
    accent: _blue,
    build: (projectId, [style = DocTheme.legal]) => _fromTemplate(
      projectId,
      style,
      'Proposta di consulenza',
      _blue,
      subtitle: 'Ambito, metodo e compensi',
      [
        page('Proposta', _opening('Proposta di consulenza', 'Ambito, metodo e compensi', 'Preparato per il gruppo di lavoro del cliente.'), PageLayout.cover),
        page('Sintesi', [h1('Sintesi della proposta'), p('Descrivi il problema del cliente e il risultato previsto.'), metrics([('Impatto', '—', ''), ('Tempi', '8 settimane', ''), ('Investimento', '—', '')])]),
        page('Metodo', [h1('Il nostro metodo'), h3('Analisi'), p('Colloqui, analisi dei dati e criteri di risultato.'), h3('Progettazione'), p('Alternative, compromessi e piano proposto.'), h3('Attuazione'), p('Supporto operativo e consegna del lavoro.')], PageLayout.twoColumn),
        page('Compensi', [h1('Investimento'), table(['Fase', 'Durata', 'Compenso'], [['Analisi', '2 settimane', '—'], ['Progettazione', '3 settimane', '—'], ['Attuazione', '3 settimane', '—']])]),
        page('Prossimi passi', [h1('Prossimi passi'), bullets(['Confermare l’ambito', 'Firmare la lettera di incarico', 'Riunione di avvio'])]),
      ],
    ),
  ),
  DocTemplate(
    id: 'report',
    name: 'Relazione trimestrale',
    description: 'Indicatori, risultati principali, dati economici e prospettive.',
    pageCount: 4,
    accent: _violet,
    build: (projectId, [style = DocTheme.legal]) => _fromTemplate(
      projectId,
      style,
      'Relazione trimestrale',
      _violet,
      subtitle: 'Valutazione dei risultati',
      [
        page('Relazione', _opening('Relazione trimestrale', 'Valutazione dei risultati', 'Edizione per il consiglio di amministrazione e la direzione.'), PageLayout.cover),
        page('Risultati principali', [h1('Il trimestre in sintesi'), metrics([('Ricavi', '—', ''), ('Clienti', '—', ''), ('Clienti persi', '—', '')]), h2('Risultati principali'), bullets(['Primo risultato', 'Secondo risultato', 'Terzo risultato'])]),
        page('Dati economici', [h1('Dati economici'), table(['Indicatore', '1° trimestre', '2° trimestre', '3° trimestre'], [['Ricavi', '—', '—', '—'], ['Margine lordo', '—', '—', '—'], ['Costi operativi', '—', '—', '—']])]),
        page('Prospettive', [h1('Prospettive'), p('Priorità e rischi per il prossimo trimestre.'), callout('Rischio principale', 'Descrivi il rischio principale e le misure per ridurlo.')]),
      ],
    ),
  ),
  DocTemplate(
    id: 'onepager',
    name: 'Scheda di presentazione',
    description: 'Una pagina curata per presentare un prodotto o servizio.',
    pageCount: 1,
    accent: _teal,
    build: (projectId, [style = DocTheme.legal]) => _fromTemplate(projectId, style, 'Scheda di presentazione', _teal, [
      page('Panoramica', [h1('Nome del prodotto'), p('Una frase che spiega il valore della proposta.'), metrics([('Indicatore', '—', ''), ('Indicatore', '—', ''), ('Indicatore', '—', '')]), h2('Perché è rilevante'), bullets(['Primo beneficio', 'Secondo beneficio', 'Terzo beneficio'])]),
    ]),
  ),
];
