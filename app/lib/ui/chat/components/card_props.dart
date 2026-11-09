// Reading a server-driven card's props: the payload is untyped JSON, so every card reads it through these.
// A prop of the wrong shape reads as missing: the card shows what it can instead of failing to build.

/// The elements of a list prop; anything that is not a list reads as empty.
List<Object?> propList(Object? value) => value is List ? value : const [];

/// The maps in a list prop; anything else in it, or a prop that is not a list, is skipped.
List<Map<String, dynamic>> propMaps(Object? value) => [
  for (final e in propList(value))
    if (e is Map) e.cast<String, dynamic>(),
];

/// The elements of a list prop as text.
List<String> propStrings(Object? value) => [for (final e in propList(value)) '$e'];

/// A map prop; anything that is not a map reads as empty.
Map<String, dynamic> propMap(Object? value) => value is Map ? value.cast<String, dynamic>() : const {};

/// A prop as trimmed text, or [fallback] when it is missing or blank.
String propStr(Object? value, [String fallback = '']) {
  final s = value?.toString().trim() ?? '';
  return s.isEmpty ? fallback : s;
}

/// A numeric prop as a whole number, or [fallback] when it is missing or not a number.
int propInt(Object? value, [int fallback = 0]) => value is num ? value.toInt() : fallback;

/// A numeric prop, or [fallback] when it is missing or not a number.
double propDouble(Object? value, [double fallback = 0]) => value is num ? value.toDouble() : fallback;

/// A whole-number prop, or null when it is missing or not a number.
int? propIntOrNull(Object? value) => value is num ? value.toInt() : null;

/// A text prop exactly as sent, or null when it is missing or not text.
String? propString(Object? value) => value is String ? value : null;

/// A flag prop, or [fallback] when it is missing or not a bool.
bool propBool(Object? value, [bool fallback = false]) => value is bool ? value : fallback;
