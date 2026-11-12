import 'package:intl/intl.dart';

const appLocale = 'es_PE';
const _dash = '—';

/// Peru has no DST, so a fixed UTC-5 offset matches `America/Lima`.
const _limaOffset = Duration(hours: 5);

final _integer = NumberFormat('#,##0', appLocale);
final _decimal2 = NumberFormat('#,##0.00', appLocale);
final _decimal4 = NumberFormat('#,##0.00##', appLocale);
final _dateOnly = DateFormat('d MMM y', appLocale);
final _dateTime = DateFormat("d MMM y, h:mm a", appLocale);
final _shortDay = DateFormat('d MMM', appLocale);

String formatQuantity(num? value) => value == null ? _dash : _integer.format(value);

String formatSignedQuantity(num? value) {
  if (value == null) return _dash;
  return '${value > 0 ? '+' : ''}${_integer.format(value)}';
}

/// Soles. [precise] shows up to four decimals (unit costs); otherwise two.
String formatPen(num? value, {bool precise = false}) {
  if (value == null) return _dash;
  return 'S/ ${(precise ? _decimal4 : _decimal2).format(value)}';
}

DateTime _toLima(DateTime value) => value.toUtc().subtract(_limaOffset);

String formatDateTime(String? iso) {
  final parsed = iso == null ? null : DateTime.tryParse(iso);
  return parsed == null ? _dash : _dateTime.format(_toLima(parsed));
}

/// Accepts a `YYYY-MM-DD` date or a full ISO timestamp.
String formatDate(String? value) {
  if (value == null || value.isEmpty) return _dash;
  if (value.length == 10) {
    final parsed = DateTime.tryParse(value);
    return parsed == null ? _dash : _dateOnly.format(parsed);
  }
  final parsed = DateTime.tryParse(value);
  return parsed == null ? _dash : _dateOnly.format(_toLima(parsed));
}

String formatShortDay(String isoDay) {
  final parsed = DateTime.tryParse(isoDay);
  return parsed == null ? isoDay : _shortDay.format(parsed);
}

/// `YYYY-MM-DD` for API filters and date fields.
String toIsoDay(DateTime value) =>
    '${value.year.toString().padLeft(4, '0')}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';

String formatPercent(num value) {
  final rounded = (value * 10).round() / 10;
  final text = rounded == rounded.roundToDouble()
      ? rounded.toStringAsFixed(0)
      : rounded.toStringAsFixed(1);
  return '${rounded >= 0 ? '+' : ''}$text%';
}

String initialsOf(String name) {
  final parts =
      name.split(RegExp(r'\s+')).where((part) => part.isNotEmpty).take(2);
  return parts.map((part) => part[0].toUpperCase()).join();
}
