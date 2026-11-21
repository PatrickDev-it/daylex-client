/// DOCX: ISO/IEC 29500 Transitional, written the way Word writes it (real styles, numbering, a repeating header row).
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

/// Arial: the one sans every Word, LibreOffice and viewer has or maps to a metric twin.
const _font = 'Arial';

Uint8List encodeDocx(PaperDocument doc) {
  final d = buildExportDoc(doc);
  final body = _Body(d)..walk();

  final images = body.images;
  final zip = ZipPackage(d.modified)
    ..addText(
      '[Content_Types].xml',
      contentTypes(
        defaults: {
          'rels': 'application/vnd.openxmlformats-package.relationships+xml',
          'xml': 'application/xml',
          for (final f in {for (final i in images) i.format}) f.extension: f.mime,
        },
        overrides: {
          '/word/document.xml': '$_wml.document.main+xml',
          '/word/styles.xml': '$_wml.styles+xml',
          '/word/numbering.xml': '$_wml.numbering+xml',
          '/word/settings.xml': '$_wml.settings+xml',
          '/word/fontTable.xml': '$_wml.fontTable+xml',
          '/word/footer1.xml': '$_wml.footer+xml',
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
    ..addText('word/document.xml', body.document())
    ..addText(
      'word/_rels/document.xml.rels',
      relationships([
        ('rId1', relType('styles'), 'styles.xml'),
        ('rId2', relType('numbering'), 'numbering.xml'),
        ('rId3', relType('settings'), 'settings.xml'),
        ('rId4', relType('fontTable'), 'fontTable.xml'),
        ('rId5', relType('footer'), 'footer1.xml'),
        for (final (n, i) in images.indexed) ('rId${n + 6}', relType('image'), 'media/image${n + 1}.${i.format.extension}'),
      ]),
    )
    ..addText('word/styles.xml', _styles(d))
    ..addText('word/numbering.xml', _numbering(d))
    ..addText('word/settings.xml', _settings)
    ..addText('word/fontTable.xml', _fontTable)
    ..addText('word/footer1.xml', _footer(d))
    ..addText('docProps/core.xml', coreProperties(d))
    ..addText('docProps/app.xml', appProperties(d));
  for (final (n, i) in images.indexed) {
    zip.addBytes('word/media/image${n + 1}.${i.format.extension}', i.bytes);
  }
  return zip.toBytes();
}

class _Image {
  const _Image(this.format, this.bytes);
  final ImageFormat format;
  final Uint8List bytes;
}

/// A table style Word lists as its own; the body names it on every table.
const _tableStyle = 'DaylexTable';

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

/// A run: [rPr] children go in schema order (bold, italic, caps, colour, size).
String _run(String text, {bool bold = false, bool italic = false, String? color, int? size}) {
  if (text.isEmpty) return '';
  final props = '${bold ? '<w:b/><w:bCs/>' : ''}${italic ? '<w:i/><w:iCs/>' : ''}'
      '${color == null ? '' : '<w:color w:val="$color"/>'}${size == null ? '' : '<w:sz w:val="$size"/><w:szCs w:val="$size"/>'}';
  return '<w:r>${props.isEmpty ? '' : '<w:rPr>$props</w:rPr>'}${_content(text)}</w:r>';
}

class _Body {
  _Body(this.d);

  final ExportDoc d;
  final out = StringBuffer();
  final images = <_Image>[];
  var _pendingBreak = false;
  var _drawing = 0;

  void walk() {
    for (final b in d.blocks) {
      switch (b) {
        case ExTitle(:final text):
          _p(_run(text), style: 'Title');
        case ExSubtitle(:final text):
          _p(_run(text), style: 'Subtitle');
        case ExFact(:final label, :final value):
          _p('${_run('$label: ', bold: true)}${_run(value)}', style: 'Detail');
        case ExSectionLabel(:final text):
          _p(_run(text), style: 'SectionLabel');
        case ExHeading(:final level, :final text):
          _p(_run(text), style: 'Heading$level');
        case ExParagraph(:final text):
          _p(_run(text));
        case ExBullets(:final items):
          for (final i in items) {
            _p(_run(i), style: 'ListParagraph', numbered: true);
          }
        case ExTable():
          _table(b);
        case ExMetrics():
          _table(b.asTable());
        case ExQuote(:final text, :final author):
          _p(_run(text), style: 'Quote', keepNext: author.isNotEmpty);
          if (author.isNotEmpty) _p(_run('— $author'), style: 'QuoteAuthor');
        case ExCallout(:final title, :final text):
          _p(_run(title, bold: true), style: 'Callout', keepNext: text.isNotEmpty);
          if (text.isNotEmpty) _p(_run(text), style: 'Callout');
        case ExImage():
          _image(b);
        case ExPageBreak():
          _pendingBreak = true;
      }
    }
  }

  String document() {
    final p = d.page;
    return '$kXmlDecl<w:document $_nsW $_nsR><w:body>$out'
        '<w:sectPr><w:footerReference w:type="default" r:id="rId5"/>'
        '<w:pgSz w:w="${ExPageSetup.widthTwips}" w:h="${ExPageSetup.heightTwips}"/>'
        '<w:pgMar w:top="${ExPageSetup.marginYTwips}" w:right="${p.marginXTwips}" w:bottom="${ExPageSetup.marginYTwips}" '
        'w:left="${p.marginXTwips}" w:header="${ExPageSetup.footerTwips}" w:footer="${ExPageSetup.footerTwips}" w:gutter="0"/>'
        '<w:cols w:space="708"/><w:docGrid w:linePitch="360"/></w:sectPr></w:body></w:document>';
  }

  /// `pPr` children in schema order: style, keepNext, pageBreakBefore, numPr, jc.
  String _pPr({String? style, bool keepNext = false, bool numbered = false, String? jc, bool pageBreak = false}) {
    final props = '${style == null ? '' : '<w:pStyle w:val="$style"/>'}${keepNext ? '<w:keepNext/>' : ''}'
        '${pageBreak ? '<w:pageBreakBefore/>' : ''}${numbered ? '<w:numPr><w:ilvl w:val="0"/><w:numId w:val="1"/></w:numPr>' : ''}'
        '${jc == null ? '' : '<w:jc w:val="$jc"/>'}';
    return props.isEmpty ? '' : '<w:pPr>$props</w:pPr>';
  }

  /// A page break is the next paragraph's `pageBreakBefore`, as Word writes it from Layout > Breaks.
  bool _takeBreak() {
    final b = _pendingBreak;
    _pendingBreak = false;
    return b;
  }

  void _p(String runs, {String? style, bool keepNext = false, bool numbered = false}) {
    out.write('<w:p>${_pPr(style: style, keepNext: keepNext, numbered: numbered, pageBreak: _takeBreak())}$runs</w:p>');
  }

  /// A paragraph with no content, thin: what separates a table from what follows it (two tables would merge).
  void _spacer({bool pageBreak = false}) {
    out.write('<w:p><w:pPr>${pageBreak ? '<w:pageBreakBefore/>' : ''}<w:spacing w:before="0" w:after="0" w:line="120" w:lineRule="exact"/></w:pPr></w:p>');
  }

  void _table(ExTable t) {
    if (_pendingBreak) {
      _pendingBreak = false;
      _spacer(pageBreak: true);
    }
    final total = d.page.textWidthTwips;
    final widths = t.widths(total);
    String cell(String text, int c, {required bool header}) {
      final shd = header ? '<w:shd w:val="clear" w:color="auto" w:fill="${d.tintHex}"/>' : '';
      final jc = t.numeric[c] ? 'right' : null;
      return '<w:tc><w:tcPr><w:tcW w:w="${widths[c]}" w:type="dxa"/>$shd${header ? '<w:vAlign w:val="center"/>' : ''}</w:tcPr>'
          '<w:p>${_pPr(style: header ? 'TableHeader' : 'TableText', jc: jc)}${_run(text)}</w:p></w:tc>';
    }

    out.write('<w:tbl><w:tblPr><w:tblStyle w:val="$_tableStyle"/><w:tblW w:w="$total" w:type="dxa"/><w:tblLayout w:type="fixed"/>'
        '<w:tblLook w:val="${t.hasHeader ? '0620' : '0600'}" w:firstRow="${t.hasHeader ? 1 : 0}" w:lastRow="0" w:firstColumn="0" '
        'w:lastColumn="0" w:noHBand="1" w:noVBand="1"/><w:tblCaption w:val="${xmlEscape(t.title, attribute: true)}"/></w:tblPr>'
        '<w:tblGrid>${widths.map((w) => '<w:gridCol w:w="$w"/>').join()}</w:tblGrid>');
    if (t.hasHeader) {
      // The header row repeats on every page the table runs onto.
      out.write('<w:tr><w:trPr><w:cantSplit/><w:tblHeader/></w:trPr>${[for (var c = 0; c < t.width; c++) cell(t.header[c], c, header: true)].join()}</w:tr>');
    }
    for (final r in t.rows) {
      out.write('<w:tr><w:trPr><w:cantSplit/></w:trPr>${[for (var c = 0; c < t.width; c++) cell(r[c], c, header: false)].join()}</w:tr>');
    }
    out.write('</w:tbl>');
    if (t.caption.isEmpty) {
      _spacer();
    } else {
      _p(_run(t.caption), style: 'Caption');
    }
  }

  void _image(ExImage img) {
    final header = img.header;
    if (header == null) {
      _p(_run(img.marker, italic: true, color: ExColors.muted), style: 'Detail');
      return;
    }
    images.add(_Image(header.format, img.bytes!));
    final id = ++_drawing;
    final (w, h) = img.fit(d.page.textWidthPt, d.page.textHeightPt * 0.8);
    final cx = (w * 12700).round(), cy = (h * 12700).round();
    final alt = xmlEscape(img.caption.isEmpty ? 'Immagine' : img.caption, attribute: true);
    final rid = 'rId${images.length + 5}';
    final drawing = '<w:r><w:drawing><wp:inline xmlns:wp="http://schemas.openxmlformats.org/drawingml/2006/wordprocessingDrawing" distT="0" distB="0" distL="0" distR="0">'
        '<wp:extent cx="$cx" cy="$cy"/><wp:effectExtent l="0" t="0" r="0" b="0"/>'
        '<wp:docPr id="$id" name="Immagine $id" descr="$alt"/>'
        '<wp:cNvGraphicFramePr><a:graphicFrameLocks xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main" noChangeAspect="1"/></wp:cNvGraphicFramePr>'
        '<a:graphic xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main"><a:graphicData uri="http://schemas.openxmlformats.org/drawingml/2006/picture">'
        '<pic:pic xmlns:pic="http://schemas.openxmlformats.org/drawingml/2006/picture">'
        '<pic:nvPicPr><pic:cNvPr id="$id" name="image$id.${header.format.extension}" descr="$alt"/><pic:cNvPicPr/></pic:nvPicPr>'
        '<pic:blipFill><a:blip r:embed="$rid"/><a:stretch><a:fillRect/></a:stretch></pic:blipFill>'
        '<pic:spPr><a:xfrm><a:off x="0" y="0"/><a:ext cx="$cx" cy="$cy"/></a:xfrm><a:prstGeom prst="rect"><a:avLst/></a:prstGeom></pic:spPr>'
        '</pic:pic></a:graphicData></a:graphic></wp:inline></w:drawing></w:r>';
    _p(drawing, keepNext: img.caption.isNotEmpty);
    if (img.caption.isNotEmpty) _p(_run(img.caption), style: 'Caption');
  }
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

const _fontTable = '$kXmlDecl<w:fonts $_nsW $_nsR>'
    '<w:font w:name="Arial"><w:panose1 w:val="020B0604020202020204"/><w:charset w:val="00"/><w:family w:val="swiss"/><w:pitch w:val="variable"/>'
    '<w:sig w:usb0="E0002EFF" w:usb1="C000785B" w:usb2="00000009" w:usb3="00000000" w:csb0="000001FF" w:csb1="00000000"/></w:font></w:fonts>';

String _footer(ExportDoc d) {
  String field(String instr) =>
      '<w:r><w:fldChar w:fldCharType="begin"/></w:r><w:r><w:instrText xml:space="preserve"> $instr </w:instrText></w:r>'
      '<w:r><w:fldChar w:fldCharType="separate"/></w:r><w:r><w:t>1</w:t></w:r><w:r><w:fldChar w:fldCharType="end"/></w:r>';
  return '$kXmlDecl<w:ftr $_nsW $_nsR><w:p><w:pPr><w:pStyle w:val="Footer"/></w:pPr>${_run(d.footerText)}<w:r><w:tab/></w:r>'
      '${_run('Pagina ')}${field('PAGE')}${_run(' di ')}${field('NUMPAGES')}</w:p></w:ftr>';
}

String _numbering(ExportDoc d) {
  const marks = ['•', '–', '▪'];
  final levels = [
    for (var i = 0; i < 9; i++)
      '<w:lvl w:ilvl="$i"><w:start w:val="1"/><w:numFmt w:val="bullet"/><w:lvlText w:val="${marks[i % 3]}"/><w:lvlJc w:val="left"/>'
          '<w:pPr><w:ind w:left="${720 * (i + 1)}" w:hanging="360"/></w:pPr>'
          '<w:rPr><w:rFonts w:ascii="$_font" w:hAnsi="$_font" w:cs="$_font" w:hint="default"/><w:color w:val="${d.accentHex}"/></w:rPr></w:lvl>',
  ];
  return '$kXmlDecl<w:numbering $_nsW><w:abstractNum w:abstractNumId="0"><w:multiLevelType w:val="hybridMultilevel"/>${levels.join()}</w:abstractNum>'
      '<w:num w:numId="1"><w:abstractNumId w:val="0"/></w:num></w:numbering>';
}

String _styles(ExportDoc d) {
  final accent = d.accentHex, tint = d.tintHex, strong = d.tintStrongHex;
  final textWidth = d.page.textWidthTwips;

  String para(
    String id,
    String name, {
    String basedOn = 'Normal',
    String? next,
    int? priority,
    bool qFormat = true,
    String pPr = '',
    String rPr = '',
  }) =>
      '<w:style w:type="paragraph" w:styleId="$id"><w:name w:val="$name"/>${basedOn.isEmpty ? '' : '<w:basedOn w:val="$basedOn"/>'}'
      '${next == null ? '' : '<w:next w:val="$next"/>'}${priority == null ? '' : '<w:uiPriority w:val="$priority"/>'}${qFormat ? '<w:qFormat/>' : ''}'
      '${pPr.isEmpty ? '' : '<w:pPr>$pPr</w:pPr>'}${rPr.isEmpty ? '' : '<w:rPr>$rPr</w:rPr>'}</w:style>';

  String border(String side, int size, String color, int space) =>
      '<w:$side w:val="single" w:sz="$size" w:space="$space" w:color="$color"/>';

  const heading = '<w:keepNext/><w:keepLines/>';
  return '$kXmlDecl<w:styles $_nsW>'
      '<w:docDefaults><w:rPrDefault><w:rPr><w:rFonts w:ascii="$_font" w:eastAsia="$_font" w:hAnsi="$_font" w:cs="$_font"/>'
      '<w:sz w:val="22"/><w:szCs w:val="22"/><w:lang w:val="it-IT" w:eastAsia="en-US" w:bidi="ar-SA"/></w:rPr></w:rPrDefault>'
      '<w:pPrDefault><w:pPr><w:spacing w:after="120" w:line="288" w:lineRule="auto"/></w:pPr></w:pPrDefault></w:docDefaults>'
      '<w:style w:type="paragraph" w:default="1" w:styleId="Normal"><w:name w:val="Normal"/><w:qFormat/></w:style>'
      '<w:style w:type="character" w:default="1" w:styleId="DefaultParagraphFont"><w:name w:val="Default Paragraph Font"/><w:uiPriority w:val="1"/><w:semiHidden/><w:unhideWhenUsed/></w:style>'
      '<w:style w:type="table" w:default="1" w:styleId="TableNormal"><w:name w:val="Normal Table"/><w:uiPriority w:val="99"/><w:semiHidden/><w:unhideWhenUsed/>'
      '<w:tblPr><w:tblInd w:w="0" w:type="dxa"/><w:tblCellMar><w:top w:w="0" w:type="dxa"/><w:left w:w="108" w:type="dxa"/><w:bottom w:w="0" w:type="dxa"/><w:right w:w="108" w:type="dxa"/></w:tblCellMar></w:tblPr></w:style>'
      '<w:style w:type="numbering" w:default="1" w:styleId="NoList"><w:name w:val="No List"/><w:uiPriority w:val="99"/><w:semiHidden/><w:unhideWhenUsed/></w:style>'
      '${para('Title', 'Title', next: 'Subtitle', priority: 10, pPr: '<w:keepNext/><w:spacing w:before="0" w:after="160" w:line="240" w:lineRule="auto"/>', rPr: '<w:b/><w:bCs/><w:color w:val="${ExColors.ink}"/><w:sz w:val="60"/><w:szCs w:val="60"/>')}'
      '${para('Subtitle', 'Subtitle', next: 'Normal', priority: 11, pPr: '<w:spacing w:before="0" w:after="200"/>', rPr: '<w:color w:val="${ExColors.muted}"/><w:sz w:val="28"/><w:szCs w:val="28"/>')}'
      '${para('Heading1', 'heading 1', next: 'Normal', priority: 9, pPr: '$heading<w:spacing w:before="360" w:after="120"/><w:outlineLvl w:val="0"/>', rPr: '<w:b/><w:bCs/><w:color w:val="${ExColors.ink}"/><w:sz w:val="44"/><w:szCs w:val="44"/>')}'
      '${para('Heading2', 'heading 2', next: 'Normal', priority: 9, pPr: '$heading<w:spacing w:before="280" w:after="100"/><w:outlineLvl w:val="1"/>', rPr: '<w:b/><w:bCs/><w:color w:val="${ExColors.ink}"/><w:sz w:val="28"/><w:szCs w:val="28"/>')}'
      '${para('Heading3', 'heading 3', next: 'Normal', priority: 9, pPr: '$heading<w:spacing w:before="200" w:after="80"/><w:outlineLvl w:val="2"/>', rPr: '<w:b/><w:bCs/><w:color w:val="$accent"/><w:sz w:val="22"/><w:szCs w:val="22"/>')}'
      '${para('Quote', 'Quote', next: 'Normal', priority: 29, pPr: '<w:pBdr>${border('left', 18, accent, 10)}</w:pBdr><w:spacing w:before="120" w:after="60"/><w:ind w:left="340"/>', rPr: '<w:i/><w:iCs/><w:color w:val="${ExColors.ink}"/><w:sz w:val="26"/><w:szCs w:val="26"/>')}'
      '${para('QuoteAuthor', 'Quote Author', next: 'Normal', priority: 29, pPr: '<w:pBdr>${border('left', 18, accent, 10)}</w:pBdr><w:spacing w:before="0" w:after="160"/><w:ind w:left="340"/>', rPr: '<w:color w:val="${ExColors.muted}"/><w:sz w:val="17"/><w:szCs w:val="17"/>')}'
      '${para('Callout', 'Callout', priority: 30, pPr: '<w:pBdr>${border('top', 4, strong, 6)}${border('left', 4, strong, 6)}${border('bottom', 4, strong, 6)}${border('right', 4, strong, 6)}</w:pBdr>'
          '<w:shd w:val="clear" w:color="auto" w:fill="$tint"/><w:spacing w:before="60" w:after="60"/><w:ind w:left="170" w:right="170"/>', rPr: '<w:sz w:val="20"/><w:szCs w:val="20"/>')}'
      '${para('ListParagraph', 'List Paragraph', priority: 34, pPr: '<w:spacing w:after="60"/><w:ind w:left="720"/><w:contextualSpacing/>')}'
      '${para('Caption', 'caption', next: 'Normal', priority: 35, pPr: '<w:spacing w:before="60" w:after="200" w:line="240" w:lineRule="auto"/>', rPr: '<w:color w:val="${ExColors.muted}"/><w:sz w:val="17"/><w:szCs w:val="17"/>')}'
      '${para('Footer', 'footer', priority: 99, pPr: '<w:tabs><w:tab w:val="right" w:pos="$textWidth"/></w:tabs><w:spacing w:after="0" w:line="240" w:lineRule="auto"/>', rPr: '<w:color w:val="${ExColors.muted}"/><w:sz w:val="15"/><w:szCs w:val="15"/>')}'
      '${para('Detail', 'Detail', priority: 31, pPr: '<w:spacing w:after="40" w:line="240" w:lineRule="auto"/>', rPr: '<w:color w:val="${ExColors.muted}"/><w:sz w:val="20"/><w:szCs w:val="20"/>')}'
      '${para('SectionLabel', 'Section Label', next: 'Normal', priority: 32, pPr: '<w:keepNext/><w:spacing w:before="0" w:after="120"/>', rPr: '<w:b/><w:bCs/><w:caps/><w:color w:val="$accent"/><w:spacing w:val="16"/><w:sz w:val="16"/><w:szCs w:val="16"/>')}'
      '${para('TableText', 'Table Text', priority: 33, pPr: '<w:spacing w:before="0" w:after="0" w:line="240" w:lineRule="auto"/>', rPr: '<w:sz w:val="18"/><w:szCs w:val="18"/>')}'
      '${para('TableHeader', 'Table Header', basedOn: 'TableText', priority: 33, pPr: '<w:keepNext/>', rPr: '<w:b/><w:bCs/><w:color w:val="$accent"/><w:sz w:val="17"/><w:szCs w:val="17"/>')}'
      '<w:style w:type="table" w:styleId="$_tableStyle"><w:name w:val="Daylex Table"/><w:basedOn w:val="TableNormal"/><w:uiPriority w:val="59"/><w:qFormat/>'
      '<w:tblPr><w:tblBorders>${border('top', 4, ExColors.hairline, 0)}${border('left', 4, ExColors.hairline, 0)}${border('bottom', 4, ExColors.hairline, 0)}'
      '${border('right', 4, ExColors.hairline, 0)}${border('insideH', 4, ExColors.hairline, 0)}${border('insideV', 4, ExColors.hairline, 0)}</w:tblBorders>'
      '<w:tblCellMar><w:top w:w="60" w:type="dxa"/><w:left w:w="100" w:type="dxa"/><w:bottom w:w="60" w:type="dxa"/><w:right w:w="100" w:type="dxa"/></w:tblCellMar></w:tblPr>'
      '<w:tblStylePr w:type="firstRow"><w:rPr><w:b/><w:bCs/></w:rPr><w:tcPr><w:shd w:val="clear" w:color="auto" w:fill="$tint"/></w:tcPr></w:tblStylePr></w:style>'
      '</w:styles>';
}
