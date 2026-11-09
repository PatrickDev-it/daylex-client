/// A reference to evidence in one conversation, independent of its visual label.
class SourceReference {
  const SourceReference(
    this.name,
    this.page, {
    this.lastPage,
    this.quote = '',
    this.sourceId = '',
    this.wholeDocument = false,
    this.unit = 'page',
  });

  final String name;
  final int page;
  final int? lastPage;
  final String quote;
  final String sourceId;
  final bool wholeDocument;
  final String unit;

  static SourceReference? fromUri(String value) {
    final uri = Uri.tryParse(value);
    if (uri == null ||
        uri.scheme != 'daylex-source' ||
        !RegExp(r'^[a-f0-9]{64}$').hasMatch(uri.host) ||
        uri.userInfo.isNotEmpty ||
        uri.hasPort ||
        uri.pathSegments.length != 1) {
      return null;
    }
    final page = int.tryParse(uri.pathSegments.single);
    final name = uri.queryParameters['name'] ?? '';
    final last = int.tryParse(uri.queryParameters['last'] ?? '');
    if (page == null ||
        page < 1 ||
        name.isEmpty ||
        name.length > 256 ||
        (last != null && last < page)) {
      return null;
    }
    return SourceReference(
      name,
      page,
      lastPage: last,
      sourceId: uri.host,
      wholeDocument: page == 1 && uri.queryParameters['document'] == '1',
      unit: uri.queryParameters['unit'] == 'section' ? 'section' : 'page',
    );
  }

  String get title {
    final stem = name
        .replaceFirst(
          RegExp(r'\.(pdf|docx?|txt|md|p7m|png|jpe?g)$', caseSensitive: false),
          '',
        )
        .replaceAll(RegExp(r'[_]+'), ' ')
        .trim();
    return stem.isEmpty ? name : stem[0].toUpperCase() + stem.substring(1);
  }

  static const pattern =
      r'\[([^\[\]\n]{1,256}?),\s*(?:pp?\.|pag(?:ina|ine)?\.?)\s*(\d{1,5})(?:\s*[-–]\s*(\d{1,5}))?\s*\]';
  static final expression = RegExp(pattern, caseSensitive: false);

  static SourceReference? fromMatch(Match match, {String before = ''}) {
    final page = int.parse(match[2]!);
    if (page < 1) return null;
    // A quote is a search hint, never evidence added to the document.
    final literal = RegExp(r'[«“"]([^«»“”"\n]{8,400})[»”"]\s*[.,;:]?\s*$')
        .firstMatch(before);
    return SourceReference(
      match[1]!.trim(),
      page,
      lastPage: int.tryParse(match[3] ?? ''),
      quote: literal?[1] ?? '',
    );
  }

  static String readable(
    String value,
    String Function(SourceReference) label,
  ) => value
      .replaceAllMapped(
        RegExp(r'\[([^\]\n]+)\]\((daylex-source://[^\s)]+)\)'),
        (m) {
          final source = fromUri(m[2]!);
          return source == null ? m[1]! : label(source);
        },
      )
      .replaceAllMapped(expression, (m) {
        final source = fromMatch(m);
        return source == null ? m[0]! : label(source);
      });
}
