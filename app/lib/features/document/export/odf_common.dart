/// The parts ODT and ODS share: namespaces, the manifest, the metadata and the way text is spelt in ODF.
library;

import 'dart:typed_data';

import 'export_model.dart';
import 'export_text.dart';
import 'zip_package.dart';

const kOdfVersion = '1.3';
const kOdfDecl = '<?xml version="1.0" encoding="UTF-8"?>\n';

/// Every namespace the content and styles parts use, declared once on the root.
const kOdfNamespaces = 'xmlns:office="urn:oasis:names:tc:opendocument:xmlns:office:1.0" '
    'xmlns:style="urn:oasis:names:tc:opendocument:xmlns:style:1.0" '
    'xmlns:text="urn:oasis:names:tc:opendocument:xmlns:text:1.0" '
    'xmlns:table="urn:oasis:names:tc:opendocument:xmlns:table:1.0" '
    'xmlns:draw="urn:oasis:names:tc:opendocument:xmlns:drawing:1.0" '
    'xmlns:fo="urn:oasis:names:tc:opendocument:xmlns:xsl-fo-compatible:1.0" '
    'xmlns:xlink="http://www.w3.org/1999/xlink" '
    'xmlns:dc="http://purl.org/dc/elements/1.1/" '
    'xmlns:meta="urn:oasis:names:tc:opendocument:xmlns:meta:1.0" '
    'xmlns:number="urn:oasis:names:tc:opendocument:xmlns:datastyle:1.0" '
    'xmlns:svg="urn:oasis:names:tc:opendocument:xmlns:svg-compatible:1.0"';

const kOdtMime = 'application/vnd.oasis.opendocument.text';
const kOdsMime = 'application/vnd.oasis.opendocument.spreadsheet';

/// 1 cm in twips (1/1440 inch).
const _twipsPerCm = 566.929;

/// A length in centimetres, from twips, without trailing zeros: `17.05cm`.
String cm(num twips) => '${_trim((twips / _twipsPerCm).toStringAsFixed(2))}cm';

/// A length in centimetres, from points.
String cmFromPt(num pt) => cm(pt * 20);

String _trim(String s) => s.contains('.') ? s.replaceFirst(RegExp(r'\.?0+$'), '') : s;

/// [s] as the content of a `text:p` or `text:h`: tabs, line breaks and runs of spaces have their own elements,
/// because ODF reads a plain run of spaces (and a leading space) as one space or none.
String odfText(String s) {
  final out = StringBuffer();
  final plain = StringBuffer();
  var pendingSpaces = 0;
  // True at the start and after a space, a tab or a line break: the next space cannot be a plain one.
  var spaceNext = true;

  void flushPlain() {
    if (plain.isEmpty) return;
    out.write(xmlEscape(plain.toString()));
    plain.clear();
  }

  void flushSpaces() {
    if (pendingSpaces == 0) return;
    out.write(pendingSpaces == 1 ? '<text:s/>' : '<text:s text:c="$pendingSpaces"/>');
    pendingSpaces = 0;
  }

  for (final c in s.codeUnits) {
    switch (c) {
      case 0x20:
        if (spaceNext) {
          flushPlain();
          pendingSpaces++;
        } else {
          plain.write(' ');
          spaceNext = true;
        }
      case 0x09 || 0x0A:
        flushPlain();
        flushSpaces();
        out.write(c == 0x09 ? '<text:tab/>' : '<text:line-break/>');
        spaceNext = true;
      default:
        flushSpaces();
        plain.writeCharCode(c);
        spaceNext = false;
    }
  }
  flushPlain();
  flushSpaces();
  return out.toString();
}

/// `META-INF/manifest.xml`: the package's media type, then each part and picture with its own.
String odfManifest(String mediaType, Map<String, String> parts) =>
    '$kOdfDecl<manifest:manifest xmlns:manifest="urn:oasis:names:tc:opendocument:xmlns:manifest:1.0" manifest:version="$kOdfVersion">'
    '<manifest:file-entry manifest:full-path="/" manifest:version="$kOdfVersion" manifest:media-type="$mediaType"/>'
    '${parts.entries.map((e) => '<manifest:file-entry manifest:full-path="${xmlEscape(e.key, attribute: true)}" manifest:media-type="${e.value}"/>').join()}'
    '</manifest:manifest>';

/// `meta.xml`: title, subject, author, language and the two dates.
String odfMeta(ExportDoc d) =>
    '$kOdfDecl<office:document-meta $kOdfNamespaces office:version="$kOdfVersion"><office:meta>'
    '<meta:generator>Daylex</meta:generator>'
    '<dc:title>${xmlEscape(d.title)}</dc:title>'
    '${d.subtitle.isEmpty ? '' : '<dc:subject>${xmlEscape(d.subtitle)}</dc:subject>'}'
    '<meta:initial-creator>${xmlEscape(d.creator)}</meta:initial-creator>'
    '<dc:creator>${xmlEscape(d.creator)}</dc:creator>'
    '<meta:creation-date>${utcStamp(d.created)}</meta:creation-date>'
    '<dc:date>${utcStamp(d.modified)}</dc:date>'
    '<dc:language>it-IT</dc:language>'
    '</office:meta></office:document-meta>';

/// The ODF package: `mimetype` first and stored (a reader finds the type at a fixed offset), then the parts.
Uint8List odfPackage(
  ExportDoc d, {
  required String mediaType,
  required String content,
  required String styles,
  String? settings,
  List<({String path, Uint8List bytes, String mime})> pictures = const [],
}) {
  final zip = ZipPackage(d.modified)
    ..addStored('mimetype', mediaType.codeUnits)
    ..addText('content.xml', content)
    ..addText('styles.xml', styles)
    ..addText('meta.xml', odfMeta(d));
  if (settings != null) zip.addText('settings.xml', settings);
  for (final p in pictures) {
    zip.addBytes(p.path, p.bytes);
  }
  zip.addText(
    'META-INF/manifest.xml',
    odfManifest(mediaType, {
      'content.xml': 'text/xml',
      'styles.xml': 'text/xml',
      'meta.xml': 'text/xml',
      if (settings != null) 'settings.xml': 'text/xml',
      for (final p in pictures) p.path: p.mime,
    }),
  );
  return zip.toBytes();
}
