import 'dart:convert';
import 'dart:typed_data';

import 'package:uuid/uuid.dart';

import 'style.dart';

export 'style.dart';

const _uuid = Uuid();

String newId() => _uuid.v4();

/// How a page sets its blocks. `cover` is a page without header and footer; `premium` is a name kept from before
/// rfc/055 and reads as `standard`.
enum PageLayout {
  cover,
  standard,
  twoColumn,
  premium;

  /// The English name in tool results and card data for the model and the server. The UI shows
  /// `ModelLabels.layout` instead.
  String get label => switch (this) {
    PageLayout.cover => 'Cover',
    PageLayout.standard => 'Standard',
    PageLayout.twoColumn => 'Two columns',
    PageLayout.premium => 'Premium',
  };

  static PageLayout parse(Object? value) => PageLayout.values.firstWhere(
    (l) => l.name == value,
    orElse: () => PageLayout.standard,
  );
}

enum DocumentStatus {
  draft,
  review,
  approved,
}

/// The accents a document can take: brand-like tones, the default among them, that read well on paper.
const kDocAccentPalette = [
  0xFF3B5BDB, kDefaultDocAccent, 0xFF7C3AED, 0xFFDB2777,
  0xFFDC2626, 0xFFEA580C, 0xFFB45309, 0xFF0F766E,
  0xFF0E7490, 0xFF111827,
];

/// The colours new projects take in turn: hues far apart, so projects tell apart in the sidebar at a glance.
const kProjectPalette = [kDefaultDocAccent, 0xFF10B981, 0xFFF59E0B, 0xFFEC4899, 0xFF8B5CF6, 0xFF06B6D4];

/// The months a document is dated in: Italian, as every document is written.
const kMonthNames = [
  'gennaio', 'febbraio', 'marzo', 'aprile', 'maggio', 'giugno',
  'luglio', 'agosto', 'settembre', 'ottobre', 'novembre', 'dicembre',
];

/// `marzo 2024`.
String monthYear(DateTime d) => '${kMonthNames[d.month - 1]} ${d.year}';

/// `12 marzo 2024`.
String documentDate(DateTime d) => '${d.day} ${monthYear(d)}';

/// What the placeholders of a header or footer ([regionPlaceholders]) say on [page] of [doc]. `{pagina}` and
/// `{pagine}` are not here: the PDF numbers its pages, a word processor its own.
Map<String, String> regionValues(PaperDocument doc, DocPage page) => {
  'titolo': doc.metadata.title,
  'sottotitolo': doc.metadata.subtitle,
  'cliente': doc.metadata.client,
  'autore': doc.metadata.author,
  'data': documentDate(doc.metadata.updatedAt),
  'studio': doc.theme.brandName,
  'sezione': page.title,
};

class DocMetadata {
  const DocMetadata({
    required this.title,
    this.subtitle = '',
    this.author = '',
    this.client = '',
    this.status = DocumentStatus.draft,
    required this.createdAt,
    required this.updatedAt,
  });

  final String title;
  final String subtitle;
  final String author;
  final String client;
  final DocumentStatus status;
  final DateTime createdAt;
  final DateTime updatedAt;

  DocMetadata copyWith({
    String? title,
    String? subtitle,
    String? author,
    String? client,
    DocumentStatus? status,
    DateTime? updatedAt,
  }) => DocMetadata(
    title: title ?? this.title,
    subtitle: subtitle ?? this.subtitle,
    author: author ?? this.author,
    client: client ?? this.client,
    status: status ?? this.status,
    createdAt: createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );

  Map<String, dynamic> toJson() => {
    'title': title,
    'subtitle': subtitle,
    'author': author,
    'client': client,
    'status': status.name,
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
  };

  factory DocMetadata.fromJson(Map<String, dynamic> json) {
    final now = DateTime.now();
    return DocMetadata(
      title: json['title'] as String? ?? 'Documento senza titolo',
      subtitle: json['subtitle'] as String? ?? '',
      author: json['author'] as String? ?? '',
      client: json['client'] as String? ?? '',
      status: DocumentStatus.values.firstWhere(
        (s) => s.name == json['status'],
        orElse: () => DocumentStatus.draft,
      ),
      createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ?? now,
      updatedAt: DateTime.tryParse(json['updatedAt'] as String? ?? '') ?? now,
    );
  }
}

// ---------------------------------------------------------------------------
// Blocks
// ---------------------------------------------------------------------------

/// A semantic unit of content on a page. The agent edits blocks, never PDF
/// bytes; the renderer decides how each block looks.
/// The kinds of block. [wire] is the name in the JSON, in the agent's tools and in the server's schema.
enum BlockKind {
  heading('heading'),
  paragraph('paragraph'),
  bullets('bullets'),
  table('table'),
  metrics('metrics'),
  quote('quote'),
  callout('callout'),
  image('image');

  const BlockKind(this.wire);

  final String wire;

  static BlockKind? parse(Object? wire) => values.where((k) => k.wire == wire).firstOrNull;
}

sealed class DocBlock {
  const DocBlock({required this.id, this.style = BlockStyle.empty});

  final String id;

  /// The block's own look, over its role's in the document's style (rfc/055).
  final BlockStyle style;

  BlockKind get kind;

  /// The kind's name on the wire.
  String get type => kind.wire;

  /// Human readable text used for search, replace and outline previews.
  String get plainText;

  Map<String, dynamic> toJson();

  /// Returns a copy with every occurrence of [find] replaced.
  DocBlock replaceText(String find, String replace);

  /// The same block with [style] as its own.
  DocBlock withStyle(BlockStyle style);

  /// The role whose style the block takes where its own says nothing. An image takes the body's spacing and box.
  StyleRole get role => switch (this) {
    HeadingBlock(level: 1) => StyleRole.heading1,
    HeadingBlock(level: 2) => StyleRole.heading2,
    HeadingBlock() => StyleRole.heading3,
    ParagraphBlock() || ImageBlock() => StyleRole.body,
    BulletListBlock() => StyleRole.bullets,
    TableBlock() => StyleRole.table,
    MetricsBlock() => StyleRole.metrics,
    QuoteBlock() => StyleRole.quote,
    CalloutBlock() => StyleRole.callout,
  };

  /// [fields] with the block's id, kind and style: every block's JSON.
  Map<String, dynamic> _json(Map<String, dynamic> fields) => {
    'id': id,
    'type': type,
    ...fields,
    if (!style.isEmpty) 'style': style.toJson(),
  };

  static DocBlock fromJson(Map<String, dynamic> json) {
    final id = json['id'] as String? ?? newId();
    final style = BlockStyle.fromJson(json['style']);
    List<String> strings(Object? v) =>
        (v as List? ?? const []).map((e) => '$e').toList();

    // An unknown kind reads as a paragraph: its text is kept.
    return switch (BlockKind.parse(json['type']) ?? BlockKind.paragraph) {
      BlockKind.heading => HeadingBlock(
        id: id,
        style: style,
        text: json['text'] as String? ?? '',
        level: (json['level'] as num?)?.toInt().clamp(1, 3) ?? 1,
      ),
      BlockKind.bullets => BulletListBlock(id: id, style: style, items: strings(json['items'])),
      BlockKind.table => TableBlock(
        id: id,
        style: style,
        columns: strings(json['columns']),
        rows: (json['rows'] as List? ?? const []).map(strings).toList(),
        caption: json['caption'] as String? ?? '',
      ),
      BlockKind.metrics => MetricsBlock(
        id: id,
        style: style,
        items: (json['items'] as List? ?? const [])
            .whereType<Map>()
            .map((m) => Metric.fromJson(m.cast<String, dynamic>()))
            .toList(),
      ),
      BlockKind.quote => QuoteBlock(
        id: id,
        style: style,
        text: json['text'] as String? ?? '',
        author: json['author'] as String? ?? '',
      ),
      BlockKind.callout => CalloutBlock(
        id: id,
        style: style,
        title: json['title'] as String? ?? '',
        text: json['text'] as String? ?? '',
      ),
      BlockKind.image => ImageBlock(
        id: id,
        style: style,
        bytes: json['data'] is String
            ? base64Decode(json['data'] as String)
            : null,
        caption: json['caption'] as String? ?? '',
        height: (json['height'] as num?)?.toDouble() ?? 180,
      ),
      BlockKind.paragraph => ParagraphBlock(id: id, style: style, text: json['text'] as String? ?? ''),
    };
  }
}

class HeadingBlock extends DocBlock {
  const HeadingBlock({required super.id, super.style, required this.text, this.level = 1});

  final String text;
  final int level;

  @override
  BlockKind get kind => BlockKind.heading;

  @override
  String get plainText => text;

  HeadingBlock copyWith({String? text, int? level, BlockStyle? style}) =>
      HeadingBlock(id: id, style: style ?? this.style, text: text ?? this.text, level: level ?? this.level);

  @override
  DocBlock withStyle(BlockStyle style) => copyWith(style: style);

  @override
  DocBlock replaceText(String find, String replace) =>
      copyWith(text: text.replaceAll(find, replace));

  @override
  Map<String, dynamic> toJson() => _json({'text': text, 'level': level});
}

class ParagraphBlock extends DocBlock {
  const ParagraphBlock({required super.id, super.style, required this.text});

  final String text;

  @override
  BlockKind get kind => BlockKind.paragraph;

  @override
  String get plainText => text;

  ParagraphBlock copyWith({String? text, BlockStyle? style}) =>
      ParagraphBlock(id: id, style: style ?? this.style, text: text ?? this.text);

  @override
  DocBlock withStyle(BlockStyle style) => copyWith(style: style);

  @override
  DocBlock replaceText(String find, String replace) =>
      copyWith(text: text.replaceAll(find, replace));

  @override
  Map<String, dynamic> toJson() => _json({'text': text});
}

class BulletListBlock extends DocBlock {
  const BulletListBlock({required super.id, super.style, required this.items});

  final List<String> items;

  @override
  BlockKind get kind => BlockKind.bullets;

  @override
  String get plainText => items.join('\n');

  BulletListBlock copyWith({List<String>? items, BlockStyle? style}) =>
      BulletListBlock(id: id, style: style ?? this.style, items: items ?? this.items);

  @override
  DocBlock withStyle(BlockStyle style) => copyWith(style: style);

  @override
  DocBlock replaceText(String find, String replace) =>
      copyWith(items: [for (final i in items) i.replaceAll(find, replace)]);

  @override
  Map<String, dynamic> toJson() => _json({'items': items});
}

class TableBlock extends DocBlock {
  const TableBlock({
    required super.id,
    super.style,
    required this.columns,
    required this.rows,
    this.caption = '',
  });

  final List<String> columns;
  final List<List<String>> rows;
  final String caption;

  @override
  BlockKind get kind => BlockKind.table;

  @override
  String get plainText => [
    caption,
    columns.join(' | '),
    for (final r in rows) r.join(' | '),
  ].where((s) => s.isNotEmpty).join('\n');

  TableBlock copyWith({
    List<String>? columns,
    List<List<String>>? rows,
    String? caption,
    BlockStyle? style,
  }) => TableBlock(
    id: id,
    style: style ?? this.style,
    columns: columns ?? this.columns,
    rows: rows ?? this.rows,
    caption: caption ?? this.caption,
  );

  @override
  DocBlock replaceText(String find, String replace) => copyWith(
    columns: [for (final c in columns) c.replaceAll(find, replace)],
    rows: [
      for (final r in rows) [for (final c in r) c.replaceAll(find, replace)],
    ],
    caption: caption.replaceAll(find, replace),
  );

  @override
  DocBlock withStyle(BlockStyle style) => copyWith(style: style);

  @override
  Map<String, dynamic> toJson() => _json({'columns': columns, 'rows': rows, 'caption': caption});
}

class Metric {
  const Metric({required this.label, required this.value, this.delta = ''});

  final String label;
  final String value;
  final String delta;

  Metric replaceText(String find, String replace) => Metric(
    label: label.replaceAll(find, replace),
    value: value.replaceAll(find, replace),
    delta: delta.replaceAll(find, replace),
  );

  Map<String, dynamic> toJson() => {
    'label': label,
    'value': value,
    'delta': delta,
  };

  factory Metric.fromJson(Map<String, dynamic> json) => Metric(
    label: json['label'] as String? ?? '',
    value: json['value'] as String? ?? '',
    delta: json['delta'] as String? ?? '',
  );
}

/// A row of KPI tiles.
class MetricsBlock extends DocBlock {
  const MetricsBlock({required super.id, super.style, required this.items});

  final List<Metric> items;

  @override
  BlockKind get kind => BlockKind.metrics;

  @override
  String get plainText =>
      items.map((m) => '${m.label}: ${m.value} ${m.delta}'.trim()).join('\n');

  MetricsBlock copyWith({List<Metric>? items, BlockStyle? style}) =>
      MetricsBlock(id: id, style: style ?? this.style, items: items ?? this.items);

  @override
  DocBlock replaceText(String find, String replace) =>
      copyWith(items: [for (final m in items) m.replaceText(find, replace)]);

  @override
  DocBlock withStyle(BlockStyle style) => copyWith(style: style);

  @override
  Map<String, dynamic> toJson() => _json({
    'items': [for (final m in items) m.toJson()],
  });
}

class QuoteBlock extends DocBlock {
  const QuoteBlock({required super.id, super.style, required this.text, this.author = ''});

  final String text;
  final String author;

  @override
  BlockKind get kind => BlockKind.quote;

  @override
  String get plainText => author.isEmpty ? text : '$text — $author';

  QuoteBlock copyWith({String? text, String? author, BlockStyle? style}) => QuoteBlock(
    id: id,
    style: style ?? this.style,
    text: text ?? this.text,
    author: author ?? this.author,
  );

  @override
  DocBlock replaceText(String find, String replace) => copyWith(
    text: text.replaceAll(find, replace),
    author: author.replaceAll(find, replace),
  );

  @override
  DocBlock withStyle(BlockStyle style) => copyWith(style: style);

  @override
  Map<String, dynamic> toJson() => _json({'text': text, 'author': author});
}

class CalloutBlock extends DocBlock {
  const CalloutBlock({required super.id, super.style, required this.title, this.text = ''});

  final String title;
  final String text;

  @override
  BlockKind get kind => BlockKind.callout;

  @override
  String get plainText => '$title\n$text'.trim();

  CalloutBlock copyWith({String? title, String? text, BlockStyle? style}) =>
      CalloutBlock(id: id, style: style ?? this.style, title: title ?? this.title, text: text ?? this.text);

  @override
  DocBlock withStyle(BlockStyle style) => copyWith(style: style);

  @override
  DocBlock replaceText(String find, String replace) => copyWith(
    title: title.replaceAll(find, replace),
    text: text.replaceAll(find, replace),
  );

  @override
  Map<String, dynamic> toJson() => _json({'title': title, 'text': text});
}

/// An image. When [bytes] is null the renderer draws a placeholder.
class ImageBlock extends DocBlock {
  const ImageBlock({
    required super.id,
    super.style,
    this.bytes,
    this.caption = '',
    this.height = 180,
  });

  final Uint8List? bytes;
  final String caption;
  final double height;

  @override
  BlockKind get kind => BlockKind.image;

  @override
  String get plainText => caption;

  ImageBlock copyWith({String? caption, double? height, BlockStyle? style}) => ImageBlock(
    id: id,
    style: style ?? this.style,
    bytes: bytes,
    caption: caption ?? this.caption,
    height: height ?? this.height,
  );

  @override
  DocBlock replaceText(String find, String replace) =>
      copyWith(caption: caption.replaceAll(find, replace));

  @override
  DocBlock withStyle(BlockStyle style) => copyWith(style: style);

  @override
  Map<String, dynamic> toJson() => _json({
    if (bytes != null) 'data': base64Encode(bytes!),
    'caption': caption,
    'height': height,
  });
}

// ---------------------------------------------------------------------------
// Page & document
// ---------------------------------------------------------------------------

class DocPage {
  const DocPage({
    required this.id,
    this.title = '',
    this.layout = PageLayout.standard,
    this.blocks = const [],
  });

  final String id;

  /// Section label shown in the page header and the outline.
  final String title;
  final PageLayout layout;
  final List<DocBlock> blocks;

  DocPage copyWith({
    String? title,
    PageLayout? layout,
    List<DocBlock>? blocks,
  }) => DocPage(
    id: id,
    title: title ?? this.title,
    layout: layout ?? this.layout,
    blocks: blocks ?? this.blocks,
  );

  int get wordCount => blocks
      .map((b) => b.plainText.split(RegExp(r'\s+')).where((w) => w.isNotEmpty))
      .fold(0, (sum, words) => sum + words.length);

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'layout': layout.name,
    'blocks': [for (final b in blocks) b.toJson()],
  };

  factory DocPage.fromJson(Map<String, dynamic> json) => DocPage(
    id: json['id'] as String? ?? newId(),
    title: json['title'] as String? ?? '',
    layout: PageLayout.parse(json['layout']),
    blocks: (json['blocks'] as List? ?? const [])
        .whereType<Map>()
        .map((b) => DocBlock.fromJson(b.cast<String, dynamic>()))
        .toList(),
  );
}

/// The structured document the agent edits. The PDF is always derived from
/// this model, never the other way around.
class PaperDocument {
  const PaperDocument({
    required this.id,
    required this.projectId,
    required this.metadata,
    this.theme = const DocTheme(),
    this.pages = const [],
  });

  final String id;
  final String projectId;
  final DocMetadata metadata;
  final DocTheme theme;
  final List<DocPage> pages;

  String get title => metadata.title;

  String get fileName {
    final safe = title.replaceAll(RegExp(r'[\\/:*?"<>|]'), '').trim();
    return '${safe.isEmpty ? 'document' : safe}.pdf';
  }

  PaperDocument copyWith({
    DocMetadata? metadata,
    DocTheme? theme,
    List<DocPage>? pages,
    String? projectId,
  }) => PaperDocument(
    id: id,
    projectId: projectId ?? this.projectId,
    metadata: metadata ?? this.metadata,
    theme: theme ?? this.theme,
    pages: pages ?? this.pages,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'projectId': projectId,
    'metadata': metadata.toJson(),
    'theme': theme.toJson(),
    'pages': [for (final p in pages) p.toJson()],
  };

  factory PaperDocument.fromJson(Map<String, dynamic> json) {
    final theme = (json['theme'] as Map? ?? const {}).cast<String, dynamic>();
    final doc = PaperDocument(
      id: json['id'] as String? ?? newId(),
      projectId: json['projectId'] as String? ?? '',
      metadata: DocMetadata.fromJson(
        (json['metadata'] as Map? ?? const {}).cast<String, dynamic>(),
      ),
      theme: DocTheme.fromJson(theme),
      pages: (json['pages'] as List? ?? const [])
          .whereType<Map>()
          .map((p) => DocPage.fromJson(p.cast<String, dynamic>()))
          .toList(),
    );
    return theme['base'] == null ? doc._withCoverBlocks() : doc;
  }

  /// A document saved before rfc/055 (its theme names no base): each cover page gets, as ordinary blocks ahead of
  /// its own, what its accent band used to draw (studio, section, title, subtitle, client, author, date). The ids
  /// derive from the page's, so the same document always loads the same.
  PaperDocument _withCoverBlocks() {
    final m = metadata;
    final facts = [
      if (m.client.isNotEmpty) 'Destinatario: **${m.client}**',
      if (m.author.isNotEmpty) 'Redatto da: **${m.author}**',
      'Data: **${monthYear(m.updatedAt)}**',
    ].join('  ·  ');
    final label = BlockStyle.of({'size': 9, 'bold': true, 'caps': true, 'color': 'accent', 'spaceAfter': 6});
    return copyWith(
      pages: [
        for (final p in pages)
          if (p.layout != PageLayout.cover)
            p
          else
            p.copyWith(
              blocks: [
                if (theme.brandName.isNotEmpty)
                  ParagraphBlock(id: '${p.id}-studio', text: theme.brandName, style: label.patch({'spaceAfter': 72})),
                if (p.title.isNotEmpty) ParagraphBlock(id: '${p.id}-section', text: p.title, style: label),
                HeadingBlock(id: '${p.id}-title', text: m.title, style: BlockStyle.of({'size': 32, 'spaceAfter': 12})),
                if (m.subtitle.isNotEmpty)
                  ParagraphBlock(
                    id: '${p.id}-subtitle',
                    text: m.subtitle,
                    style: BlockStyle.of({'size': 14, 'color': '#64748b', 'spaceAfter': 24}),
                  ),
                ParagraphBlock(id: '${p.id}-facts', text: facts, style: BlockStyle.of({'spaceAfter': 28})),
                ...p.blocks,
              ],
            ),
      ],
    );
  }
}

class Project {
  const Project({
    required this.id,
    required this.name,
    this.description = '',
    this.color = kDefaultDocAccent,
  });

  final String id;
  final String name;
  final String description;
  final int color;

  Map<String, dynamic> toJson() => {'id': id, 'name': name, 'description': description, 'color': color};

  factory Project.fromJson(Map<String, dynamic> json) => Project(
    id: json['id'] as String,
    name: json['name'] as String? ?? 'Progetto senza nome',
    description: json['description'] as String? ?? '',
    color: json['color'] as int? ?? kDefaultDocAccent,
  );
}
