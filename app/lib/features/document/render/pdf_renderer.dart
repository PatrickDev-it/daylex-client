import '../../../l10n/app_localizations_it.dart';

import 'dart:isolate';
import 'dart:typed_data';

import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../model/document.dart';

/// Width over height of the pages the renderer makes (A4): placeholders and thumbnails take this shape.
final kA4AspectRatio = PdfPageFormat.a4.width / PdfPageFormat.a4.height;

/// Raw font files handed to the renderer. Plain bytes, so they can cross an
/// isolate boundary together with the document.
class PdfFontSet {
  const PdfFontSet({
    required this.regular,
    required this.medium,
    required this.semiBold,
    required this.bold,
  });

  final Uint8List regular;
  final Uint8List medium;
  final Uint8List semiBold;
  final Uint8List bold;

  static Future<PdfFontSet> load() async {
    Future<Uint8List> read(String name) async =>
        (await rootBundle.load('assets/fonts/$name')).buffer.asUint8List();
    return PdfFontSet(
      regular: await read('Inter-Regular.ttf'),
      medium: await read('Inter-Medium.ttf'),
      semiBold: await read('Inter-SemiBold.ttf'),
      bold: await read('Inter-Bold.ttf'),
    );
  }
}

/// Converts a [PaperDocument] into PDF bytes. One model page always produces
/// exactly one PDF page, so "page 3" means the same thing to the user, the
/// agent and the viewer.
class PdfRenderer {
  const PdfRenderer(this.fonts);

  final PdfFontSet fonts;

  /// Renders on a background isolate to keep the UI responsive.
  Future<Uint8List> renderInBackground(PaperDocument doc) {
    if (kIsWeb) return render(doc);
    final fonts = this.fonts;
    return Isolate.run(() => PdfRenderer(fonts).render(doc));
  }

  Future<Uint8List> render(PaperDocument doc) {
    final f = _Fonts(
      regular: pw.Font.ttf(_byteData(fonts.regular)),
      medium: pw.Font.ttf(_byteData(fonts.medium)),
      semiBold: pw.Font.ttf(_byteData(fonts.semiBold)),
      bold: pw.Font.ttf(_byteData(fonts.bold)),
    );
    final pdf = pw.Document(
      title: doc.title,
      author: doc.metadata.author,
      creator: 'PaperAgent',
      theme: pw.ThemeData.withFont(base: f.regular, bold: f.bold),
    );
    final style = _Style(PdfColor.fromInt(doc.theme.accent), f);
    for (var i = 0; i < doc.pages.length; i++) {
      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          margin: pw.EdgeInsets.zero,
          build: (_) => _PageBuilder(doc, i, style).build(),
        ),
      );
    }
    return pdf.save();
  }

  static ByteData _byteData(Uint8List bytes) =>
      bytes.buffer.asByteData(bytes.offsetInBytes, bytes.lengthInBytes);
}

class _Fonts {
  const _Fonts({
    required this.regular,
    required this.medium,
    required this.semiBold,
    required this.bold,
  });

  final pw.Font regular;
  final pw.Font medium;
  final pw.Font semiBold;
  final pw.Font bold;
}

/// An export must contain all text. Page numbers remain identical to the editor.
class PdfLayoutException implements Exception {
  const PdfLayoutException(this.page);
  final int page;
  @override
  String toString() =>
      'La pagina $page contiene più testo dello spazio disponibile. '
      'Suddividi il contenuto su più pagine prima di esportare il PDF.';
}

class _FitContent extends pw.SingleChildWidget {
  _FitContent({required pw.Widget child, required this.page})
    : super(child: child);
  final int page;

  @override
  void layout(
    pw.Context context,
    pw.BoxConstraints constraints, {
    bool parentUsesSize = false,
  }) {
    child!.layout(
      context,
      pw.BoxConstraints(
        minWidth: constraints.minWidth,
        maxWidth: constraints.maxWidth,
      ),
      parentUsesSize: true,
    );
    final measured = child!.box!;
    if (measured.height > constraints.maxHeight + 0.1 ||
        measured.width > constraints.maxWidth + 0.1) {
      throw PdfLayoutException(page);
    }
    box = constraints.constrainRect(
      width: measured.width,
      height: measured.height,
    );
    child!.box = PdfRect(
      0,
      box!.height - measured.height,
      measured.width,
      measured.height,
    );
  }

  @override
  void paint(pw.Context context) {
    super.paint(context);
    paintChild(context);
  }
}

class _Style {
  _Style(this.accent, this.fonts)
    : tint = _mix(accent, 0.07),
      tintStrong = _mix(accent, 0.16);

  final PdfColor accent;
  final PdfColor tint;
  final PdfColor tintStrong;
  final _Fonts fonts;

  static const ink = PdfColor.fromInt(0xFF0F172A);
  static const body = PdfColor.fromInt(0xFF334155);
  static const muted = PdfColor.fromInt(0xFF64748B);
  static const hairline = PdfColor.fromInt(0xFFE2E8F0);
  static const zebra = PdfColor.fromInt(0xFFF8FAFC);
  static const positive = PdfColor.fromInt(0xFF059669);
  static const negative = PdfColor.fromInt(0xFFDC2626);

  /// Blends [c] over white with the given opacity.
  static PdfColor _mix(PdfColor c, double opacity) => PdfColor(
    1 - (1 - c.red) * opacity,
    1 - (1 - c.green) * opacity,
    1 - (1 - c.blue) * opacity,
  );

  pw.TextStyle text(
    double size, {
    pw.Font? font,
    PdfColor color = body,
    double lineSpacing = 0,
    double letterSpacing = 0,
  }) => pw.TextStyle(
    font: font ?? fonts.regular,
    fontSize: size,
    color: color,
    lineSpacing: lineSpacing,
    letterSpacing: letterSpacing,
  );
}

class _PageBuilder {
  _PageBuilder(this.doc, this.index, this.s);

  final PaperDocument doc;
  final int index;
  final _Style s;

  DocPage get page => doc.pages[index];
  bool get premium => page.layout == PageLayout.premium;

  pw.Widget build() => switch (page.layout) {
    PageLayout.cover => _cover(),
    PageLayout.twoColumn => _frame(_twoColumns()),
    PageLayout.standard || PageLayout.premium => _frame(
      pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.stretch,
        children: _blocks(page.blocks),
      ),
    ),
  };

  // -- chrome ---------------------------------------------------------------

  pw.Widget _frame(pw.Widget content) {
    final horizontal = premium ? 64.0 : 56.0;
    return pw.Stack(
      children: [
        if (premium)
          pw.Positioned(
            left: 0,
            top: 0,
            bottom: 0,
            child: pw.Container(width: 6, color: s.accent),
          ),
        pw.Padding(
          padding: pw.EdgeInsets.fromLTRB(horizontal, 40, horizontal, 36),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.stretch,
            children: [
              _header(),
              pw.SizedBox(height: premium ? 36 : 28),
              pw.Expanded(
                child: _FitContent(page: index + 1, child: content),
              ),
              _footer(),
            ],
          ),
        ),
      ],
    );
  }

  pw.Widget _header() {
    final brand = doc.theme.brandName.isNotEmpty
        ? doc.theme.brandName
        : doc.title;
    return pw.Container(
      padding: const pw.EdgeInsets.only(bottom: 10),
      decoration: const pw.BoxDecoration(
        border: pw.Border(bottom: pw.BorderSide(color: _Style.hairline)),
      ),
      child: pw.Row(
        children: [
          pw.Container(
            width: 7,
            height: 7,
            decoration: pw.BoxDecoration(
              color: s.accent,
              borderRadius: pw.BorderRadius.circular(2),
            ),
          ),
          pw.SizedBox(width: 7),
          pw.Expanded(
            child: pw.Text(
              brand,
              style: s.text(8.5, font: s.fonts.semiBold, color: _Style.ink),
            ),
          ),
          pw.SizedBox(width: 12),
          pw.Expanded(
            child: pw.Text(
              page.title.toUpperCase(),
              textAlign: pw.TextAlign.right,
              style: s.text(
                7.5,
                font: s.fonts.semiBold,
                color: s.accent,
                letterSpacing: 0.8,
              ),
            ),
          ),
        ],
      ),
    );
  }

  pw.Widget _footer() {
    final left = [
      doc.title,
      if (doc.metadata.client.isNotEmpty) doc.metadata.client,
    ].join('  ·  ');
    return pw.Container(
      padding: const pw.EdgeInsets.only(top: 10),
      decoration: const pw.BoxDecoration(
        border: pw.Border(top: pw.BorderSide(color: _Style.hairline)),
      ),
      child: pw.Row(
        children: [
          pw.Expanded(
            child: pw.Text(left, style: s.text(7.5, color: _Style.muted)),
          ),
          pw.SizedBox(width: 12),
          pw.Text(
            '${index + 1} / ${doc.pages.length}',
            style: s.text(7.5, font: s.fonts.medium, color: _Style.muted),
          ),
        ],
      ),
    );
  }

  pw.Widget _cover() {
    final meta = doc.metadata;
    final date = meta.updatedAt;
    // Export language is Italian, independent of the UI language and isolate locale.
    final labels = AppLocalizationsIt();
    final months = labels.pdfMonthNames.split(';');
    final dateLabel = '${months[date.month - 1]} ${date.year}';
    const white = PdfColors.white;
    final softWhite = PdfColor(1, 1, 1, 0.72);

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.stretch,
      children: [
        pw.Container(
          height: 470,
          color: s.accent,
          padding: const pw.EdgeInsets.fromLTRB(64, 56, 64, 56),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                (doc.theme.brandName.isEmpty
                        ? 'PaperAgent'
                        : doc.theme.brandName)
                    .toUpperCase(),
                style: s.text(
                  8.5,
                  font: s.fonts.semiBold,
                  color: softWhite,
                  letterSpacing: 1.6,
                ),
              ),
              pw.Expanded(
                child: pw.Align(
                  alignment: pw.Alignment.bottomLeft,
                  child: _FitContent(
                    page: index + 1,
                    child: pw.Column(
                      mainAxisSize: pw.MainAxisSize.min,
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        if (page.title.isNotEmpty) ...[
                          pw.Text(
                            page.title.toUpperCase(),
                            style: s.text(
                              9,
                              font: s.fonts.semiBold,
                              color: softWhite,
                              letterSpacing: 1.2,
                            ),
                          ),
                          pw.SizedBox(height: 14),
                        ],
                        pw.Text(
                          meta.title,
                          style: s
                              .text(38, font: s.fonts.bold, color: white)
                              .copyWith(lineSpacing: 2),
                        ),
                        if (meta.subtitle.isNotEmpty) ...[
                          pw.SizedBox(height: 14),
                          pw.Text(
                            meta.subtitle,
                            style: s.text(14, color: softWhite, lineSpacing: 3),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        pw.Expanded(
          child: pw.Padding(
            padding: const pw.EdgeInsets.fromLTRB(64, 40, 64, 48),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.stretch,
              children: [
                pw.Row(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    if (meta.client.isNotEmpty)
                      pw.Expanded(
                        child: _coverFact(labels.pdfPreparedFor, meta.client),
                      ),
                    if (meta.author.isNotEmpty)
                      pw.Expanded(
                        child: _coverFact(labels.pdfPreparedBy, meta.author),
                      ),
                    pw.Expanded(child: _coverFact(labels.pdfDate, dateLabel)),
                  ],
                ),
                pw.SizedBox(height: 28),
                pw.Expanded(
                  child: _FitContent(
                    page: index + 1,
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.stretch,
                      children: _blocks(page.blocks),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  pw.Widget _coverFact(String label, String value) => pw.Column(
    crossAxisAlignment: pw.CrossAxisAlignment.start,
    children: [
      pw.Text(
        label.toUpperCase(),
        style: s.text(
          7,
          font: s.fonts.semiBold,
          color: _Style.muted,
          letterSpacing: 1,
        ),
      ),
      pw.SizedBox(height: 5),
      pw.Text(
        value,
        style: s.text(11, font: s.fonts.semiBold, color: _Style.ink),
      ),
    ],
  );

  pw.Widget _twoColumns() {
    final blocks = page.blocks;
    // A leading heading spans both columns; the rest is balanced by length.
    final lead = blocks.isNotEmpty && blocks.first is HeadingBlock
        ? blocks.first
        : null;
    final rest = lead == null ? blocks : blocks.sublist(1);

    // Keep each heading together with the blocks that follow it.
    final groups = <List<DocBlock>>[];
    for (final b in rest) {
      if (groups.isEmpty || b is HeadingBlock) groups.add([]);
      groups.last.add(b);
    }
    final total = groups.fold(
      0,
      (sum, g) => sum + g.fold(0, (s, b) => s + _weight(b)),
    );
    final left = <DocBlock>[];
    final right = <DocBlock>[];
    var leftWeight = 0;
    // Fill the left column in reading order until it holds about half.
    for (final g in groups) {
      final w = g.fold(0, (s, b) => s + _weight(b));
      if (right.isEmpty && (left.isEmpty || leftWeight + w / 2 <= total / 2)) {
        left.addAll(g);
        leftWeight += w;
      } else {
        right.addAll(g);
      }
    }
    pw.Widget column(List<DocBlock> b) => pw.Expanded(
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.stretch,
        children: _blocks(b),
      ),
    );
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.stretch,
      children: [
        if (lead != null) ...[
          ..._blocks([lead]),
          pw.SizedBox(height: 18),
        ],
        pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [column(left), pw.SizedBox(width: 28), column(right)],
        ),
      ],
    );
  }

  int _weight(DocBlock b) => switch (b) {
    TableBlock(:final rows) => 60 + rows.length * 22,
    MetricsBlock() => 90,
    ImageBlock(:final height) => height.round(),
    _ => 30 + b.plainText.length ~/ 3,
  };

  // -- blocks ---------------------------------------------------------------

  List<pw.Widget> _blocks(List<DocBlock> blocks) {
    final gap = premium ? 18.0 : 14.0;
    return [
      for (var i = 0; i < blocks.length; i++) ...[
        if (i > 0) pw.SizedBox(height: _gapBefore(blocks[i], gap)),
        _block(blocks[i]),
      ],
    ];
  }

  double _gapBefore(DocBlock b, double gap) =>
      b is HeadingBlock && b.level <= 2 ? gap + 10 : gap;

  pw.Widget _block(DocBlock block) => switch (block) {
    HeadingBlock() => _heading(block),
    ParagraphBlock(:final text) => pw.Text(
      text,
      style: s.text(premium ? 11 : 10, lineSpacing: premium ? 5 : 4),
    ),
    BulletListBlock(:final items) => _bullets(items),
    TableBlock() => _table(block),
    MetricsBlock(:final items) => _metrics(items),
    QuoteBlock() => _quote(block),
    CalloutBlock() => _callout(block),
    ImageBlock() => _image(block),
  };

  pw.Widget _heading(HeadingBlock h) => switch (h.level) {
    1 => pw.Text(
      h.text,
      style: s.text(
        premium ? 28 : 22,
        font: s.fonts.bold,
        color: _Style.ink,
        lineSpacing: 2,
        letterSpacing: -0.3,
      ),
    ),
    2 => pw.Text(
      h.text,
      style: s.text(
        premium ? 16 : 14,
        font: s.fonts.semiBold,
        color: _Style.ink,
      ),
    ),
    _ => pw.Text(
      h.text.toUpperCase(),
      style: s.text(
        8,
        font: s.fonts.semiBold,
        color: s.accent,
        letterSpacing: 1,
      ),
    ),
  };

  pw.Widget _bullets(List<String> items) => pw.Column(
    crossAxisAlignment: pw.CrossAxisAlignment.stretch,
    children: [
      for (final item in items)
        pw.Padding(
          padding: const pw.EdgeInsets.only(bottom: 6),
          child: pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Container(
                margin: const pw.EdgeInsets.only(top: 4.5, right: 10),
                width: 4,
                height: 4,
                decoration: pw.BoxDecoration(
                  color: s.accent,
                  shape: pw.BoxShape.circle,
                ),
              ),
              pw.Expanded(
                child: pw.Text(
                  item,
                  style: s.text(premium ? 10.5 : 10, lineSpacing: 3),
                ),
              ),
            ],
          ),
        ),
    ],
  );

  pw.Widget _table(TableBlock t) {
    final columnCount = [
      t.columns.length,
      ...t.rows.map((r) => r.length),
    ].fold(0, (a, b) => a > b ? a : b);
    if (columnCount == 0) return pw.SizedBox();
    List<String> pad(List<String> r) => [
      ...r,
      ...List.filled(columnCount - r.length, ''),
    ];

    pw.Widget cell(String text, {bool header = false, bool first = false}) =>
        pw.Padding(
          padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 7),
          child: pw.Text(
            header ? text.toUpperCase() : text,
            textAlign: first ? pw.TextAlign.left : pw.TextAlign.right,
            style: header
                ? s.text(
                    7,
                    font: s.fonts.semiBold,
                    color: s.accent,
                    letterSpacing: 0.6,
                  )
                : s.text(
                    9,
                    font: first ? s.fonts.medium : s.fonts.regular,
                    color: first ? _Style.ink : _Style.body,
                  ),
          ),
        );

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.stretch,
      children: [
        pw.Table(
          border: const pw.TableBorder(
            horizontalInside: pw.BorderSide(color: _Style.hairline, width: 0.6),
            bottom: pw.BorderSide(color: _Style.hairline, width: 0.6),
          ),
          columnWidths: {0: const pw.FlexColumnWidth(1.6)},
          children: [
            if (t.columns.isNotEmpty)
              pw.TableRow(
                decoration: pw.BoxDecoration(color: s.tint),
                children: [
                  for (final (i, c) in pad(t.columns).indexed)
                    cell(c, header: true, first: i == 0),
                ],
              ),
            for (final (r, row) in t.rows.indexed)
              pw.TableRow(
                decoration: r.isOdd
                    ? const pw.BoxDecoration(color: _Style.zebra)
                    : null,
                children: [
                  for (final (i, c) in pad(row).indexed) cell(c, first: i == 0),
                ],
              ),
          ],
        ),
        if (t.caption.isNotEmpty)
          pw.Padding(
            padding: const pw.EdgeInsets.only(top: 6),
            child: pw.Text(t.caption, style: s.text(7.5, color: _Style.muted)),
          ),
      ],
    );
  }

  pw.Widget _metrics(List<Metric> items) {
    if (items.isEmpty) return pw.SizedBox();
    pw.Widget tile(Metric m) {
      final negative = m.delta.trim().startsWith('-');
      return pw.Container(
        padding: const pw.EdgeInsets.fromLTRB(14, 12, 14, 12),
        decoration: pw.BoxDecoration(
          color: s.tint,
          borderRadius: pw.BorderRadius.circular(6),
        ),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(
              m.label.toUpperCase(),
              style: s.text(
                6.5,
                font: s.fonts.semiBold,
                color: _Style.muted,
                letterSpacing: 0.7,
              ),
            ),
            pw.SizedBox(height: 6),
            pw.Text(
              m.value,
              style: s.text(
                premium ? 20 : 17,
                font: s.fonts.bold,
                color: _Style.ink,
              ),
            ),
            if (m.delta.isNotEmpty) ...[
              pw.SizedBox(height: 3),
              pw.Text(
                m.delta,
                style: s.text(
                  7.5,
                  font: s.fonts.medium,
                  color: negative ? _Style.negative : _Style.positive,
                ),
              ),
            ],
          ],
        ),
      );
    }

    return pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        for (final (i, m) in items.indexed) ...[
          if (i > 0) pw.SizedBox(width: 10),
          pw.Expanded(child: tile(m)),
        ],
      ],
    );
  }

  pw.Widget _quote(QuoteBlock q) => pw.Container(
    padding: const pw.EdgeInsets.fromLTRB(16, 4, 0, 4),
    decoration: pw.BoxDecoration(
      border: pw.Border(left: pw.BorderSide(color: s.accent, width: 2.5)),
    ),
    child: pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          q.text,
          style: s.text(
            premium ? 15 : 13,
            font: s.fonts.medium,
            color: _Style.ink,
            lineSpacing: 4,
          ),
        ),
        if (q.author.isNotEmpty) ...[
          pw.SizedBox(height: 8),
          pw.Text(q.author, style: s.text(8.5, color: _Style.muted)),
        ],
      ],
    ),
  );

  pw.Widget _callout(CalloutBlock c) => pw.Container(
    padding: const pw.EdgeInsets.all(14),
    decoration: pw.BoxDecoration(
      color: s.tint,
      border: pw.Border.all(color: s.tintStrong, width: 0.8),
      borderRadius: pw.BorderRadius.circular(6),
    ),
    child: pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          c.title,
          style: s.text(10, font: s.fonts.semiBold, color: _Style.ink),
        ),
        if (c.text.isNotEmpty) ...[
          pw.SizedBox(height: 5),
          pw.Text(c.text, style: s.text(9.5, lineSpacing: 3)),
        ],
      ],
    ),
  );

  pw.Widget _image(ImageBlock img) {
    final bytes = img.bytes;
    final picture = bytes != null
        ? pw.ClipRRect(
            horizontalRadius: 6,
            verticalRadius: 6,
            child: pw.Image(
              pw.MemoryImage(bytes),
              height: img.height,
              fit: pw.BoxFit.cover,
            ),
          )
        : pw.Container(
            height: img.height,
            decoration: pw.BoxDecoration(
              color: s.tint,
              borderRadius: pw.BorderRadius.circular(6),
            ),
            alignment: pw.Alignment.center,
            child: pw.Text(
              'IMAGE',
              style: s.text(
                8,
                font: s.fonts.semiBold,
                color: s.accent,
                letterSpacing: 1.2,
              ),
            ),
          );
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.stretch,
      children: [
        picture,
        if (img.caption.isNotEmpty)
          pw.Padding(
            padding: const pw.EdgeInsets.only(top: 6),
            child: pw.Text(
              img.caption,
              style: s.text(7.5, color: _Style.muted),
            ),
          ),
      ],
    );
  }
}
