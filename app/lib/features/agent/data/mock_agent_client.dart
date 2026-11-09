import 'dart:async';
import 'dart:convert';

import '../../document/model/document.dart';
import '../domain/agent_protocol.dart';
import '../domain/document_tools.dart';

/// Offline stand-in for the model server.
///
/// It recognises a handful of intents with keyword rules and answers with the
/// same event stream (text deltas + tool calls) the real server sends, so
/// the whole UI → tools → document → PDF pipeline can be exercised without a
/// model. Only tests and `PAPERAGENT_MOCK=1` use it; a lawyer never gets its answers.
class MockAgentClient implements AgentClient {
  MockAgentClient({this.speed = 1.0});

  /// Multiplier for simulated latency; 0 disables delays (tests).
  final double speed;

  @override
  String get displayName => 'Mock agent';

  @override
  bool get isMock => true;

  @override
  String? get problem => null;

  var _callSeq = 0;

  /// Tool results reported back by the app, newest last (useful in tests).
  final toolResults = <Map<String, dynamic>>[];

  @override
  Future<void> submitToolResult(
    String sessionId,
    String callId,
    Map<String, dynamic> result,
  ) async => toolResults.add({'callId': callId, ...result});

  /// No case file offline: attachments travel with each run.
  @override
  Future<AttachmentCard?> uploadAttachment(
    String sessionId,
    AgentAttachment attachment,
  ) async => null;

  @override
  Future<void> deleteAttachment(String sessionId, String name) async {}

  @override
  Future<void> deleteCaseFile(String sessionId) async {}

  @override
  Future<SourceDocument?> readSource(
    String sessionId,
    String name,
    int page, {
    bool includeOriginal = true,
  }) async => null;

  @override
  Stream<AgentEvent> run(AgentRequest request) async* {
    final prompt = request.prompt.trim();
    final lower = prompt.toLowerCase();
    final it = _isItalian(lower);
    final doc = request.document;

    yield it
        ? const AgentStatusEvent('Sto analizzando la richiesta')
        : const AgentStatusEvent('Thinking', quiet: true);
    await _pause(450);

    final plan = _plan(prompt, lower, it, doc, request);
    for (final step in plan) {
      switch (step) {
        case _Say(:final text):
          yield* _stream(text);
        case _Call(:final name, :final args):
          yield AgentToolCall(
            id: 'call_${_callSeq++}',
            name: name,
            arguments: args,
          );
          await _pause(350);
        case _Ui(:final component, :final props):
          yield AgentUiEvent(component, props);
          await _pause(200);
        case _Status(:final label):
          yield AgentStatusEvent(label);
          await _pause(300);
      }
    }
    yield const AgentDone();
  }

  // -- planning ---------------------------------------------------------------

  List<_Step> _plan(
    String prompt,
    String lower,
    bool it,
    PaperDocument? doc,
    AgentRequest request,
  ) {
    final t = _Lang(it);

    final wantsCreate =
        _Intent.createVerb.hasMatch(lower) &&
        _Intent.createNoun.hasMatch(lower) &&
        !_Intent.addVerb.hasMatch(lower);

    if (wantsCreate || doc == null) {
      if (!wantsCreate) {
        return [
          _Say(
            t(
              'No document is open yet. Try **"Create a 6-page consulting proposal for Acme Corp"**, or open one from the sidebar.',
              'Nessun documento aperto. Prova con **"Crea una proposta di consulenza di 6 pagine per Acme Corp"**, oppure aprine uno dalla barra laterale.',
            ),
          ),
        ];
      }
      return _create(prompt, lower, it);
    }

    final page = _pageNumber(lower, doc, request.currentPage);

    if (_Intent.outline.hasMatch(lower)) {
      return _outline(doc, it);
    }

    if (_Intent.json.hasMatch(lower)) {
      final target = doc.pages[page - 1];
      final json = const JsonEncoder.withIndent('  ')
          .convert(target.toJson()..remove('id'));
      return [
        _Say(
          t(
            'This is how page $page is stored: typed blocks, never PDF bytes. The model edits these through tools.\n\n```json\n$json\n```',
            'Ecco come è salvata la pagina $page: blocchi tipizzati, mai byte PDF. Il modello li modifica tramite i tool.\n\n```json\n$json\n```',
          ),
        ),
      ];
    }

    if (_Intent.roi.hasMatch(lower)) {
      const table =
          '| Scenario | Gain | ROI |\n|---|---:|---:|\n| Conservative | €400k | 82% |\n| Expected | €620k | 182% |\n| Ambitious | €900k | 309% |';
      const tableIt =
          '| Scenario | Guadagno | ROI |\n|---|---:|---:|\n| Prudente | €400k | 82% |\n| Atteso | €620k | 182% |\n| Ambizioso | €900k | 309% |';
      const formula =
          r'$$ROI = \frac{\text{Gain} - \text{Cost}}{\text{Cost}} \times 100\%$$';
      const example =
          r'$$ROI = \frac{620 - 220}{220} \times 100\% \approx 182\%$$';
      return [
        _Say(
          t(
            'Return on investment compares the gain with what it costs:\n\n$formula\n\nWith an illustrative **€620k** gain on a **€220k** programme:\n\n$example\n\n$table',
            'Il ritorno sull\'investimento confronta il guadagno con il costo:\n\n$formula\n\nCon un guadagno indicativo di **€620k** su un programma da **€220k**:\n\n$example\n\n$tableIt',
          ),
        ),
      ];
    }

    if (_Intent.show.hasMatch(lower)) {
      return [
        _Say(
          t(
            'Here is page $page:\n\n```ui:pdf_page\n{"page": $page}\n```\n\nAsk me to change anything on it.',
            'Ecco la pagina $page:\n\n```ui:pdf_page\n{"page": $page}\n```\n\nChiedimi pure di modificarla.',
          ),
        ),
      ];
    }

    if (_Intent.translate.hasMatch(lower)) {
      return [
        _Say(
          t(
            'Translation needs the real language model, which is not connected in this offline build. Everything else in the pipeline is ready for it.',
            'La traduzione richiede il modello linguistico reale, che in questa build offline non è collegato. Il resto della pipeline è già pronto.',
          ),
        ),
      ];
    }

    if (_Intent.export.hasMatch(lower)) {
      return [
        _Say(
          t(
            'Exporting **${doc.title}** as PDF.',
            'Esporto **${doc.title}** in PDF.',
          ),
        ),
        const _Call(ToolNames.exportPdf, {}),
      ];
    }

    if (_Intent.deleteVerb.hasMatch(lower) &&
        _Intent.pageNoun.hasMatch(lower)) {
      if (doc.pages.length == 1) {
        return [
          _Say(
            t(
              'This is the only page, so I kept it.',
              'È l\'unica pagina, quindi l\'ho mantenuta.',
            ),
          ),
        ];
      }
      return [
        _Say(
          t(
            'Removing page $page. This needs your approval.',
            'Rimuovo la pagina $page. Serve la tua approvazione.',
          ),
        ),
        _Call(ToolNames.deletePage, {'page': page}),
      ];
    }

    final replace = _Intent.replace.firstMatch(prompt);
    if (replace != null) {
      return [
        _Say(
          t(
            'Replacing the text across the document.',
            'Sostituisco il testo in tutto il documento.',
          ),
        ),
        _Call(ToolNames.replaceText, {
          'find': replace.group(1)!,
          'replace': replace.group(2)!,
        }),
      ];
    }

    if (_Intent.table.hasMatch(lower)) {
      return [
        _Say(
          t(
            'Adding a summary table to page $page.',
            'Aggiungo una tabella di sintesi a pagina $page.',
          ),
        ),
        _Call(ToolNames.addTable, {
          'page': page,
          'columns': it
              ? ['Voce', 'Q1', 'Q2', 'Q3']
              : ['Item', 'Q1', 'Q2', 'Q3'],
          'rows': [
            [it ? 'Ricavi' : 'Revenue', '€3.1M', '€3.6M', '€4.2M'],
            [it ? 'Nuovi clienti' : 'New customers', '210', '258', '320'],
            [it ? 'Margine lordo' : 'Gross margin', '58%', '59%', '62%'],
          ],
          'caption': it ? 'Valori stimati.' : 'Estimated figures.',
        }),
      ];
    }

    if (_Intent.image.hasMatch(lower)) {
      final image = request.attachments.where((a) => a.isImage).firstOrNull;
      return [
        _Say(
          image == null
              ? t(
                  'No image attached, so I added a placeholder to page $page. Attach a PNG or JPG to use a real one.',
                  'Nessuna immagine allegata: ho inserito un segnaposto a pagina $page. Allega un PNG o JPG per usarne una vera.',
                )
              : t(
                  'Adding **${image.name}** to page $page.',
                  'Aggiungo **${image.name}** a pagina $page.',
                ),
        ),
        _Call(ToolNames.addImage, {
          'page': page,
          'attachment': ?image?.name,
          'caption': image?.name ?? (it ? 'Immagine' : 'Image'),
          'position': 2,
        }),
      ];
    }

    if (_Intent.addPage.hasMatch(lower)) {
      return [
        _Say(
          t(
            'Adding a new page after page $page.',
            'Aggiungo una nuova pagina dopo la pagina $page.',
          ),
        ),
        _Call(ToolNames.addPage, {
          'position': page + 1,
          'page': {
            'title': it ? 'Nuova sezione' : 'New section',
            'layout': 'standard',
            'blocks': [
              {'type': 'heading', 'text': it ? 'Nuova sezione' : 'New section'},
              {
                'type': 'paragraph',
                'text': it
                    ? 'Descrivi qui il contenuto della sezione.'
                    : 'Describe the content of this section here.',
              },
            ],
          },
        }),
      ];
    }

    final color = _color(lower);
    if (color != null && _Intent.colorWord.hasMatch(lower)) {
      return [
        _Say(t('Switching the accent colour.', 'Cambio il colore di accento.')),
        _Call(ToolNames.setTheme, {'accent': color}),
      ];
    }

    if (_Intent.twoColumns.hasMatch(lower)) {
      return [
        _Say(
          t(
            'Switching page $page to a two-column layout.',
            'Imposto la pagina $page su due colonne.',
          ),
        ),
        _Call(ToolNames.changeLayout, {'page': page, 'layout': 'twoColumn'}),
      ];
    }

    final premium = _Intent.premium.hasMatch(lower);
    final shorter = _Intent.shorter.hasMatch(lower);
    if (premium || shorter) {
      return _rewrite(doc, page, t, premium: premium, shorter: shorter);
    }

    return [
      _Say(
        t(
          'I\'m running in **offline mock mode**, so I understand a limited set of requests. Try:\n\n'
              '- *Make page 3 more premium and reduce the amount of text*\n'
              '- *Add a table to page 2*\n'
              '- *Change the accent colour to green*\n'
              '- *Replace "Acme Corp" with "Globex"*\n'
              '- *Add a page* · *Delete page 4* · *Export the PDF*\n'
              '- *Give me an overview* · *Show page 2* · *Show page 2 as JSON* · *Calculate the ROI*',
          'Sono in **modalità mock offline**, quindi capisco un insieme limitato di richieste. Prova:\n\n'
              '- *Rendi la pagina 3 più premium e riduci il testo*\n'
              '- *Aggiungi una tabella a pagina 2*\n'
              '- *Cambia il colore in verde*\n'
              '- *Sostituisci "Acme Corp" con "Globex"*\n'
              '- *Aggiungi una pagina* · *Elimina la pagina 4* · *Esporta il PDF*\n'
              '- *Fammi una panoramica* · *Mostra la pagina 2* · *Pagina 2 in JSON* · *Calcola il ROI*',
        ),
      ),
    ];
  }

  /// Page [page] rewritten as the lawyer asked: a premium layout, less text, or both.
  List<_Step> _rewrite(
    PaperDocument doc,
    int page,
    _Lang t, {
    required bool premium,
    required bool shorter,
  }) {
    final target = doc.pages[page - 1];
    final blocks = _condense(target.blocks, keepAll: !shorter);
    final layout = target.layout == PageLayout.cover
        ? PageLayout.cover
        : premium
        ? PageLayout.premium
        : target.layout;
    final before = target.wordCount;
    final after = DocPage(id: '', blocks: blocks).wordCount;
    final plan = [
      if (premium)
        t(
          'switch to the **premium** layout: accent bar, more whitespace, larger type',
          'passo al layout **premium**: barra d\'accento, più respiro, tipografia più grande',
        ),
      if (shorter)
        t(
          'keep one lead sentence per paragraph and at most three bullets',
          'tengo una frase chiave per paragrafo e al massimo tre punti elenco',
        ),
      t(
        'leave tables, metrics and the other pages untouched',
        'lascio invariati tabelle, metriche e le altre pagine',
      ),
    ];
    return [
      _Status(t('Reading the document', 'Leggo il documento')),
      const _Call(ToolNames.readDocument, {}),
      _Say(
        t(
          'Page $page (**${target.title}**) as it is now, $before words:',
          'La pagina $page (**${target.title}**) com\'è ora, $before parole:',
        ),
      ),
      _Ui('pdf_page', {
        'page': page,
        'caption': t('Current version', 'Versione attuale'),
      }),
      _Say(
        t('My plan:\n\n', 'Il mio piano:\n\n') +
            plan.map((p) => '- $p').join('\n'),
      ),
      _Status(t('Rewriting page $page', 'Riscrivo la pagina $page')),
      _Call(ToolNames.updatePage, {
        'page': page,
        'layout': layout.name,
        'blocks': [for (final b in blocks) b.toJson()],
      }),
      _Say(
        t(
          'Done. Only page $page changed:\n\n| | Before | After |\n|---|---:|---:|\n| Words | $before | $after |\n| Layout | ${target.layout.label} | ${layout.label} |\n\nUse **Undo** below to revert, or **Review** to compare in the side panel.',
          'Fatto. È cambiata solo la pagina $page:\n\n| | Prima | Dopo |\n|---|---:|---:|\n| Parole | $before | $after |\n| Layout | ${target.layout.label} | ${layout.label} |\n\nUsa **Undo** qui sotto per tornare indietro, o **Review** per confrontare nel pannello laterale.',
        ),
      ),
    ];
  }

  List<_Step> _outline(PaperDocument doc, bool it) {
    final t = _Lang(it);
    final words = [for (final p in doc.pages) p.wordCount];
    final total = words.fold(0, (a, b) => a + b);
    final densest = words.indexOf(words.reduce((a, b) => a > b ? a : b));
    final layouts = <String, int>{};
    for (final p in doc.pages) {
      layouts[p.layout.label] = (layouts[p.layout.label] ?? 0) + 1;
    }
    final mix = layouts.entries.map((e) => '${e.value}× ${e.key}').join(', ');
    final average = (total / doc.pages.length).round();
    return [
      _Status(t('Reading the document', 'Leggo il documento')),
      const _Call(ToolNames.readDocument, {}),
      _Say(
        t(
          '**${doc.title}** has ${doc.pages.length} pages and $total words.',
          '**${doc.title}** ha ${doc.pages.length} pagine e $total parole.',
        ),
      ),
      const _Ui('document_outline', {}),
      _Ui('chart', {
        'title': t('Words per page', 'Parole per pagina'),
        'unit': t('words', 'parole'),
        'series': [
          for (final (i, p) in doc.pages.indexed)
            {'label': '${i + 1} · ${p.title}', 'value': p.wordCount},
        ],
      }),
      _Say(
        t(
          '### What I would change\n\n'
              '1. **Page ${densest + 1}** is the densest (${words[densest]} words): shorten it or split it.\n'
              '2. Layout mix: $mix.\n'
              '3. Average $average words per page; aim for under 180 on a proposal.',
          '### Cosa cambierei\n\n'
              '1. **Pagina ${densest + 1}** è la più densa (${words[densest]} parole): accorciala o dividila.\n'
              '2. Layout: $mix.\n'
              '3. Media di $average parole per pagina; per una proposta meglio sotto le 180.',
        ),
      ),
    ];
  }

  List<_Step> _create(String prompt, String lower, bool it) {
    final count =
        int.tryParse(_Intent.pageCount.firstMatch(lower)?.group(1) ?? '')
            ?.clamp(1, 10) ??
        6;
    final client = _Intent.client.firstMatch(prompt)?.group(1);
    final kind = _Intent.report.hasMatch(lower) ? 'report' : 'proposal';
    final pages = _generatePages(
      count,
      client ?? (it ? 'il cliente' : 'the client'),
      kind,
      it,
    );
    final title = kind == 'report'
        ? (it ? 'Report trimestrale' : 'Quarterly Report')
        : (it ? 'Proposta di consulenza' : 'Consulting Proposal');

    return [
      _Say(
        it
            ? 'Creo un documento di **$count pagine**${client != null ? ' per **$client**' : ''}: struttura, contenuti e layout.\n\n'
            : 'Drafting a **$count-page** ${kind == 'report' ? 'report' : 'proposal'}${client != null ? ' for **$client**' : ''}: structure, content and layout.\n\n',
      ),
      _Call(ToolNames.createDocument, {
        'title': client == null ? title : '$title · $client',
        'subtitle': it
            ? 'Obiettivi, approccio e investimento'
            : 'Objectives, approach and investment',
        'client': ?client,
        'accent': '#3B5BDB',
        'brandName': 'Daylex Studio',
        'pages': pages,
      }),
      _Say(it ? 'Ecco la struttura:' : 'Here is the structure:'),
      const _Ui('document_outline', {}),
      _Say(
        it
            ? 'Documento pronto: ${pages.length} pagine con copertina, sintesi e prossimi passi. Chiedimi di modificare qualsiasi pagina.'
            : 'Your document is ready: ${pages.length} pages with a cover, summary and next steps. Ask me to refine any page.',
      ),
    ];
  }

  // -- content generation ---------------------------------------------------

  List<Map<String, dynamic>> _generatePages(
    int count,
    String client,
    String kind,
    bool it,
  ) {
    Map<String, dynamic> pg(
      String title,
      String layout,
      List<Map<String, dynamic>> blocks,
    ) => {'title': title, 'layout': layout, 'blocks': blocks};
    Map<String, dynamic> h(String text, [int level = 1]) => {
      'type': 'heading',
      'text': text,
      'level': level,
    };
    Map<String, dynamic> para(String text) => {
      'type': 'paragraph',
      'text': text,
    };
    Map<String, dynamic> list(List<String> items) => {
      'type': 'bullets',
      'items': items,
    };

    final cover = pg(it ? 'Proposta' : 'Proposal', 'cover', [
      para(
        it
            ? 'Un piano concreto per aiutare $client a crescere nei prossimi tre mesi.'
            : 'A focused plan to help $client grow over the next quarter.',
      ),
    ]);
    final body = <Map<String, dynamic>>[
      pg(it ? 'Sintesi' : 'Summary', 'standard', [
        h(it ? 'Sintesi' : 'Executive summary'),
        para(
          it
              ? '$client ha una base clienti solida e margini in crescita. Proponiamo tre iniziative coordinate per accelerare i ricavi mantenendo la disciplina sui costi.'
              : '$client has a loyal customer base and improving margins. We propose three coordinated initiatives to accelerate revenue while keeping costs disciplined.',
        ),
        {
          'type': 'metrics',
          'items': [
            {
              'label': it ? 'Crescita ricavi' : 'Revenue growth',
              'value': '+18%',
              'delta': 'QoQ',
            },
            {
              'label': it ? 'Nuovi clienti' : 'New customers',
              'value': '240',
              'delta': '+21%',
            },
            {'label': 'Payback', 'value': '6 mo', 'delta': ''},
          ],
        },
      ]),
      pg(it ? 'Obiettivi' : 'Objectives', 'standard', [
        h(it ? 'Contesto e obiettivi' : 'Context & objectives'),
        para(
          it
              ? 'Il mercato si sta spostando verso soluzioni più rapide da adottare. Questo crea una finestra di opportunità per $client.'
              : 'The market is shifting towards solutions that are faster to adopt, opening a window of opportunity for $client.',
        ),
        list(
          it
              ? [
                  'Aumentare la pipeline enterprise del 30%',
                  'Ridurre i tempi di onboarding',
                  'Migliorare la retention a 12 mesi',
                ]
              : [
                  'Grow enterprise pipeline by 30%',
                  'Cut onboarding time in half',
                  'Improve 12-month retention',
                ],
        ),
      ]),
      pg(it ? 'Approccio' : 'Approach', 'twoColumn', [
        h(it ? 'Il nostro approccio' : 'Our approach'),
        h(it ? 'Analisi' : 'Discover', 3),
        para(
          it
              ? 'Interviste, dati e criteri di successo.'
              : 'Interviews, data review and success criteria.',
        ),
        h(it ? 'Progettazione' : 'Design', 3),
        para(
          it
              ? 'Opzioni, compromessi e piano consigliato.'
              : 'Options, trade-offs and a recommended plan.',
        ),
        h(it ? 'Esecuzione' : 'Deliver', 3),
        para(
          it
              ? 'Supporto all\'implementazione e passaggio di consegne.'
              : 'Implementation support and handover.',
        ),
        {
          'type': 'callout',
          'title': it ? 'Principio guida' : 'Guiding principle',
          'text': it
              ? 'Ogni iniziativa deve mostrare un indicatore misurabile entro quattro settimane.'
              : 'Every initiative shows a measurable indicator within four weeks.',
        },
      ]),
      pg(it ? 'Tempistiche' : 'Timeline', 'standard', [
        h(it ? 'Tempistiche' : 'Timeline'),
        {
          'type': 'table',
          'columns': it
              ? ['Fase', 'Durata', 'Risultato']
              : ['Phase', 'Duration', 'Outcome'],
          'rows': it
              ? [
                  ['Analisi', '2 settimane', 'Diagnosi'],
                  ['Progettazione', '3 settimane', 'Piano'],
                  ['Esecuzione', '6 settimane', 'Risultati'],
                ]
              : [
                  ['Discover', '2 weeks', 'Diagnosis'],
                  ['Design', '3 weeks', 'Plan'],
                  ['Deliver', '6 weeks', 'Results'],
                ],
        },
      ]),
      pg(it ? 'Investimento' : 'Investment', 'standard', [
        h(it ? 'Investimento' : 'Investment'),
        {
          'type': 'table',
          'columns': it ? ['Voce', 'Importo'] : ['Item', 'Amount'],
          'rows': it
              ? [
                  ['Analisi', '€40k'],
                  ['Progettazione', '€60k'],
                  ['Esecuzione', '€120k'],
                  ['Totale', '€220k'],
                ]
              : [
                  ['Discover', '€40k'],
                  ['Design', '€60k'],
                  ['Deliver', '€120k'],
                  ['Total', '€220k'],
                ],
          'caption': it ? 'IVA esclusa.' : 'Excluding VAT.',
        },
      ]),
      pg(it ? 'Case study' : 'Case study', 'premium', [
        h('Case study'),
        {
          'type': 'quote',
          'text': it
              ? 'In dieci settimane abbiamo dimezzato i tempi di onboarding.'
              : 'In ten weeks we cut onboarding time in half.',
          'author': 'COO, Globex',
        },
      ]),
      pg(it ? 'Rischi' : 'Risks', 'standard', [
        h(it ? 'Rischi e mitigazioni' : 'Risks & mitigations'),
        list(
          it
              ? [
                  'Disponibilità del team: sponsor dedicato',
                  'Dati incompleti: fase di pulizia iniziale',
                ]
              : [
                  'Team availability: dedicated sponsor',
                  'Incomplete data: upfront clean-up phase',
                ],
        ),
      ]),
    ];
    final closing = pg(it ? 'Prossimi passi' : 'Next steps', 'standard', [
      h(it ? 'Prossimi passi' : 'Next steps'),
      list(
        it
            ? [
                'Conferma di perimetro e budget',
                'Workshop di avvio',
                'Riunioni settimanali di avanzamento',
              ]
            : [
                'Confirm scope and budget',
                'Kick-off workshop',
                'Weekly steering meetings',
              ],
      ),
    ]);

    if (count == 1) return [body.first..['layout'] = 'premium'];
    if (count == 2) return [cover, closing];
    final middle = <Map<String, dynamic>>[
      for (var i = 0; i < count - 2; i++) body[i % body.length],
    ];
    return [cover, ...middle, closing];
  }

  /// Shortens text-heavy blocks: one lead sentence per paragraph run, at most
  /// three concise bullets. Data blocks are kept as they are.
  List<DocBlock> _condense(List<DocBlock> blocks, {required bool keepAll}) {
    final out = <DocBlock>[];
    var paragraphRun = false;
    for (final b in blocks) {
      switch (b) {
        case ParagraphBlock(:final text):
          if (paragraphRun && !keepAll) continue;
          out.add(
            ParagraphBlock(
              id: b.id,
              text: _firstSentences(text, keepAll ? 2 : 1),
            ),
          );
          paragraphRun = true;
          continue;
        case BulletListBlock(:final items):
          out.add(
            BulletListBlock(
              id: b.id,
              items: items.take(3).map(_clause).toList(),
            ),
          );
        default:
          out.add(b);
      }
      paragraphRun = false;
    }
    return out;
  }

  static String _firstSentences(String text, int n) {
    final parts = text.split(_Intent.sentenceEnd);
    return parts.take(n).join(' ');
  }

  static String _clause(String text) {
    final cut = text.split(_Intent.clauseEnd).first.trim();
    return cut.endsWith('.') ? cut : '$cut.';
  }

  // -- helpers ------------------------------------------------------------------

  static bool _isItalian(String lower) =>
      _Intent.italianWord.allMatches(lower).length >= 2;

  static int _pageNumber(String lower, PaperDocument doc, int? current) {
    final match =
        _Intent.pageBefore.firstMatch(lower) ??
        _Intent.pageAfter.firstMatch(lower);
    var n = int.tryParse(match?.group(1) ?? '');
    if (n == null && _Intent.cover.hasMatch(lower)) n = 1;
    if (n == null && _Intent.last.hasMatch(lower)) n = doc.pages.length;
    return (n ?? current ?? 1).clamp(1, doc.pages.length);
  }

  static String? _color(String lower) {
    for (final e in _Intent.colors.entries) {
      if (e.key.hasMatch(lower)) return e.value;
    }
    return null;
  }

  Stream<AgentEvent> _stream(String text) async* {
    final tokens = _Intent.token.allMatches(text).map((m) => m[0]!);
    for (final token in tokens) {
      yield AgentTextDelta(token);
      await _pause(22);
    }
  }

  Future<void> _pause(int ms) => speed == 0
      ? Future<void>.value()
      : Future<void>.delayed(Duration(milliseconds: (ms * speed).round()));
}

sealed class _Step {
  const _Step();
}

class _Say extends _Step {
  const _Say(this.text);
  final String text;
}

class _Call extends _Step {
  const _Call(this.name, this.args);
  final String name;
  final Map<String, dynamic> args;
}

class _Ui extends _Step {
  const _Ui(this.component, this.props);
  final String component;
  final Map<String, dynamic> props;
}

class _Status extends _Step {
  const _Status(this.label);
  final String label;
}

/// Picks the sentence in the language of the request: `t('Done.', 'Fatto.')`.
class _Lang {
  const _Lang(this.italian);
  final bool italian;

  String call(String en, String itText) => italian ? itText : en;
}

/// The keyword rules that tell what a request asks for. Order of use is in [MockAgentClient._plan].
abstract final class _Intent {
  static final createVerb = RegExp(
    r'\b(create|generate|draft|write|new|crea|genera|scrivi|nuov[oa]|prepara)\b',
  );
  static final createNoun = RegExp(
    r'(document|proposal|report|one-pager|onepager|pdf|deck|proposta|documento|relazione|brochure|pages?\b|pagine)',
  );
  static final addVerb = RegExp(r'\b(add|aggiungi|inserisci)\b');
  static final outline = RegExp(
    r'(outline|structure|overview|summar|struttura|panoramica|riassum|analizza|analyse|analyze)',
  );
  static final json = RegExp(r'\b(json|schema|code|codice|raw)\b');
  static final roi = RegExp(
    r'\b(roi|payback|formula|calcola|calculate|math)\b',
  );
  static final show = RegExp(
    r'(show|mostra|vedi|preview|anteprima|fammi vedere)',
  );
  static final translate = RegExp(r'(translate|traduci)');
  static final export = RegExp(r'(export|esporta|scarica|download|salva)');
  static final deleteVerb = RegExp(r'(delete|remove|elimina|rimuovi|cancella)');
  static final pageNoun = RegExp(r'(page|pagina)');
  static final replace = RegExp(
    r'''(?:replace|sostituisci)\s+["'“]?(.+?)["'”]?\s+(?:with|con)\s+["'“]?(.+?)["'”]?\s*$''',
    caseSensitive: false,
  );
  static final table = RegExp(r'(table|tabella)');
  static final image = RegExp(r'(image|immagine|logo|foto|picture|photo)');
  static final addPage = RegExp(r'(add|aggiungi|inserisci).*(page|pagina)');
  static final colorWord = RegExp(
    r'(colou?r|colore|theme|tema|accent|brand|palette)',
  );
  static final twoColumns = RegExp(
    r'(two columns?|2 columns?|due colonne|2 colonne)',
  );
  static final premium = RegExp(
    r'(premium|elegant|eleganti|raffinat|luxur|lussuos|più bell|polish|sofisticat)',
  );
  static final shorter = RegExp(
    r'(reduce|less text|shorter|shorten|concise|trim|riduci|meno testo|accorcia|sintetizza|più corto|più breve|conciso)',
  );

  /// Accent colours by the words that name them, first match wins.
  static final colors = {
    RegExp(r'(green|verde)'): '#0F766E',
    RegExp(r'(purple|violet|viola)'): '#7C3AED',
    RegExp(r'(red|rosso)'): '#DC2626',
    RegExp(r'(orange|arancio)'): '#EA580C',
    RegExp(r'(black|nero|dark|scuro)'): '#111827',
    RegExp(r'(teal|petrolio)'): '#0E7490',
    RegExp(r'(pink|rosa)'): '#DB2777',
    RegExp(r'(gold|oro)'): '#B45309',
    RegExp(r'(blue|blu|azzurro)'): '#3B5BDB',
  };

  // Details of a new document.
  static final pageCount = RegExp(r'(\d+)\s*-?\s*(?:page|pagin)');
  static final client = RegExp(
    r'\b(?:for|per)\s+([A-Z][\w&.\-]*(?:\s+[A-Z][\w&.\-]*)*)',
  );
  static final report = RegExp(r'(report|relazione)');

  // Which page, and which language.
  static final pageBefore = RegExp(r'(?:page|pagina|p\.)\s*(\d+)');
  static final pageAfter = RegExp(
    r'(\d+)(?:st|nd|rd|th|a|°)?\s*(?:page|pagina)',
  );
  static final cover = RegExp(r'(cover|copertina)');
  static final last = RegExp(r'\b(last|ultima)\b');
  static final italianWord = RegExp(
    r'\b(il|la|le|di|della|del|per|una|pagina|pagine|rendi|crea|aggiungi|più|meno|con|cambia|elimina|esporta|riduci|copertina|colore)\b',
  );

  // Text shaping.
  static final sentenceEnd = RegExp(r'(?<=[.!?])\s+');
  static final clauseEnd = RegExp(r',\s|;\s|\s—\s|\s-\s');
  static final token = RegExp(r'\S+\s*|\s+');
}
