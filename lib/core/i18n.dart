import 'dictionary.dart';

/// UI language state + translation helpers (port of DICT / T / L3).
class I18n {
  static String lang = 'en';
  static final Map<String, Map<String, String>> _d = _build();

  static Map<String, Map<String, String>> _build() {
    final fr = <String, String>{};
    final ar = <String, String>{};
    for (final r in kDictRows) {
      if (r.length == 3 && r[0].isNotEmpty && r[1].isNotEmpty && r[2].isNotEmpty) {
        fr[r[0]] = r[1];
        ar[r[0]] = r[2];
      }
    }
    return {'fr': fr, 'ar': ar};
  }
}

bool get isRtl => I18n.lang == 'ar';

/// Translate a UI key. Unknown keys fall back to the English text
/// (with the `__` marker removed), exactly like the web app.
String T(String x) {
  final d = I18n._d[I18n.lang];
  final v = d == null ? null : d[x];
  if (v != null && v.isNotEmpty) return v;
  return x.replaceFirst('__', '');
}

/// Inline three-language text (port of L3).
String l3(String en, String fr, String ar) {
  switch (I18n.lang) {
    case 'fr':
      return fr;
    case 'ar':
      return ar;
    default:
      return en;
  }
}

/// Same as [l3] but for an explicit language code.
String l3x(String lang, String en, String fr, String ar) {
  switch (lang) {
    case 'fr':
      return fr;
    case 'ar':
      return ar;
    default:
      return en;
  }
}

int langIx(String lang) => lang == 'fr' ? 1 : (lang == 'ar' ? 2 : 0);

/// Translate [x] into an explicit language (used by reports whose language differs from the UI).
String tx(String lang, String x) {
  final d = I18n._d[lang];
  final v = d == null ? null : d[x];
  return (v != null && v.isNotEmpty) ? v : x;
}
