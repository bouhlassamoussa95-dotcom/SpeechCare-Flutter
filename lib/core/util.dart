import 'dart:math';
import 'package:intl/intl.dart';

/// JSON-like record. The whole app state is kept as plain JSON maps so the cloud
/// documents stay 100% compatible with the existing web/Capacitor build.
typedef J = Map<String, dynamic>;

final Random _rnd = Random();

String uid() {
  const chars = '0123456789abcdefghijklmnopqrstuvwxyz';
  final b = StringBuffer();
  for (var i = 0; i < 7; i++) {
    b.write(chars[_rnd.nextInt(36)]);
  }
  return b.toString();
}

/// JS `String(x == null ? '' : x)`
String str(dynamic v) => v == null ? '' : v.toString();

/// JS `+v` (NaN becomes 0).
double nv(dynamic v) {
  if (v == null) return 0;
  if (v is num) return v.toDouble();
  if (v is bool) return v ? 1 : 0;
  final s = v.toString().trim();
  if (s.isEmpty) return 0;
  return double.tryParse(s) ?? 0;
}

int iv(dynamic v) => nv(v).round();

/// Null when the value is empty or not numeric (JS `isNaN(+v)` / `v === ''`).
double? numOrNull(dynamic v) {
  if (v == null) return null;
  if (v is num) return v.toDouble();
  final s = v.toString().trim();
  if (s.isEmpty) return null;
  return double.tryParse(s);
}

bool truthy(dynamic v) => v != null && v != '' && v != 0 && v != false;

String two(int n) => n.toString().padLeft(2, '0');
String fmtDate(DateTime d) => '${d.year.toString().padLeft(4, '0')}-${two(d.month)}-${two(d.day)}';
String td() => fmtDate(DateTime.now());

/// Parses 'yyyy-MM-dd' at local noon (same as JS `new Date(s + 'T12:00')`).
DateTime parseD(String s) {
  final p = s.split('-');
  if (p.length >= 3) {
    final y = int.tryParse(p[0]);
    final m = int.tryParse(p[1]);
    final d = int.tryParse(p[2].length > 2 ? p[2].substring(0, 2) : p[2]);
    if (y != null && m != null && d != null) return DateTime(y, m, d, 12);
  }
  return DateTime.now();
}

String addD(String s, int n) {
  final d = parseD(s);
  return fmtDate(DateTime(d.year, d.month, d.day + n, 12));
}

/// JS `Date.getDay()`: 0 = Sunday ... 6 = Saturday.
int jsDay(DateTime d) => d.weekday % 7;

/// Monday-first offset: JS `(getDay()+6)%7`.
int monOffset(DateTime d) => d.weekday - 1;

const Map<String, String> kLocales = {'en': 'en_GB', 'fr': 'fr_FR', 'ar': 'ar_DZ'};

String fmtLoc(String lang, String ds, String pattern) {
  try {
    return DateFormat(pattern, kLocales[lang] ?? 'en_GB').format(parseD(ds));
  } catch (_) {
    return ds;
  }
}

String fmtNum(String lang, num n) {
  try {
    return NumberFormat('#,##0.##', kLocales[lang] ?? 'en_GB').format(n);
  } catch (_) {
    return n.toString();
  }
}


/// Strips a leading ` (` suffix exactly like `x.split(' (')[0]`.
String shortCond(String s) => s.split(' (').first;

List<J> asList(dynamic v) {
  if (v is List) return v.whereType<Map>().map((e) => e as J).toList();
  return <J>[];
}

String? firstNonEmpty(List<String?> xs) {
  for (final x in xs) {
    if (x != null && x.isNotEmpty) return x;
  }
  return null;
}
