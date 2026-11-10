/// Internal helpers for reading untyped JSON into typed fields.
///
/// Every reader throws a [FormatException] naming the field when a required
/// value is missing or has the wrong type, so a malformed response fails loudly
/// instead of surfacing as a `TypeError` deep inside the caller's code.
library;

/// A decoded JSON object.
typedef Json = Map<String, Object?>;

/// Casts [value] to a JSON object or throws a [FormatException].
Json asJson(Object? value, [String what = 'value']) {
  if (value is Map<String, Object?>) return value;
  if (value is Map) return value.cast<String, Object?>();
  throw FormatException(
      'Expected $what to be a JSON object, got ${_typeOf(value)}.');
}

/// Reads a required string.
String reqString(Json json, String key) {
  final value = json[key];
  if (value is String) return value;
  throw _bad(key, 'a string', value);
}

/// Reads an optional string; `null` and a missing key both give `null`.
String? optString(Json json, String key) {
  final value = json[key];
  if (value == null || value is String) return value as String?;
  throw _bad(key, 'a string or null', value);
}

/// Reads a required integer. Whole-number doubles are accepted.
int reqInt(Json json, String key) {
  final value = optInt(json, key);
  if (value != null) return value;
  throw _bad(key, 'an integer', json[key]);
}

/// Reads an optional integer. Whole-number doubles are accepted.
int? optInt(Json json, String key) {
  final value = json[key];
  if (value == null) return null;
  if (value is int) return value;
  if (value is double && value == value.truncateToDouble()) {
    return value.toInt();
  }
  throw _bad(key, 'an integer or null', value);
}

/// Reads a boolean, falling back to [fallback] when the key is missing or null.
bool readBool(Json json, String key, {bool fallback = false}) {
  final value = json[key];
  if (value == null) return fallback;
  if (value is bool) return value;
  throw _bad(key, 'a boolean', value);
}

/// Reads a required ISO-8601 timestamp.
DateTime reqDate(Json json, String key) {
  final value = optDate(json, key);
  if (value != null) return value;
  throw _bad(key, 'an ISO-8601 timestamp', json[key]);
}

/// Reads an optional ISO-8601 timestamp.
DateTime? optDate(Json json, String key) {
  final value = optString(json, key);
  if (value == null) return null;
  final parsed = DateTime.tryParse(value);
  if (parsed == null) throw _bad(key, 'an ISO-8601 timestamp', value);
  return parsed;
}

/// Reads a required nested object with [read].
T reqObject<T>(Json json, String key, T Function(Json) read) {
  final value = json[key];
  if (value == null) throw _bad(key, 'an object', value);
  return read(asJson(value, '"$key"'));
}

/// Reads an optional nested object with [read].
T? optObject<T>(Json json, String key, T Function(Json) read) {
  final value = json[key];
  if (value == null) return null;
  return read(asJson(value, '"$key"'));
}

/// Reads a list of objects with [read]; a missing or null list gives `[]`.
List<T> readList<T>(Json json, String key, T Function(Json) read) {
  final value = json[key];
  if (value == null) return const [];
  if (value is! List) throw _bad(key, 'a list', value);
  return List.unmodifiable(
      value.map((item) => read(asJson(item, 'an item of "$key"'))));
}

/// Reads a list of strings; a missing or null list gives `[]`.
List<String> readStringList(Json json, String key) {
  final value = json[key];
  if (value == null) return const [];
  if (value is! List) throw _bad(key, 'a list of strings', value);
  return List.unmodifiable(value.map((item) {
    if (item is String) return item;
    throw _bad(key, 'a list of strings', value);
  }));
}

/// Reads an optional string-to-string map.
Map<String, String>? optStringMap(Json json, String key) {
  final value = json[key];
  if (value == null) return null;
  if (value is! Map) throw _bad(key, 'an object of strings', value);
  return Map.unmodifiable(value.map((k, v) {
    if (k is String && v is String) return MapEntry(k, v);
    throw _bad(key, 'an object of strings', value);
  }));
}

/// Formats a timestamp the way the API does (UTC, milliseconds, `Z`).
String? isoOrNull(DateTime? value) => value?.toUtc().toIso8601String();

FormatException _bad(String key, String expected, Object? got) =>
    FormatException('Expected "$key" to be $expected, got ${_typeOf(got)}.');

String _typeOf(Object? value) =>
    value == null ? 'null' : value.runtimeType.toString();
