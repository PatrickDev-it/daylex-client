import 'dart:isolate';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/services.dart' show rootBundle;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../model/document.dart';
import '../model/inline.dart';
import 'pdfa.dart';

/// Width over height of an A4 page upright: placeholders and thumbnails take this shape until a page is drawn.
final kA4AspectRatio = PdfPageFormat.a4.width / PdfPageFormat.a4.height;

/// The paper of [doc]: A4, upright or landscape as its style says.
PdfPageFormat pageFormatOf(PaperDocument doc) =>
    DocStyles(doc.theme).page.orientation == PageOrientation.landscape
    ? PdfPageFormat.a4.landscape
    : PdfPageFormat.a4;

/// Width over height of [doc]'s pages.
double pageAspectRatio(PaperDocument doc) {
  final format = pageFormatOf(doc);
  return format.width / format.height;
}

/// Raw font files handed to the renderer, and the colour profile its PDF/A output intent embeds. Plain bytes,
/// so they can cross an isolate boundary together with the document.
class PdfFontSet {
  const PdfFontSet({required this.faces, required this.colorProfile});

  /// The faces of each typeface, in [faceNames] order.
  final Map<DocFont, List<Uint8List>> faces;

  /// sRGB2014.icc, unchanged (assets/icc/LICENSE.txt).
  final Uint8List colorProfile;

  /// The four files of a typeface: `assets/fonts/<asset>-<name>.ttf`, regular, bold, italic, bold italic.
  static const faceNames = ['Regular', 'Bold', 'Italic', 'BoldItalic'];

  static Future<PdfFontSet> load() async {
    Future<Uint8List> read(String path) async =>
        (await rootBundle.load('assets/$path')).buffer.asUint8List();
    return PdfFontSet(
      faces: {
        for (final font in DocFont.values)
          font: [
            for (final face in faceNames)
              await read('fonts/${font.asset}-$face.ttf'),
          ],
      },
      colorProfile: await read('icc/sRGB2014.icc'),
    );
  }
}

/// Converts a [PaperDocument] into PDF bytes. One model page always produces
/// exactly one PDF page, so "page 3" means the same thing to the user, the
/// agent and the viewer. Every PDF it makes, the preview's included, is PDF/A-1b
/// ([newPdfaDocument]): the lawyer exports what the preview shows.
///
/// Nothing on a page is drawn that the document does not say (rfc/055): every size, colour, line and text comes from
/// [DocStyles], the document's style over its base.
class PdfRenderer {
  const PdfRenderer(this.fonts);

  final PdfFontSet fonts;

  /// Renders on a background isolate to keep the UI responsive.
  Future<Uint8List> renderInBackground(PaperDocument doc) {
    if (kIsWeb) return render(doc);
    final fonts = this.fonts;
    return Isolate.run(() => PdfRenderer(fonts).render(doc));
  }

  /// [doc] as a PDF. [firstPage] (0-based) and [pageCount] place its pages in a longer document, as the page
  /// fitter measures one page at a time: they decide the first-page header and the page numbers.
  Future<Uint8List> render(PaperDocument doc, {int firstPage = 0, int? pageCount}) {
    final faces = _Faces(fonts);
    final styles = DocStyles(doc.theme);
    final body = styles.resolve(styles.merged(StyleRole.body));
    final pdf = newPdfaDocument(
      title: doc.title,
      author: doc.metadata.author,
      application: 'Daylex',
      colorProfile: fonts.colorProfile,
      theme: pw.ThemeData.withFont(
        base: faces.font(body.font),
        bold: faces.font(body.font, bold: true),
        italic: faces.font(body.font, italic: true),
        boldItalic: faces.font(body.font, bold: true, italic: true),
      ),
    );
    final format = pageFormatOf(doc);
    final total = pageCount ?? doc.pages.length;
    for (var i = 0; i < doc.pages.length; i++) {
      pdf.addPage(
        pw.Page(
          pageFormat: format,
          margin: pw.EdgeInsets.zero,
          build: (_) => _PageBuilder(doc, styles, faces, doc.pages[i], firstPage + i, total).build(),
        ),
      );
    }
    return pdf.save();
  }
}

ByteData _byteData(Uint8List bytes) => bytes.buffer.asByteData(bytes.offsetInBytes, bytes.lengthInBytes);

/// The faces one render uses, read from [PdfFontSet] the first time each is asked for: a typeface the document never
/// names is neither parsed nor embedded.
class _Faces {
  _Faces(this.set);

  final PdfFontSet set;
  final _fonts = <(DocFont, int), pw.Font>{};
  final _metrics = <DocFont, _Metrics>{};

  pw.Font font(DocFont font, {bool bold = false, bool italic = false}) {
    final face = (bold ? 1 : 0) + (italic ? 2 : 0);
    return _fonts[(font, face)] ??= pw.Font.ttf(_byteData(set.faces[font]![face]));
  }

  _Metrics metrics(DocFont font) => _metrics[font] ??= _Metrics(TtfParser(_byteData(set.faces[font]![0])));
}

/// A typeface's line, as a fraction of its size: what the PDF library stacks ([natural], ascender to descender)
/// and what a word processor calls single spacing ([single], with the line gap).
class _Metrics {
  _Metrics(TtfParser font)
    : natural = (font.ascent - font.descent) / font.unitsPerEm,
      single = (font.ascent - font.descent + font.lineGap) / font.unitsPerEm;

  final double natural;
  final double single;
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

/// Lays its child out without a height limit and refuses, with a [PdfLayoutException], one taller than the space
/// it is given: a page never loses text silently.
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

/// Where a page's parts go, in points.
class _Geometry {
  _Geometry(PageSetup page)
    : top = cmToPt(page.margin('top') ?? 0),
      right = cmToPt(page.margin('right') ?? 0),
      bottom = cmToPt(page.margin('bottom') ?? 0),
      left = cmToPt(page.margin('left') ?? 0),
      header = cmToPt(page.header ?? 0),
      footer = cmToPt(page.footer ?? 0);

  final double top;
  final double right;
  final double bottom;
  final double left;

  /// From the top edge to the header's top.
  final double header;

  /// From the bottom edge to the footer's bottom.
  final double footer;
}

/// The text of a page between its margins, pushed down by a header (up by a footer) that reaches past its margin,
/// as a word processor does. Laid out after the header and footer, whose sizes it reads.
class _Body extends pw.SingleChildWidget {
  _Body({
    required pw.Widget child,
    required this.geometry,
    required this.page,
    this.header,
    this.headerGap = 0,
    this.footer,
    this.footerGap = 0,
  }) : super(child: child);

  final _Geometry geometry;
  final int page;
  final pw.Widget? header;
  final double headerGap;
  final pw.Widget? footer;
  final double footerGap;

  @override
  void layout(pw.Context context, pw.BoxConstraints constraints, {bool parentUsesSize = false}) {
    final g = geometry;
    box = PdfRect(0, 0, constraints.maxWidth, constraints.maxHeight);
    final top = math.max(g.top, header == null ? 0.0 : g.header + header!.box!.height + headerGap);
    final bottom = math.max(g.bottom, footer == null ? 0.0 : g.footer + footer!.box!.height + footerGap);
    final width = box!.width - g.left - g.right;
    final height = box!.height - top - bottom;
    if (width <= 0 || height <= 0) throw PdfLayoutException(page);
    child!.layout(
      context,
      pw.BoxConstraints(minWidth: width, maxWidth: width, maxHeight: height),
      parentUsesSize: true,
    );
    final laid = child!.box!;
    child!.box = PdfRect(g.left, bottom + height - laid.height, width, laid.height);
  }

  @override
  void paint(pw.Context context) {
    super.paint(context);
    paintChild(context);
  }
}

class _PageBuilder {
  _PageBuilder(this.doc, this.styles, this.faces, this.page, this.number, this.total);

  final PaperDocument doc;
  final DocStyles styles;
  final _Faces faces;
  final DocPage page;

  /// 0-based, in the whole document.
  final int number;
  final int total;

  pw.Widget build() {
    final g = _Geometry(styles.page);
    final cover = page.layout == PageLayout.cover;
    final first = number == 0;
    final header = cover ? null : _region(styles.region(first ? RegionSlot.firstHeader : RegionSlot.header), true);
    final footer = cover ? null : _region(styles.region(first ? RegionSlot.firstFooter : RegionSlot.footer), false);
    final content = page.layout == PageLayout.twoColumn
        ? _twoColumns()
        : pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.stretch, children: _blocks(page.blocks));
    return pw.Stack(
      children: [
        if (header case (final widget, _))
          pw.Positioned(left: g.left, right: g.right, top: g.header, child: widget),
        if (footer case (final widget, _))
          pw.Positioned(left: g.left, right: g.right, bottom: g.footer, child: widget),
        pw.Positioned(
          left: 0,
          top: 0,
          right: 0,
          bottom: 0,
          child: _Body(
            geometry: g,
            page: number + 1,
            header: header?.$1,
            headerGap: header?.$2.spaceAfter ?? 0,
            footer: footer?.$1,
            footerGap: footer?.$2.spaceBefore ?? 0,
            child: _FitContent(page: number + 1, child: content),
          ),
        ),
      ],
    );
  }

  // -- text -----------------------------------------------------------------

  /// The space a line of [s] gets beyond what the PDF library stacks, so [ResolvedStyle.lineHeight] is the word
  /// processor's: 1.5 is Word's «1,5 righe» for this typeface.
  double _extra(ResolvedStyle s) {
    final m = faces.metrics(s.font);
    return s.size * (s.lineHeight * m.single - m.natural);
  }

  pw.TextStyle _textStyle(ResolvedStyle s, {bool bold = false, bool italic = false, bool underline = false}) =>
      pw.TextStyle(
        font: faces.font(s.font, bold: s.bold || bold, italic: s.italic || italic),
        fontSize: s.size,
        color: PdfColor.fromInt(s.color),
        lineSpacing: _extra(s),
        decoration: s.underline || underline ? pw.TextDecoration.underline : pw.TextDecoration.none,
      );

  static pw.TextAlign _align(BlockAlign align) => switch (align) {
    BlockAlign.left => pw.TextAlign.left,
    BlockAlign.center => pw.TextAlign.center,
    BlockAlign.right => pw.TextAlign.right,
    BlockAlign.justify => pw.TextAlign.justify,
  };

  /// [text] in [s], its emphasis ([parseInline]) kept. Each line is as tall as [ResolvedStyle.lineHeight] makes it,
  /// the extra space above the text as Word puts it.
  pw.Widget _text(String text, ResolvedStyle s) {
    final extra = _extra(s);
    return pw.Padding(
      padding: pw.EdgeInsets.only(top: math.max(0, extra)),
      child: pw.RichText(
        textAlign: _align(s.align),
        text: pw.TextSpan(
          style: _textStyle(s),
          children: [
            if (s.firstLineIndent > 0) pw.WidgetSpan(child: pw.SizedBox(width: s.firstLineIndent)),
            for (final run in parseInline(text))
              pw.TextSpan(
                text: s.cased(run.text),
                style: _textStyle(s, bold: run.bold, italic: run.italic, underline: run.underline),
              ),
          ],
        ),
      ),
    );
  }

  ResolvedStyle _resolve(BlockStyle style, [Map<String, Object>? patch]) =>
      styles.resolve(patch == null ? style : style.patch(patch));

  /// [child] inside the box [s] describes: background, border, padding, and the indent outside them.
  pw.Widget _box(ResolvedStyle s, pw.Widget child, {bool indent = true}) {
    final side = pw.BorderSide(color: PdfColor.fromInt(s.lineColor), width: s.borderWidth);
    final border = s.borderWidth <= 0
        ? null
        : switch (s.border) {
            BlockBorder.none => null,
            BlockBorder.left => pw.Border(left: side),
            BlockBorder.top => pw.Border(top: side),
            BlockBorder.bottom => pw.Border(bottom: side),
            BlockBorder.box => pw.Border.fromBorderSide(side),
          };
    var widget = child;
    if (border != null || s.background != null || s.padding > 0) {
      widget = pw.Container(
        padding: pw.EdgeInsets.all(s.padding),
        decoration: pw.BoxDecoration(
          color: s.background == null ? null : PdfColor.fromInt(s.background!),
          border: border,
        ),
        child: child,
      );
    }
    return indent && s.indent > 0 ? pw.Padding(padding: pw.EdgeInsets.only(left: s.indent), child: widget) : widget;
  }

  // -- headers and footers ----------------------------------------------------

  /// The header (or footer) [r] for this page, and its style; null when it shows nothing.
  (pw.Widget, ResolvedStyle)? _region(PageRegion r, bool header) {
    if (r.isEmpty) return null;
    final style = styles.regionStyle(r);
    final s = styles.resolve(style);
    final values = {...regionValues(doc, page), 'pagina': '${number + 1}', 'pagine': '$total'};
    final logo = r.logo;
    final logoAlign = logo?.align == BlockAlign.justify ? BlockAlign.left : logo?.align;
    pw.Widget? part(String text, BlockAlign align) {
      final filled = fillPlaceholders(text, values);
      final hasLogo = logo != null && logoAlign == align;
      if (filled.isEmpty && !hasLogo) return null;
      return pw.Column(
        crossAxisAlignment: switch (align) {
          BlockAlign.center => pw.CrossAxisAlignment.center,
          BlockAlign.right => pw.CrossAxisAlignment.end,
          _ => pw.CrossAxisAlignment.start,
        },
        children: [
          if (hasLogo) pw.Image(OpaqueImage(logo.bytes), height: logo.height),
          if (hasLogo && filled.isNotEmpty) pw.SizedBox(height: 4),
          if (filled.isNotEmpty) _text(filled, _resolve(style, {'align': align.name, 'firstLineIndent': 0})),
        ],
      );
    }

    final left = part(r.left, BlockAlign.left);
    final center = part(r.center, BlockAlign.center);
    final right = part(r.right, BlockAlign.right);
    final present = [?left, ?center, ?right];
    if (present.isEmpty) return null;
    pw.Widget row = present.length == 1
        ? pw.Align(
            alignment: center != null
                ? pw.Alignment.topCenter
                : (right != null ? pw.Alignment.topRight : pw.Alignment.topLeft),
            child: present.single,
          )
        : pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              if (center == null) ...[
                pw.Expanded(child: left ?? pw.SizedBox()),
                pw.Expanded(child: pw.Align(alignment: pw.Alignment.topRight, child: right ?? pw.SizedBox())),
              ] else ...[
                pw.Expanded(child: left ?? pw.SizedBox()),
                pw.Expanded(child: pw.Center(child: center)),
                pw.Expanded(child: pw.Align(alignment: pw.Alignment.topRight, child: right ?? pw.SizedBox())),
              ],
            ],
          );
    if (r.line && s.borderWidth > 0) {
      final side = pw.BorderSide(color: PdfColor.fromInt(s.lineColor), width: s.borderWidth);
      row = pw.Container(
        padding: header ? pw.EdgeInsets.only(bottom: s.padding) : pw.EdgeInsets.only(top: s.padding),
        decoration: pw.BoxDecoration(border: header ? pw.Border(bottom: side) : pw.Border(top: side)),
        child: row,
      );
    }
    return (row, s);
  }

  // -- columns ------------------------------------------------------------------

  pw.Widget _twoColumns() {
    final blocks = page.blocks;
    // A leading heading spans both columns; the rest is balanced by length.
    final lead = blocks.isNotEmpty && blocks.first is HeadingBlock ? blocks.first : null;
    final rest = lead == null ? blocks : blocks.sublist(1);

    // Keep each heading together with the blocks that follow it.
    final groups = <List<DocBlock>>[];
    for (final b in rest) {
      if (groups.isEmpty || b is HeadingBlock) groups.add([]);
      groups.last.add(b);
    }
    final total = groups.fold(0, (sum, g) => sum + g.fold(0, (s, b) => s + _weight(b)));
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
      child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.stretch, children: _blocks(b)),
    );
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.stretch,
      children: [
        if (lead != null) ...[
          ..._blocks([lead]),
          pw.SizedBox(height: _style(lead).spaceAfter),
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

  // -- blocks -----------------------------------------------------------------

  /// The block's own style over its role's: what spacing and boxes read.
  ResolvedStyle _style(DocBlock b) => styles.resolve(styles.merged(b.role, b.style));

  /// [blocks] one under the other, each the space its style asks for (after the one before it, before itself)
  /// from the previous; the first of a page or a column takes no space above it.
  List<pw.Widget> _blocks(List<DocBlock> blocks) {
    final widgets = <pw.Widget>[];
    ResolvedStyle? previous;
    for (final b in blocks) {
      final s = _style(b);
      if (previous != null) widgets.add(pw.SizedBox(height: previous.spaceAfter + s.spaceBefore));
      widgets.add(_block(b));
      previous = s;
    }
    return widgets;
  }

  pw.Widget _block(DocBlock block) {
    final style = styles.merged(block.role, block.style);
    final s = styles.resolve(style);
    return switch (block) {
      HeadingBlock(:final text) || ParagraphBlock(:final text) => _box(s, _text(text, s)),
      BulletListBlock(:final items) => _bullets(items, s, style),
      TableBlock() => _table(block, s, style),
      MetricsBlock(:final items) => _metrics(items, s, style),
      QuoteBlock() => _box(
        s,
        pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.stretch,
          children: [
            _text(block.text, s),
            if (block.author.isNotEmpty) _caption(block.author, style),
          ],
        ),
      ),
      CalloutBlock() => _box(
        s,
        pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.stretch,
          children: [
            if (block.title.isNotEmpty) _text(block.title, _resolve(style, {'bold': true})),
            if (block.title.isNotEmpty && block.text.isNotEmpty) pw.SizedBox(height: 4),
            if (block.text.isNotEmpty) _text(block.text, s),
          ],
        ),
      ),
      ImageBlock() => _box(s, _image(block, s, style)),
    };
  }

  /// A caption (of a table, a picture, a quote) under the block whose style is [of].
  pw.Widget _caption(String text, BlockStyle of) {
    final s = styles.resolve(styles.part(StyleRole.caption, of));
    return pw.Padding(padding: pw.EdgeInsets.only(top: s.spaceBefore), child: _text(text, s));
  }

  pw.Widget _bullets(List<String> items, ResolvedStyle s, BlockStyle style) {
    final markerWidth = s.markerWidth;
    final marker = _resolve(style, {'bold': false, 'underline': false, 'caps': false, 'align': 'left', 'firstLineIndent': 0});
    return _box(
      s,
      indent: false,
      pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.stretch,
        children: [
          for (final (i, item) in items.indexed)
            pw.Padding(
              padding: pw.EdgeInsets.only(top: i == 0 ? 0 : s.spaceAfter),
              child: pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.SizedBox(width: markerWidth, child: _text(listMarker(s.marker, i), marker)),
                  pw.Expanded(child: _text(item, s)),
                ],
              ),
            ),
        ],
      ),
    );
  }

  pw.Widget _table(TableBlock t, ResolvedStyle s, BlockStyle style) {
    final columnCount = [t.columns.length, ...t.rows.map((r) => r.length)].fold(0, math.max);
    if (columnCount == 0) return t.caption.isEmpty ? pw.SizedBox() : _caption(t.caption, style);
    List<String> pad(List<String> r) => [...r, ...List.filled(columnCount - r.length, '')];
    final head = styles.resolve(styles.part(StyleRole.tableHeader, style));
    final side = pw.BorderSide(color: PdfColor.fromInt(s.lineColor), width: s.borderWidth);
    final border = s.borderWidth <= 0
        ? null
        : switch (s.grid) {
            TableGrid.rows => pw.TableBorder(horizontalInside: side, bottom: side),
            TableGrid.all => pw.TableBorder.symmetric(outside: side, inside: side),
            TableGrid.none => null,
          };
    pw.Widget cell(String text, ResolvedStyle cs) =>
        pw.Padding(padding: pw.EdgeInsets.all(s.padding), child: _text(text, cs));
    PdfColor? fill(int? argb) => argb == null ? null : PdfColor.fromInt(argb);
    final table = pw.Table(
      border: border,
      columnWidths: {0: const pw.FlexColumnWidth(1.6)},
      children: [
        if (t.columns.isNotEmpty)
          pw.TableRow(
            decoration: pw.BoxDecoration(color: fill(head.background ?? s.background)),
            children: [for (final c in pad(t.columns)) cell(c, head)],
          ),
        for (final (r, row) in t.rows.indexed)
          pw.TableRow(
            decoration: pw.BoxDecoration(color: fill(r.isOdd ? (s.stripe ?? s.background) : s.background)),
            children: [for (final c in pad(row)) cell(c, s)],
          ),
      ],
    );
    final widget = t.caption.isEmpty
        ? table
        : pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.stretch, children: [table, _caption(t.caption, style)]);
    return s.indent > 0 ? pw.Padding(padding: pw.EdgeInsets.only(left: s.indent), child: widget) : widget;
  }

  pw.Widget _metrics(List<Metric> items, ResolvedStyle s, BlockStyle style) {
    if (items.isEmpty) return pw.SizedBox();
    final label = styles.part(StyleRole.caption, style);
    pw.Widget tile(Metric m) {
      final negative = m.delta.trim().startsWith('-');
      return _box(
        s,
        indent: false,
        pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            _text(m.label, styles.resolve(label)),
            pw.SizedBox(height: 4),
            _text(m.value, s),
            if (m.delta.isNotEmpty)
              _text(m.delta, _resolve(label, {'color': negative ? '#dc2626' : '#059669'})),
          ],
        ),
      );
    }

    final row = pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        for (final (i, m) in items.indexed) ...[
          if (i > 0) pw.SizedBox(width: 10),
          pw.Expanded(child: tile(m)),
        ],
      ],
    );
    return s.indent > 0 ? pw.Padding(padding: pw.EdgeInsets.only(left: s.indent), child: row) : row;
  }

  pw.Widget _image(ImageBlock img, ResolvedStyle s, BlockStyle style) {
    final bytes = img.bytes;
    final picture = bytes != null
        ? pw.Image(OpaqueImage(bytes), height: img.height, fit: pw.BoxFit.cover)
        : pw.Container(
            height: img.height,
            color: const PdfColor.fromInt(0xFFF1F5F9),
            alignment: pw.Alignment.center,
            child: _text('IMMAGINE', _resolve(style, {'size': 8, 'bold': true, 'color': '#64748b', 'align': 'center'})),
          );
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.stretch,
      children: [picture, if (img.caption.isNotEmpty) _caption(img.caption, style)],
    );
  }
}
