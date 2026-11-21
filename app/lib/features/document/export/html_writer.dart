/// HTML: one standalone HTML5 file, inline CSS close to the PDF, pictures as data URIs, semantic tables and quotes.
library;

import 'dart:convert';
import 'dart:typed_data';

import '../model/document.dart';
import 'export_model.dart';
import 'export_text.dart';

Uint8List encodeHtml(PaperDocument doc) => Uint8List.fromList(utf8.encode(_Html(buildExportDoc(doc)).build()));

/// Text for an element or an attribute: escaped, and a newline is a line break.
String _t(String s) => htmlEscape(s).replaceAll('\n', '<br>');

String _css(ExportDoc d) => '''
:root{--accent:#${d.accentHex};--tint:#${d.tintHex};--tint-strong:#${d.tintStrongHex};--ink:#${ExColors.ink};--body:#334155;--muted:#${ExColors.muted};--hairline:#${ExColors.hairline};--zebra:#${ExColors.zebra};--positive:#${ExColors.positive};--negative:#${ExColors.negative}}
*{box-sizing:border-box}
body{margin:0;background:#f1f5f9;color:var(--body);font:15px/1.65 Inter,"Segoe UI",Roboto,Helvetica,Arial,sans-serif;-webkit-text-size-adjust:100%}
article{max-width:794px;margin:32px auto;background:#fff;padding:56px;box-shadow:0 1px 3px rgba(15,23,42,.12),0 8px 24px rgba(15,23,42,.06)}
h1,h2,h3,h4{color:var(--ink);line-height:1.25;margin:0}
h1{font-size:38px;letter-spacing:-.4px}
h2{font-size:29px;letter-spacing:-.3px;margin:40px 0 14px}
h3{font-size:19px;margin:30px 0 10px}
h4{font-size:12px;text-transform:uppercase;letter-spacing:1px;color:var(--accent);margin:24px 0 8px}
p{margin:0 0 14px}
.subtitle{font-size:18px;color:var(--muted);margin:10px 0 0}
.facts{display:flex;flex-wrap:wrap;gap:24px 48px;margin:28px 0 0;padding-top:20px;border-top:1px solid var(--hairline)}
.facts dt{font-size:11px;text-transform:uppercase;letter-spacing:1px;color:var(--muted)}
.facts dd{margin:4px 0 0;font-weight:600;color:var(--ink)}
.page{margin-top:36px}
.label{font-size:11px;font-weight:700;text-transform:uppercase;letter-spacing:1.2px;color:var(--accent);margin:0 0 16px}
ul{margin:0 0 14px;padding-left:22px}
li{margin:0 0 6px;padding-left:4px}
li::marker{color:var(--accent)}
table{width:100%;border-collapse:collapse;margin:0 0 14px;font-size:13.5px}
caption{caption-side:bottom;text-align:left;font-size:12px;color:var(--muted);padding-top:8px}
th{background:var(--tint);color:var(--accent);font-size:11px;text-transform:uppercase;letter-spacing:.7px;text-align:left}
th,td{padding:8px 10px;border-bottom:1px solid var(--hairline);vertical-align:top}
tbody tr:nth-child(even){background:var(--zebra)}
td:first-child{font-weight:500;color:var(--ink)}
.num{text-align:right}
.metrics{display:grid;grid-template-columns:repeat(auto-fit,minmax(150px,1fr));gap:10px;margin:0 0 14px}
.metric{background:var(--tint);border-radius:6px;padding:12px 14px}
.metric dt{font-size:10px;text-transform:uppercase;letter-spacing:.7px;color:var(--muted)}
.metric dd{margin:0}
.metric .value{font-size:24px;font-weight:700;color:var(--ink);margin-top:6px}
.metric .delta{font-size:12px;font-weight:500;color:var(--positive);margin-top:3px}
.metric .delta.down{color:var(--negative)}
figure{margin:0 0 14px}
figcaption{font-size:12px;color:var(--muted);margin-top:6px}
.quote blockquote{margin:0;padding:4px 0 4px 18px;border-left:3px solid var(--accent);font-size:18px;font-weight:500;color:var(--ink)}
.quote blockquote p:last-child{margin-bottom:0}
.quote figcaption{padding-left:21px}
.callout{background:var(--tint);border:1px solid var(--tint-strong);border-radius:6px;padding:14px 16px;margin:0 0 14px}
.callout p{margin:0 0 6px;font-size:14px}
.callout p:last-child{margin-bottom:0}
.callout-title{font-weight:600;color:var(--ink)}
img{display:block;max-width:100%;height:auto;border-radius:6px}
.placeholder{color:var(--muted);font-style:italic}
@media (max-width:640px){article{margin:0;padding:24px 18px;box-shadow:none}h1{font-size:30px}h2{font-size:24px}}
@media print{body{background:#fff}article{max-width:none;margin:0;padding:0;box-shadow:none}.page+.page{break-before:page;margin-top:0}tr,figure,.callout{break-inside:avoid}thead{display:table-header-group}}
''';

class _Html {
  _Html(this.d);

  final ExportDoc d;
  final _out = StringBuffer();
  var _inPage = false;

  String build() {
    final front = d.blocks.take(d.bodyStart).toList();
    final facts = front.whereType<ExFact>().toList();
    final title = d.blocks.first as ExTitle;
    final subtitle = front.whereType<ExSubtitle>().firstOrNull;

    _out
      ..writeln('<!doctype html>')
      ..writeln('<html lang="it">')
      ..writeln('<head>')
      ..writeln('<meta charset="utf-8">')
      ..writeln('<meta name="viewport" content="width=device-width, initial-scale=1">')
      ..writeln('<title>${htmlEscape(d.title.replaceAll('\n', ' '))}</title>')
      ..writeln('<meta name="author" content="${htmlEscape(d.creator.replaceAll('\n', ' '))}">');
    if (d.subtitle.isNotEmpty) _out.writeln('<meta name="description" content="${htmlEscape(d.subtitle.replaceAll('\n', ' '))}">');
    _out
      ..writeln('<meta name="generator" content="Daylex">')
      ..writeln('<style>${_css(d)}</style>')
      ..writeln('</head>')
      ..writeln('<body>')
      ..writeln('<article>')
      ..writeln('<header>')
      ..writeln('<h1>${_t(title.text)}</h1>');
    if (subtitle != null) _out.writeln('<p class="subtitle">${_t(subtitle.text)}</p>');
    _out
      ..writeln('<dl class="facts">${facts.map((f) => '<div><dt>${_t(f.label)}</dt><dd>${_t(f.value)}</dd></div>').join()}</dl>')
      ..writeln('</header>');

    for (final b in d.blocks.skip(d.bodyStart)) {
      if (b is ExPageBreak) {
        _closePage();
        continue;
      }
      if (!_inPage) {
        _out.writeln('<div class="page">');
        _inPage = true;
      }
      _block(b);
    }
    _closePage();
    _out
      ..writeln('</article>')
      ..writeln('</body>')
      ..writeln('</html>');
    return _out.toString();
  }

  void _closePage() {
    if (_inPage) _out.writeln('</div>');
    _inPage = false;
  }

  void _block(ExBlock b) {
    switch (b) {
      case ExTitle() || ExSubtitle() || ExFact() || ExPageBreak():
        break;
      case ExSectionLabel(:final text):
        _out.writeln('<p class="label">${_t(text)}</p>');
      case ExHeading(:final level, :final text):
        _out.writeln('<h${level + 1}>${_t(text)}</h${level + 1}>');
      case ExParagraph(:final text):
        _out.writeln('<p>${_t(text)}</p>');
      case ExBullets(:final items):
        _out.writeln('<ul>${items.map((i) => '<li>${_t(i)}</li>').join()}</ul>');
      case ExTable():
        _table(b);
      case ExMetrics(:final items):
        _out.writeln('<dl class="metrics">${items.map(_metric).join()}</dl>');
      case ExQuote(:final text, :final author):
        _out.writeln('<figure class="quote"><blockquote><p>${_t(text)}</p></blockquote>'
            '${author.isEmpty ? '' : '<figcaption>— ${_t(author)}</figcaption>'}</figure>');
      case ExCallout(:final title, :final text):
        _out.writeln('<div class="callout" role="note">${title.isEmpty ? '' : '<p class="callout-title">${_t(title)}</p>'}'
            '${text.isEmpty ? '' : '<p>${_t(text)}</p>'}</div>');
      case ExImage():
        _image(b);
    }
  }

  String _metric(ExMetric m) {
    final down = m.delta.trim().startsWith('-');
    return '<div class="metric"><dt>${_t(m.label)}</dt><dd class="value">${_t(m.value)}</dd>'
        '${m.delta.isEmpty ? '' : '<dd class="delta${down ? ' down' : ''}">${_t(m.delta)}</dd>'}</div>';
  }

  void _table(ExTable t) {
    String cells(List<String> row, String tag) => [
      for (var c = 0; c < t.width; c++) '<$tag${tag == 'th' ? ' scope="col"' : ''}${t.numeric[c] ? ' class="num"' : ''}>${_t(row[c])}</$tag>',
    ].join();

    _out
      ..write('<table>')
      ..write(t.caption.isEmpty ? '' : '<caption>${_t(t.caption)}</caption>')
      ..write(t.hasHeader ? '<thead><tr>${cells(t.header, 'th')}</tr></thead>' : '')
      ..write('<tbody>${t.rows.map((r) => '<tr>${cells(r, 'td')}</tr>').join()}</tbody>')
      ..writeln('</table>');
  }

  void _image(ExImage img) {
    final header = img.header;
    if (header == null) {
      _out.writeln('<p class="placeholder">${_t(img.marker)}</p>');
      return;
    }
    final (w, h) = img.fit(d.page.textWidthPt, d.page.textHeightPt);
    final alt = htmlEscape((img.caption.isEmpty ? 'Immagine' : img.caption).replaceAll('\n', ' '));
    _out.writeln('<figure><img src="data:${header.format.mime};base64,${base64Encode(img.bytes!)}" alt="$alt" '
        'width="${(w / 0.75).round()}" height="${(h / 0.75).round()}">'
        '${img.caption.isEmpty ? '' : '<figcaption>${_t(img.caption)}</figcaption>'}</figure>');
  }
}
