/// Emphasis inside a text (rfc/055): `**grassetto**`, `*corsivo*`, `__sottolineato__`. Parsed here once, for the PDF
/// and for every export, so a format cannot read a text differently from the page.
///
/// A marker opens only before a character that is not a space and when the same marker closes it later, after one;
/// otherwise it is text. A run of three or more `*` or `_` is text (a signature line `________`), so is a single `_`,
/// and `\*` or `\_` writes the character itself.
library;

/// A stretch of text with one emphasis.
class InlineRun {
  const InlineRun(this.text, {this.bold = false, this.italic = false, this.underline = false});

  final String text;
  final bool bold;
  final bool italic;
  final bool underline;

  bool get plain => !bold && !italic && !underline;

  @override
  bool operator ==(Object other) =>
      other is InlineRun &&
      other.text == text &&
      other.bold == bold &&
      other.italic == italic &&
      other.underline == underline;

  @override
  int get hashCode => Object.hash(text, bold, italic, underline);

  @override
  String toString() => '${bold ? 'B' : ''}${italic ? 'I' : ''}${underline ? 'U' : ''}"$text"';
}

enum _Mark {
  bold('**'),
  italic('*'),
  underline('__');

  const _Mark(this.token);

  final String token;
}

/// A marker or an escape at [start], [length] characters long.
class _Token {
  const _Token(this.start, this.length, this.mark);

  final int start;
  final int length;

  /// Null for an escape: the character after the backslash is text.
  final _Mark? mark;
}

/// The markers of [text] that open or close, in order: what parsing and cutting both walk.
List<_Token> _tokens(String text) {
  final candidates = <_Token>[];
  for (var i = 0; i < text.length;) {
    final c = text[i];
    if (c == r'\' && i + 1 < text.length && (text[i + 1] == '*' || text[i + 1] == '_')) {
      candidates.add(_Token(i, 2, null));
      i += 2;
      continue;
    }
    if (c != '*' && c != '_') {
      i++;
      continue;
    }
    var j = i;
    while (j < text.length && text[j] == c) {
      j++;
    }
    final mark = switch ((c, j - i)) {
      ('*', 2) => _Mark.bold,
      ('*', 1) => _Mark.italic,
      ('_', 2) => _Mark.underline,
      _ => null,
    };
    if (mark != null) candidates.add(_Token(i, j - i, mark));
    i = j;
  }

  bool space(int at) => at < 0 || at >= text.length || text[at].trim().isEmpty;
  final open = <_Mark, int>{};
  final kept = <_Token>[];
  for (var k = 0; k < candidates.length; k++) {
    final t = candidates[k];
    final mark = t.mark;
    if (mark == null) {
      kept.add(t);
    } else if (open.containsKey(mark)) {
      if (!space(t.start - 1)) {
        open.remove(mark);
        kept.add(t);
      }
    } else if (!space(t.start + t.length) &&
        candidates.skip(k + 1).any((c) => c.mark == mark && !space(c.start - 1))) {
      open[mark] = k;
      kept.add(t);
    }
  }
  return kept;
}

/// [text] as runs of one emphasis each, the markers gone. Adjacent runs never share an emphasis.
List<InlineRun> parseInline(String text) {
  final runs = <InlineRun>[];
  final on = <_Mark>{};
  final buffer = StringBuffer();
  void flush() {
    if (buffer.isEmpty) return;
    final run = InlineRun(
      buffer.toString(),
      bold: on.contains(_Mark.bold),
      italic: on.contains(_Mark.italic),
      underline: on.contains(_Mark.underline),
    );
    buffer.clear();
    final last = runs.lastOrNull;
    if (last != null && last.bold == run.bold && last.italic == run.italic && last.underline == run.underline) {
      runs[runs.length - 1] = InlineRun(
        last.text + run.text,
        bold: run.bold,
        italic: run.italic,
        underline: run.underline,
      );
    } else {
      runs.add(run);
    }
  }

  var at = 0;
  for (final t in _tokens(text)) {
    buffer.write(text.substring(at, t.start));
    at = t.start + t.length;
    final mark = t.mark;
    if (mark == null) {
      buffer.write(text[t.start + 1]);
      continue;
    }
    flush();
    if (!on.remove(mark)) on.add(mark);
  }
  buffer.write(text.substring(at));
  flush();
  return runs;
}

/// [text] without its markers: what a format without emphasis carries, and what the eye reads.
String plainInline(String text) => parseInline(text).map((r) => r.text).join();

/// [text] cut at [at] into two texts that each read as their part did: an emphasis open at the cut is closed at the
/// end of the first and opened again at the start of the second. The whitespace at the cut goes.
(String, String) splitInline(String text, int at) {
  final open = <_Mark>[];
  for (final t in _tokens(text)) {
    if (t.start >= at) break;
    final mark = t.mark;
    if (mark == null) continue;
    if (!open.remove(mark)) open.add(mark);
  }
  final head = text.substring(0, at).trimRight();
  final tail = text.substring(at).trimLeft();
  return (
    head + open.reversed.map((m) => m.token).join(),
    open.map((m) => m.token).join() + tail,
  );
}
