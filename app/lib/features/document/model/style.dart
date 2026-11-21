import 'dart:convert';
import 'dart:typed_data';

/// The look of a document (rfc/055): a base and, over it, what the document says. Every value the renderer and the
/// exporters draw comes from here and from the base's defaults ([styleBases]); none is fixed in their code.
///
/// The same objects travel as JSON: in the saved document, in the agent's tool calls and on the wire. A tool call is
/// read strictly (the `patch` methods throw a [StyleException] the model reads); a saved document leniently (the
/// `fromJson` constructors drop what they cannot read), so a value this version does not know never makes a document
/// unreadable. `daylex_server/docsim.py` reads both ways alike, with the same messages.

/// A style the agent asked for that cannot be applied. [message] is what the model reads: Italian, byte-stable.
class StyleException implements Exception {
  const StyleException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// The defaults a document's style is a patch over.
enum StyleBase {
  /// DM 7 agosto 2023 n. 110, art. 6: Times 12 pt, line spacing 1.5, 2.5 cm margins; justified, black.
  legal,

  /// The look of documents before rfc/055, without the cover band, the header dot and the side bar.
  report;

  static StyleBase? parse(Object? value) => values.where((b) => b.name == value).firstOrNull;
}

/// The typefaces a document can use, each embedded in four faces. The first four are metric-compatible with the
/// office fonts they stand for, so a DOCX opened in Word breaks its lines where the PDF does.
enum DocFont {
  times('Tinos', 'Times New Roman', FontKind.serif),
  arial('Arimo', 'Arial', FontKind.sans),
  courier('Cousine', 'Courier New', FontKind.mono),
  calibri('Carlito', 'Calibri', FontKind.sans),
  garamond('EBGaramond', 'Garamond', FontKind.serif),
  inter('Inter', 'Inter', FontKind.sans);

  const DocFont(this.asset, this.family, this.kind);

  /// The prefix of its files in assets/fonts: `<asset>-Regular.ttf`, `-Bold`, `-Italic`, `-BoldItalic`.
  final String asset;

  /// The name an office suite knows it by: DOCX, ODT, RTF and HTML name it so.
  final String family;

  /// What a reader without the font falls back to.
  final FontKind kind;
}

enum FontKind { serif, sans, mono }

enum BlockAlign { left, center, right, justify }

enum BlockBorder { none, left, top, bottom, box }

/// How a list marks its items.
enum ListMarker { disc, dash, number, letter, none }

/// Which lines a table draws: between rows, every cell, or none.
enum TableGrid { rows, all, none }

enum PageOrientation { portrait, landscape }

/// What a block is in the document's style: the style of every block of a kind, and of the parts of some.
enum StyleRole { body, heading1, heading2, heading3, bullets, table, tableHeader, quote, callout, caption, metrics }

/// The running texts of a page. A missing `first*` repeats its other; a missing header or footer is the base's.
enum RegionSlot {
  header,
  footer,
  firstHeader,
  firstFooter;

  bool get isFirst => this == firstHeader || this == firstFooter;

  static RegionSlot? parse(Object? value) => values.where((s) => s.name == value).firstOrNull;
}

/// Centimetres to points, the unit of the PDF.
double cmToPt(double cm) => cm * 72 / 2.54;

/// What one style field accepts, and the value it stores: a plain JSON value, so a style is its own JSON.
sealed class _Spec {
  const _Spec();

  Object read(String key, Object value);
}

class _Choice extends _Spec {
  const _Choice(this.values);

  final List<String> values;

  @override
  Object read(String key, Object value) => values.contains(value)
      ? value
      : throw StyleException('Stile non valido: "$key" deve essere uno tra ${values.join(', ')}.');
}

class _Number extends _Spec {
  const _Number(this.min, this.max);

  final num min;
  final num max;

  @override
  Object read(String key, Object value) => value is num && value >= min && value <= max
      ? value.toDouble()
      : throw StyleException('Stile non valido: "$key" deve essere un numero da $min a $max.');
}

class _Flag extends _Spec {
  const _Flag();

  @override
  Object read(String key, Object value) =>
      value is bool ? value : throw StyleException('Stile non valido: "$key" deve essere true o false.');
}

class _Colour extends _Spec {
  const _Colour();

  static final _hex = RegExp(r'^#?([0-9a-f]{6})$');
  static final _accent = RegExp(r'^accent/(\d{1,3})$');

  @override
  Object read(String key, Object value) {
    if (value is String) {
      final v = value.trim().toLowerCase();
      if (v == 'accent' || v == 'none') return v;
      if (_hex.firstMatch(v) case final m?) return '#${m[1]}';
      if (_accent.firstMatch(v) case final m?) {
        final n = int.parse(m[1]!);
        if (n >= 1 && n <= 100) return 'accent/$n';
      }
    }
    throw StyleException(
      'Stile non valido: "$key" deve essere un colore #RRGGBB, "accent", "accent/NN" (da 1 a 100) o "none".',
    );
  }
}

List<String> _names(List<Enum> values) => [for (final v in values) v.name];

const _colour = _Colour();
const _flag = _Flag();

final Map<String, _Spec> _blockFields = {
  'font': _Choice(_names(DocFont.values)),
  'size': const _Number(6, 72),
  'bold': _flag,
  'italic': _flag,
  'underline': _flag,
  'caps': _flag,
  'color': _colour,
  'background': _colour,
  'align': _Choice(_names(BlockAlign.values)),
  'lineHeight': const _Number(0.8, 3),
  'spaceBefore': const _Number(0, 72),
  'spaceAfter': const _Number(0, 72),
  'indent': const _Number(0, 10),
  'firstLineIndent': const _Number(0, 5),
  'border': _Choice(_names(BlockBorder.values)),
  'borderColor': _colour,
  'borderWidth': const _Number(0, 6),
  'padding': const _Number(0, 72),
  'marker': _Choice(_names(ListMarker.values)),
  'grid': _Choice(_names(TableGrid.values)),
  'stripe': _colour,
};

/// The fields a style can set, in the order the tools list them.
List<String> get blockStyleFields => [..._blockFields.keys];

/// The fields a role takes from the body (a part from its block) when neither it nor the block sets them: the
/// typography, never a box.
const inheritedFields = {'font', 'size', 'bold', 'italic', 'underline', 'caps', 'color', 'align', 'lineHeight'};

Map<String, dynamic> _object(Object? value, String what) {
  if (value is Map) return value.cast<String, dynamic>();
  throw StyleException('Stile non valido: $what deve essere un oggetto.');
}

/// The look of a block, of a role or of a header: each field set or left to what is under it. Sizes are points,
/// [indent] and [firstLineIndent] centimetres, [lineHeight] a multiple of the typeface's single spacing (1.5 is
/// Word's «1,5 righe»).
class BlockStyle {
  const BlockStyle._(this._values);

  static const empty = BlockStyle._({});

  final Map<String, Object> _values;

  bool get isEmpty => _values.isEmpty;

  T? _enum<T extends Enum>(List<T> values, String key) => values.where((v) => v.name == _values[key]).firstOrNull;
  double? _number(String key) => _values[key] as double?;
  bool? _bool(String key) => _values[key] as bool?;
  String? _string(String key) => _values[key] as String?;

  DocFont? get font => _enum(DocFont.values, 'font');
  double? get size => _number('size');
  bool? get bold => _bool('bold');
  bool? get italic => _bool('italic');
  bool? get underline => _bool('underline');
  bool? get caps => _bool('caps');

  /// `#rrggbb`, `accent`, `accent/NN` (the accent at NN % over white) or `none`.
  String? get color => _string('color');
  String? get background => _string('background');
  BlockAlign? get align => _enum(BlockAlign.values, 'align');
  double? get lineHeight => _number('lineHeight');
  double? get spaceBefore => _number('spaceBefore');
  double? get spaceAfter => _number('spaceAfter');
  double? get indent => _number('indent');
  double? get firstLineIndent => _number('firstLineIndent');
  BlockBorder? get border => _enum(BlockBorder.values, 'border');
  String? get borderColor => _string('borderColor');
  double? get borderWidth => _number('borderWidth');
  double? get padding => _number('padding');
  ListMarker? get marker => _enum(ListMarker.values, 'marker');
  TableGrid? get grid => _enum(TableGrid.values, 'grid');
  String? get stripe => _string('stripe');

  /// This style over [under]: each field this one leaves unset comes from [under].
  BlockStyle over(BlockStyle? under) =>
      under == null || under.isEmpty ? this : BlockStyle._({...under._values, ..._values});

  /// Only the [fields] of this style.
  BlockStyle only(Set<String> fields) =>
      BlockStyle._({for (final e in _values.entries) if (fields.contains(e.key)) e.key: e.value});

  /// The style the agent's [patch] makes of this one: a field set to null goes back to what is under it.
  BlockStyle patch(Object? patch) {
    final values = {..._values};
    for (final MapEntry(:key, :value) in _object(patch, 'lo stile').entries) {
      final spec = _blockFields[key] ??
          (throw StyleException(
            'Stile non valido: "$key" non è un campo di stile. Campi: ${blockStyleFields.join(', ')}.',
          ));
      if (value == null) {
        values.remove(key);
      } else {
        values[key] = spec.read(key, value as Object);
      }
    }
    return values.isEmpty ? empty : BlockStyle._(values);
  }

  Map<String, dynamic> toJson() => {..._values};

  /// A saved style: what this version cannot read is left out.
  factory BlockStyle.fromJson(Object? json) {
    if (json is! Map) return empty;
    final values = <String, Object>{};
    for (final MapEntry(:key, :value) in json.entries) {
      final spec = _blockFields[key];
      if (spec == null || value == null) continue;
      try {
        values[key as String] = spec.read(key, value as Object);
      } on StyleException {
        continue;
      }
    }
    return values.isEmpty ? empty : BlockStyle._(values);
  }

  /// A style written in code, as the bases are: the same validation as a tool call, so a base cannot hold a value a
  /// document could not.
  factory BlockStyle.of(Map<String, Object> values) => empty.patch(values);

  @override
  bool operator ==(Object other) => other is BlockStyle && jsonEncode(_values) == jsonEncode(other._values);

  @override
  int get hashCode => jsonEncode(_values).hashCode;
}

/// The page: its orientation, its margins and where header and footer sit, in centimetres. Each field set or the
/// base's.
class PageSetup {
  const PageSetup._(this._values);

  static const empty = PageSetup._({});

  static const sides = ['top', 'right', 'bottom', 'left'];
  static final Map<String, _Spec> _fields = {
    'orientation': _Choice(_names(PageOrientation.values)),
    for (final side in sides) 'margins.$side': const _Number(0, 10),
    'header': const _Number(0, 5),
    'footer': const _Number(0, 5),
  };

  final Map<String, Object> _values;

  bool get isEmpty => _values.isEmpty;

  PageOrientation? get orientation =>
      PageOrientation.values.where((o) => o.name == _values['orientation']).firstOrNull;

  /// The margin on [side] (one of [sides]).
  double? margin(String side) => _values['margins.$side'] as double?;

  /// How far the header's top is from the top of the page.
  double? get header => _values['header'] as double?;

  /// How far the footer's bottom is from the bottom of the page.
  double? get footer => _values['footer'] as double?;

  PageSetup over(PageSetup under) => PageSetup._({...under._values, ..._values});

  /// The page the agent's [patch] makes of this one: `{"margins": {"top": 3}}` changes one margin, null restores
  /// the base's.
  PageSetup patch(Object? patch) {
    final values = {..._values};
    void set(String key, Object? value) {
      final spec = _fields[key] ??
          (throw StyleException(
            'Stile non valido: "$key" non è un campo della pagina. Campi: orientation, margins (top, right, '
            'bottom, left), header, footer.',
          ));
      if (value == null) {
        values.remove(key);
      } else {
        values[key] = spec.read(key, value);
      }
    }

    for (final MapEntry(:key, :value) in _object(patch, 'la pagina').entries) {
      if (key == 'margins' && value != null) {
        for (final m in _object(value, '"margins"').entries) {
          set('margins.${m.key}', m.value);
        }
      } else if (key == 'margins') {
        values.removeWhere((k, _) => k.startsWith('margins.'));
      } else {
        set(key, value);
      }
    }
    return PageSetup._(values);
  }

  Map<String, dynamic> toJson() {
    final margins = {for (final side in sides) side: ?margin(side)};
    return {
      'orientation': ?_values['orientation'],
      if (margins.isNotEmpty) 'margins': margins,
      'header': ?header,
      'footer': ?footer,
    };
  }

  factory PageSetup.fromJson(Object? json) {
    if (json is! Map) return empty;
    var page = empty;
    for (final MapEntry(:key, :value) in json.entries) {
      if (key == 'margins' && value is Map) {
        for (final m in value.entries) {
          try {
            page = page.patch({
              'margins': {m.key: m.value},
            });
          } on StyleException {
            continue;
          }
        }
        continue;
      }
      try {
        page = page.patch({key: value});
      } on StyleException {
        continue;
      }
    }
    return page;
  }

  factory PageSetup.of(Map<String, Object> values) => empty.patch(values);
}

/// A logo in a header or footer.
class RegionLogo {
  const RegionLogo({required this.bytes, this.height = 40, this.align = BlockAlign.left});

  final Uint8List bytes;

  /// Points.
  final double height;

  /// left, center or right; justify reads as left.
  final BlockAlign align;

  Map<String, dynamic> toJson() => {'data': base64Encode(bytes), 'height': height, 'align': align.name};

  static RegionLogo? fromJson(Object? json) {
    if (json is! Map || json['data'] is! String) return null;
    final height = json['height'];
    try {
      return RegionLogo(
        bytes: base64Decode(json['data'] as String),
        height: (height is num ? height.toDouble() : 40.0).clamp(8, 200),
        align: BlockAlign.values.where((a) => a.name == json['align']).firstOrNull ?? BlockAlign.left,
      );
    } on FormatException {
      return null;
    }
  }
}

/// A header or a footer: three texts (left, centre, right; lines split by `\n`), their style, a line between it and
/// the text of the page, a logo. The texts take placeholders ([regionPlaceholders]) and inline emphasis. Of the
/// style, `padding` is the space between the texts and the line, and the header's `spaceAfter` (the footer's
/// `spaceBefore`) the least space between it and the text of the page.
class PageRegion {
  const PageRegion({
    this.left = '',
    this.center = '',
    this.right = '',
    this.style = BlockStyle.empty,
    this.line = false,
    this.logo,
  });

  final String left;
  final String center;
  final String right;
  final BlockStyle style;
  final bool line;
  final RegionLogo? logo;

  bool get isEmpty => left.isEmpty && center.isEmpty && right.isEmpty && logo == null;

  PageRegion copyWith({String? left, String? center, String? right, BlockStyle? style, bool? line}) => PageRegion(
    left: left ?? this.left,
    center: center ?? this.center,
    right: right ?? this.right,
    style: style ?? this.style,
    line: line ?? this.line,
    logo: logo,
  );

  /// The region with its logo replaced; null removes it.
  PageRegion withLogo(RegionLogo? logo) =>
      PageRegion(left: left, center: center, right: right, style: style, line: line, logo: logo);

  PageRegion replaceText(String find, String replace) => copyWith(
    left: left.replaceAll(find, replace),
    center: center.replaceAll(find, replace),
    right: right.replaceAll(find, replace),
  );

  /// The region the agent's [patch] makes of this one: `left`, `center`, `right`, `style` (a style patch, null for
  /// none) and `line`.
  PageRegion patch(Map<String, dynamic> patch) {
    String text(String key, String current) => switch (patch[key]) {
      null => current,
      final String value => value,
      _ => throw StyleException('Stile non valido: "$key" deve essere un testo.'),
    };
    final line = patch['line'];
    return copyWith(
      left: text('left', left),
      center: text('center', center),
      right: text('right', right),
      style: patch.containsKey('style')
          ? (patch['style'] == null ? BlockStyle.empty : style.patch(patch['style']))
          : null,
      line: line == null ? null : _flag.read('line', line) as bool,
    );
  }

  Map<String, dynamic> toJson() => {
    if (left.isNotEmpty) 'left': left,
    if (center.isNotEmpty) 'center': center,
    if (right.isNotEmpty) 'right': right,
    if (!style.isEmpty) 'style': style.toJson(),
    if (line) 'line': true,
    if (logo != null) 'logo': logo!.toJson(),
  };

  factory PageRegion.fromJson(Object? json) {
    if (json is! Map) return const PageRegion();
    String text(String key) => json[key] is String ? json[key] as String : '';
    return PageRegion(
      left: text('left'),
      center: text('center'),
      right: text('right'),
      style: BlockStyle.fromJson(json['style']),
      line: json['line'] == true,
      logo: RegionLogo.fromJson(json['logo']),
    );
  }
}

/// The placeholders a header or footer text takes, and what each stands for.
const regionPlaceholders = {
  'pagina': 'il numero della pagina',
  'pagine': 'il numero delle pagine',
  'titolo': 'il titolo del documento',
  'sottotitolo': 'il sottotitolo',
  'cliente': 'il cliente',
  'autore': 'l’autore',
  'data': 'la data del documento',
  'studio': 'il nome dello studio',
  'sezione': 'il titolo della pagina',
};

/// [text] with its placeholders filled from [values]; one not in [values] stays as written. A placeholder that comes
/// out empty takes with it the separator before it («{titolo} · {cliente}» without a client reads «Atto»), or the
/// one after it when it opens the line.
String fillPlaceholders(String text, Map<String, String> values) {
  final out = StringBuffer();
  var dropLeading = false;
  var last = 0;
  for (final m in _placeholder.allMatches(text)) {
    var before = text.substring(last, m.start);
    if (dropLeading) before = before.replaceFirst(_leadingSeparator, '');
    dropLeading = false;
    final value = values[m[1]];
    if (value == null) {
      out.write(before + m[0]!);
    } else if (value.isNotEmpty) {
      out.write(before + value);
    } else {
      final trimmed = before.replaceFirst(_trailingSeparator, '');
      out.write(trimmed);
      dropLeading = trimmed.length == before.length && out.toString().split('\n').last.trim().isEmpty;
    }
    last = m.end;
  }
  var rest = text.substring(last);
  if (dropLeading) rest = rest.replaceFirst(_leadingSeparator, '');
  out.write(rest);
  return out.toString();
}

final _placeholder = RegExp(r'\{(\w+)\}');
final _trailingSeparator = RegExp(r'\s*[·•|–—,/-]\s*$');
final _leadingSeparator = RegExp(r'^\s*[·•|–—,/-]\s*');

// ---------------------------------------------------------------------------
// Colours
// ---------------------------------------------------------------------------

/// The accent of a document, a template or a project when nothing says otherwise (ARGB).
const kDefaultDocAccent = 0xFF4A7CFF;

/// Parses `#RRGGBB`, `RRGGBB` or an int into an opaque ARGB int.
int? parseColor(Object? value) {
  if (value is int) return value | 0xFF000000;
  if (value is! String) return null;
  final hex = value.replaceFirst('#', '');
  if (hex.length != 6) return null;
  final parsed = int.tryParse(hex, radix: 16);
  return parsed == null ? null : 0xFF000000 | parsed;
}

/// [argb] blended over white with [opacity] (0-1): the tints `accent/NN` names.
int tint(int argb, double opacity) {
  int mix(int shift) => (255 - (255 - ((argb >> shift) & 0xFF)) * opacity).round().clamp(0, 255);
  return 0xFF000000 | mix(16) << 16 | mix(8) << 8 | mix(0);
}

/// The colour a style value names, given the document's [accent]; null for `none` or unset.
int? resolveColor(String? value, int accent) => switch (value) {
  null || 'none' => null,
  'accent' => accent | 0xFF000000,
  final v when v.startsWith('accent/') => tint(accent, int.parse(v.substring(7)) / 100),
  final v => parseColor(v),
};

// ---------------------------------------------------------------------------
// The document's theme
// ---------------------------------------------------------------------------

/// Document-wide styling: the accent, the studio's name, and the style of rfc/055. Colours are ARGB ints so the
/// model stays free of Flutter types and can be sent to a render isolate or a server.
class DocTheme {
  const DocTheme({
    this.accent = kDefaultDocAccent,
    this.brandName = '',
    this.base = StyleBase.report,
    this.page = PageSetup.empty,
    this.styles = const {},
    this.regions = const {},
  });

  /// What a new document starts from when the studio has saved no style of its own.
  static const legal = DocTheme(base: StyleBase.legal);

  final int accent;
  final String brandName;
  final StyleBase base;

  /// What the document changes of the base's page.
  final PageSetup page;

  /// What the document changes of the base's style, by role.
  final Map<StyleRole, BlockStyle> styles;

  /// The headers and footers the document sets; a slot it does not set is the base's (or, for a first page, the
  /// other pages').
  final Map<RegionSlot, PageRegion> regions;

  DocTheme copyWith({
    int? accent,
    String? brandName,
    StyleBase? base,
    PageSetup? page,
    Map<StyleRole, BlockStyle>? styles,
    Map<RegionSlot, PageRegion>? regions,
  }) => DocTheme(
    accent: accent ?? this.accent,
    brandName: brandName ?? this.brandName,
    base: base ?? this.base,
    page: page ?? this.page,
    styles: styles ?? this.styles,
    regions: regions ?? this.regions,
  );

  /// The theme `set_style` makes of this one: `base`, `accent`, `page` (a patch, null for the base's) and `styles`
  /// (by role, each a patch or null for the base's; null for all of them).
  DocTheme patchStyle(Map<String, dynamic> a) {
    var base = this.base;
    if (a.containsKey('base')) {
      base = StyleBase.parse(a['base']) ??
          (throw StyleException('Stile non valido: "base" deve essere uno tra ${_names(StyleBase.values).join(', ')}.'));
    }
    final accent = a['accent'] == null ? this.accent : parseColor(a['accent']);
    if (accent == null) throw StyleException('Colore non valido "${a['accent']}".');
    var page = this.page;
    if (a.containsKey('page')) page = a['page'] == null ? PageSetup.empty : page.patch(a['page']);
    var styles = this.styles;
    if (a.containsKey('styles')) {
      styles = {};
      if (a['styles'] != null) {
        styles = {...this.styles};
        for (final MapEntry(:key, :value) in _object(a['styles'], '"styles"').entries) {
          final role = StyleRole.values.where((r) => r.name == key).firstOrNull ??
              (throw StyleException(
                'Stile non valido: "$key" non è un ruolo. Ruoli: ${_names(StyleRole.values).join(', ')}.',
              ));
          final style = value == null ? BlockStyle.empty : (styles[role] ?? BlockStyle.empty).patch(value);
          if (style.isEmpty) {
            styles.remove(role);
          } else {
            styles[role] = style;
          }
        }
      }
    }
    return copyWith(accent: accent, base: base, page: page, styles: styles);
  }

  /// The theme with [slot] set to [region]; null gives the slot back to the base (or to the other pages).
  DocTheme withRegion(RegionSlot slot, PageRegion? region) =>
      copyWith(regions: {...regions}..remove(slot)..addAll({slot: ?region}));

  /// Every text of the headers and footers, as `replace_text` and the search see them.
  Iterable<String> get regionTexts => [
    for (final r in regions.values) ...[r.left, r.center, r.right],
  ].where((t) => t.isNotEmpty);

  DocTheme replaceText(String find, String replace) => copyWith(
    regions: {for (final MapEntry(:key, :value) in regions.entries) key: value.replaceText(find, replace)},
  );

  Map<String, dynamic> toJson() => {
    'accent': '#${(accent & 0xFFFFFF).toRadixString(16).padLeft(6, '0')}',
    'brandName': brandName,
    'base': base.name,
    if (!page.isEmpty) 'page': page.toJson(),
    if (styles.isNotEmpty) 'styles': {for (final MapEntry(:key, :value) in styles.entries) key.name: value.toJson()},
    for (final slot in RegionSlot.values)
      if (regions[slot] case final r?) slot.name: r.toJson(),
  };

  factory DocTheme.fromJson(Map<String, dynamic> json) {
    final styles = <StyleRole, BlockStyle>{};
    if (json['styles'] case final Map saved) {
      for (final role in StyleRole.values) {
        final style = BlockStyle.fromJson(saved[role.name]);
        if (!style.isEmpty) styles[role] = style;
      }
    }
    return DocTheme(
      accent: parseColor(json['accent']) ?? kDefaultDocAccent,
      brandName: json['brandName'] as String? ?? '',
      base: StyleBase.parse(json['base']) ?? StyleBase.report,
      page: PageSetup.fromJson(json['page']),
      styles: styles,
      regions: {
        for (final slot in RegionSlot.values)
          if (json[slot.name] is Map) slot: PageRegion.fromJson(json[slot.name]),
      },
    );
  }
}

// ---------------------------------------------------------------------------
// The bases
// ---------------------------------------------------------------------------

/// The defaults of a [StyleBase]: what a document that sets nothing looks like.
class BaseStyle {
  const BaseStyle({required this.page, required this.styles, required this.regions});

  final PageSetup page;
  final Map<StyleRole, BlockStyle> styles;
  final Map<RegionSlot, PageRegion> regions;
}

/// Every value either base gives. A role a base does not name takes the body's typography and no box.
final Map<StyleBase, BaseStyle> styleBases = {
  StyleBase.legal: BaseStyle(
    page: PageSetup.of({
      'orientation': 'portrait',
      'margins': {'top': 2.5, 'right': 2.5, 'bottom': 2.5, 'left': 2.5},
      'header': 1.25,
      'footer': 1.25,
    }),
    styles: {
      StyleRole.body: BlockStyle.of({
        'font': 'times', 'size': 12, 'lineHeight': 1.5, 'align': 'justify', 'color': '#000000', 'spaceAfter': 6,
      }),
      StyleRole.heading1: BlockStyle.of({
        'bold': true, 'caps': true, 'align': 'center', 'spaceBefore': 12, 'spaceAfter': 12,
      }),
      StyleRole.heading2: BlockStyle.of({'bold': true, 'align': 'left', 'spaceBefore': 12, 'spaceAfter': 6}),
      StyleRole.heading3: BlockStyle.of({
        'bold': true, 'italic': true, 'align': 'left', 'spaceBefore': 6, 'spaceAfter': 6,
      }),
      StyleRole.bullets: BlockStyle.of({'marker': 'dash', 'indent': 0.75, 'spaceAfter': 6}),
      StyleRole.table: BlockStyle.of({
        'size': 11, 'lineHeight': 1.15, 'align': 'left', 'grid': 'all', 'borderColor': '#000000',
        'borderWidth': 0.5, 'padding': 4, 'spaceBefore': 6, 'spaceAfter': 12,
      }),
      StyleRole.tableHeader: BlockStyle.of({'bold': true}),
      StyleRole.quote: BlockStyle.of({
        'size': 11, 'italic': true, 'lineHeight': 1.15, 'indent': 1.25, 'spaceBefore': 6, 'spaceAfter': 12,
      }),
      StyleRole.callout: BlockStyle.of({
        'align': 'left', 'border': 'box', 'borderColor': '#000000', 'borderWidth': 0.5, 'padding': 8,
        'spaceBefore': 6, 'spaceAfter': 12,
      }),
      StyleRole.caption: BlockStyle.of({
        'size': 10, 'italic': true, 'align': 'left', 'lineHeight': 1.15, 'spaceBefore': 4,
      }),
      StyleRole.metrics: BlockStyle.of({
        'size': 14, 'bold': true, 'align': 'left', 'lineHeight': 1.15, 'border': 'box', 'borderColor': '#000000',
        'borderWidth': 0.5, 'padding': 8, 'spaceAfter': 12,
      }),
    },
    regions: {
      RegionSlot.footer: PageRegion(
        center: '{pagina}',
        style: BlockStyle.of({'size': 10, 'lineHeight': 1, 'spaceBefore': 12}),
      ),
    },
  ),
  StyleBase.report: BaseStyle(
    page: PageSetup.of({
      'orientation': 'portrait',
      'margins': {'top': 3, 'right': 2, 'bottom': 2.3, 'left': 2},
      'header': 1.4,
      'footer': 1.25,
    }),
    styles: {
      StyleRole.body: BlockStyle.of({
        'font': 'inter', 'size': 10, 'lineHeight': 1.33, 'align': 'left', 'color': '#334155', 'spaceAfter': 12,
      }),
      StyleRole.heading1: BlockStyle.of({
        'size': 22, 'bold': true, 'color': '#0f172a', 'lineHeight': 1.1, 'spaceBefore': 8, 'spaceAfter': 12,
      }),
      StyleRole.heading2: BlockStyle.of({
        'size': 14, 'bold': true, 'color': '#0f172a', 'lineHeight': 1.2, 'spaceBefore': 8, 'spaceAfter': 10,
      }),
      StyleRole.heading3: BlockStyle.of({'size': 8, 'bold': true, 'caps': true, 'color': 'accent', 'spaceAfter': 8}),
      StyleRole.bullets: BlockStyle.of({'marker': 'disc', 'indent': 0.5, 'lineHeight': 1.25, 'spaceAfter': 6}),
      StyleRole.table: BlockStyle.of({
        'size': 9, 'lineHeight': 1.15, 'grid': 'rows', 'borderColor': '#e2e8f0', 'borderWidth': 0.6,
        'padding': 7, 'stripe': '#f8fafc', 'spaceAfter': 12,
      }),
      StyleRole.tableHeader: BlockStyle.of({
        'size': 7, 'bold': true, 'caps': true, 'color': 'accent', 'background': 'accent/7',
      }),
      StyleRole.quote: BlockStyle.of({
        'size': 13, 'color': '#0f172a', 'lineHeight': 1.3, 'border': 'left', 'borderColor': 'accent',
        'borderWidth': 2.5, 'padding': 10, 'spaceAfter': 12,
      }),
      StyleRole.callout: BlockStyle.of({
        'size': 9.5, 'background': 'accent/7', 'border': 'box', 'borderColor': 'accent/16', 'borderWidth': 0.8,
        'padding': 14, 'spaceAfter': 12,
      }),
      StyleRole.caption: BlockStyle.of({'size': 7.5, 'color': '#64748b', 'lineHeight': 1.2, 'spaceBefore': 6}),
      StyleRole.metrics: BlockStyle.of({
        'size': 17, 'bold': true, 'color': '#0f172a', 'lineHeight': 1.1, 'background': 'accent/7',
        'padding': 12, 'spaceAfter': 12,
      }),
    },
    regions: {
      RegionSlot.header: PageRegion(
        left: '{studio}',
        right: '{sezione}',
        line: true,
        style: _reportRegion.patch({'spaceAfter': 18}),
      ),
      RegionSlot.footer: PageRegion(
        left: '{titolo} · {cliente}',
        right: '{pagina} / {pagine}',
        line: true,
        style: _reportRegion.patch({'spaceBefore': 12}),
      ),
    },
  ),
};

final _reportRegion = BlockStyle.of({
  'size': 7.5, 'color': '#64748b', 'lineHeight': 1, 'borderColor': '#e2e8f0', 'borderWidth': 0.6, 'padding': 8,
});

// ---------------------------------------------------------------------------
// Resolution
// ---------------------------------------------------------------------------

/// A style with every field decided, colours as ARGB (null: none) and lengths in points: what the renderer and the
/// exporters draw.
class ResolvedStyle {
  ResolvedStyle(BlockStyle s, int accent)
    : font = s.font ?? DocFont.inter,
      size = s.size ?? 11,
      bold = s.bold ?? false,
      italic = s.italic ?? false,
      underline = s.underline ?? false,
      caps = s.caps ?? false,
      color = resolveColor(s.color, accent) ?? 0xFF000000,
      background = resolveColor(s.background, accent),
      align = s.align ?? BlockAlign.left,
      lineHeight = s.lineHeight ?? 1.15,
      spaceBefore = s.spaceBefore ?? 0,
      spaceAfter = s.spaceAfter ?? 0,
      indent = cmToPt(s.indent ?? 0),
      firstLineIndent = cmToPt(s.firstLineIndent ?? 0),
      border = s.border ?? BlockBorder.none,
      borderColor = resolveColor(s.borderColor, accent),
      borderWidth = s.borderWidth ?? 0.5,
      padding = s.padding ?? 0,
      marker = s.marker ?? ListMarker.disc,
      grid = s.grid ?? TableGrid.rows,
      stripe = resolveColor(s.stripe, accent);

  final DocFont font;
  final double size;
  final bool bold;
  final bool italic;
  final bool underline;
  final bool caps;
  final int color;
  final int? background;
  final BlockAlign align;
  final double lineHeight;
  final double spaceBefore;
  final double spaceAfter;
  final double indent;
  final double firstLineIndent;
  final BlockBorder border;
  final int? borderColor;
  final double borderWidth;
  final double padding;
  final ListMarker marker;
  final TableGrid grid;
  final int? stripe;

  /// The colour of borders and grid lines: the one set, else the text's.
  int get lineColor => borderColor ?? color;

  /// The room a list gives its markers, in points: the list's indent, else one and a half times its type.
  double get markerWidth => indent > 0 ? indent : size * 1.5;

  /// [text] as this style shows it.
  String cased(String text) => caps ? text.toUpperCase() : text;
}

/// The marker of item [index] (0-based) of a list.
String listMarker(ListMarker marker, int index) => switch (marker) {
  ListMarker.disc => '•',
  ListMarker.dash => '–',
  ListMarker.number => '${index + 1}.',
  ListMarker.letter => '${_letters(index)})',
  ListMarker.none => '',
};

String _letters(int index) =>
    index < 26 ? String.fromCharCode(0x61 + index) : _letters(index ~/ 26 - 1) + _letters(index % 26);

/// A document's theme over its base: the one place that decides what each role, block and region looks like.
class DocStyles {
  DocStyles(this.theme) : base = styleBases[theme.base]!;

  final DocTheme theme;
  final BaseStyle base;

  /// What the document and its base say of [role], without inheritance.
  BlockStyle role(StyleRole role) => (theme.styles[role] ?? BlockStyle.empty).over(base.styles[role]);

  /// The style of a block of [role] carrying [block]: the block over its role over the body's typography.
  BlockStyle merged(StyleRole role, [BlockStyle? block]) {
    final own = (block ?? BlockStyle.empty).over(this.role(role));
    return role == StyleRole.body ? own : own.over(this.role(StyleRole.body).only(inheritedFields));
  }

  /// The style of a part (a table's header row, a caption) of a block whose style is [of].
  BlockStyle part(StyleRole part, BlockStyle of) => role(part).over(of.only(inheritedFields));

  ResolvedStyle resolve(BlockStyle style) => ResolvedStyle(style, theme.accent);

  PageSetup get page => theme.page.over(base.page);

  /// The region a page shows in [slot]: the document's, else the base's; a first page not set repeats the others.
  PageRegion region(RegionSlot slot) =>
      theme.regions[slot] ??
      switch (slot) {
        RegionSlot.firstHeader => region(RegionSlot.header),
        RegionSlot.firstFooter => region(RegionSlot.footer),
        _ => base.regions[slot] ?? const PageRegion(),
      };

  /// The style a region's texts are drawn in.
  BlockStyle regionStyle(PageRegion region) => region.style.over(role(StyleRole.body).only(inheritedFields));
}
