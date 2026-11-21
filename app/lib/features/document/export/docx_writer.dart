/// DOCX: ISO/IEC 29500 Transitional, written the way Word writes it: a named style per role of the document's style
/// (what a block sets apart on its own paragraph), numbering, headers and footers with page fields and a first page of
/// their own, a repeating header row.
library;

import 'dart:typed_data';

import '../model/document.dart';
import 'export_model.dart';
import 'export_text.dart';
import 'image_info.dart';
import 'opc.dart';
import 'zip_package.dart';

const _nsW = 'xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main"';
const _nsR = 'xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships"';
const _wml = 'application/vnd.openxmlformats-officedocument.wordprocessingml';

Uint8List encodeDocx(PaperDocument doc) {
  final d = buildExportDoc(doc);
  final w = _Writer(d)..walk();
  final document = w.document();

  final zip = ZipPackage(d.modified)
    ..addText(
      '[Content_Types].xml',
      contentTypes(
        defaults: {
          'rels': 'application/vnd.openxmlformats-package.relationships+xml',
          'xml': 'application/xml',
          for (final f in {for (final m in w.media) m.format}) f.extension: f.mime,
        },
        overrides: {
          '/word/document.xml': '$_wml.document.main+xml',
          '/word/styles.xml': '$_wml.styles+xml',
          '/word/numbering.xml': '$_wml.numbering+xml',
          '/word/settings.xml': '$_wml.settings+xml',
          '/word/fontTable.xml': '$_wml.fontTable+xml',
          for (final p in w.parts) '/word/${p.name}': '$_wml.${p.kind}+xml',
          '/docProps/core.xml': kCoreContentType,
          '/docProps/app.xml': kAppContentType,
        },
      ),
    )
    ..addText(
      '_rels/.rels',
      relationships([
        ('rId1', relType('officeDocument'), 'word/document.xml'),
        ('rId2', kCoreRelType, 'docProps/core.xml'),
        ('rId3', relType('extended-properties'), 'docProps/app.xml'),
      ]),
    )
    ..addText('word/document.xml', document)
    ..addText('word/_rels/document.xml.rels', relationships(w.rels.entries))
    ..addText('word/styles.xml', _styles(d))
    ..addText('word/numbering.xml', _numbering(w.lists))
    ..addText('word/settings.xml', _settings)
    ..addText('word/fontTable.xml', _fontTable)
    ..addText('docProps/core.xml', coreProperties(d))
    ..addText('docProps/app.xml', appProperties(d));
  for (final p in w.parts) {
    zip.addText('word/${p.name}', p.xml);
    if (p.rels.entries.isNotEmpty) zip.addText('word/_rels/${p.name}.rels', relationships(p.rels.entries));
  }
  for (final (n, m) in w.media.indexed) {
    zip.addBytes('word/media/image${n + 1}.${m.format.extension}', m.bytes);
  }
  return zip.toBytes();
}

class _Image {
  const _Image(this.format, this.bytes);
  final ImageFormat format;
  final Uint8List bytes;
}

/// A part's relationships, numbered as they are added.
class _Rels {
  final entries = <(String, String, String)>[];

  String add(String type, String target) {
    final id = 'rId${entries.length + 1}';
    entries.add((id, relType(type), target));
    return id;
  }
}

/// A header or a footer part.
class _Part {
  _Part(this.name, this.kind);

  final String name;

  /// `header` or `footer`.
  final String kind;
  final rels = _Rels();
  var xml = '';
}

/// A table style Word lists as its own; the body names it on every table.
const _tableStyle = 'DaylexTable';

/// The named style each role's paragraphs take.
const _styleIds = {
  StyleRole.body: 'Normal',
  StyleRole.heading1: 'Heading1',
  StyleRole.heading2: 'Heading2',
  StyleRole.heading3: 'Heading3',
  StyleRole.bullets: 'ListParagraph',
  StyleRole.table: 'TableText',
  StyleRole.tableHeader: 'TableHeader',
  StyleRole.quote: 'Quote',
  StyleRole.callout: 'Callout',
  StyleRole.caption: 'Caption',
  StyleRole.metrics: 'Metrics',
};

/// Points to twips.
int _tw(double pt) => (pt * 20).round();

/// A border's width in eighths of a point, as Word takes it (2 to 96).
int _eighths(double pt) => (pt * 8).round().clamp(2, 96);

String _jc(BlockAlign a) => switch (a) {
  BlockAlign.left => 'left',
  BlockAlign.center => 'center',
  BlockAlign.right => 'right',
  BlockAlign.justify => 'both',
};

String _family(FontKind k) => switch (k) {
  FontKind.serif => 'roman',
  FontKind.sans => 'swiss',
  FontKind.mono => 'modern',
};

/// The text of [s] as run content: a newline is a break, a tab is a tab, the rest is `w:t`.
String _content(String s) {
  final out = StringBuffer();
  final run = StringBuffer();
  void flush() {
    if (run.isEmpty) return;
    out.write('<w:t xml:space="preserve">${xmlEscape(run.toString())}</w:t>');
    run.clear();
  }

  for (final c in s.codeUnits) {
    if (c == 0x0A) {
      flush();
      out.write('<w:br/>');
    } else if (c == 0x09) {
      flush();
      out.write('<w:tab/>');
    } else {
      run.writeCharCode(c);
    }
  }
  flush();
  return out.toString();
}

String _run(String text, String rPr) => text.isEmpty ? '' : '<w:r>${rPr.isEmpty ? '' : '<w:rPr>$rPr</w:rPr>'}${_content(text)}</w:r>';

/// `rPr` children in schema order (fonts, bold, italic, caps, colour, size, underline): every one of [s] when [only]
/// is null (a style), else those [only] names, and the emphasis of [run] (or a forced [bold]) on top.
String _rPr(ResolvedStyle s, Set<String>? only, {ExRun? run, bool bold = false}) {
  bool has(String f) => only == null || only.contains(f);
  String toggle(String tag, String field, bool on, bool forced, {String off = '0', String cs = ''}) {
    if (!has(field) && !forced) return '';
    final value = on ? '' : ' w:val="$off"';
    return '<w:$tag$value/>${cs.isEmpty ? '' : '<w:$cs$value/>'}';
  }

  final b = s.bold || bold || (run?.bold ?? false), i = s.italic || (run?.italic ?? false);
  final u = s.underline || (run?.underline ?? false);
  final f = s.font.family;
  return '${has('font') ? '<w:rFonts w:ascii="$f" w:eastAsia="$f" w:hAnsi="$f" w:cs="$f"/>' : ''}'
      '${toggle('b', 'bold', b, bold || (run?.bold ?? false), cs: 'bCs')}'
      '${toggle('i', 'italic', i, run?.italic ?? false, cs: 'iCs')}'
      '${toggle('caps', 'caps', s.caps, false)}'
      '${has('color') ? '<w:color w:val="${hex6(s.color)}"/>' : ''}'
      '${has('size') ? '<w:sz w:val="${(s.size * 2).round()}"/><w:szCs w:val="${(s.size * 2).round()}"/>' : ''}'
      '${has('underline') || (run?.underline ?? false) ? '<w:u w:val="${u ? 'single' : 'none'}"/>' : ''}';
}

/// The runs of [text] in [st], its emphasis kept.
String _runs(String text, ExStyle st, {bool bold = false}) =>
    [for (final r in runsOf(text)) _run(r.text, _rPr(st.resolved, st.own, run: r, bold: bold))].join();

/// `w:spacing` of [s]: before and after in twips, the line as Word's multiple of a single line.
String _spacing(ResolvedStyle s, {double? before, double? after}) =>
    '<w:spacing w:before="${_tw(before ?? s.spaceBefore)}" w:after="${_tw(after ?? s.spaceAfter)}" '
    'w:line="${(s.lineHeight * 240).round()}" w:lineRule="auto"/>';

/// `w:pBdr` and `w:shd` of [s]'s box. [explicit] also cancels what a style draws (a block that drops its role's box).
String _frame(ResolvedStyle s, {required bool explicit}) {
  final drawn = s.borderWidth > 0 && s.border != BlockBorder.none;
  final space = s.padding.round().clamp(0, 31);
  String side(String name, bool on) => on
      ? '<w:$name w:val="single" w:sz="${_eighths(s.borderWidth)}" w:space="$space" w:color="${hex6(s.lineColor)}"/>'
      : '<w:$name w:val="nil"/>';
  bool on(BlockBorder b) => drawn && (s.border == BlockBorder.box || s.border == b);
  final border = drawn || explicit
      ? '<w:pBdr>${side('top', on(BlockBorder.top))}${side('left', on(BlockBorder.left))}'
            '${side('bottom', on(BlockBorder.bottom))}${side('right', s.border == BlockBorder.box && drawn)}</w:pBdr>'
      : '';
  final fill = s.background;
  final shd = fill != null
      ? '<w:shd w:val="clear" w:color="auto" w:fill="${hex6(fill)}"/>'
      : (explicit ? '<w:shd w:val="clear" w:color="auto" w:fill="auto"/>' : '');
  return '$border$shd';
}

/// `pPr` in schema order: style, keepNext, keepLines, pageBreakBefore, numPr, pBdr, shd, spacing, ind, jc,
/// outlineLvl, sectPr. [s] gives the formatting, all of it when [only] is null (a style), else what [only] names;
/// [boxed] false leaves its box out (a table cell); the named strings override.
String _pPr({
  String? style,
  bool keepNext = false,
  bool keepLines = false,
  bool pageBreak = false,
  int? numId,
  ResolvedStyle? s,
  Set<String>? only,
  bool boxed = true,
  String? frame,
  String? spacing,
  String? ind,
  String? jc,
  int? outline,
  String sectPr = '',
}) {
  bool has(String f) => s != null && (only == null || only.contains(f));
  final props = StringBuffer();
  if (style != null && style != 'Normal') props.write('<w:pStyle w:val="$style"/>');
  if (keepNext) props.write('<w:keepNext/>');
  if (keepLines) props.write('<w:keepLines/>');
  if (pageBreak) props.write('<w:pageBreakBefore/>');
  if (numId != null) props.write('<w:numPr><w:ilvl w:val="0"/><w:numId w:val="$numId"/></w:numPr>');
  if (frame != null) {
    props.write(frame);
  } else if (boxed && ['border', 'borderColor', 'borderWidth', 'padding', 'background'].any(has)) {
    props.write(_frame(s!, explicit: only != null));
  }
  final sp = spacing ?? (['spaceBefore', 'spaceAfter', 'lineHeight'].any(has) ? _spacing(s!) : null);
  if (sp != null) props.write(sp);
  final indent = ind ??
      (['indent', 'firstLineIndent'].any(has)
          ? '<w:ind w:left="${_tw(boxed ? s!.indent : 0)}" w:firstLine="${_tw(s!.firstLineIndent)}"/>'
          : null);
  if (indent != null) props.write(indent);
  final align = jc ?? (has('align') ? _jc(s!.align) : null);
  if (align != null) props.write('<w:jc w:val="$align"/>');
  if (outline != null) props.write('<w:outlineLvl w:val="$outline"/>');
  props.write(sectPr);
  return props.isEmpty ? '' : '<w:pPr>$props</w:pPr>';
}

/// A thin empty paragraph: what follows a table (two tables would merge), or carries a line or a section's end.
String _thin({String frame = '', bool pageBreak = false, String sectPr = ''}) =>
    '<w:p><w:pPr>${pageBreak ? '<w:pageBreakBefore/>' : ''}$frame'
    '<w:spacing w:before="0" w:after="0" w:line="20" w:lineRule="exact"/>$sectPr</w:pPr></w:p>';

class _Writer {
  _Writer(this.d);

  final ExportDoc d;
  final out = StringBuffer();
  final rels = _Rels()
    ..add('styles', 'styles.xml')
    ..add('numbering', 'numbering.xml')
    ..add('settings', 'settings.xml')
    ..add('fontTable', 'fontTable.xml');
  final media = <_Image>[];
  final _targets = Map<Uint8List, String>.identity();
  final parts = <_Part>[];
  final _partIds = <String, String>{};

  /// The marker of each list, in order: list N is `w:num` N + 1.
  final lists = <ListMarker>[];
  var _page = 0;
  var _pendingBreak = false;
  var _drawings = 0;

  void walk() {
    for (final b in d.blocks) {
      switch (b) {
        case ExHeading(:final text, :final style) || ExParagraph(:final text, :final style):
          _p(_runs(text, style), style);
        case ExBullets():
          _bullets(b);
        case ExTable():
          _table(b);
        case ExMetrics():
          _table(b.asTable());
        case ExQuote(:final text, :final author, :final style, :final authorStyle):
          _p(_runs(text, style), style, keepNext: author.isNotEmpty);
          if (author.isNotEmpty) {
            // The author stands in the quote's box, in the caption's type.
            final q = style.resolved;
            _p(
              _runs('— $author', authorStyle),
              authorStyle,
              frame: _frame(q, explicit: true),
              ind: '<w:ind w:left="${_tw(q.indent)}" w:firstLine="0"/>',
            );
          }
        case ExCallout(:final title, :final text, :final style):
          if (title.isNotEmpty) _p(_runs(title, style, bold: true), style, keepNext: text.isNotEmpty);
          if (text.isNotEmpty) _p(_runs(text, style), style);
        case ExImage():
          _image(b);
        case ExPageBreak():
          if (d.perPage) {
            // Each page of the document is a section with its own header and footer; a section starts a page.
            out.write(_thin(sectPr: _sectPr(_page)));
            _page++;
          } else {
            _pendingBreak = true;
          }
      }
    }
  }

  String document() => '$kXmlDecl<w:document $_nsW $_nsR><w:body>$out${_sectPr(_page)}</w:body></w:document>';

  /// A page break is the next paragraph's `pageBreakBefore`, as Word writes it from Layout > Breaks.
  bool _takeBreak() {
    final b = _pendingBreak;
    _pendingBreak = false;
    return b;
  }

  void _p(String runs, ExStyle st, {bool keepNext = false, String? frame, String? ind}) {
    out.write('<w:p>${_pPr(style: _styleIds[st.role], keepNext: keepNext, pageBreak: _takeBreak(), s: st.resolved, only: st.own, frame: frame, ind: ind)}$runs</w:p>');
  }

  void _bullets(ExBullets b) {
    final s = b.style.resolved;
    int? numId;
    if (s.marker != ListMarker.none) {
      lists.add(s.marker);
      numId = lists.length;
    }
    final marker = _tw(s.markerWidth);
    for (final (i, item) in b.items.indexed) {
      out.write('<w:p>${_pPr(
        style: 'ListParagraph',
        pageBreak: _takeBreak(),
        numId: numId,
        s: s,
        only: b.style.own,
        spacing: i == 0 ? null : _spacing(s, before: 0),
        ind: '<w:ind w:left="$marker" w:hanging="$marker"/>',
      )}${_runs(item, b.style)}</w:p>');
    }
  }

  void _table(ExTable t) {
    if (_pendingBreak) {
      _pendingBreak = false;
      out.write(_thin(pageBreak: true));
    }
    final s = t.style.resolved;
    final indent = _tw(s.indent);
    final total = d.page.textWidthTwips - indent;
    final widths = t.widths(total);
    final head = t.headerStyle.resolved;

    String cell(String text, int c, ExStyle st, int? fill, {required bool header}) {
      final shd = fill == null ? '' : '<w:shd w:val="clear" w:color="auto" w:fill="${hex6(fill)}"/>';
      return '<w:tc><w:tcPr><w:tcW w:w="${widths[c]}" w:type="dxa"/>$shd${header ? '<w:vAlign w:val="center"/>' : ''}</w:tcPr>'
          '<w:p>${_pPr(
            style: _styleIds[st.role],
            keepNext: header,
            s: st.resolved,
            only: st.own,
            boxed: false,
            spacing: _spacing(st.resolved, before: 0, after: 0),
            jc: t.numeric[c] ? 'right' : null,
          )}${_runs(text, st)}</w:p></w:tc>';
    }

    out.write('<w:tbl><w:tblPr><w:tblStyle w:val="$_tableStyle"/><w:tblW w:w="$total" w:type="dxa"/>'
        '${indent > 0 ? '<w:tblInd w:w="$indent" w:type="dxa"/>' : ''}${_tableBorders(s)}<w:tblLayout w:type="fixed"/>'
        '${_cellMargins(s)}<w:tblLook w:val="${t.hasHeader ? '0620' : '0600'}" w:firstRow="${t.hasHeader ? 1 : 0}" w:lastRow="0" '
        'w:firstColumn="0" w:lastColumn="0" w:noHBand="1" w:noVBand="1"/><w:tblCaption w:val="${xmlEscape(t.title, attribute: true)}"/></w:tblPr>'
        '<w:tblGrid>${widths.map((w) => '<w:gridCol w:w="$w"/>').join()}</w:tblGrid>');
    if (t.hasHeader) {
      // The header row repeats on every page the table runs onto.
      final fill = head.background ?? s.background;
      out.write('<w:tr><w:trPr><w:cantSplit/><w:tblHeader/></w:trPr>'
          '${[for (var c = 0; c < t.width; c++) cell(t.header[c], c, t.headerStyle, fill, header: true)].join()}</w:tr>');
    }
    for (final (r, row) in t.rows.indexed) {
      final fill = r.isOdd ? (s.stripe ?? s.background) : s.background;
      out.write('<w:tr><w:trPr><w:cantSplit/></w:trPr>'
          '${[for (var c = 0; c < t.width; c++) cell(row[c], c, t.style, fill, header: false)].join()}</w:tr>');
    }
    out.write('</w:tbl>');
    if (t.caption.isEmpty) {
      out.write(_thin());
    } else {
      _p(_runs(t.caption, t.captionStyle), t.captionStyle);
    }
  }

  /// The part path of [bytes] in word/media, written once however many parts show it.
  String _media(ImageFormat format, Uint8List bytes) => _targets.putIfAbsent(bytes, () {
    media.add(_Image(format, bytes));
    return 'media/image${media.length}.${format.extension}';
  });

  /// A picture inline, [rid] naming its bytes in the part's relationships.
  String _drawing(double wPt, double hPt, String rid, String alt, ImageFormat format) {
    final id = ++_drawings;
    final cx = (wPt * 12700).round(), cy = (hPt * 12700).round();
    final a = xmlEscape(alt, attribute: true);
    return '<w:r><w:drawing><wp:inline xmlns:wp="http://schemas.openxmlformats.org/drawingml/2006/wordprocessingDrawing" distT="0" distB="0" distL="0" distR="0">'
        '<wp:extent cx="$cx" cy="$cy"/><wp:effectExtent l="0" t="0" r="0" b="0"/>'
        '<wp:docPr id="$id" name="Immagine $id" descr="$a"/>'
        '<wp:cNvGraphicFramePr><a:graphicFrameLocks xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main" noChangeAspect="1"/></wp:cNvGraphicFramePr>'
        '<a:graphic xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main"><a:graphicData uri="http://schemas.openxmlformats.org/drawingml/2006/picture">'
        '<pic:pic xmlns:pic="http://schemas.openxmlformats.org/drawingml/2006/picture">'
        '<pic:nvPicPr><pic:cNvPr id="$id" name="image$id.${format.extension}" descr="$a"/><pic:cNvPicPr/></pic:nvPicPr>'
        '<pic:blipFill><a:blip r:embed="$rid"/><a:stretch><a:fillRect/></a:stretch></pic:blipFill>'
        '<pic:spPr><a:xfrm><a:off x="0" y="0"/><a:ext cx="$cx" cy="$cy"/></a:xfrm><a:prstGeom prst="rect"><a:avLst/></a:prstGeom></pic:spPr>'
        '</pic:pic></a:graphicData></a:graphic></wp:inline></w:drawing></w:r>';
  }

  void _image(ExImage img) {
    final header = img.header;
    if (header == null) {
      _p(_run(img.marker, '<w:i/><w:iCs/>'), img.style);
      return;
    }
    final rid = rels.add('image', _media(header.format, img.bytes!));
    final (w, h) = img.fit(d.page.textWidthPt, d.page.textHeightPt * 0.8);
    _p(_drawing(w, h, rid, img.caption.isEmpty ? 'Immagine' : img.caption, header.format), img.style, keepNext: img.caption.isNotEmpty);
    if (img.caption.isNotEmpty) _p(_runs(img.caption, img.captionStyle), img.captionStyle);
  }

  // -- sections, headers and footers -------------------------------------------

  /// Whether any page shows a header ([kind] `header`) or a footer: without one, no part and no reference.
  bool _uses(String kind) => [d.first, ...d.pages].any((p) => !(kind == 'header' ? p.header : p.footer).isEmpty);

  /// The section of page [i]: its header and footer, page 1's own when the first page differs, the page set-up.
  String _sectPr(int i) {
    final p = d.page;
    final regions = d.pages[i < d.pages.length ? i : d.pages.length - 1];
    final first = i == 0 && d.firstDiffers;
    final refs = StringBuffer();
    for (final kind in ['header', 'footer']) {
      if (!_uses(kind)) continue;
      ExRegion of(ExPageRegions r) => kind == 'header' ? r.header : r.footer;
      refs.write('<w:${kind}Reference w:type="default" r:id="${_part(kind, of(regions))}"/>');
      if (first) refs.write('<w:${kind}Reference w:type="first" r:id="${_part(kind, of(d.first))}"/>');
    }
    return '<w:sectPr>$refs<w:pgSz w:w="${p.widthTwips}" w:h="${p.heightTwips}"${p.landscape ? ' w:orient="landscape"' : ''}/>'
        '<w:pgMar w:top="${p.topTwips}" w:right="${p.rightTwips}" w:bottom="${p.bottomTwips}" w:left="${p.leftTwips}" '
        'w:header="${p.headerTwips}" w:footer="${p.footerTwips}" w:gutter="0"/>'
        '<w:cols w:space="708"/>${first ? '<w:titlePg/>' : ''}<w:docGrid w:linePitch="360"/></w:sectPr>';
  }

  /// The relationship id of the part that shows [r]; pages that show the same share it. An empty region is a part
  /// too: a section without a reference would repeat the one before it.
  String _part(String kind, ExRegion r) => _partIds.putIfAbsent('$kind\u0002${r.key}', () {
    final part = _Part('$kind${parts.where((p) => p.kind == kind).length + 1}.xml', kind);
    final tag = kind == 'header' ? 'w:hdr' : 'w:ftr';
    part.xml = '$kXmlDecl<$tag $_nsW $_nsR>${r.isEmpty ? '<w:p/>' : _region(r, part)}</$tag>';
    parts.add(part);
    return rels.add(kind, part.name);
  });

  /// [r]'s content: one part as paragraphs in its alignment, two or three side by side in a borderless table; the
  /// line, when the region has one, between it and the page.
  String _region(ExRegion r, _Part part) {
    final s = r.style!;
    final footer = part.kind == 'footer';
    final style = footer ? 'Footer' : 'Header';

    String paragraphs(({String text, BlockAlign align, ExLogo? logo}) p) {
      final jc = _jc(p.align);
      final logo = p.logo;
      return [
        if (logo != null)
          '<w:p>${_pPr(style: style, spacing: '<w:spacing w:before="0" w:after="${p.text.isEmpty ? 0 : 80}"/>', jc: jc)}'
              '${_drawing(logo.widthPt, logo.heightPt, part.rels.add('image', _media(logo.header!.format, logo.bytes)), 'Logo', logo.header!.format)}</w:p>',
        if (p.text.isNotEmpty)
          '<w:p>${_pPr(style: style, s: s, boxed: false, spacing: _spacing(s, before: 0, after: 0), ind: '<w:ind w:left="0" w:firstLine="0"/>', jc: jc)}'
              '${[
                for (final run in runsOf(p.text, fields: true))
                  run.field == null
                      ? _run(run.text, _rPr(s, null, run: run))
                      : '<w:fldSimple w:instr=" ${run.field == ExField.page ? 'PAGE' : 'NUMPAGES'} "><w:r><w:rPr>${_rPr(s, null, run: run)}</w:rPr><w:t>1</w:t></w:r></w:fldSimple>',
              ].join()}</w:p>',
      ].join();
    }

    final shown = r.parts;
    final String content;
    if (shown.length == 1) {
      content = paragraphs(shown.single);
    } else {
      final width = d.page.textWidthTwips ~/ shown.length;
      content = '<w:tbl><w:tblPr><w:tblW w:w="${width * shown.length}" w:type="dxa"/><w:tblBorders><w:top w:val="nil"/><w:left w:val="nil"/>'
          '<w:bottom w:val="nil"/><w:right w:val="nil"/><w:insideH w:val="nil"/><w:insideV w:val="nil"/></w:tblBorders><w:tblLayout w:type="fixed"/>'
          '<w:tblCellMar><w:left w:w="0" w:type="dxa"/><w:right w:w="0" w:type="dxa"/></w:tblCellMar><w:tblLook w:val="0000"/></w:tblPr>'
          '<w:tblGrid>${'<w:gridCol w:w="$width"/>' * shown.length}</w:tblGrid><w:tr>'
          '${shown.map((p) => '<w:tc><w:tcPr><w:tcW w:w="$width" w:type="dxa"/></w:tcPr>${paragraphs(p)}</w:tc>').join()}</w:tr></w:tbl>';
    }
    if (!r.line || s.borderWidth <= 0) return shown.length == 1 ? content : '$content${_thin()}';
    final rule = '<w:${footer ? 'bottom' : 'top'} w:val="single" w:sz="${_eighths(s.borderWidth)}" w:space="${s.padding.round().clamp(0, 31)}" w:color="${hex6(s.lineColor)}"/>';
    final line = _thin(frame: '<w:pBdr>$rule</w:pBdr>');
    return footer ? '$line$content${shown.length == 1 ? '' : _thin()}' : '$content$line';
  }
}

/// The table's lines: between rows, every cell, or none, in its line colour.
String _tableBorders(ResolvedStyle s) {
  final line = '<w:@ w:val="single" w:sz="${_eighths(s.borderWidth)}" w:space="0" w:color="${hex6(s.lineColor)}"/>';
  String side(String name, bool on) => on && s.borderWidth > 0 ? line.replaceFirst('@', name) : '<w:$name w:val="nil"/>';
  final all = s.grid == TableGrid.all, rows = s.grid != TableGrid.none;
  return '<w:tblBorders>${side('top', all)}${side('left', all)}${side('bottom', rows)}${side('right', all)}'
      '${side('insideH', rows)}${side('insideV', all)}</w:tblBorders>';
}

String _cellMargins(ResolvedStyle s) {
  final p = _tw(s.padding);
  return '<w:tblCellMar><w:top w:w="$p" w:type="dxa"/><w:left w:w="$p" w:type="dxa"/><w:bottom w:w="$p" w:type="dxa"/>'
      '<w:right w:w="$p" w:type="dxa"/></w:tblCellMar>';
}

// ---------------------------------------------------------------------------
// Fixed parts
// ---------------------------------------------------------------------------

const _settings = '$kXmlDecl<w:settings $_nsW><w:zoom w:percent="100"/><w:defaultTabStop w:val="720"/>'
    '<w:characterSpacingControl w:val="doNotCompress"/><w:compat>'
    '<w:compatSetting w:name="compatibilityMode" w:uri="http://schemas.microsoft.com/office/word" w:val="15"/>'
    '<w:compatSetting w:name="overrideTableStyleFontSizeAndJustification" w:uri="http://schemas.microsoft.com/office/word" w:val="1"/>'
    '<w:compatSetting w:name="enableOpenTypeFeatures" w:uri="http://schemas.microsoft.com/office/word" w:val="1"/>'
    '<w:compatSetting w:name="doNotFlipMirrorIndents" w:uri="http://schemas.microsoft.com/office/word" w:val="1"/>'
    '<w:compatSetting w:name="differentiateMultirowTableHeaders" w:uri="http://schemas.microsoft.com/office/word" w:val="1"/>'
    '</w:compat><w:themeFontLang w:val="it-IT"/><w:decimalSymbol w:val=","/><w:listSeparator w:val=";"/></w:settings>';

final _fontTable = '$kXmlDecl<w:fonts $_nsW $_nsR>'
    '${DocFont.values.map((f) => '<w:font w:name="${f.family}"><w:charset w:val="00"/><w:family w:val="${_family(f.kind)}"/>'
        '<w:pitch w:val="${f.kind == FontKind.mono ? 'fixed' : 'variable'}"/></w:font>').join()}</w:fonts>';

/// One abstract list per marker; each list of the document is its own `w:num`, so a numbered list starts at 1.
String _numbering(List<ListMarker> lists) {
  String level(String format, String text) =>
      '<w:lvl w:ilvl="0"><w:start w:val="1"/><w:numFmt w:val="$format"/><w:lvlText w:val="$text"/><w:lvlJc w:val="left"/>'
      '<w:pPr><w:ind w:left="360" w:hanging="360"/></w:pPr>'
      '<w:rPr><w:b w:val="0"/><w:bCs w:val="0"/><w:i w:val="0"/><w:iCs w:val="0"/><w:caps w:val="0"/><w:u w:val="none"/></w:rPr></w:lvl>';
  final kinds = {
    ListMarker.disc: level('bullet', '•'),
    ListMarker.dash: level('bullet', '–'),
    ListMarker.number: level('decimal', '%1.'),
    ListMarker.letter: level('lowerLetter', '%1)'),
  };
  return '$kXmlDecl<w:numbering $_nsW>'
      '${kinds.entries.map((e) => '<w:abstractNum w:abstractNumId="${e.key.index}"><w:multiLevelType w:val="singleLevel"/>${e.value}</w:abstractNum>').join()}'
      '${[
        for (final (i, m) in lists.indexed)
          '<w:num w:numId="${i + 1}"><w:abstractNumId w:val="${m.index}"/><w:lvlOverride w:ilvl="0"><w:startOverride w:val="1"/></w:lvlOverride></w:num>',
      ].join()}</w:numbering>';
}

String _styles(ExportDoc d) {
  final body = d.roles[StyleRole.body]!;

  String para(
    String id,
    String name,
    ResolvedStyle s, {
    String basedOn = 'Normal',
    String? next,
    int? priority,
    bool isDefault = false,
    bool boxed = true,
    bool heading = false,
    int? outline,
    String? spacing,
    String? ind,
  }) =>
      '<w:style w:type="paragraph"${isDefault ? ' w:default="1"' : ''} w:styleId="$id"><w:name w:val="$name"/>'
      '${basedOn.isEmpty ? '' : '<w:basedOn w:val="$basedOn"/>'}${next == null ? '' : '<w:next w:val="$next"/>'}'
      '${priority == null ? '' : '<w:uiPriority w:val="$priority"/>'}<w:qFormat/>'
      '${_pPr(keepNext: heading, keepLines: heading, s: s, boxed: boxed, spacing: spacing, ind: ind, outline: outline)}'
      '<w:rPr>${_rPr(s, null)}</w:rPr></w:style>';

  ResolvedStyle role(StyleRole r) => d.roles[r]!;
  final bullets = role(StyleRole.bullets);
  final marker = _tw(bullets.markerWidth);
  String cells(ResolvedStyle s) => _spacing(s, before: 0, after: 0);
  final region = '<w:spacing w:before="0" w:after="0" w:line="240" w:lineRule="auto"/>';
  final table = role(StyleRole.table);
  final f = body.font.family;
  return '$kXmlDecl<w:styles $_nsW>'
      '<w:docDefaults><w:rPrDefault><w:rPr><w:rFonts w:ascii="$f" w:eastAsia="$f" w:hAnsi="$f" w:cs="$f"/>'
      '<w:sz w:val="${(body.size * 2).round()}"/><w:szCs w:val="${(body.size * 2).round()}"/><w:lang w:val="it-IT" w:eastAsia="en-US" w:bidi="ar-SA"/></w:rPr></w:rPrDefault>'
      '<w:pPrDefault><w:pPr><w:spacing w:after="0" w:line="240" w:lineRule="auto"/></w:pPr></w:pPrDefault></w:docDefaults>'
      '${para('Normal', 'Normal', body, basedOn: '', isDefault: true)}'
      '<w:style w:type="character" w:default="1" w:styleId="DefaultParagraphFont"><w:name w:val="Default Paragraph Font"/><w:uiPriority w:val="1"/><w:semiHidden/><w:unhideWhenUsed/></w:style>'
      '<w:style w:type="table" w:default="1" w:styleId="TableNormal"><w:name w:val="Normal Table"/><w:uiPriority w:val="99"/><w:semiHidden/><w:unhideWhenUsed/>'
      '<w:tblPr><w:tblInd w:w="0" w:type="dxa"/><w:tblCellMar><w:top w:w="0" w:type="dxa"/><w:left w:w="108" w:type="dxa"/><w:bottom w:w="0" w:type="dxa"/><w:right w:w="108" w:type="dxa"/></w:tblCellMar></w:tblPr></w:style>'
      '<w:style w:type="numbering" w:default="1" w:styleId="NoList"><w:name w:val="No List"/><w:uiPriority w:val="99"/><w:semiHidden/><w:unhideWhenUsed/></w:style>'
      '${para('Heading1', 'heading 1', role(StyleRole.heading1), next: 'Normal', priority: 9, heading: true, outline: 0)}'
      '${para('Heading2', 'heading 2', role(StyleRole.heading2), next: 'Normal', priority: 9, heading: true, outline: 1)}'
      '${para('Heading3', 'heading 3', role(StyleRole.heading3), next: 'Normal', priority: 9, heading: true, outline: 2)}'
      '${para('Quote', 'Quote', role(StyleRole.quote), next: 'Normal', priority: 29)}'
      '${para('Callout', 'Callout', role(StyleRole.callout), priority: 30)}'
      '${para('ListParagraph', 'List Paragraph', bullets, priority: 34, ind: '<w:ind w:left="$marker" w:hanging="$marker"/>')}'
      '${para('Caption', 'caption', role(StyleRole.caption), next: 'Normal', priority: 35)}'
      '${para('TableText', 'Table Text', table, priority: 33, boxed: false, spacing: cells(table))}'
      '${para('TableHeader', 'Table Header', role(StyleRole.tableHeader), basedOn: 'TableText', priority: 33, boxed: false, spacing: cells(role(StyleRole.tableHeader)))}'
      '${para('Metrics', 'Metrics', role(StyleRole.metrics), priority: 33, boxed: false, spacing: cells(role(StyleRole.metrics)))}'
      '${para('Header', 'header', body, priority: 99, boxed: false, spacing: region)}'
      '${para('Footer', 'footer', body, priority: 99, boxed: false, spacing: region)}'
      '<w:style w:type="table" w:styleId="$_tableStyle"><w:name w:val="Daylex Table"/><w:basedOn w:val="TableNormal"/><w:uiPriority w:val="59"/><w:qFormat/>'
      '<w:tblPr>${_tableBorders(table)}${_cellMargins(table)}</w:tblPr></w:style>'
      '</w:styles>';
}
