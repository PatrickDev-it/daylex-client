/// HTML: one standalone HTML5 file. Each page of the document is a sheet with its own header and footer, each role of
/// the document's style a class, a block's own look inline on it; pictures are data URIs, tables and quotes semantic.
library;

import 'dart:convert';
import 'dart:typed_data';

import '../model/document.dart';
import '../model/inline.dart';
import 'export_model.dart';
import 'export_text.dart';

Uint8List encodeHtml(PaperDocument doc) => Uint8List.fromList(utf8.encode(_Html(buildExportDoc(doc)).build()));

/// Text for an element: escaped, and a newline is a line break.
String _t(String s) => htmlEscape(s).replaceAll('\n', '<br>');

String _attr(String s) => htmlEscape(s.replaceAll('\n', ' '));

/// The PDF's line height is a multiple of the typeface's single spacing, CSS's a multiple of the type size: single
/// spacing is about 1.15 of the size for these typefaces, so the page reads as the PDF does without matching it to
/// the point.
const _singleSpacing = 1.15;

String _family(DocFont f) {
  final generic = switch (f.kind) {
    FontKind.serif => 'serif',
    FontKind.sans => 'sans-serif',
    FontKind.mono => 'monospace',
  };
  // Single quotes: the list also stands inside a style="..." attribute.
  return ["'${f.family}'", if (f.asset != f.family) "'${f.asset}'", generic].join(',');
}

String _hex(int argb) => '#${hex6(argb)}';

/// CSS declarations of [s] as the PDF draws it; [only] picks the fields a block sets itself (null: all). [boxed] false
/// leaves the indent and the box out (a list, whose indent is its markers', or a cell, whose box is the table's).
List<String> _decl(ResolvedStyle s, Set<String>? only, {bool boxed = true}) {
  bool has(String f) => only == null || only.contains(f);
  final drawn = s.borderWidth > 0 && s.border != BlockBorder.none;
  String side(BlockBorder b) =>
      drawn && (s.border == BlockBorder.box || s.border == b) ? '${ptLength(s.borderWidth)} solid ${_hex(s.lineColor)}' : 'none';
  return [
    if (has('font')) 'font-family:${_family(s.font)}',
    if (has('size')) 'font-size:${ptLength(s.size)}',
    if (has('bold')) 'font-weight:${s.bold ? 700 : 400}',
    if (has('italic')) 'font-style:${s.italic ? 'italic' : 'normal'}',
    if (has('underline')) 'text-decoration:${s.underline ? 'underline' : 'none'}',
    if (has('caps')) 'text-transform:${s.caps ? 'uppercase' : 'none'}',
    if (has('color')) 'color:${_hex(s.color)}',
    if (has('lineHeight')) 'line-height:${(s.lineHeight * _singleSpacing).toStringAsFixed(3)}',
    if (has('align')) 'text-align:${s.align.name}',
    if (has('spaceBefore')) 'margin-top:${ptLength(s.spaceBefore)}',
    if (has('spaceAfter')) 'margin-bottom:${ptLength(s.spaceAfter)}',
    if (boxed && has('indent')) 'margin-left:${ptLength(s.indent)}',
    if (has('firstLineIndent')) 'text-indent:${ptLength(s.firstLineIndent)}',
    if (boxed && ['border', 'borderColor', 'borderWidth'].any(has))
      'border-top:${side(BlockBorder.top)};border-left:${side(BlockBorder.left)};'
          'border-bottom:${side(BlockBorder.bottom)};border-right:${side(BlockBorder.box)}',
    if (boxed && has('padding')) 'padding:${ptLength(s.padding)}',
    if (boxed && has('background')) 'background:${s.background == null ? 'transparent' : _hex(s.background!)}',
  ];
}

/// The list-style-type of each marker; a letter is `a)`, as the PDF writes it.
String _listType(ListMarker m) => switch (m) {
  ListMarker.disc => 'disc',
  ListMarker.dash => '"– "',
  ListMarker.number => 'decimal',
  ListMarker.letter => 'daylex-letter',
  ListMarker.none => 'none',
};

String _css(ExportDoc d) {
  final p = d.page;
  double pt(int twips) => twips / 20;
  final roles = [
    for (final role in StyleRole.values)
      '.r-${role.name}{${_decl(d.roles[role]!, null, boxed: role != StyleRole.bullets && role != StyleRole.table && role != StyleRole.tableHeader).join(';')}}',
  ].join('\n');
  return '''
@counter-style daylex-letter{system:extends lower-alpha;suffix:") "}
*{box-sizing:border-box}
body{margin:0;background:#E2E8F0;color:#000;-webkit-text-size-adjust:100%}
h1,h2,h3,p,ul,ol,blockquote,figure,table{margin:0}
ul,ol{padding:0}
.page{position:relative;width:${ptLength(pt(p.widthTwips))};min-height:${ptLength(pt(p.heightTwips))};margin:24px auto;background:#fff;
padding:${ptLength(pt(p.topTwips))} ${ptLength(pt(p.rightTwips))} ${ptLength(pt(p.bottomTwips))} ${ptLength(pt(p.leftTwips))};
box-shadow:0 1px 3px rgba(15,23,42,.12),0 8px 24px rgba(15,23,42,.06)}
.region{position:absolute;left:${ptLength(pt(p.leftTwips))};right:${ptLength(pt(p.rightTwips))};display:flex;gap:12pt}
.region.top{top:${ptLength(pt(p.headerTwips))};align-items:flex-start}
.region.bottom{bottom:${ptLength(pt(p.footerTwips))};align-items:flex-end}
.region>div{flex:1 1 0;min-width:0}
.region img{display:inline-block;vertical-align:top}
table{width:100%;border-collapse:collapse}
td,th{vertical-align:top;text-align:inherit}
caption{caption-side:bottom}
.num{text-align:right}
.metrics{display:flex;flex-wrap:wrap;gap:10pt}
.metrics>div{flex:1 1 0;min-width:100pt;margin:0 !important}
.metrics dd{margin:0}
.up{color:#${ExColors.positive}}
.down{color:#${ExColors.negative}}
img{max-width:100%;height:auto}
$roles
@media (max-width:680px){.page{width:auto;min-height:0;margin:0 0 12px;padding:24px 18px;box-shadow:none}
.region{position:static;margin:0 0 16px}.region.bottom{margin:16px 0 0}}
@page{size:A4 ${p.landscape ? 'landscape' : 'portrait'};margin:0}
@media print{body{background:#fff}.page{margin:0;box-shadow:none;break-after:page}.page:last-child{break-after:auto}
tr,figure{break-inside:avoid}thead{display:table-header-group}}
''';
}

class _Html {
  _Html(this.d);

  final ExportDoc d;
  final _out = StringBuffer();
  var _page = 0;

  ExPageRegions get _regions => _page == 0 ? d.first : d.pages[_page];

  String build() {
    _out
      ..writeln('<!doctype html>')
      ..writeln('<html lang="it">')
      ..writeln('<head>')
      ..writeln('<meta charset="utf-8">')
      ..writeln('<meta name="viewport" content="width=device-width, initial-scale=1">')
      ..writeln('<title>${_attr(d.title)}</title>')
      ..writeln('<meta name="author" content="${_attr(d.creator)}">');
    if (d.subtitle.isNotEmpty) _out.writeln('<meta name="description" content="${_attr(d.subtitle)}">');
    _out
      ..writeln('<meta name="generator" content="Daylex">')
      ..writeln('<style>${_css(d)}</style>')
      ..writeln('</head>')
      ..writeln('<body>');
    _open();
    for (final b in d.blocks) {
      _block(b);
    }
    _close();
    _out
      ..writeln('</body>')
      ..writeln('</html>');
    return _out.toString();
  }

  void _open() {
    _out.writeln('<section class="page">');
    _region(_regions.header, top: true);
  }

  void _close() {
    _region(_regions.footer, top: false);
    _out.writeln('</section>');
  }

  /// The class of [st]'s role and, inline, what the block sets itself.
  static String _look(ExStyle st, {bool boxed = true, List<String> extra = const []}) {
    final own = [..._decl(st.resolved, st.own, boxed: boxed), ...extra];
    return ' class="r-${st.role.name}"${own.isEmpty ? '' : ' style="${own.join(';')}"'}';
  }

  /// [text]'s runs, each in its emphasis; [fields] gives what `{pagina}` and `{pagine}` print.
  static String _runs(String text, {Map<ExField, String>? fields}) => [
    for (final r in runsOf(text, fields: fields != null))
      () {
        var s = r.field == null ? _t(r.text) : fields![r.field]!;
        if (r.underline) s = '<u>$s</u>';
        if (r.italic) s = '<em>$s</em>';
        if (r.bold) s = '<strong>$s</strong>';
        return s;
      }(),
  ].join();

  /// A header or a footer: its parts side by side, its line between it and the page.
  void _region(ExRegion r, {required bool top}) {
    if (r.isEmpty) return;
    final s = r.style!;
    final fields = {ExField.page: '${_page + 1}', ExField.pages: '${d.pages.length}'};
    final line = r.line && s.borderWidth > 0
        ? ';border-${top ? 'bottom' : 'top'}:${ptLength(s.borderWidth)} solid ${_hex(s.lineColor)};padding-${top ? 'bottom' : 'top'}:${ptLength(s.padding)}'
        : '';
    final parts = [
      for (final p in r.parts)
        '<div style="text-align:${p.align.name}">'
            '${p.logo == null ? '' : '<div><img src="data:${p.logo!.header!.format.mime};base64,${base64Encode(p.logo!.bytes)}" alt="" '
                'style="height:${ptLength(p.logo!.heightPt)};width:auto"></div>'}'
            '${p.text.isEmpty ? '' : _runs(p.text, fields: fields)}</div>',
    ].join();
    final tag = top ? 'header' : 'footer';
    _out.writeln('<$tag class="region ${top ? 'top' : 'bottom'}" style="${_decl(s, null, boxed: false).where((x) => !x.startsWith('margin')).join(';')}$line">$parts</$tag>');
  }

  void _block(ExBlock b) {
    switch (b) {
      case ExPageBreak():
        _close();
        _page++;
        _open();
      case ExHeading(:final level, :final text, :final style):
        _out.writeln('<h$level${_look(style)}>${_runs(text)}</h$level>');
      case ExParagraph(:final text, :final style):
        _out.writeln('<p${_look(style)}>${_runs(text)}</p>');
      case ExBullets():
        _bullets(b);
      case ExTable():
        _table(b);
      case ExMetrics():
        _metrics(b);
      case ExQuote(:final text, :final author, :final style, :final authorStyle):
        _out.writeln('<figure${_look(style)}><blockquote>${_runs(text)}</blockquote>'
            '${author.isEmpty ? '' : '<figcaption${_look(authorStyle)}>— ${_runs(author)}</figcaption>'}</figure>');
      case ExCallout(:final title, :final text, :final style):
        _out.writeln('<div role="note"${_look(style)}>${title.isEmpty ? '' : '<div style="font-weight:700">${_runs(title)}</div>'}'
            '${text.isEmpty ? '' : '<div${title.isEmpty ? '' : ' style="margin-top:4pt"'}>${_runs(text)}</div>'}</div>');
      case ExImage():
        _image(b);
    }
  }

  void _bullets(ExBullets b) {
    final s = b.style.resolved;
    final tag = s.marker == ListMarker.number || s.marker == ListMarker.letter ? 'ol' : 'ul';
    final extra = ['list-style-type:${_listType(s.marker)}', 'padding-left:${ptLength(s.markerWidth)}'];
    _out.writeln('<$tag${_look(b.style, boxed: false, extra: extra)}>${b.items.map((i) => '<li>${_runs(i)}</li>').join()}</$tag>');
  }

  void _table(ExTable t) {
    final s = t.style.resolved;
    final line = s.borderWidth > 0 ? '${ptLength(s.borderWidth)} solid ${_hex(s.lineColor)}' : 'none';
    final borders = switch (s.grid) {
      TableGrid.all => 'border:$line',
      TableGrid.rows => 'border-bottom:$line',
      TableGrid.none => 'border:none',
    };
    final pad = 'padding:${ptLength(s.padding)}';
    String cells(List<String> row, ExStyle st, String tag, int? fill) => [
      for (var c = 0; c < t.width; c++)
        '<$tag${tag == 'th' ? ' scope="col"' : ''}${_look(st, boxed: false, extra: [
          borders,
          pad,
          if (fill != null) 'background:${_hex(fill)}',
          if (t.numeric[c]) 'text-align:right',
        ])}>${_runs(row[c])}</$tag>',
    ].join();

    final indent = s.indent > 0 ? ' style="margin-left:${ptLength(s.indent)};width:calc(100% - ${ptLength(s.indent)})"' : '';
    _out
      ..write('<table$indent>')
      ..write(t.caption.isEmpty ? '' : '<caption${_look(t.captionStyle)}>${_runs(t.caption)}</caption>')
      ..write(t.hasHeader ? '<thead><tr>${cells(t.header, t.headerStyle, 'th', t.headerStyle.resolved.background ?? s.background)}</tr></thead>' : '')
      ..write('<tbody>${[
        for (final (r, row) in t.rows.indexed) '<tr>${cells(row, t.style, 'td', r.isOdd ? (s.stripe ?? s.background) : s.background)}</tr>',
      ].join()}</tbody>')
      ..writeln('</table>');
  }

  /// The indicators side by side, each in the block's box as the PDF draws them: label, value, change.
  void _metrics(ExMetrics m) {
    final s = m.style.resolved;
    // Each tile takes the role's class, box included; the list holds the block's spacing and indent.
    final tile = _look(m.style);
    String metric(ExMetric x) => '<div$tile><dt${_look(m.labelStyle)}>${_runs(x.label)}</dt>'
        '<dd style="margin-top:4pt">${_runs(x.value)}</dd>'
        '${x.delta.isEmpty ? '' : '<dd${_look(m.labelStyle)}><span class="${x.down ? 'down' : 'up'}">${_runs(x.delta)}</span></dd>'}</div>';
    _out.writeln('<dl class="metrics" style="margin:${ptLength(s.spaceBefore)} 0 ${ptLength(s.spaceAfter)} ${ptLength(s.indent)}">'
        '${m.items.map(metric).join()}</dl>');
  }

  void _image(ExImage img) {
    final header = img.header;
    if (header == null) {
      _out.writeln('<p${_look(img.style)}><em>${_t(img.marker)}</em></p>');
      return;
    }
    final (w, h) = img.fit(d.page.textWidthPt, d.page.textHeightPt);
    final alt = _attr(img.caption.isEmpty ? 'Immagine' : plainInline(img.caption));
    _out.writeln('<figure${_look(img.style)}><img src="data:${header.format.mime};base64,${base64Encode(img.bytes!)}" alt="$alt" '
        'width="${(w / 0.75).round()}" height="${(h / 0.75).round()}">'
        '${img.caption.isEmpty ? '' : '<figcaption${_look(img.captionStyle)}>${_runs(img.caption)}</figcaption>'}</figure>');
  }
}
