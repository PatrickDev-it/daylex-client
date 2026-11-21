import 'dart:convert';
import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

/// What makes the `pdf` package's output PDF/A-1b (ISO 19005-1, level B), the one profile the civil (PCT), the
/// administrative (PAT) and the tax (PTT) courts all accept for a filing. [newPdfaDocument] is the one place a
/// document is made and [OpaqueImage] the one way an image enters it, so the renderer cannot write any other kind
/// of PDF and there is no flag to forget.
///
/// Only the package's public API is used. What the package already does right is left alone: every font embedded,
/// widths within a unit of the font program, a trailer file ID, no annotations, no JavaScript, no encryption. What
/// it gets wrong for PDF/A is done here: the 1.5 file structure, the missing identification and output intent, the
/// metadata that disagrees with the Info dictionary, and the transparency of every image.

const _pdfaIdNamespace = 'http://www.aiim.org/pdfa/ns/id/';

/// A new document that saves as PDF/A-1b: header 1.4 with a plain cross-reference table (no xref or object
/// streams), the Info dictionary and the XMP packet written from one set of values, and [colorProfile] (an
/// sRGB ICC profile) as the GTS_PDFA1 output intent that every DeviceRGB colour of the page refers to.
///
/// [title] and [author] may be empty: an empty entry is left out of both Info and XMP.
pw.Document newPdfaDocument({
  required String title,
  required String author,
  required String application,
  required Uint8List colorProfile,
  required pw.ThemeData theme,
}) {
  final pdf = pw.Document(version: PdfVersion.pdf_1_4, theme: theme);
  final info = _PdfaInfo(
    pdf.document,
    title: _xmlSafe(title),
    author: _xmlSafe(author),
    creator: application,
    producer: application,
  );
  _PdfaXmp(pdf.document, info);
  PdfaColorProfile(pdf.document, colorProfile);
  return pdf;
}

/// Characters XML 1.0 cannot carry, which an XMP packet would be refused for: they would also make the Info
/// entry differ from its XMP twin.
final _notXml = RegExp(r'[\x00-\x08\x0B\x0C\x0E-\x1F\x7F-\x9F]');

String? _xmlSafe(String text) {
  final clean = text.replaceAll(_notXml, ' ').trim();
  return clean.isEmpty ? null : clean;
}

/// The Info dictionary. The XMP packet reads its entries back from here, so the two can never differ.
class _PdfaInfo extends PdfInfo {
  _PdfaInfo(
    super.pdfDocument, {
    super.title,
    super.author,
    super.creator,
    super.producer,
  });

  @override
  void prepare() {
    super.prepare();
    // The catalog always says `/Version /1.7`, which overrides the header: a PDF/A-1 file must not claim more
    // than the 1.4 it is. The catalog is prepared before this object, which is made after it.
    pdfDocument.catalog.params.values.remove('/Version');
  }

  /// The text of entry [key] as the package wrote it, or null when the entry is absent.
  String? text(String key) {
    final dynamic entry = params[key];
    if (entry == null) return null;
    final Uint8List bytes = entry.value;
    if (bytes.length >= 2 && bytes[0] == 0xFE && bytes[1] == 0xFF) {
      // UTF-16BE with a byte order mark: what the package writes when Latin-1 cannot hold the text.
      return String.fromCharCodes([
        for (var i = 2; i + 1 < bytes.length; i += 2)
          (bytes[i] << 8) | bytes[i + 1],
      ]);
    }
    return latin1.decode(bytes);
  }
}

/// The XMP metadata stream: PDF/A part 1 level B, and the Info entries again as the properties veraPDF compares
/// them with (6.7.3).
///
/// A `PdfMetadata` has to be given an XML document, and `package:xml` is not a dependency of the app. The
/// package's own `PdfaRdf` is given only to satisfy that: it says part 3, so its content never reaches the file.
class _PdfaXmp extends PdfMetadata {
  _PdfaXmp(PdfDocument document, this._info)
    : super(document, PdfaRdf().create()!);

  final _PdfaInfo _info;

  @override
  void prepare() {
    super.prepare();
    params.data = Uint8List.fromList(utf8.encode(_packet()));
  }

  String _packet() {
    final title = _info.text('/Title');
    final author = _info.text('/Author');
    // The BOM in `begin` is how a reader tells the packet is UTF-8.
    return '<?xpacket begin="\uFEFF" id="W5M0MpCehiHzreSzNTczkc9d"?>\n'
        '<x:xmpmeta xmlns:x="adobe:ns:meta/">\n'
        '<rdf:RDF xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#">\n'
        '<rdf:Description rdf:about="" xmlns:pdfaid="$_pdfaIdNamespace">\n'
        '<pdfaid:part>1</pdfaid:part>\n'
        '<pdfaid:conformance>B</pdfaid:conformance>\n'
        '</rdf:Description>\n'
        '<rdf:Description rdf:about="" xmlns:dc="http://purl.org/dc/elements/1.1/">\n'
        '<dc:format>application/pdf</dc:format>\n'
        '${title == null ? '' : '<dc:title><rdf:Alt><rdf:li xml:lang="x-default">${_xml(title)}</rdf:li></rdf:Alt></dc:title>\n'}'
        '${author == null ? '' : '<dc:creator><rdf:Seq><rdf:li>${_xml(author)}</rdf:li></rdf:Seq></dc:creator>\n'}'
        '</rdf:Description>\n'
        '<rdf:Description rdf:about="" xmlns:pdf="http://ns.adobe.com/pdf/1.3/">\n'
        '<pdf:Producer>${_xml(_info.text('/Producer')!)}</pdf:Producer>\n'
        '</rdf:Description>\n'
        '<rdf:Description rdf:about="" xmlns:xmp="http://ns.adobe.com/xap/1.0/">\n'
        '<xmp:CreatorTool>${_xml(_info.text('/Creator')!)}</xmp:CreatorTool>\n'
        '<xmp:CreateDate>${_xmpDate(_info.text('/CreationDate')!)}</xmp:CreateDate>\n'
        '</rdf:Description>\n'
        '</rdf:RDF>\n'
        '</x:xmpmeta>\n'
        '<?xpacket end="w"?>';
  }

  static String _xml(String text) => text
      .replaceAll('&', '&amp;')
      .replaceAll('<', '&lt;')
      .replaceAll('>', '&gt;');

  /// `D:20261120222004Z` as `2026-11-20T22:20:04Z`: the same instant, in the same zone, written the XMP way.
  static String _xmpDate(String pdfDate) {
    final m = RegExp(r'^D:(\d{4})(\d{2})(\d{2})(\d{2})(\d{2})(\d{2})Z$')
        .firstMatch(pdfDate);
    if (m == null) {
      // The package changed how it writes the date: fail here, not as a PDF/A file that disagrees with itself.
      throw StateError('Unexpected PDF date "$pdfDate"');
    }
    return '${m[1]}-${m[2]}-${m[3]}T${m[4]}:${m[5]}:${m[6]}Z';
  }
}

/// An image the PDF can hold: opaque, and in no colour space that needs an output intent the file lacks.
///
/// The package embeds every non-JPEG image as RGB plus an `/SMask` for its alpha channel, even when the alpha is
/// all 255, and PDF/A-1 forbids any soft mask. Such an image is flattened on white here, as the page is white
/// (the renderer already blends its own opacities on white, `_Style._mix`). An RGB or grey JPEG is embedded as it
/// is, still compressed; a CMYK one is decoded and encoded again as RGB by the package, as DeviceCMYK needs a
/// CMYK output intent.
///
/// Built lazily, like any [pw.ImageProvider]: an image is decoded when the page is painted, never while pages
/// that cannot fit are being measured.
class OpaqueImage extends pw.ImageProvider {
  factory OpaqueImage(Uint8List bytes) => OpaqueImage._(pw.MemoryImage(bytes));

  OpaqueImage._(this._source)
    : super(
        // The base class keeps the width and height as stored and swaps them for a rotated image itself.
        _source.orientation.index >= 4 ? _source.height : _source.width,
        (_source.orientation.index >= 4 ? _source.width : _source.height)!,
        _source.orientation,
        _source.dpi,
      );

  final pw.MemoryImage _source;

  /// Always the image as stored: a resampled copy would come back with the transparency it was made without.
  @override
  PdfImage buildImage(pw.Context context, {int? width, int? height}) {
    final document = context.document;
    final stored = _source.buildImage(context);
    final mask = stored.params['/SMask'];
    if (mask == null) {
      if (stored.params['/ColorSpace'] != const PdfName('/DeviceCMYK')) {
        return stored;
      }
      // Smaller by a pixel, the package decodes the JPEG and writes it again as RGB; it keeps the source as is
      // at its own size.
      document.objects.remove(stored);
      return _source.buildImage(context, width: stored.width - 1);
    }
    final dynamic reference = mask;
    final alpha = document.objects.whereType<PdfImage>().firstWhere(
      (object) => object.objser == reference.ser,
    );
    final flat = _onWhite(stored.buf.output(), alpha.buf.output());
    document.objects
      ..remove(alpha)
      ..remove(stored);
    return PdfImage(
      document,
      image: flat,
      width: stored.width,
      height: stored.height,
      alpha: false,
    );
  }
}

/// [rgb] (three bytes a pixel) with each pixel blended on white by its byte of [alpha]; [rgb] itself when
/// nothing in the image is transparent.
Uint8List _onWhite(Uint8List rgb, Uint8List alpha) {
  if (!alpha.any((a) => a != 255)) return rgb;
  final flat = Uint8List(rgb.length);
  for (var pixel = 0; pixel < alpha.length; pixel++) {
    final a = alpha[pixel];
    for (var channel = pixel * 3; channel < pixel * 3 + 3; channel++) {
      flat[channel] = (rgb[channel] * a + 255 * (255 - a) + 127) ~/ 255;
    }
  }
  return flat;
}
