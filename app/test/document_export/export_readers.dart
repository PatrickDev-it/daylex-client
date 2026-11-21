import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xml/xml.dart';

/// The parts of a ZIP package by name, in the order they are in the file.
Map<String, Uint8List> unzip(Uint8List bytes) => {
  for (final f in ZipDecoder().decodeBytes(bytes).files)
    if (f.isFile) f.name: Uint8List.fromList(f.content as List<int>),
};

String textOf(Map<String, Uint8List> parts, String name) {
  final bytes = parts[name];
  if (bytes == null) fail('missing part $name; the package has ${parts.keys.toList()}');
  return utf8.decode(bytes);
}

XmlDocument xmlOf(Map<String, Uint8List> parts, String name) => XmlDocument.parse(textOf(parts, name));

/// Every XML part of [parts] parses (the writers escape everything and strip what XML cannot carry).
void expectWellFormed(Map<String, Uint8List> parts) {
  for (final e in parts.entries) {
    if (e.key == 'mimetype' || !(e.key.endsWith('.xml') || e.key.endsWith('.rels'))) continue;
    try {
      XmlDocument.parse(utf8.decode(e.value));
    } on Object catch (error) {
      fail('${e.key} is not well-formed XML: $error');
    }
  }
}

/// The text of every `local` element (`t` of `w:t`) of [doc], one string per element.
List<String> elementTexts(XmlNode doc, String local) => [for (final e in doc.descendantElements.where((e) => e.name.local == local)) e.innerText];

Iterable<XmlElement> elements(XmlNode doc, String qualified) => doc.descendantElements.where((e) => e.name.qualified == qualified);

/// The text of a ZIP part with its markup gone, an element's text apart from the next one's by a newline.
String xmlTextOf(XmlNode doc) => doc.descendants.whereType<XmlText>().map((t) => t.value).join('\n');

/// A raw zip's first local file header: name, compression method (0 is stored), extra field length and the bytes
/// that follow the header.
({String name, int method, int extra, Uint8List data}) firstZipEntry(Uint8List zip) {
  final b = ByteData.sublistView(zip);
  expect(b.getUint32(0, Endian.little), 0x04034B50, reason: 'not a zip local file header');
  final method = b.getUint16(8, Endian.little);
  final size = b.getUint32(18, Endian.little);
  final nameLength = b.getUint16(26, Endian.little);
  final extra = b.getUint16(28, Endian.little);
  final start = 30 + nameLength + extra;
  return (
    name: utf8.decode(zip.sublist(30, 30 + nameLength)),
    method: method,
    extra: extra,
    data: zip.sublist(start, start + size),
  );
}

/// The OPC package rules every DOCX and XLSX must keep: each part has a content type, each relationship names a part
/// that exists, and every part but the content types and the relationships is reached by a relationship.
void expectConsistentOpc(Map<String, Uint8List> parts) {
  final types = xmlOf(parts, '[Content_Types].xml');
  final defaults = {for (final e in elements(types, 'Default')) e.getAttribute('Extension')!.toLowerCase()};
  final overrides = {for (final e in elements(types, 'Override')) e.getAttribute('PartName')!};
  for (final name in parts.keys) {
    if (name == '[Content_Types].xml') continue;
    final ext = name.split('.').last.toLowerCase();
    expect(overrides.contains('/$name') || defaults.contains(ext), isTrue, reason: '$name has no content type');
  }
  for (final o in overrides) {
    expect(parts.containsKey(o.substring(1)), isTrue, reason: 'content type override for a part that is not there: $o');
  }

  final targets = <String>{};
  for (final rels in parts.keys.where((n) => n.endsWith('.rels'))) {
    final base = rels.contains('/_rels/') ? rels.substring(0, rels.indexOf('/_rels/') + 1) : '';
    final ids = <String>{};
    for (final r in elements(xmlOf(parts, rels), 'Relationship')) {
      expect(ids.add(r.getAttribute('Id')!), isTrue, reason: 'duplicate relationship id in $rels');
      if (r.getAttribute('TargetMode') == 'External') continue;
      final target = r.getAttribute('Target')!;
      final path = target.startsWith('/') ? target.substring(1) : _normalise('$base$target');
      expect(parts.containsKey(path), isTrue, reason: '$rels points at $path, which is not in the package');
      targets.add(path);
    }
  }
  for (final name in parts.keys) {
    if (name == '[Content_Types].xml' || name.endsWith('.rels')) continue;
    expect(targets.contains(name), isTrue, reason: '$name is in the package but no relationship reaches it');
  }
}

String _normalise(String path) {
  final out = <String>[];
  for (final s in path.split('/')) {
    if (s == '..') {
      out.removeLast();
    } else if (s != '.' && s.isNotEmpty) {
      out.add(s);
    }
  }
  return out.join('/');
}

/// A CSV record parser by RFC 4180: quoted fields, doubled quotes, line breaks inside quotes.
List<List<String>> parseCsv(String text, {String delimiter = ';'}) {
  final records = <List<String>>[];
  var record = <String>[];
  final field = StringBuffer();
  var quoted = false, wasQuoted = false;
  void endField() {
    record.add(field.toString());
    field.clear();
    wasQuoted = false;
  }

  for (var i = 0; i < text.length; i++) {
    final c = text[i];
    if (quoted) {
      if (c == '"') {
        if (i + 1 < text.length && text[i + 1] == '"') {
          field.write('"');
          i++;
        } else {
          quoted = false;
        }
      } else {
        field.write(c);
      }
    } else if (c == '"' && field.isEmpty && !wasQuoted) {
      quoted = true;
      wasQuoted = true;
    } else if (c == delimiter) {
      endField();
    } else if (c == '\r' && i + 1 < text.length && text[i + 1] == '\n') {
      endField();
      records.add(record);
      record = [];
      i++;
    } else {
      field.write(c);
    }
  }
  if (quoted) fail('an unterminated quoted field');
  if (field.isNotEmpty || record.isNotEmpty || wasQuoted) {
    endField();
    records.add(record);
  }
  return records;
}

/// The plain text of RTF: `\uN?` decoded, `\'hh` read as Latin-1, the escapes for `\ { }` undone, the rest of the
/// control words dropped.
String rtfText(String rtf) {
  final out = StringBuffer();
  for (var i = 0; i < rtf.length; i++) {
    final c = rtf[i];
    if (c == '{' || c == '}' || c == '\r' || c == '\n') continue;
    if (c != r'\') {
      out.write(c);
      continue;
    }
    final next = i + 1 < rtf.length ? rtf[i + 1] : '';
    if (next == r'\' || next == '{' || next == '}') {
      out.write(next);
      i++;
    } else if (next == "'") {
      out.writeCharCode(int.parse(rtf.substring(i + 2, i + 4), radix: 16));
      i += 3;
    } else if (next == '*' || next == '~' || next == '-' || next == '_') {
      i++;
    } else {
      final m = RegExp(r'^\\([a-zA-Z]+)(-?\d+)? ?').firstMatch(rtf.substring(i, i + 40 > rtf.length ? rtf.length : i + 40));
      if (m == null) continue;
      final word = m[1]!, number = m[2];
      i += m[0]!.length - 1;
      if (word == 'u' && number != null) {
        final unit = int.parse(number);
        out.writeCharCode(unit < 0 ? unit + 0x10000 : unit);
        i++; // the one ASCII stand-in (`\uc1`)
      } else if (word == 'line' || word == 'par') {
        out.write('\n');
      } else if (word == 'tab' || word == 'cell') {
        out.write(word == 'tab' ? '\t' : '\n');
      }
    }
  }
  return out.toString();
}

/// Markdown with its backslash escapes undone (CommonMark: a backslash before ASCII punctuation is that punctuation).
String markdownText(String md) => md.replaceAllMapped(RegExp(r'\\([!-/:-@\[-`{-~])'), (m) => m[1]!).replaceAll('<br>', '\n');

/// HTML as text: tags dropped, the five entities undone.
String htmlText(String html) {
  final body = html.replaceAll(RegExp(r'<style>.*?</style>', dotAll: true), '').replaceAll('<br>', '\n');
  return body
      .replaceAll(RegExp(r'<[^>]*>'), '\n')
      .replaceAll('&lt;', '<')
      .replaceAll('&gt;', '>')
      .replaceAll('&quot;', '"')
      .replaceAll('&#39;', "'")
      .replaceAll('&amp;', '&');
}

/// What each word of [words] must be in [text]; names the missing ones.
void expectWords(String text, Iterable<String> words, {String reason = ''}) {
  final missing = [for (final w in words) if (!text.contains(w)) w];
  expect(missing, isEmpty, reason: '$reason missing from the text');
}

/// The characters no format may carry survive in no file: C0 controls but tab and line feed, the BOM, U+FFFE/F.
final forbiddenChars = RegExp('[\u0000-\u0008\u000B\u000C\u000E-\u001F\u007F-\u009F\uFEFF\uFFFE\uFFFF]');
