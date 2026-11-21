/// The one place a table cell's text becomes a typed spreadsheet value (Italian numbers, amounts, dates, percentages).
library;

/// What a cell holds. [text] is the safe default: a cell only becomes more when its text is unambiguous.
enum CellKind { text, number, currency, date, percent }

class CellValue {
  const CellValue.text(this.text) : kind = CellKind.text, decimal = '', serial = 0, isoDate = '';

  const CellValue._(this.kind, this.text, {this.decimal = '', this.serial = 0, this.isoDate = ''});

  final CellKind kind;

  /// The cell as the lawyer wrote it (trimmed): what a viewer shows when it does not format the value.
  final String text;

  /// The value as a plain decimal (`-1234.56`, `0.18`): exact, no binary rounding. Empty for text and dates.
  final String decimal;

  /// The date as an Excel serial (days since 1899-12-30), for [CellKind.date].
  final int serial;

  /// The date as `yyyy-mm-dd`, for [CellKind.date].
  final String isoDate;

  bool get isText => kind == CellKind.text;
}

const _months = {
  'gennaio': 1, 'gen': 1, 'febbraio': 2, 'feb': 2, 'marzo': 3, 'mar': 3, 'aprile': 4, 'apr': 4,
  'maggio': 5, 'mag': 5, 'giugno': 6, 'giu': 6, 'luglio': 7, 'lug': 7, 'agosto': 8, 'ago': 8,
  'settembre': 9, 'set': 9, 'sett': 9, 'ottobre': 10, 'ott': 10, 'novembre': 11, 'nov': 11,
  'dicembre': 12, 'dic': 12,
};

/// `1.234,56`, `1234,56`, `1.234`, `12`: dots group thousands, the comma is the decimal mark.
const _num = r'(?:\d{1,3}(?:\.\d{3})+|\d+)(?:,\d+)?';
const _cur = r'(?:€|EUR\.?|euro\b)';

final _dateNumeric = RegExp(r'^(\d{1,2})([/.\-])(\d{1,2})\2(\d{4})$');
final _dateWords = RegExp(r'^(\d{1,2})\s*[°º]?\s+([A-Za-zàèéìòù]+)\.?\s+(\d{4})$');
final _percent = RegExp('^([+-]?)($_num)\\s*%\$');
final _currencyBefore = RegExp('^([+-])?\\s*$_cur\\s*([+-])?\\s*($_num)\$', caseSensitive: false);
final _currencyAfter = RegExp('^([+-])?\\s*($_num)\\s*$_cur\$', caseSensitive: false);
final _number = RegExp('^([+-])?($_num)\$');

/// Dates before this serial would need Excel's phantom 29 February 1900: they stay text.
final _firstDate = DateTime.utc(1900, 3, 1);
final _epoch = DateTime.utc(1899, 12, 30);

/// Types [raw] as a spreadsheet cell: a number, an amount in euro, a date, a percentage, or else text.
///
/// Conservative on purpose: `007`, a 16-digit code or `1.5` (no thousands groups, no comma) stay text, because a
/// wrong number in a legal table is worse than a left-aligned string.
CellValue parseCell(String raw) {
  final text = raw.trim();
  if (text.isEmpty) return const CellValue.text('');
  final s = text.replaceAll(RegExp('[\u00A0\u202F\u2009]'), ' ').replaceAll('\u2212', '-');

  final date = _date(s);
  if (date != null) {
    return CellValue._(
      CellKind.date,
      text,
      serial: date.difference(_epoch).inDays,
      isoDate: '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}',
    );
  }

  var m = _percent.firstMatch(s);
  if (m != null) {
    final d = _decimal(m[1]!, m[2]!, shift: -2);
    if (d != null) return CellValue._(CellKind.percent, text, decimal: d);
  }

  m = _currencyBefore.firstMatch(s);
  if (m != null && !(m[1] != null && m[2] != null)) {
    final d = _decimal(m[1] ?? m[2] ?? '', m[3]!);
    if (d != null) return CellValue._(CellKind.currency, text, decimal: d);
  }
  m = _currencyAfter.firstMatch(s);
  if (m != null) {
    final d = _decimal(m[1] ?? '', m[2]!);
    if (d != null) return CellValue._(CellKind.currency, text, decimal: d);
  }

  m = _number.firstMatch(s);
  if (m != null) {
    final d = _decimal(m[1] ?? '', m[2]!, strict: true);
    if (d != null) return CellValue._(CellKind.number, text, decimal: d);
  }
  return CellValue.text(text);
}

DateTime? _date(String s) {
  DateTime? valid(int d, int m, int y) {
    if (y < 1900 || y > 9999 || m < 1 || m > 12 || d < 1) return null;
    final date = DateTime.utc(y, m, d);
    if (date.month != m || date.day != d || date.isBefore(_firstDate)) return null;
    return date;
  }

  final n = _dateNumeric.firstMatch(s);
  if (n != null) return valid(int.parse(n[1]!), int.parse(n[3]!), int.parse(n[4]!));
  final w = _dateWords.firstMatch(s);
  if (w != null) {
    final month = _months[w[2]!.toLowerCase()];
    return month == null ? null : valid(int.parse(w[1]!), month, int.parse(w[3]!));
  }
  return null;
}

/// `1.234,56` to the plain decimal `1234.56`, moved [shift] places (a percentage is a hundredth). Null for what is
/// not safely a number: more than the 15 digits a spreadsheet keeps, or with [strict] an integer with a leading zero
/// (a code, not a count).
String? _decimal(String sign, String italian, {int shift = 0, bool strict = false}) {
  final comma = italian.indexOf(',');
  var whole = (comma < 0 ? italian : italian.substring(0, comma)).replaceAll('.', '');
  var frac = comma < 0 ? '' : italian.substring(comma + 1);
  if (strict && comma < 0 && !italian.contains('.') && whole.length > 1 && whole.startsWith('0')) return null;
  if (whole.length + frac.length > 15) return null;

  if (shift < 0) {
    whole = whole.padLeft(-shift + 1, '0');
    frac = whole.substring(whole.length + shift) + frac;
    whole = whole.substring(0, whole.length + shift);
  }
  whole = whole.replaceFirst(RegExp(r'^0+(?=\d)'), '');
  frac = frac.replaceFirst(RegExp(r'0+$'), '');
  final magnitude = frac.isEmpty ? whole : '$whole.$frac';
  final zero = magnitude == '0';
  return sign == '-' && !zero ? '-$magnitude' : magnitude;
}
