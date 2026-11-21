/// The one walk every writer reads: a [PaperDocument] flattened into the blocks a file carries, cleaned and numbered.
///
/// A writer never looks at a page, a layout or a raw string: what the file shows is decided here once (what the
/// front matter says, how a page's label is kept, which heading names a table, how wide a column is), so the nine
/// formats cannot disagree and a change of rule is one edit.
library;

import 'dart:math' as math;
import 'dart:typed_data';

import '../model/document.dart';
import 'cell_value.dart';
import 'export_text.dart';
import 'image_info.dart';

/// A4, in twips (1/20 pt), the unit Word and RTF count in; ODF and HTML convert from here.
class ExPageSetup {
  const ExPageSetup({required this.marginXTwips});

  static const widthTwips = 11906;
  static const heightTwips = 16838;
  static const marginYTwips = 1134;
  static const footerTwips = 567;

  /// The renderer's side margin: 56 pt, 64 pt on a premium page.
  final int marginXTwips;

  int get textWidthTwips => widthTwips - 2 * marginXTwips;
  double get textWidthPt => textWidthTwips / 20;
  double get textHeightPt => (heightTwips - 2 * marginYTwips) / 20;
}

sealed class ExBlock {
  const ExBlock();
}

final class ExTitle extends ExBlock {
  const ExTitle(this.text);
  final String text;
}

final class ExSubtitle extends ExBlock {
  const ExSubtitle(this.text);
  final String text;
}

/// A line of the cover facts: `Destinatario: Acme`.
final class ExFact extends ExBlock {
  const ExFact(this.label, this.value);
  final String label;
  final String value;
}

/// A page's section label (the running header of the PDF), kept when the page's own heading does not say it.
final class ExSectionLabel extends ExBlock {
  const ExSectionLabel(this.text);
  final String text;
}

final class ExHeading extends ExBlock {
  const ExHeading(this.level, this.text);
  final int level;
  final String text;
}

final class ExParagraph extends ExBlock {
  const ExParagraph(this.text);
  final String text;
}

final class ExBullets extends ExBlock {
  const ExBullets(this.items);
  final List<String> items;
}

final class ExTable extends ExBlock {
  ExTable._({required this.title, required this.number, required this.header, required this.rows, required this.caption});

  /// A table block: cells cleaned, every row padded to the widest one (as the PDF does).
  factory ExTable.from(TableBlock t, {required int number, required String title}) {
    final width = [t.columns.length, ...t.rows.map((r) => r.length)].fold(0, math.max);
    List<String> pad(List<String> r) => [for (var i = 0; i < width; i++) i < r.length ? cleanText(r[i]) : ''];
    return ExTable._(
      title: title,
      number: number,
      header: t.columns.isEmpty ? const [] : pad(t.columns),
      rows: [for (final r in t.rows) pad(r)],
      caption: cleanText(t.caption),
    );
  }

  /// The metrics as a small table: one row per indicator.
  factory ExTable.metrics(List<ExMetric> items) {
    final delta = items.any((m) => m.delta.isNotEmpty);
    return ExTable._(
      title: 'Indicatori',
      number: 0,
      header: ['Indicatore', 'Valore', if (delta) 'Variazione'],
      rows: [for (final m in items) [m.label, m.value, if (delta) m.delta]],
      caption: '',
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

  bool get hasHeader => header.isNotEmpty;
  int get width => hasHeader ? header.length : (rows.isEmpty ? 0 : rows.first.length);

  /// Columns that hold only numbers, amounts, dates or percentages: set to the right, the way a ledger is.
  late final List<bool> numeric = [
    for (var c = 0; c < width; c++)
      () {
        var typed = 0;
        for (final r in rows) {
          final v = r[c].trim();
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

int _longestLine(String s) => s.split('\n').map((l) => l.runes.length).fold(0, math.max);

final class ExMetric {
  const ExMetric(this.label, this.value, this.delta);
  final String label;
  final String value;
  final String delta;
}

final class ExMetrics extends ExBlock {
  const ExMetrics(this.items);
  final List<ExMetric> items;
  ExTable asTable() => ExTable.metrics(items);
}

final class ExQuote extends ExBlock {
  const ExQuote(this.text, this.author);
  final String text;
  final String author;
}

final class ExCallout extends ExBlock {
  const ExCallout(this.title, this.text);
  final String title;
  final String text;
}

final class ExImage extends ExBlock {
  ExImage(this.bytes, this.caption, this.heightPt) : header = bytes == null ? null : sniffImage(bytes);

  final Uint8List? bytes;

  /// Format and pixel size when [bytes] is an image a file can carry as it is (PNG, JPEG, GIF), else null.
  final ImageHeader? header;
  final String caption;

  /// The height the PDF gives the picture; the files size the picture to the text width instead.
  final double heightPt;

  /// What a text format and a placeholder say in the image's place.
  String get marker => markerWith((s) => s);

  /// The same, with the caption passed through [escape] (a format that has metacharacters of its own).
  String markerWith(String Function(String) escape) => caption.isEmpty ? '[Immagine]' : '[Immagine: ${escape(caption)}]';

  /// The size in points, at 96 dpi, never larger than the box and never enlarged.
  (double, double) fit(double maxWidthPt, double maxHeightPt) {
    final h = header;
    if (h == null) return (maxWidthPt, heightPt);
    final w = h.width * 0.75, ht = h.height * 0.75;
    final scale = math.min(1.0, math.min(maxWidthPt / w, maxHeightPt / ht));
    return (w * scale, ht * scale);
  }
}

final class ExPageBreak extends ExBlock {
  const ExPageBreak();
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
    required this.blocks,
    required this.bodyStart,
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
  final List<ExBlock> blocks;

  /// `blocks` before this index are the front matter (title, subtitle, facts); the pages' content follows.
  final int bodyStart;

  late final List<ExTable> tables = [for (final b in blocks) if (b is ExTable) b];

  /// The document properties' author: the lawyer, or the app when nobody signed.
  String get creator => author.isEmpty ? 'Daylex' : author;

  /// The footer line, as the PDF prints it.
  String get footerText => [title, if (client.isNotEmpty) client].join('  ·  ');

  String get accentHex => hex6(accent);
  String get tintHex => tintOf(accent, 0.07);
  String get tintStrongHex => tintOf(accent, 0.16);
}

/// The palette of the PDF renderer, as `RRGGBB`.
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

String _fold(String s) => s.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');

/// Flattens [doc]: front matter first, then each page's blocks in order, a page break between pages.
ExportDoc buildExportDoc(PaperDocument doc) {
  final m = doc.metadata;
  final cleanTitle = cleanText(m.title).trim();
  final title = cleanTitle.isEmpty ? 'Documento senza titolo' : cleanTitle;
  final blocks = <ExBlock>[ExTitle(title)];

  final subtitle = cleanText(m.subtitle).trim();
  if (subtitle.isNotEmpty) blocks.add(ExSubtitle(subtitle));
  final client = cleanText(m.client).trim();
  final author = cleanText(m.author).trim();
  if (client.isNotEmpty) blocks.add(ExFact('Destinatario', client));
  if (author.isNotEmpty) blocks.add(ExFact('Redatto da', author));
  blocks.add(ExFact('Data', monthYear(m.updatedAt)));
  final bodyStart = blocks.length;

  var tables = 0;
  var heading = '';
  for (final (i, page) in doc.pages.indexed) {
    if (i > 0) blocks.add(const ExPageBreak());
    final label = cleanText(page.title).trim();
    final first = page.blocks.firstOrNull;
    if (label.isNotEmpty && !(first is HeadingBlock && _fold(cleanText(first.text)) == _fold(label))) {
      blocks.add(ExSectionLabel(label));
    }
    for (final b in page.blocks) {
      switch (b) {
        case HeadingBlock():
          heading = cleanText(b.text).trim();
          blocks.add(ExHeading(b.level.clamp(1, 3), cleanText(b.text)));
        case ParagraphBlock():
          blocks.add(ExParagraph(cleanText(b.text)));
        case BulletListBlock():
          blocks.add(ExBullets([for (final item in b.items) cleanText(item)]));
        case TableBlock():
          tables++;
          final t = ExTable.from(b, number: tables, title: heading.isEmpty ? 'Tabella $tables' : heading);
          if (t.width > 0) {
            blocks.add(t);
          } else if (t.caption.isNotEmpty) {
            blocks.add(ExParagraph(t.caption));
          }
        case MetricsBlock():
          if (b.items.isNotEmpty) {
            blocks.add(ExMetrics([for (final x in b.items) ExMetric(cleanText(x.label), cleanText(x.value), cleanText(x.delta))]));
          }
        case QuoteBlock():
          blocks.add(ExQuote(cleanText(b.text), cleanText(b.author)));
        case CalloutBlock():
          blocks.add(ExCallout(cleanText(b.title), cleanText(b.text)));
        case ImageBlock():
          blocks.add(ExImage(b.bytes, cleanText(b.caption), b.height));
      }
    }
  }

  final premium = doc.pages.isNotEmpty && doc.pages.every((p) => p.layout == PageLayout.premium);
  return ExportDoc._(
    title: title,
    subtitle: subtitle,
    author: author,
    client: client,
    brand: cleanText(doc.theme.brandName).trim(),
    status: _statusLabel(m.status),
    accent: doc.theme.accent,
    created: m.createdAt,
    modified: m.updatedAt,
    page: ExPageSetup(marginXTwips: premium ? 1280 : 1120),
    blocks: blocks,
    bodyStart: bodyStart,
  );
}
