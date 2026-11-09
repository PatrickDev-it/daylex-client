import 'dart:async';
import 'dart:convert';

import '../../../l10n/app_localizations.dart';
import '../../document/model/document.dart';
import '../../document/model/operations.dart';
import '../../document/service/document_service.dart';
import 'agent_protocol.dart';

part 'tool_specs.g.dart';

/// JSON-schema description of a tool, as the server's registry declares it.
class ToolSpec {
  const ToolSpec(
    this.name,
    this.description,
    this.parameters, {
    this.requiresApproval = false,
    this.mutates = true,
  });

  final String name;
  final String description;
  final Map<String, dynamic> parameters;

  /// Destructive tools wait for the user to approve them in the chat.
  final bool requiresApproval;

  /// Whether the tool changes the document (and so shows up in Review).
  final bool mutates;

  factory ToolSpec.fromJson(Map<String, dynamic> json) => ToolSpec(
    json['name'] as String,
    json['description'] as String,
    (json['parameters'] as Map).cast<String, dynamic>(),
    requiresApproval: json['requiresApproval'] as bool,
    mutates: json['mutates'] as bool,
  );

  Map<String, dynamic> toJson() => {
    'name': name,
    'description': description,
    'parameters': parameters,
    'requiresApproval': requiresApproval,
    'mutates': mutates,
  };
}

ToolSpec? toolSpec(String name) =>
    appToolSpecs.where((t) => t.name == name).firstOrNull;

/// The tools the agent can call. Declared once, in the server's registry
/// (paperagent_server/tools.py), and generated into tool_specs.g.dart: a tool
/// is never added or changed here.
final appToolSpecs = [
  for (final spec in jsonDecode(_toolsJson) as List)
    ToolSpec.fromJson((spec as Map).cast<String, dynamic>()),
];

final documentToolSpecs = appToolSpecs
    .where((t) => !t.name.startsWith('whatsapp_'))
    .toList();

/// What the executor needs from the app. Implemented by the agent controller
/// on top of the workspace state, so tools never reach into widgets.
abstract interface class ToolHost {
  PaperDocument? get activeDocument;

  /// Applies operations to the active document as one undo step.
  void applyOperations(List<DocOperation> ops, {required String label});

  void openNewDocument(PaperDocument doc);

  /// Returns the saved path, or null if the user cancelled.
  Future<String?> exportActiveDocument();

  AgentAttachment? attachment(String name);
}

class ToolResult {
  const ToolResult.ok(this.summary, {this.focusPage, this.data}) : ok = true;
  const ToolResult.error(this.summary)
    : ok = false,
      focusPage = null,
      data = null;

  final bool ok;
  final String summary;

  /// 1-based page the preview should show after this call.
  final int? focusPage;
  final Map<String, dynamic>? data;

  /// What the server receives of the call (`POST /v1/agent/runs/{id}/tool-results`).
  Map<String, dynamic> toJson() => {
    'ok': ok,
    'summary': summary,
    'focusPage': ?focusPage,
    'data': ?data,
  };
}

/// The names of the tools, as the server's registry declares them (see [documentToolSpecs]): the one place the
/// app spells them.
abstract final class ToolNames {
  static const createDocument = 'create_document';
  static const readDocument = 'read_document';
  static const addPage = 'add_page';
  static const deletePage = 'delete_page';
  static const updatePage = 'update_page';
  static const replaceText = 'replace_text';
  static const insertBlock = 'insert_block';
  static const updateBlock = 'update_block';
  static const removeBlock = 'remove_block';
  static const addTable = 'add_table';
  static const addImage = 'add_image';
  static const changeLayout = 'change_layout';
  static const setTheme = 'set_theme';
  static const updateMetadata = 'update_metadata';
  static const exportPdf = 'export_pdf';

  static const all = {
    createDocument,
    readDocument,
    addPage,
    deletePage,
    updatePage,
    replaceText,
    insertBlock,
    updateBlock,
    removeBlock,
    addTable,
    addImage,
    changeLayout,
    setTheme,
    updateMetadata,
    exportPdf,
  };
}

/// Human label for a running tool call, in the app language.
String describeToolCall(
  AppLocalizations l,
  String name,
  Map<String, dynamic> args,
) {
  final page = args['page'];
  final on = page is num ? l.toolOnPage('$page') : '';
  return switch (name) {
    'whatsapp_status' => l.whatsappCheckStatus,
    'whatsapp_find_contact' => l.whatsappSearchContact,
    'whatsapp_send_message' => l.whatsappSendText,
    ToolNames.createDocument => l.toolCreateDocument(
      '${args['title'] ?? l.toolDocumentFallback}',
    ),
    ToolNames.readDocument => l.toolReadDocument,
    ToolNames.addPage => l.toolAddPage,
    ToolNames.deletePage => l.toolDeletePage(on),
    ToolNames.updatePage => l.toolUpdatePage(on),
    ToolNames.replaceText => l.toolReplaceText('${args['find']}'),
    ToolNames.insertBlock => l.toolInsertBlock(on),
    ToolNames.updateBlock => l.toolUpdateBlock('${args['block'] ?? ''}', on),
    ToolNames.removeBlock => l.toolRemoveBlock('${args['block'] ?? ''}', on),
    ToolNames.addTable => l.toolAddTable(on),
    ToolNames.addImage => l.toolAddImage(on),
    ToolNames.changeLayout => l.toolChangeLayout(on),
    ToolNames.setTheme => l.toolSetTheme,
    ToolNames.updateMetadata => l.toolUpdateMetadata,
    ToolNames.exportPdf => l.toolExportPdf,
    _ => l.operationRunning,
  };
}

/// Validates tool arguments and turns them into [DocOperation]s.
class DocumentToolExecutor {
  DocumentToolExecutor(this.host, {this.service = const DocumentService()});

  final ToolHost host;
  final DocumentService service;

  /// One handler per tool of the server's registry; [handledTools] is what a guard test compares to it.
  late final Map<String, FutureOr<ToolResult> Function(_Run)> _handlers = {
    ToolNames.readDocument: _read,
    ToolNames.addPage: _addPage,
    ToolNames.deletePage: _deletePage,
    ToolNames.updatePage: _updatePage,
    ToolNames.replaceText: _replaceText,
    ToolNames.insertBlock: _insertBlock,
    ToolNames.updateBlock: _updateBlock,
    ToolNames.removeBlock: _removeBlock,
    ToolNames.addTable: _addTable,
    ToolNames.addImage: _addImage,
    ToolNames.changeLayout: _changeLayout,
    ToolNames.setTheme: _setTheme,
    ToolNames.updateMetadata: _updateMetadata,
    ToolNames.exportPdf: _exportPdf,
  };

  /// The tools it runs on the open document, besides [ToolNames.createDocument] which opens one.
  Set<String> get handledTools => {ToolNames.createDocument, ..._handlers.keys};

  Future<ToolResult> execute(AgentToolCall call) async {
    try {
      return await _execute(call.name, call.arguments);
    } on DocumentOperationException catch (e) {
      return ToolResult.error(e.message);
    } on _ArgumentError catch (e) {
      return ToolResult.error(e.message);
    } catch (e) {
      // Arguments of the wrong type (a string where a list is due) throw a TypeError, not an
      // _ArgumentError: still the model's mistake, told back to it so it can retry.
      return ToolResult.error('Argomenti non validi: $e');
    }
  }

  Future<ToolResult> _execute(String name, Map<String, dynamic> a) async {
    if (name == ToolNames.createDocument) return _create(a);

    final doc = host.activeDocument;
    if (doc == null) {
      return const ToolResult.error('Nessun documento aperto.');
    }
    final handler = _handlers[name];
    if (handler == null) {
      return ToolResult.error('Strumento sconosciuto "$name".');
    }
    return handler(_Run(host, doc, a));
  }

  ToolResult _read(_Run r) =>
      ToolResult.ok('Lette ${r.doc.pages.length} pagine', data: r.doc.toJson());

  ToolResult _addPage(_Run r) {
    final page = DocPage.fromJson(_map(r.args['page']));
    final at = r.position() ?? r.doc.pages.length;
    return r.apply(
      [AddPage(page, index: at)],
      'Aggiunta la pagina ${at + 1}',
      focus: at + 1,
    );
  }

  ToolResult _deletePage(_Run r) {
    final i = r.pageIndex();
    // Show the page that preceded the deleted one.
    return r.apply(
      [DeletePage(i)],
      'Eliminata la pagina ${i + 1}',
      focus: i == 0 ? 1 : i,
    );
  }

  ToolResult _updatePage(_Run r) {
    final a = r.args;
    final i = r.pageIndex();
    return r.apply(
      [
        UpdatePage(
          i,
          title: a['title'] as String?,
          layout: a['layout'] == null ? null : PageLayout.parse(a['layout']),
          blocks: a['blocks'] == null ? null : _blocks(a['blocks']),
        ),
      ],
      'Aggiornata la pagina ${i + 1}',
      focus: i + 1,
    );
  }

  ToolResult _replaceText(_Run r) {
    final a = r.args;
    final find = a['find'] as String? ?? '';
    final i = a['page'] == null ? null : r.pageIndex();
    final count = service.countOccurrences(r.doc, find, pageIndex: i);
    if (count == 0) return ToolResult.error(_notFound(r.doc, find, i));
    final replace = a['replace'] as String? ?? '';
    final done = r.apply(
      [ReplaceText(find, replace, pageIndex: i)],
      count == 1 ? 'Sostituita 1 occorrenza' : 'Sostituite $count occorrenze',
      focus: i == null ? null : i + 1,
    );
    // Tell the agent what a rename or anonymisation missed: the same text
    // on other pages, or a name from it in another form ("Rossi").
    final left = _leftovers(host.activeDocument!, find, replace);
    return left.isEmpty
        ? done
        : ToolResult.ok(
            '${done.summary}. Ancora nel documento: $left. '
            'Se è lo stesso nome o testo, sostituisci anche questo.',
            focusPage: done.focusPage,
          );
  }

  ToolResult _insertBlock(_Run r) {
    final i = r.pageIndex();
    final block = DocBlock.fromJson(_map(r.args['block']));
    return r.apply(
      [InsertBlock(i, block, index: r.position())],
      'Inserito un blocco a pagina ${i + 1}',
      focus: i + 1,
    );
  }

  ToolResult _updateBlock(_Run r) {
    final (i, b, current) = _locateBlock(r);
    final block = DocBlock.fromJson({
      ..._map(r.args['content']),
      'id': current.id,
    });
    return r.apply(
      [UpdateBlock(block)],
      'Aggiornato il blocco ${b + 1} a pagina ${i + 1}',
      focus: i + 1,
    );
  }

  ToolResult _removeBlock(_Run r) {
    final (i, b, current) = _locateBlock(r);
    return r.apply(
      [RemoveBlock(current.id)],
      'Rimosso il blocco ${b + 1} da pagina ${i + 1}',
      focus: i + 1,
    );
  }

  /// The 0-based page and block that [r] names, and the block.
  (int, int, DocBlock) _locateBlock(_Run r) {
    // In a one-page letter the page is not in doubt: models sometimes
    // repeat the block number there ("page": 5, "block": 5).
    final i = r.doc.pages.length == 1 ? 0 : r.pageIndex();
    final blocks = r.doc.pages[i].blocks;
    final number = r.args['block'];
    if (number is! num) throw _ArgumentError('Manca "block".');
    final b = number.toInt() - 1;
    if (b < 0 || b >= blocks.length) {
      throw _ArgumentError(
        'Il blocco ${number.toInt()} non esiste a pagina ${i + 1} '
        '(${blocks.length} blocchi).',
      );
    }
    return (i, b, blocks[b]);
  }

  ToolResult _addTable(_Run r) {
    final i = r.pageIndex();
    final columns = [
      for (final c in r.args['columns'] as List? ?? const []) '$c',
    ];
    final twin = r.doc.pages[i].blocks.indexWhere(
      (b) => b is TableBlock && b.columns.join('|') == columns.join('|'),
    );
    if (twin >= 0) {
      throw _ArgumentError(
        'La pagina ${i + 1} ha già questa tabella (blocco ${twin + 1}). Per aggiungere '
        'righe chiama ${ToolNames.updateBlock} sul blocco ${twin + 1} con tutte le righe.',
      );
    }
    final block = DocBlock.fromJson({
      ...r.args,
      'type': 'table',
      'id': newId(),
    });
    return r.apply(
      [InsertBlock(i, block, index: r.position())],
      'Aggiunta una tabella a pagina ${i + 1}',
      focus: i + 1,
    );
  }

  ToolResult _addImage(_Run r) {
    final a = r.args;
    final i = r.pageIndex();
    final attachment = a['attachment'] as String?;
    final file = attachment == null ? null : host.attachment(attachment);
    if (attachment != null && file == null) {
      throw _ArgumentError('Allegato "$attachment" non trovato.');
    }
    final block = ImageBlock(
      id: newId(),
      bytes: file?.bytes,
      caption: a['caption'] as String? ?? '',
      height: (a['height'] as num?)?.toDouble() ?? 200,
    );
    return r.apply(
      [InsertBlock(i, block, index: r.position())],
      "Aggiunta un'immagine a pagina ${i + 1}",
      focus: i + 1,
    );
  }

  ToolResult _changeLayout(_Run r) {
    final i = r.pageIndex();
    final layout = PageLayout.parse(r.args['layout']);
    return r.apply(
      [UpdatePage(i, layout: layout)],
      'Impaginazione aggiornata a pagina ${i + 1}',
      focus: i + 1,
    );
  }

  ToolResult _setTheme(_Run r) {
    final a = r.args;
    final accent = parseColor(a['accent']);
    if (a['accent'] != null && accent == null) {
      throw _ArgumentError('Colore non valido "${a['accent']}".');
    }
    return r.apply([
      SetTheme(
        r.doc.theme.copyWith(
          accent: accent,
          brandName: a['brandName'] as String?,
        ),
      ),
    ], 'Tema aggiornato');
  }

  ToolResult _updateMetadata(_Run r) {
    final a = r.args;
    return r.apply([
      UpdateMetadata(
        title: a['title'] as String?,
        subtitle: a['subtitle'] as String?,
        client: a['client'] as String?,
        author: a['author'] as String?,
        status: DocumentStatus.values
            .where((s) => s.name == a['status'])
            .firstOrNull,
      ),
    ], 'Dati aggiornati');
  }

  Future<ToolResult> _exportPdf(_Run r) async {
    final path = await host.exportActiveDocument();
    return path == null
        ? const ToolResult.error('Esportazione annullata.')
        : ToolResult.ok('Salvato in $path', data: {'path': path});
  }

  ToolResult _create(Map<String, dynamic> a) {
    final title = (a['title'] as String?)?.trim();
    if (title == null || title.isEmpty) {
      throw _ArgumentError('Manca il titolo.');
    }
    final pages = (a['pages'] as List? ?? const [])
        .map((p) => DocPage.fromJson(_map(p)))
        .toList();
    if (pages.isEmpty) {
      throw _ArgumentError(DocumentOperationException.lastPageMessage);
    }
    final now = DateTime.now();
    final current = host.activeDocument;
    final doc = PaperDocument(
      id: newId(),
      projectId: current?.projectId ?? '',
      metadata: DocMetadata(
        title: title,
        subtitle: a['subtitle'] as String? ?? '',
        client: a['client'] as String? ?? '',
        author: a['author'] as String? ?? '',
        createdAt: now,
        updatedAt: now,
      ),
      theme: DocTheme(
        accent: parseColor(a['accent']) ?? kDefaultDocAccent,
        brandName: a['brandName'] as String? ?? '',
      ),
      pages: pages,
    );
    host.openNewDocument(doc);
    return ToolResult.ok(
      pages.length == 1
          ? 'Creato un documento di 1 pagina'
          : 'Creato un documento di ${pages.length} pagine',
      focusPage: 1,
      data: {'documentId': doc.id},
    );
  }

  static final _name = RegExp(r'[A-ZÀ-Ý][A-Za-zÀ-ÿ]{3,}');

  /// A not-found error that says where the text actually is, so a wrong
  /// page guess is fixed on the next step instead of retried blindly.
  String _notFound(PaperDocument doc, String find, int? pageIndex) {
    if (pageIndex == null || service.countOccurrences(doc, find) == 0) {
      return '"$find" non trovato.';
    }
    final pages = [
      for (var p = 0; p < doc.pages.length; p++)
        if (service.countOccurrences(doc, find, pageIndex: p) > 0) p + 1,
    ];
    final where = pages.isEmpty
        ? 'solo nel titolo, nel sottotitolo o nel cliente del documento'
        : 'a pagina ${pages.join(', ')}';
    return '"$find" non è a pagina ${pageIndex + 1}: è $where. '
        'Ometti "page" per sostituirlo ovunque.';
  }

  String _leftovers(PaperDocument doc, String find, String replace) {
    final forms = {
      find,
      // Names inside a filled-in placeholder ("[Nome Cognome]") are not names.
      if (!find.contains('['))
        for (final m in _name.allMatches(find)) m[0]!,
    };
    return [
      for (final form in forms)
        if (!replace.contains(form))
          if (service.countOccurrences(doc, form) case final n when n > 0)
            '"$form" ×$n',
    ].join(', ');
  }

  static Map<String, dynamic> _map(Object? value) {
    if (value is Map) return value.cast<String, dynamic>();
    throw _ArgumentError('Atteso un oggetto, ricevuto ${value.runtimeType}.');
  }

  static List<DocBlock> _blocks(Object? value) => (value as List? ?? const [])
      .map((b) => DocBlock.fromJson(_map(b)))
      .toList();
}

/// One tool call on the open document: the arguments to read and the one way to apply a change.
class _Run {
  _Run(this.host, this.doc, this.args);

  final ToolHost host;
  final PaperDocument doc;
  final Map<String, dynamic> args;

  /// The 0-based index of the page `args[key]` names.
  int pageIndex([String key = 'page']) {
    final value = args[key];
    if (value is! num) throw _ArgumentError('Manca "$key".');
    final index = value.toInt() - 1;
    if (index < 0 || index >= doc.pages.length) {
      throw _ArgumentError(
        'La pagina ${value.toInt()} non esiste (${doc.pages.length} pagine). "$key" è un numero di pagina; i blocchi di una pagina si numerano a parte con "block".',
      );
    }
    return index;
  }

  /// The 0-based index of `args['position']`, if given.
  int? position() {
    final value = args['position'];
    return value is num ? value.toInt() - 1 : null;
  }

  ToolResult apply(List<DocOperation> ops, String summary, {int? focus}) {
    host.applyOperations(ops, label: summary);
    return ToolResult.ok(summary, focusPage: focus);
  }
}

class _ArgumentError implements Exception {
  _ArgumentError(this.message);
  final String message;
}
