/// The one walk every writer reads: a [PaperDocument] flattened into the blocks a file carries, cleaned, numbered and
/// styled.
///
/// A writer never looks at a page, a theme or a raw string: what the file shows is decided here once (the page, each
/// block's look as the PDF draws it, the headers and footers of each page, which heading names a table, how wide a
/// column is), so the nine formats cannot disagree with each other or with the PDF, and a change of rule is one edit.
library;

import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';

import '../model/document.dart';
import '../model/inline.dart';
import 'cell_value.dart';
import 'export_text.dart';
import 'image_info.dart';

/// The page of the files, in twips (1/20 pt), the unit Word and RTF count in; ODF and HTML convert from here.
class ExPageSetup {
  const ExPageSetup({
    required this.widthTwips,
    required this.heightTwips,
    required this.topTwips,
    required this.rightTwips,
    required this.bottomTwips,
    required this.leftTwips,
    required this.headerTwips,
    required this.footerTwips,
  });

  /// The document's page ([DocStyles.page]): A4 in its orientation, its margins, and how far the header and the
  /// footer are from the edge.
  factory ExPageSetup.of(PageSetup p) {
    int twips(double? cm) => (cmToPt(cm ?? 0) * 20).round();
    final landscape = p.orientation == PageOrientation.landscape;
    return ExPageSetup(
      widthTwips: landscape ? _a4Long : _a4Short,
      heightTwips: landscape ? _a4Short : _a4Long,
      topTwips: twips(p.margin('top')),
      rightTwips: twips(p.margin('right')),
      bottomTwips: twips(p.margin('bottom')),
      leftTwips: twips(p.margin('left')),
      headerTwips: twips(p.header),
      footerTwips: twips(p.footer),
    );
  }

  static const _a4Short = 11906, _a4Long = 16838;

  final int widthTwips;
  final int heightTwips;
  final int topTwips;
  final int rightTwips;
  final int bottomTwips;
  final int leftTwips;

  /// From the top edge to the header.
  final int headerTwips;

  /// From the bottom edge to the footer.
  final int footerTwips;

  bool get landscape => widthTwips > heightTwips;
  int get textWidthTwips => widthTwips - leftTwips - rightTwips;
  double get textWidthPt => textWidthTwips / 20;
  double get textHeightPt => (heightTwips - topTwips - bottomTwips) / 20;
}

/// The look of a block or of a part of one: its role's style with the block's own over it ([resolved]), and the
/// fields the block itself sets ([own]). A format with named styles writes the role in the style and only [own] on
/// the paragraph, so a lawyer who restyles «Titolo 1» in Word restyles every heading the agent did not set apart.
final class ExStyle {
  const ExStyle(this.role, this.resolved, this.own);

  final StyleRole role;
  final ResolvedStyle resolved;
  final Set<String> own;
}

/// What a header or footer prints in place of `{pagina}` and `{pagine}`: the reader's own page fields.
enum ExField { page, pages }

/// A run of text with one emphasis ([parseInline]); in a header or a footer, possibly a page field instead.
final class ExRun {
  const ExRun(this.text, {this.bold = false, this.italic = false, this.underline = false, this.field});

  final String text;
  final bool bold;
  final bool italic;
  final bool underline;
  final ExField? field;
}

final _pageField = RegExp(r'\{(pagina|pagine)\}');

/// The runs of [text], its emphasis kept; with [fields], `{pagina}` and `{pagine}` are page fields in the emphasis of
/// the text around them.
List<ExRun> runsOf(String text, {bool fields = false}) => [
  for (final r in parseInline(text))
    if (!fields)
      ExRun(r.text, bold: r.bold, italic: r.italic, underline: r.underline)
    else
      ...() sync* {
        var at = 0;
        for (final m in _pageField.allMatches(r.text)) {
          if (m.start > at) yield ExRun(r.text.substring(at, m.start), bold: r.bold, italic: r.italic, underline: r.underline);
          yield ExRun(m[0]!, bold: r.bold, italic: r.italic, underline: r.underline, field: m[1] == 'pagina' ? ExField.page : ExField.pages);
          at = m.end;
        }
        if (at < r.text.length) yield ExRun(r.text.substring(at), bold: r.bold, italic: r.italic, underline: r.underline);
      }(),
];

sealed class ExBlock {
  const ExBlock();
}

final class ExHeading extends ExBlock {
  const ExHeading(this.level, this.text, this.style);
  final int level;
  final String text;
  final ExStyle style;
}

final class ExParagraph extends ExBlock {
  const ExParagraph(this.text, this.style);
  final String text;
  final ExStyle style;
}

/// A list; [ExStyle.resolved] says its marker.
final class ExBullets extends ExBlock {
  const ExBullets(this.items, this.style);
  final List<String> items;
  final ExStyle style;
}

final class ExTable extends ExBlock {
  ExTable._({
    required this.title,
    required this.number,
    required this.header,
    required this.rows,
    required this.caption,
    required this.style,
    required this.headerStyle,
    required this.captionStyle,
  });

  /// A table block: cells cleaned, every row padded to the widest one (as the PDF does).
  factory ExTable.from(
    TableBlock t, {
    required int number,
    required String title,
    required String Function(String) text,
    required ExStyle style,
    required ExStyle headerStyle,
    required ExStyle captionStyle,
  }) {
    final width = [t.columns.length, ...t.rows.map((r) => r.length)].fold(0, math.max);
    List<String> pad(List<String> r) => [for (var i = 0; i < width; i++) i < r.length ? text(r[i]) : ''];
    return ExTable._(
      title: title,
      number: number,
      header: t.columns.isEmpty ? const [] : pad(t.columns),
      rows: [for (final r in t.rows) pad(r)],
      caption: text(t.caption),
      style: style,
      headerStyle: headerStyle,
      captionStyle: captionStyle,
    );
  }

  /// The metrics as a small table: one row per indicator, the labels' style on the header.
  factory ExTable.metrics(ExMetrics m) {
    final delta = m.items.any((x) => x.delta.isNotEmpty);
    return ExTable._(
      title: 'Indicatori',
      number: 0,
      header: ['Indicatore', 'Valore', if (delta) 'Variazione'],
      rows: [for (final x in m.items) [x.label, x.value, if (delta) x.delta]],
      caption: '',
      style: m.style,
      headerStyle: m.labelStyle,
      captionStyle: m.labelStyle,
    );
  }

  /// Names the table: the nearest heading before it, else `Tabella N`.
  final String title;

  /// 1-based among the document's tables (0 for a metrics table).
  final int number;

  /// The column names; empty when the table has none.
  final List<String> header;
  final List<List<String>> rows;
  final String caption;
  final ExStyle style;
  final ExStyle headerStyle;
  final ExStyle captionStyle;

  bool get hasHeader => header.isNotEmpty;
  int get width => hasHeader ? header.length : (rows.isEmpty ? 0 : rows.first.length);

  /// Columns that hold only numbers, amounts, dates or percentages: set to the right, the way a ledger is.
  late final List<bool> numeric = [
    for (var c = 0; c < width; c++)
      () {
        var typed = 0;
        for (final r in rows) {
          final v = plainInline(r[c]).trim();
          if (v.isEmpty || v == '—' || v == '–' || v == '-') continue;
          if (parseCell(v).isText) return false;
          typed++;
        }
        return typed > 0;
      }(),
  ];

  /// Each column's share of the width: by the longest line in it, kept between a sliver and two fifths.
  late final List<double> shares = () {
    if (width == 0) return const <double>[];
    final weight = [
      for (var c = 0; c < width; c++)
        math.min(36, math.max(6, [if (hasHeader) header[c], for (final r in rows) r[c]].map(_longestLine).fold(0, math.max))).toDouble(),
    ];
    final total = weight.fold(0.0, (a, b) => a + b);
    return [for (final w in weight) w / total];
  }();

  /// The column widths in whole units of [total] (twips, say) that add up to exactly [total].
  List<int> widths(int total) {
    final out = [for (final s in shares) (s * total).floor()];
    out[out.length - 1] += total - out.fold(0, (a, b) => a + b);
    return out;
  }
}

int _longestLine(String s) => plainInline(s).split('\n').map((l) => l.runes.length).fold(0, math.max);

final class ExMetric {
  const ExMetric(this.label, this.value, this.delta);
  final String label;
  final String value;
  final String delta;

  /// A change for the worse: the PDF prints it red.
  bool get down => delta.trim().startsWith('-');
}

final class ExMetrics extends ExBlock {
  const ExMetrics(this.items, this.style, this.labelStyle);
  final List<ExMetric> items;
  final ExStyle style;

  /// The labels and the changes: the caption's style, as the PDF draws them.
  final ExStyle labelStyle;
  ExTable asTable() => ExTable.metrics(this);
}

final class ExQuote extends ExBlock {
  const ExQuote(this.text, this.author, this.style, this.authorStyle);
  final String text;
  final String author;
  final ExStyle style;
  final ExStyle authorStyle;
}

final class ExCallout extends ExBlock {
  const ExCallout(this.title, this.text, this.style);
  final String title;
  final String text;
  final ExStyle style;
}

final class ExImage extends ExBlock {
  ExImage(this.bytes, this.caption, this.heightPt, this.style, this.captionStyle)
    : header = bytes == null ? null : sniffImage(bytes);

  final Uint8List? bytes;

  /// Format and pixel size when [bytes] is an image a file can carry as it is (PNG, JPEG, GIF), else null.
  final ImageHeader? header;
  final String caption;

  /// The height the PDF gives the picture; the files size the picture to the text width instead.
  final double heightPt;
  final ExStyle style;
  final ExStyle captionStyle;

  /// What a text format and a placeholder say in the image's place.
  String get marker => markerWith((s) => s);

  /// The same, with the caption passed through [escape] (a format that has metacharacters of its own).
  String markerWith(String Function(String) escape) =>
      caption.isEmpty ? '[Immagine]' : '[Immagine: ${escape(plainInline(caption))}]';

  /// The size in points, at 96 dpi, never larger than the box and never enlarged.
  (double, double) fit(double maxWidthPt, double maxHeightPt) {
    final h = header;
    if (h == null) return (maxWidthPt, heightPt);
    final w = h.width * 0.75, ht = h.height * 0.75;
    final scale = math.min(1.0, math.min(maxWidthPt / w, maxHeightPt / ht));
    return (w * scale, ht * scale);
  }
}

/// The start of the next page of the document.
final class ExPageBreak extends ExBlock {
  const ExPageBreak();
}

/// A header's or a footer's logo.
final class ExLogo {
  ExLogo(this.bytes, this.heightPt, this.align) : header = sniffImage(bytes);

  final Uint8List bytes;

  /// Null when the bytes are no PNG, JPEG or GIF: the files leave the logo out.
  final ImageHeader? header;
  final double heightPt;
  final BlockAlign align;

  /// The width at [heightPt], the picture's proportions kept.
  double get widthPt => header == null ? heightPt : heightPt * header!.width / header!.height;
}

/// A header or a footer as one page shows it.
final class ExRegion {
  const ExRegion._(this.slot, this.left, this.center, this.right, this.style, this.line, this.logo, this.key);

  static const _none = ExRegion._(RegionSlot.header, '', '', '', null, false, null, '');

  final RegionSlot slot;

  /// The three texts, their emphasis kept and their placeholders filled but for the page numbers ([runsOf] with
  /// `fields`).
  final String left;
  final String center;
  final String right;

  /// Null only when the region is empty.
  final ResolvedStyle? style;
  final bool line;

  /// Null when there is none, or none a file can carry.
  final ExLogo? logo;

  bool get isEmpty => left.isEmpty && center.isEmpty && right.isEmpty && logo == null;

  /// The parts that print, in order, each with its alignment and whether the logo stands above it.
  List<({String text, BlockAlign align, ExLogo? logo})> get parts {
    final at = logo?.align == BlockAlign.justify ? BlockAlign.left : logo?.align;
    return [
      for (final (text, align) in [(left, BlockAlign.left), (center, BlockAlign.center), (right, BlockAlign.right)])
        if (text.isNotEmpty || at == align) (text: text, align: align, logo: at == align ? logo : null),
    ];
  }

  /// Equal for two regions that print the same (texts, style, line and logo), so the files can share one header or
  /// footer between pages, and between page 1 and the others; empty for an empty region.
  final String key;
}

/// The header and the footer of one page.
final class ExPageRegions {
  const ExPageRegions(this.header, this.footer);

  final ExRegion header;
  final ExRegion footer;

  String get key => '${header.key}\u0001${footer.key}';
}

/// The whole document, ready to write.
final class ExportDoc {
  ExportDoc._({
    required this.title,
    required this.subtitle,
    required this.author,
    required this.client,
    required this.brand,
    required this.status,
    required this.accent,
    required this.created,
    required this.modified,
    required this.page,
    required this.roles,
    required this.blocks,
    required this.first,
    required this.pages,
  });

  final String title;
  final String subtitle;
  final String author;
  final String client;
  final String brand;

  /// `Bozza`, `In revisione` or `Approvato`.
  final String status;
  final int accent;
  final DateTime created;
  final DateTime modified;
  final ExPageSetup page;

  /// Each role's style in this document, before any block's own: what a format's named styles say.
  final Map<StyleRole, ResolvedStyle> roles;
  final List<ExBlock> blocks;

  /// The first page's header and footer (the letterhead, when the document has one).
  final ExPageRegions first;

  /// Every page's header and footer as the pages after the first show them, one entry per page of the document.
  final List<ExPageRegions> pages;

  late final List<ExTable> tables = [for (final b in blocks) if (b is ExTable) b];

  /// The first page shows a header or footer of its own.
  bool get firstDiffers => first.key != pages.first.key;

  /// The pages do not all show the same header and footer (`{sezione}`): each page of the document is a section of
  /// the file.
  bool get perPage => pages.any((p) => p.key != pages.first.key);

  /// The document properties' author: the lawyer, or the app when nobody signed.
  String get creator => author.isEmpty ? 'Daylex' : author;

  String get accentHex => hex6(accent);
  String get tintHex => tintOf(accent, 0.07);
  String get tintStrongHex => tintOf(accent, 0.16);
}

/// The colours the files use where the document has none to say: the spreadsheets' grid and the changes of a metric.
abstract final class ExColors {
  static const ink = '0F172A';
  static const muted = '64748B';
  static const hairline = 'E2E8F0';
  static const zebra = 'F8FAFC';
  static const positive = '059669';
  static const negative = 'DC2626';
}

String _statusLabel(DocumentStatus s) => switch (s) {
  DocumentStatus.draft => 'Bozza',
  DocumentStatus.review => 'In revisione',
  DocumentStatus.approved => 'Approvato',
};

/// Flattens [doc]: each page's blocks in order, a page break between pages, each block styled as the PDF draws it.
/// With [plain], every text loses its emphasis markers: what MD, TXT and the spreadsheets write.
ExportDoc buildExportDoc(PaperDocument doc, {bool plain = false}) {
  final m = doc.metadata;
  final styles = DocStyles(doc.theme);
  String text(String s) => plain ? plainInline(cleanText(s)) : cleanText(s);
  String bare(String s) => plainInline(cleanText(s)).trim();

  ExStyle look(StyleRole role, BlockStyle own) =>
      ExStyle(role, styles.resolve(styles.merged(role, own)), {...own.toJson().keys});
  ExStyle part(StyleRole part, StyleRole of, BlockStyle own) => ExStyle(
    part,
    styles.resolve(styles.part(part, styles.merged(of, own))),
    {...own.toJson().keys.where(inheritedFields.contains)},
  );

  final blocks = <ExBlock>[];
  var tables = 0;
  var heading = '';
  for (final (i, page) in doc.pages.indexed) {
    if (i > 0) blocks.add(const ExPageBreak());
    for (final b in page.blocks) {
      final style = look(b.role, b.style);
      switch (b) {
        case HeadingBlock():
          heading = bare(b.text);
          blocks.add(ExHeading(b.level.clamp(1, 3), text(b.text), style));
        case ParagraphBlock():
          blocks.add(ExParagraph(text(b.text), style));
        case BulletListBlock():
          blocks.add(ExBullets([for (final item in b.items) text(item)], style));
        case TableBlock():
          tables++;
          final t = ExTable.from(
            b,
            number: tables,
            title: heading.isEmpty ? 'Tabella $tables' : heading,
            text: text,
            style: style,
            headerStyle: part(StyleRole.tableHeader, b.role, b.style),
            captionStyle: part(StyleRole.caption, b.role, b.style),
          );
          if (t.width > 0) {
            blocks.add(t);
          } else if (t.caption.isNotEmpty) {
            blocks.add(ExParagraph(t.caption, t.captionStyle));
          }
        case MetricsBlock():
          if (b.items.isNotEmpty) {
            blocks.add(ExMetrics(
              [for (final x in b.items) ExMetric(text(x.label), text(x.value), text(x.delta))],
              style,
              part(StyleRole.caption, b.role, b.style),
            ));
          }
        case QuoteBlock():
          blocks.add(ExQuote(text(b.text), text(b.author), style, part(StyleRole.caption, b.role, b.style)));
        case CalloutBlock():
          blocks.add(ExCallout(text(b.title), text(b.text), style));
        case ImageBlock():
          blocks.add(ExImage(b.bytes, text(b.caption), b.height, style, part(StyleRole.caption, b.role, b.style)));
      }
    }
  }

  // A logo is the same picture on every page that shows it: counted by identity, so a key never reads its bytes.
  final logos = Map<Uint8List, int>.identity();
  ExRegion region(RegionSlot slot, DocPage page) {
    final r = styles.region(slot);
    // A cover page shows no header or footer, as in the PDF.
    if (r.isEmpty || page.layout == PageLayout.cover) return ExRegion._none;
    final values = regionValues(doc, page);
    String fill(String s) => text(fillPlaceholders(s, values));
    final source = r.logo;
    final candidate = source == null ? null : ExLogo(source.bytes, source.height, source.align);
    final logo = candidate?.header == null ? null : candidate;
    final (left, center, right) = (fill(r.left), fill(r.center), fill(r.right));
    if (left.isEmpty && center.isEmpty && right.isEmpty && logo == null) return ExRegion._none;
    final key = jsonEncode([
      r.style.toJson(),
      left,
      center,
      right,
      r.line,
      if (logo != null) [logos.putIfAbsent(logo.bytes, () => logos.length), logo.heightPt, logo.align.name],
    ]);
    return ExRegion._(slot, left, center, right, styles.resolve(styles.regionStyle(r)), r.line, logo, key);
  }

  final shown = doc.pages.isEmpty ? const [DocPage(id: '')] : doc.pages;
  final cleanTitle = bare(m.title);
  return ExportDoc._(
    title: cleanTitle.isEmpty ? 'Documento senza titolo' : cleanTitle,
    subtitle: bare(m.subtitle),
    author: bare(m.author),
    client: bare(m.client),
    brand: bare(doc.theme.brandName),
    status: _statusLabel(m.status),
    accent: doc.theme.accent,
    created: m.createdAt,
    modified: m.updatedAt,
    page: ExPageSetup.of(styles.page),
    roles: {for (final role in StyleRole.values) role: styles.resolve(styles.merged(role))},
    blocks: blocks,
    first: ExPageRegions(region(RegionSlot.firstHeader, shown.first), region(RegionSlot.firstFooter, shown.first)),
    pages: [for (final p in shown) ExPageRegions(region(RegionSlot.header, p), region(RegionSlot.footer, p))],
  );
}
