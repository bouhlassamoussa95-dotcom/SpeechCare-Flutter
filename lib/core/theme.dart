import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Colors copied 1:1 from the web app's CSS variables.
class Pal {
  final bool dark;
  final Color sec;
  const Pal(this.dark, this.sec);

  static const Color pri = Color(0xFF5B3F8C);
  static const Color tea = Color(0xFF0F7A72);
  static const Color amb = Color(0xFFE8A33D);
  static const Color red = Color(0xFFD64545);

  Color get bg => dark ? const Color(0xFF0F161B) : const Color(0xFFF2F5F9);
  Color get card => dark ? const Color(0xFF18222A) : const Color(0xFFFFFFFF);
  Color get ink => dark ? const Color(0xFFE8EFF3) : const Color(0xFF16222B);
  Color get mut => dark ? const Color(0xFF93A5AE) : const Color(0xFF64767F);
  Color get line => dark ? const Color(0xFF26333C) : const Color(0xFFE3E9EE);
  Color get chip => dark ? const Color(0xFF2B2742) : const Color(0xFFECE8F7);
  double get tint => dark ? 0.18 : 0.11;

  /// `color-mix(in srgb, var(--sec) var(--tint), var(--bg))`
  Color get page => Color.lerp(bg, sec, tint)!;

  static Pal of(BuildContext c) {
    return Pal(Theme.of(c).brightness == Brightness.dark, currentSec);
  }
}

/// Current section accent (`--sec`). Updated by the shell on every navigation.
Color currentSec = const Color(0xFF5B3F8C);

Color hex(String h) {
  var s = h.replaceAll('#', '');
  if (s.length == 6) s = 'FF$s';
  return Color(int.parse(s, radix: 16));
}

Color alpha(Color c, double o) => c.withAlpha((o.clamp(0.0, 1.0) * 255).round());

/// `color-mix(in srgb, a pct%, b)`
Color mix(Color a, double pct, Color b) => Color.lerp(b, a, pct)!;

/// Section colors (SECC).
final Map<String, Color> kSecc = {
  'home': hex('#2563eb'),
  'sess': hex('#1f9d63'),
  'cal': hex('#e07b00'),
  'today': hex('#0f8a82'),
  'cons': hex('#c9407a'),
  'pats': hex('#6d48c9'),
  'pat': hex('#6d48c9'),
  'fin': hex('#b8860b'),
  'rep': hex('#d64545'),
  'me': hex('#52606d'),
  'set': hex('#0f7a72'),
  'activities': hex('#0f7a72'),
  'toys': hex('#c9407a'),
  'wps': hex('#2f6fe4'),
};

/// Card accent colors COL.
final List<Color> kCol = [
  hex('#2f8cf0'),
  hex('#2fb872'),
  hex('#f29a2e'),
  hex('#e24b4b'),
  hex('#7c55d6'),
  hex('#16a39a'),
];

/// Appointment status colors SCL.
final Map<String, Color> kScl = {
  'done': hex('#2fb872'),
  'scheduled': hex('#e8a33d'),
  'absent': hex('#e24b4b'),
  'cancelled': hex('#9aa5ad'),
  'rescheduled': hex('#8a6cc9'),
};

/// Status tag colors (.t-done etc.): [background, foreground]
final Map<String, List<Color>> kTag = {
  'done': [hex('#d5f3e3'), hex('#12724a')],
  'scheduled': [hex('#dbe9ff'), hex('#1d4fa8')],
  'absent': [hex('#ffe0e0'), hex('#a52a2a')],
  'cancelled': [hex('#e6e8eb'), hex('#555555')],
  'rescheduled': [hex('#ece4ff'), hex('#5b3f8c')],
};

TextTheme _cairo(TextTheme base) => GoogleFonts.cairoTextTheme(base);

final Map<Brightness, ThemeData> _themeCache = {};

ThemeData buildTheme(Brightness b) => _themeCache.putIfAbsent(b, () => _buildTheme(b));

ThemeData _buildTheme(Brightness b) {
  final base = ThemeData(brightness: b, useMaterial3: true);
  final pal = Pal(b == Brightness.dark, currentSec);
  return base.copyWith(
    textTheme: _cairo(base.textTheme).apply(bodyColor: pal.ink, displayColor: pal.ink),
    colorScheme: ColorScheme.fromSeed(
      seedColor: Pal.pri,
      brightness: b,
    ).copyWith(primary: Pal.pri, surface: pal.card),
    scaffoldBackgroundColor: pal.bg,
    dividerColor: pal.line,
    splashFactory: InkRipple.splashFactory,
    canvasColor: pal.card,
  );
}
