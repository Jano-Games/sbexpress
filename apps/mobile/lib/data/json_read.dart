Map<String, Object?> asJsonMap(Object? value, String label) {
  if (value is Map<String, Object?>) return value;
  if (value is Map) {
    final mapped = <String, Object?>{};
    for (final key in value.keys) {
      mapped['$key'] = value[key] as Object?;
    }
    return mapped;
  }
  throw FormatException('$label is not an object');
}

void requireKey(Map<String, Object?> json, String key) {
  if (!json.containsKey(key)) throw FormatException('Missing $key');
}

String asString(Object? value, String label) {
  if (value is String) return value;
  throw FormatException('$label is not text');
}

String? asNullableString(Object? value, String label) {
  if (value == null) return null;
  return asString(value, label);
}

String requiredString(Map<String, Object?> json, String key) {
  requireKey(json, key);
  return asString(json[key], key);
}

String? requiredNullableString(Map<String, Object?> json, String key) {
  requireKey(json, key);
  return asNullableString(json[key], key);
}

double asDouble(Object? value, String label) {
  if (value is int) return value.toDouble();
  if (value is double) return value;
  throw FormatException('$label is not a number');
}

double? asNullableDouble(Object? value, String label) {
  if (value == null) return null;
  return asDouble(value, label);
}

double requiredDouble(Map<String, Object?> json, String key) {
  requireKey(json, key);
  return asDouble(json[key], key);
}

double? requiredNullableDouble(Map<String, Object?> json, String key) {
  requireKey(json, key);
  return asNullableDouble(json[key], key);
}

int asInt(Object? value, String label) {
  if (value is int) return value;
  if (value is double && value == value.roundToDouble()) return value.toInt();
  throw FormatException('$label is not an integer');
}

int requiredInt(Map<String, Object?> json, String key) {
  requireKey(json, key);
  return asInt(json[key], key);
}

bool asBool(Object? value, String label) {
  if (value is bool) return value;
  throw FormatException('$label is not a boolean');
}

bool requiredBool(Map<String, Object?> json, String key) {
  requireKey(json, key);
  return asBool(json[key], key);
}

List<String> asStringList(Object? value, String label) {
  if (value is! List) throw FormatException('$label is not a list');
  return [for (final item in value) asString(item as Object?, label)];
}

List<String> requiredStringList(Map<String, Object?> json, String key) {
  requireKey(json, key);
  return asStringList(json[key], key);
}

List<Map<String, Object?>> asMapList(Object? value, String label) {
  if (value is! List) throw FormatException('$label is not a list');
  return [for (final item in value) asJsonMap(item as Object?, label)];
}

List<Map<String, Object?>> requiredMapList(
    Map<String, Object?> json, String key) {
  requireKey(json, key);
  return asMapList(json[key], key);
}

/// Null when [key] is absent or null. Fields added to the API later are read
/// this way, so the app keeps working against a server that predates them.
double? optionalDouble(Map<String, Object?> json, String key) =>
    json[key] == null ? null : asDouble(json[key], key);

String? optionalString(Map<String, Object?> json, String key) =>
    json[key] == null ? null : asString(json[key], key);

int? optionalInt(Map<String, Object?> json, String key) =>
    json[key] == null ? null : asInt(json[key], key);

Map<String, Object?>? optionalMap(Map<String, Object?> json, String key) =>
    json[key] == null ? null : asJsonMap(json[key], key);
