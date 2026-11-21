/// Text hygiene and escaping shared by every writer: one place decides what a character becomes.
library;

import '../model/style.dart';

/// Everything that is not text any format can carry is dropped here, once, so no writer repeats it.
///
/// Dropped: control characters (C0 and C1, but for tab and newline), lone surrogates, U+FFFE, U+FFFF and the byte
/// order mark. Line ends (`\r\n`, `\r`, NEL, LS, PS) become `\n`. What stays is legal XML 1.0 in every part.
String cleanText(String input) {
  final units = input.codeUnits;
  final out = StringBuffer();
  for (var i = 0; i < units.length; i++) {
    final c = units[i];
    if (c >= 0xD800 && c <= 0xDBFF) {
      if (i + 1 < units.length && units[i + 1] >= 0xDC00 && units[i + 1] <= 0xDFFF) {
        out
          ..writeCharCode(c)
          ..writeCharCode(units[++i]);
      }
      continue;
    }
    if (c >= 0xDC00 && c <= 0xDFFF) continue;
    switch (c) {
      case 0x0D:
        if (i + 1 < units.length && units[i + 1] == 0x0A) i++;
        out.write('\n');
      case 0x0A || 0x85 || 0x2028 || 0x2029:
        out.write('\n');
      case 0x09:
        out.write('\t');
      case < 0x20 || 0x7F || (>= 0x80 && <= 0x9F) || 0xFFFE || 0xFFFF || 0xFEFF:
        break;
      default:
        out.writeCharCode(c);
    }
  }
  return out.toString();
}

/// Escapes [s] for an XML text node, or for an attribute with [attribute] (where a tab or a newline would be
/// folded to a space by the parser, so they travel as character references).
String xmlEscape(String s, {bool attribute = false}) {
  final out = StringBuffer();
  for (final c in s.codeUnits) {
    switch (c) {
      case 0x26:
        out.write('&amp;');
      case 0x3C:
        out.write('&lt;');
      case 0x3E:
        out.write('&gt;');
      case 0x22:
        out.write('&quot;');
      case 0x27:
        out.write('&apos;');
      case 0x0A when attribute:
        out.write('&#10;');
      case 0x09 when attribute:
        out.write('&#9;');
      default:
        out.writeCharCode(c);
    }
  }
  return out.toString();
}

/// HTML has no `&apos;` before HTML5 parsers and `&#39;` is the form every consumer reads.
String htmlEscape(String s) {
  final out = StringBuffer();
  for (final c in s.codeUnits) {
    switch (c) {
      case 0x26:
        out.write('&amp;');
      case 0x3C:
        out.write('&lt;');
      case 0x3E:
        out.write('&gt;');
      case 0x22:
        out.write('&quot;');
      case 0x27:
        out.write('&#39;');
      default:
        out.writeCharCode(c);
    }
  }
  return out.toString();
}

String _two(int n) => n.toString().padLeft(2, '0');

/// W3CDTF in UTC, the form core properties and ODF metadata take: `2024-03-12T10:30:00Z`.
String utcStamp(DateTime d) {
  final u = d.toUtc();
  return '${u.year.toString().padLeft(4, '0')}-${_two(u.month)}-${_two(u.day)}T${_two(u.hour)}:${_two(u.minute)}:${_two(u.second)}Z';
}

/// A length in points as ODF and CSS write it: at most two decimals and no trailing zeros (`11pt`, `10.5pt`).
String ptLength(double v) => '${v.toStringAsFixed(2).replaceFirst(RegExp(r'\.?0+$'), '')}pt';

/// `#RRGGBB` without the hash, upper case, from an ARGB int.
String hex6(int argb) => (argb & 0xFFFFFF).toRadixString(16).padLeft(6, '0').toUpperCase();

/// [argb] blended over white with the given opacity, as `RRGGBB` (the renderer's tints).
String tintOf(int argb, double opacity) => hex6(tint(argb, opacity));
