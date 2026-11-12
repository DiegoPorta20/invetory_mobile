// Lenient JSON readers: MySQL decimals can reach the client as numbers or strings.

int asInt(Object? value, [int fallback = 0]) {
  if (value is int) return value;
  if (value is num) return value.round();
  if (value is String) return int.tryParse(value) ?? double.tryParse(value)?.round() ?? fallback;
  return fallback;
}

int? asIntOrNull(Object? value) => value == null ? null : asInt(value);

double asDouble(Object? value, [double fallback = 0]) {
  if (value is num) return value.toDouble();
  if (value is String) return double.tryParse(value) ?? fallback;
  return fallback;
}

double? asDoubleOrNull(Object? value) => value == null ? null : asDouble(value);

String asString(Object? value, [String fallback = '']) => value?.toString() ?? fallback;

String? asStringOrNull(Object? value) => value?.toString();

bool asBool(Object? value, [bool fallback = false]) {
  if (value is bool) return value;
  if (value is num) return value != 0;
  if (value is String) return value == 'true' || value == '1';
  return fallback;
}

Map<String, dynamic> asMap(Object? value) =>
    value is Map<String, dynamic> ? value : <String, dynamic>{};

List<Map<String, dynamic>> asMapList(Object? value) =>
    value is List ? value.whereType<Map<String, dynamic>>().toList() : const [];
