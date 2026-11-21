import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show listEquals;
import 'package:flutter_test/flutter_test.dart';
import 'package:daylex/features/document/render/pdf_renderer.dart';
import 'package:daylex/features/document/render/pdfa.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import 'pdfa_samples.dart';

/// Every PDF the renderer makes is PDF/A-1b, the profile the Italian courts accept (PCT, PAT, PTT).
///
/// veraPDF is the judge of that, and it is run by hand (`PDFA_SAMPLES_DIR`, below). What this file keeps in the
/// suite is what a change to the renderer or the `pdf` package can break without anyone running veraPDF: the
/// features PDF/A-1 forbids, read off the bytes. [pdfaViolations] is checked against a PDF the package makes
/// by default, so a scanner that stopped seeing a rule would fail here.

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late PdfRenderer renderer;
  final samples = <String, Uint8List>{};

  setUpAll(() async {
    renderer = PdfRenderer(await PdfFontSet.load());
    for (final sample in pdfaSamples().entries) {
      samples[sample.key] = await renderer.render(sample.value);
    }
    samples['portrait-and-landscape'] = await _portraitAndLandscape();
  });

  test('every sample is PDF/A-1b by the scanner', () {
    expect(samples, isNotEmpty);
    for (final sample in samples.entries) {
      expect(pdfaViolations(sample.value), isEmpty, reason: sample.key);
    }
  });

  test('the file says it is PDF/A part 1, level B, and starts as a 1.4', () {
    for (final bytes in samples.values) {
      final xmp = _xmp(bytes);
      expect(xmp, contains('<pdfaid:part>1</pdfaid:part>'));
      expect(xmp, contains('<pdfaid:conformance>B</pdfaid:conformance>'));
      expect(latin1.decode(bytes.sublist(0, 8)), '%PDF-1.4');
    }
  });

  test('the Info dictionary and the XMP packet carry the same values', () {
    for (final entry in samples.entries) {
      final info = _info(entry.value);
      final xmp = _xmp(entry.value);
      expect(info['Creator'], 'Daylex', reason: entry.key);
      expect(_xmpValue(xmp, 'xmp:CreatorTool'), info['Creator']);
      expect(_xmpValue(xmp, 'pdf:Producer'), info['Producer']);
      expect(
        _xmpValue(xmp, 'xmp:CreateDate'),
        _isoDate(info['CreationDate']!),
        reason: 'one instant, one zone',
      );
    }
  });

  test('the title and the author are in both, accents and markup included', () {
    final bytes = samples['accents-symbols']!;
    final info = _info(bytes);
    final xmp = _xmp(bytes);
    const title = 'Perché “è” così: àèéìòù – € & <test>';
    expect(info['Title'], title);
    expect(info['Author'], 'Avv. Maria Rossi');
    expect(
      _xmpValue(xmp, 'dc:title'),
      '<rdf:Alt><rdf:li xml:lang="x-default">'
      'Perché “è” così: àèéìòù – € &amp; &lt;test&gt;</rdf:li></rdf:Alt>',
    );
    expect(
      _xmpValue(xmp, 'dc:creator'),
      '<rdf:Seq><rdf:li>Avv. Maria Rossi</rdf:li></rdf:Seq>',
    );
  });

  test('an untitled document has no title or author in either', () {
    final bytes = samples['untitled']!;
    expect(_info(bytes).keys, isNot(contains('Title')));
    expect(_info(bytes).keys, isNot(contains('Author')));
    expect(_xmp(bytes), isNot(contains('dc:title')));
    expect(_xmp(bytes), isNot(contains('dc:creator')));
  });

  test(
    'a title with characters XML cannot carry still makes a PDF/A',
    () async {
      final doc = untitledDocument().copyWith(
        metadata: untitledDocument().metadata.copyWith(
          title: 'Atto\u0001 \u0008di\u007f citazione',
          author: '\u0000',
        ),
      );
      final bytes = await renderer.render(doc);
      expect(pdfaViolations(bytes), isEmpty);
      expect(_info(bytes)['Title'], 'Atto   di  citazione');
      expect(_info(bytes).keys, isNot(contains('Author')));
    },
  );

  test(
    'the output intent is GTS_PDFA1 with the sRGB profile, unchanged',
    () async {
      final profile = File('assets/icc/sRGB2014.icc').readAsBytesSync();
      for (final bytes in samples.values) {
        final text = _plain(bytes);
        expect(
          text,
          contains('/OutputIntents[<</Type/OutputIntent/S/GTS_PDFA1'),
        );
        expect(text, contains('/DestOutputProfile'));
        final embedded = _streams(bytes)
            .where((s) => s.dict.contains('/N 3'))
            .toList();
        expect(embedded, hasLength(1));
        expect(listEquals(embedded.single.data, profile), isTrue);
      }
    },
  );

  test('the trailer has a file ID and the catalog no /Version', () {
    for (final bytes in samples.values) {
      expect(_plain(bytes), matches(RegExp(r'trailer\n<<[^\n]*/ID\[<')));
      expect(_plain(bytes), isNot(contains('/Version')));
    }
  });

  test('no transparency, script, encryption, attachment or LZW', () {
    for (final bytes in samples.values) {
      final keys = _keys(_plain(bytes));
      for (final forbidden in _forbidden) {
        expect(keys, isNot(contains(forbidden)), reason: forbidden);
      }
    }
  });

  test('every font is embedded and maps its glyphs to text', () {
    for (final bytes in samples.values) {
      final text = _plain(bytes);
      expect(RegExp('/Subtype/Type0').allMatches(text), isNotEmpty);
      expect(
        RegExp('/Subtype/Type0').allMatches(text).length,
        RegExp('/ToUnicode').allMatches(text).length,
        reason: 'a font with no ToUnicode cannot be searched or copied from',
      );
      for (final descriptor in _objects(text, '/Type/FontDescriptor')) {
        expect(descriptor, contains('/FontFile2'));
      }
      expect(text, isNot(contains('/Subtype/Type1')));
    }
  });

  test('an image with transparency is flattened on white', () {
    final images = _streams(samples['every-block']!)
        .where((s) => s.dict.contains('/Subtype/Image'))
        .where((s) => s.dict.contains('/FlateDecode'))
        .toList();
    expect(images, hasLength(1), reason: 'the PNG, and no mask beside it');
    final rgb = zlib.decode(images.single.data);
    expect(rgb, hasLength(160 * 100 * 3));
    List<int> pixel(int x, int y) =>
        rgb.sublist((y * 160 + x) * 3).sublist(0, 3);
    expect(pixel(0, 0), [200, 30, 30], reason: 'opaque stays as it was');
    expect(pixel(159, 99), [255, 255, 255], reason: 'transparent is paper');
    // (20, 160, 60) at alpha 128 on white: (c * 128 + 255 * 127) / 255, rounded.
    expect(pixel(0, 70), [137, 207, 157]);
  });

  test('an RGB or grey JPEG is embedded as it is, and a CMYK one as RGB', () {
    final bytes = samples['every-block']!;
    final jpegs = _streams(bytes)
        .where((s) => s.dict.contains('/DCTDecode'))
        .toList();
    for (final name in ['photo.jpg', 'gray.jpg']) {
      final source = File('test/fixtures/pdfa/$name').readAsBytesSync();
      expect(
        jpegs.any((j) => listEquals(j.data, source)),
        isTrue,
        reason: '$name, still compressed and untouched',
      );
    }
    expect(jpegs, hasLength(3), reason: 'the CMYK one is the third');
    expect(_plain(bytes), isNot(contains('/DeviceCMYK')));
  });

  test(
    'the preview, made in the background, is the same kind of file',
    () async {
      final bytes = await renderer.renderInBackground(everyBlockDocument());
      expect(pdfaViolations(bytes), isEmpty);
    },
  );

  group('the scanner', () {
    final alpha = File('test/fixtures/pdfa/alpha.png').readAsBytesSync();

    Future<Uint8List> plain({PdfVersion version = PdfVersion.pdf_1_5}) async {
      final pdf = pw.Document(version: version);
      pdf.addPage(
        pw.Page(
          build: (_) => pw.Column(
            children: [pw.Text('Testo'), pw.Image(pw.MemoryImage(alpha))],
          ),
        ),
      );
      return pdf.save();
    }

    test('reports a PDF the package makes by default', () async {
      final violations = pdfaViolations(await plain());
      expect(
        violations,
        containsAll([
          contains('header'),
          contains('object or cross-reference stream'),
          contains('PDF/A identification'),
          contains('output intent'),
        ]),
      );
    });

    test('sees a soft mask and a font left out of the file', () async {
      final violations = pdfaViolations(
        await plain(version: PdfVersion.pdf_1_4),
      );
      expect(
        violations,
        containsAll([
          contains('/SMask'),
          contains('font is not embedded'),
          contains('PDF/A identification'),
          contains('output intent'),
        ]),
      );
      expect(violations, isNot(contains(contains('header'))));
    });

    test('sees each forbidden key in a PDF/A', () {
      final good = samples['untitled']!;
      for (final key in _forbidden) {
        final bytes = Uint8List.fromList([
          ...good,
          ...utf8.encode('\n99 0 obj\n<</S/$key /X(y)>>\nendobj\n'),
        ]);
        expect(pdfaViolations(bytes), contains(contains(key)), reason: key);
      }
    });

    test('does not mistake a key that only starts like one', () {
      final bytes = Uint8List.fromList([
        ...samples['untitled']!,
        ...utf8.encode('\n99 0 obj\n<</Calibrated/JSON/Encrypted>>\nendobj\n'),
      ]);
      expect(pdfaViolations(bytes), isEmpty);
    });

    test('does not read a key inside a compressed stream', () {
      final bytes = Uint8List.fromList([
        ...samples['untitled']!,
        ...utf8.encode(
          '\n99 0 obj\n<</Length 9>>stream\n/SMask /JS\nendstream\n',
        ),
      ]);
      expect(pdfaViolations(bytes), isEmpty);
    });
  });

  // `PDFA_SAMPLES_DIR=<folder> flutter test test/pdfa_test.dart --plain-name veraPDF` writes the samples, for
  //  `verapdf --flavour 1b <folder>/*.pdf`.
  test(
    'writes the samples for veraPDF',
    () {
      final dir = Directory(Platform.environment['PDFA_SAMPLES_DIR']!)
        ..createSync(recursive: true);
      for (final sample in samples.entries) {
        File('${dir.path}/${sample.key}.pdf').writeAsBytesSync(sample.value);
      }
    },
    skip: Platform.environment['PDFA_SAMPLES_DIR'] == null
        ? 'set PDFA_SAMPLES_DIR to write them'
        : false,
  );
}

/// The renderer only makes portrait A4 pages; the document it builds on is not limited to them, and a landscape
/// page is the same PDF/A, with its colour, its image and its text.
Future<Uint8List> _portraitAndLandscape() {
  pw.Font font(String name) => pw.Font.ttf(
    ByteData.sublistView(File('assets/fonts/$name').readAsBytesSync()),
  );
  final pdf = newPdfaDocument(
    title: 'Pagine miste',
    author: 'Avv. Maria Rossi',
    application: 'Daylex',
    colorProfile: File('assets/icc/sRGB2014.icc').readAsBytesSync(),
    theme: pw.ThemeData.withFont(
      base: font('Inter-Regular.ttf'),
      bold: font('Inter-Bold.ttf'),
    ),
  );
  final alpha = File('test/fixtures/pdfa/alpha.png').readAsBytesSync();
  for (final format in [PdfPageFormat.a4, PdfPageFormat.a4.landscape]) {
    pdf.addPage(
      pw.Page(
        pageFormat: format,
        build: (_) => pw.Column(
          children: [
            pw.Text(
              'Pagina ${format.width > format.height ? 'orizzontale' : 'verticale'}: àèéìòù €',
            ),
            pw.Container(width: 120, height: 30, color: PdfColors.blue),
            pw.Image(OpaqueImage(alpha)),
          ],
        ),
      ),
    );
  }
  return pdf.save();
}

/// The keys PDF/A-1 forbids outright, or forbids as soon as they are used: transparency (`/SMask`, a blend
/// mode, a constant alpha), script, encryption, attachments and LZW; and CMYK, which needs an output intent
/// of its own that the file does not have.
const _forbidden = [
  'SMask',
  'BM',
  'CA',
  'ca',
  'JavaScript',
  'JS',
  'Encrypt',
  'EmbeddedFile',
  'EmbeddedFiles',
  'LZWDecode',
  'DeviceCMYK',
];

/// What a PDF/A-1b file must not do or must have, read off [bytes]: one sentence per rule broken, empty for a
/// file that follows them all.
///
/// Dictionaries are plain text in a file with no object streams, which is itself a PDF/A-1 rule and so the
/// first thing checked: a file that hides them from this scan is reported before anything else.
List<String> pdfaViolations(Uint8List bytes) {
  final text = _plain(bytes);
  final found = <String>[];
  final header = latin1.decode(
    bytes.sublist(0, bytes.length < 8 ? bytes.length : 8),
  );
  if (header != '%PDF-1.4') found.add('header is "$header", not %PDF-1.4');
  if (text.contains('/ObjStm') || text.contains('/XRef')) {
    found.add('object or cross-reference stream (PDF 1.5 structure)');
  }
  if (RegExp(r'/Version\s*/1\.[5-9]').hasMatch(text)) {
    found.add('the catalog claims a version above 1.4');
  }
  final xmp = _xmpOrNull(bytes);
  if (xmp == null ||
      !xmp.contains('<pdfaid:part>1</pdfaid:part>') ||
      !xmp.contains('<pdfaid:conformance>B</pdfaid:conformance>')) {
    found.add('no PDF/A identification (part 1, level B) in XMP');
  }
  if (!text.contains('/GTS_PDFA1') || !text.contains('/DestOutputProfile')) {
    found.add('no GTS_PDFA1 output intent with a profile');
  }
  if (!RegExp(r'trailer\s*<<[^\n]*/ID\s*\[').hasMatch(text)) {
    found.add('no file ID in the trailer');
  }
  final keys = _keys(text);
  for (final key in _forbidden) {
    if (keys.contains(key)) found.add('/$key is used');
  }
  for (final font in _objects(text, '/Type/Font')) {
    if (RegExp(r'/Subtype/(Type1|TrueType|MMType1)').hasMatch(font)) {
      found.add(
        'a font is not embedded: ${font.substring(0, font.length.clamp(0, 60))}',
      );
    }
  }
  for (final descriptor in _objects(text, '/Type/FontDescriptor')) {
    if (!RegExp('/FontFile[23]?[ /]').hasMatch(descriptor)) {
      found.add('a font is not embedded (no font file in its descriptor)');
    }
  }
  return found;
}

/// The file as text, a byte a character, without the bytes between `stream` and `endstream`: compressed data
/// is not a dictionary, and must not be read as one.
String _plain(Uint8List bytes) => latin1
    .decode(bytes)
    .replaceAll(
      RegExp(r'stream\r?\n[\s\S]*?\r?\nendstream'),
      'stream\nendstream',
    );

/// The names used as keys or values in [plain]: `/SMask` is `SMask`. A name that only starts like another
/// (`/Calibrated`, `/JSON`) is a different name.
Set<String> _keys(String plain) =>
    RegExp(r'/([A-Za-z0-9_.+-]+)').allMatches(plain).map((m) => m[1]!).toSet();

/// The objects of [plain] whose dictionary contains [marker].
Iterable<String> _objects(String plain, String marker) =>
    RegExp(r'\d+ 0 obj\n([^\n]*)\nendobj')
        .allMatches(plain)
        .map((m) => m[1]!)
        .where((object) => object.contains(marker));

class _Stream {
  _Stream(this.dict, this.data);
  final String dict;
  final Uint8List data;
}

/// Every stream of the file, as written: still compressed when its dictionary says so.
List<_Stream> _streams(Uint8List bytes) {
  final text = latin1.decode(bytes);
  return [
    for (final head in RegExp(
      r'\d+ 0 obj\n(<<[^\n]*>>)stream\n',
    ).allMatches(text))
      _Stream(
        head[1]!,
        bytes.sublist(head.end, text.indexOf('\nendstream', head.end)),
      ),
  ];
}

/// The XMP packet, or null when the file has none.
String? _xmpOrNull(Uint8List bytes) {
  final text = latin1.decode(bytes);
  final start = text.indexOf('<?xpacket begin');
  if (start < 0) return null;
  final end = text.indexOf('<?xpacket end', start);
  if (end < 0) return null;
  return utf8.decode(bytes.sublist(start, end));
}

String _xmp(Uint8List bytes) => _xmpOrNull(bytes)!;

/// The text of `<[tag]>…</[tag]>`, with the XML escapes of `& < >` read back.
String? _xmpValue(String xmp, String tag) {
  final match = RegExp('<$tag>([\\s\\S]*?)</$tag>').firstMatch(xmp);
  if (match == null) return null;
  final inner = match[1]!;
  if (inner.startsWith('<')) return inner;
  return inner
      .replaceAll('&lt;', '<')
      .replaceAll('&gt;', '>')
      .replaceAll('&amp;', '&');
}

/// `D:20261120222924Z` as `2026-11-20T22:22:24Z`.
String _isoDate(String pdfDate) {
  final m = RegExp(r'^D:(\d{4})(\d{2})(\d{2})(\d{2})(\d{2})(\d{2})Z$')
      .firstMatch(pdfDate)!;
  return '${m[1]}-${m[2]}-${m[3]}T${m[4]}:${m[5]}:${m[6]}Z';
}

/// The Info dictionary as text by key: literal strings with their escapes read back, UTF-16 when the string
/// starts with a byte order mark and Latin-1 otherwise.
Map<String, String> _info(Uint8List bytes) {
  final text = latin1.decode(bytes);
  final root = RegExp(r'trailer\s*<<[^\n]*?/Info (\d+) 0 R').firstMatch(text)!;
  final object = RegExp('\n${root[1]} 0 obj\n<<').firstMatch(text)!;
  final info = <String, String>{};
  var at = object.end;
  while (text.startsWith('/', at)) {
    final key = RegExp(r'/([A-Za-z]+)').matchAsPrefix(text, at)!;
    at = key.end;
    assert(text[at] == '(', 'Info entries are literal strings');
    final value = <int>[];
    var depth = 0;
    do {
      final c = text.codeUnitAt(at++);
      if (c == 0x5C) {
        final next = text[at++];
        value.add(switch (next) {
          'n' => 0x0A,
          'r' => 0x0D,
          't' => 0x09,
          'b' => 0x08,
          'f' => 0x0C,
          _ => next.codeUnitAt(0),
        });
      } else if (c == 0x28 && depth++ == 0) {
        continue;
      } else if (c == 0x29 && --depth == 0) {
        break;
      } else {
        value.add(c);
      }
    } while (true);
    info[key[1]!] = value.length >= 2 && value[0] == 0xFE && value[1] == 0xFF
        ? String.fromCharCodes([
            for (var i = 2; i + 1 < value.length; i += 2)
              (value[i] << 8) | value[i + 1],
          ])
        : latin1.decode(value);
  }
  return info;
}
