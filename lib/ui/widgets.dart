import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../core/globals.dart';
import '../core/i18n.dart';
import '../core/theme.dart';
import '../core/util.dart';
import '../state/app_state.dart';
import '../state/logic.dart';

Pal pal(BuildContext c) => Pal.of(c);

void haptic() {
  try {
    HapticFeedback.lightImpact();
  } catch (_) {}
}

// ------------------------------------------------------------------ icons
const Map<String, IconData> kIcons = {
  'spark': Icons.auto_awesome,
  'box': Icons.inventory_2_outlined,
  'home': Icons.home_outlined,
  'cal': Icons.calendar_month_outlined,
  'users': Icons.people_outline,
  'doc': Icons.description_outlined,
  'menu': Icons.menu,
  'bell': Icons.notifications_none,
  'plus': Icons.add,
  'search': Icons.search,
  'phone': Icons.phone_outlined,
  'check': Icons.check,
  'x': Icons.close,
  'clock': Icons.schedule,
  'pin': Icons.place_outlined,
  'back': Icons.arrow_back,
  'out': Icons.logout,
  'user': Icons.person_outline,
  'mail': Icons.mail_outline,
  'lock': Icons.lock_outline,
  'eye': Icons.visibility_outlined,
  'chev': Icons.chevron_right,
  'list': Icons.format_list_bulleted,
  'chat': Icons.chat_bubble_outline,
  'x2': Icons.cancel_outlined,
  'refresh': Icons.refresh,
  'send': Icons.send,
  'gear': Icons.settings_outlined,
};

Widget ic(String n, {double size = 20, Color? color}) => Icon(kIcons[n] ?? Icons.circle, size: size, color: color);

// ----------------------------------------------------------------- text
class H2 extends StatelessWidget {
  final String text;
  const H2(this.text, {super.key});
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(0, 18, 0, 8),
        child: Text(text, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
      );
}

class H3 extends StatelessWidget {
  final String text;
  final Color? color;
  const H3(this.text, {super.key, this.color});
  @override
  Widget build(BuildContext context) => Text(text, style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: color));
}

class Mut extends StatelessWidget {
  final String text;
  final double size;
  final int? maxLines;
  final TextAlign? align;
  const Mut(this.text, {super.key, this.size = 13, this.maxLines, this.align});
  @override
  Widget build(BuildContext context) => Text(text, maxLines: maxLines, overflow: maxLines == null ? null : TextOverflow.ellipsis, textAlign: align, style: TextStyle(fontSize: size, color: pal(context).mut));
}

class Lbl extends StatelessWidget {
  final String text;
  final Color? color;
  const Lbl(this.text, {super.key, this.color});
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: 2),
        child: Text(text, style: TextStyle(fontSize: 13, color: color ?? pal(context).mut, fontWeight: color != null ? FontWeight.w700 : FontWeight.w400)),
      );
}

const SizedBox gap8 = SizedBox(height: 8);
const SizedBox gap10 = SizedBox(height: 10);
const SizedBox gap4 = SizedBox(height: 4);

// ---------------------------------------------------------------- cards
/// `.card` (+ optional `.sec` start bar and `border-inline-end` bar).
class AppCard extends StatelessWidget {
  final Widget child;
  final VoidCallback? onTap;
  final Color? startBar, endBar;
  final EdgeInsets padding;
  final EdgeInsets margin;
  final Color? color;
  final Color? borderColor;
  const AppCard({super.key, required this.child, this.onTap, this.startBar, this.endBar, this.padding = const EdgeInsets.fromLTRB(14, 12, 14, 12), this.margin = const EdgeInsets.only(bottom: 10), this.color, this.borderColor});

  @override
  Widget build(BuildContext context) {
    final p = pal(context);
    final radius = BorderRadius.circular(18);
    Widget inner = Padding(padding: padding, child: child);
    if (startBar != null || endBar != null) {
      inner = Stack(children: [
        Padding(padding: EdgeInsetsDirectional.only(start: startBar != null ? 5 : 0, end: endBar != null ? 5 : 0), child: inner),
        if (startBar != null) PositionedDirectional(start: 0, top: 0, bottom: 0, width: 5, child: ColoredBox(color: startBar!)),
        if (endBar != null) PositionedDirectional(end: 0, top: 0, bottom: 0, width: 5, child: ColoredBox(color: endBar!)),
      ]);
    }
    return Container(
      margin: margin,
      decoration: BoxDecoration(color: color ?? p.card, borderRadius: radius, border: Border.all(color: borderColor ?? p.line)),
      child: ClipRRect(
        borderRadius: radius,
        child: Material(
          color: Colors.transparent,
          child: onTap == null
              ? inner
              : InkWell(
                  onTap: () {
                    haptic();
                    onTap!();
                  },
                  child: inner),
        ),
      ),
    );
  }
}

/// Card with the coloured start bar and coloured heading label (`.card.sec`).
Widget secCard(Color c, Widget child, {EdgeInsets? margin, VoidCallback? onTap, Color? endBar}) => AppCard(startBar: c, endBar: endBar, margin: margin ?? const EdgeInsets.only(bottom: 10), onTap: onTap, child: child);

Widget emptyCard(String text) => Builder(builder: (c) => AppCard(child: Text(text, style: TextStyle(fontSize: 13, color: pal(c).mut))));

// -------------------------------------------------------------- buttons
enum BK { primary, ghost, teal, red, outline }

class Btn extends StatelessWidget {
  final String? label;
  final Widget? child;
  final VoidCallback? onTap;
  final BK kind;
  final bool small;
  final bool full;
  final Widget? icon;
  const Btn(this.label, this.onTap, {super.key, this.kind = BK.primary, this.small = false, this.full = false, this.icon, this.child});

  @override
  Widget build(BuildContext context) {
    final p = pal(context);
    Color bg, fg;
    BorderSide side = BorderSide.none;
    switch (kind) {
      case BK.ghost:
        bg = Colors.transparent;
        fg = p.ink;
        side = BorderSide(color: p.line);
        break;
      case BK.teal:
        bg = Pal.tea;
        fg = Colors.white;
        break;
      case BK.red:
        bg = Pal.red;
        fg = Colors.white;
        break;
      case BK.outline:
        bg = Colors.transparent;
        fg = const Color(0xFF2563EB);
        side = const BorderSide(color: Color(0xFF2563EB));
        break;
      default:
        bg = p.sec;
        fg = Colors.white;
    }
    final content = child ??
        Row(mainAxisSize: MainAxisSize.min, mainAxisAlignment: MainAxisAlignment.center, children: [
          if (icon != null) ...[IconTheme(data: IconThemeData(color: fg, size: 16), child: icon!), const SizedBox(width: 6)],
          Flexible(child: Text(label ?? '', textAlign: TextAlign.center, style: TextStyle(color: fg, fontWeight: FontWeight.w600, fontSize: small ? 13 : 15, height: 1.2))),
        ]);
    final b = Material(
      color: onTap == null ? alpha(bg, .5) : bg,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: side),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap == null
            ? null
            : () {
                haptic();
                onTap!();
              },
        child: Container(
          constraints: BoxConstraints(minHeight: small ? 48 : 52, minWidth: 48),
          padding: EdgeInsets.symmetric(horizontal: small ? 12 : 16, vertical: small ? 5 : 9),
          alignment: Alignment.center,
          child: content,
        ),
      ),
    );
    return full ? SizedBox(width: double.infinity, child: b) : b;
  }
}

/// Two-stage destructive confirmation ("Tap again to confirm").
class DangerBtn extends StatefulWidget {
  final String label;
  final VoidCallback onConfirm;
  final bool small;
  final bool iconOnly;
  const DangerBtn(this.label, this.onConfirm, {super.key, this.small = false, this.iconOnly = false});
  @override
  State<DangerBtn> createState() => _DangerBtnState();
}

class _DangerBtnState extends State<DangerBtn> {
  bool armed = false;
  Timer? t;
  @override
  void dispose() {
    t?.cancel();
    super.dispose();
  }

  void tap() {
    if (armed) {
      t?.cancel();
      HapticFeedback.mediumImpact();
      widget.onConfirm();
      return;
    }
    HapticFeedback.heavyImpact();
    setState(() => armed = true);
    t = Timer(const Duration(milliseconds: 3600), () {
      if (mounted) setState(() => armed = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    final p = pal(context);
    if (widget.iconOnly) {
      return IconBtn(armed ? ic('x2', size: 18, color: Colors.white) : ic('x', size: 18, color: p.mut), tap, bg: armed ? Pal.red : null);
    }
    return Btn(armed ? T('Tap again to delete') : widget.label, tap, kind: BK.red, small: widget.small, icon: armed ? ic('x2', size: 16) : null);
  }
}

class IconBtn extends StatelessWidget {
  final Widget icon;
  final VoidCallback onTap;
  final Color? bg;
  final String? tooltip;
  const IconBtn(this.icon, this.onTap, {super.key, this.bg, this.tooltip});
  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip ?? '',
      child: Material(
        color: bg ?? Colors.transparent,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () {
            haptic();
            onTap();
          },
          child: SizedBox(width: 48, height: 48, child: Center(child: icon)),
        ),
      ),
    );
  }
}

// ------------------------------------------------------------ seg / pill
class SegItem {
  final String v, t;
  const SegItem(this.v, this.t);
}

class Seg extends StatelessWidget {
  final List<SegItem> items;
  final String value;
  final ValueChanged<String> onChanged;
  const Seg(this.items, this.value, this.onChanged, {super.key});
  @override
  Widget build(BuildContext context) {
    final p = pal(context);
    return Container(
      margin: const EdgeInsets.fromLTRB(0, 3, 0, 10),
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(color: p.chip, borderRadius: BorderRadius.circular(14)),
      child: Row(
        children: items.map((x) {
          final on = x.v == value;
          return Expanded(
            child: GestureDetector(
              onTap: () {
                haptic();
                onChanged(x.v);
              },
              behavior: HitTestBehavior.opaque,
              child: Container(
                constraints: const BoxConstraints(minHeight: 44),
                alignment: Alignment.center,
                padding: const EdgeInsets.symmetric(vertical: 7, horizontal: 4),
                decoration: BoxDecoration(
                  color: on ? p.card : Colors.transparent,
                  borderRadius: BorderRadius.circular(11),
                  boxShadow: on ? const [BoxShadow(color: Color(0x22000000), blurRadius: 4, offset: Offset(0, 1))] : null,
                ),
                child: Text(x.t, textAlign: TextAlign.center, style: TextStyle(fontSize: 13, color: on ? p.sec : p.mut, fontWeight: on ? FontWeight.w700 : FontWeight.w400)),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

class PillBtn extends StatelessWidget {
  final String text;
  final bool on;
  final VoidCallback onTap;
  const PillBtn(this.text, this.on, this.onTap, {super.key});
  @override
  Widget build(BuildContext context) {
    final p = pal(context);
    return Padding(
      padding: const EdgeInsetsDirectional.only(end: 6),
      child: GestureDetector(
        onTap: () {
          haptic();
          onTap();
        },
        behavior: HitTestBehavior.opaque,
        child: Container(
          constraints: const BoxConstraints(minHeight: 40),
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 5),
          decoration: BoxDecoration(color: on ? p.sec : p.card, borderRadius: BorderRadius.circular(20), border: Border.all(color: on ? p.sec : p.line)),
          child: Text(text, style: TextStyle(color: on ? Colors.white : p.ink, fontSize: 14)),
        ),
      ),
    );
  }
}

/// Horizontal scrolling filter row (`.fltr`).
class PillRow extends StatelessWidget {
  final List<Widget> children;
  const PillRow(this.children, {super.key});
  @override
  Widget build(BuildContext context) => SizedBox(height: 46, child: ListView(scrollDirection: Axis.horizontal, children: children));
}

class ChipW extends StatelessWidget {
  final String text;
  final Widget? icon;
  final Color? bg;
  final Color? fg;
  final VoidCallback? onTap;
  const ChipW(this.text, {super.key, this.icon, this.bg, this.fg, this.onTap});
  @override
  Widget build(BuildContext context) {
    final p = pal(context);
    final w = Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(color: bg ?? p.chip, borderRadius: BorderRadius.circular(20)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        if (icon != null) ...[IconTheme(data: IconThemeData(color: fg ?? p.ink, size: 13), child: icon!), const SizedBox(width: 4)],
        Flexible(child: Text(text, style: TextStyle(fontSize: 12, color: fg ?? p.ink))),
      ]),
    );
    return onTap == null ? w : GestureDetector(onTap: onTap, child: w);
  }
}

Widget chips(List<Widget> c) => Padding(padding: const EdgeInsets.symmetric(vertical: 8), child: Wrap(spacing: 6, runSpacing: 6, children: c));

class TagW extends StatelessWidget {
  final String status;
  const TagW(this.status, {super.key});
  @override
  Widget build(BuildContext context) {
    final c = kTag[status] ?? kTag['cancelled']!;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
      decoration: BoxDecoration(color: c[0], borderRadius: BorderRadius.circular(20)),
      child: Text(T(kSt[status] ?? status), style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: c[1])),
    );
  }
}

class Avatar extends StatelessWidget {
  final String text;
  final double size;
  final Color? bg;
  final Widget? child;
  const Avatar(this.text, {super.key, this.size = 42, this.bg, this.child});
  @override
  Widget build(BuildContext context) => Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: bg,
          gradient: bg == null ? const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Pal.pri, Pal.tea]) : null,
        ),
        child: child ?? Text(text, style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: size * 0.36)),
      );
}

class ProgressBar extends StatelessWidget {
  final double frac;
  const ProgressBar(this.frac, {super.key});
  @override
  Widget build(BuildContext context) {
    final p = pal(context);
    return ClipRRect(
      borderRadius: BorderRadius.circular(6),
      child: Container(
        height: 8,
        color: p.line,
        alignment: AlignmentDirectional.centerStart,
        child: FractionallySizedBox(
          widthFactor: frac.clamp(0.0, 1.0),
          child: Container(decoration: const BoxDecoration(gradient: LinearGradient(colors: [Pal.tea, Pal.pri]))),
        ),
      ),
    );
  }
}

/// `.goal`
class GoalBox extends StatelessWidget {
  final Widget child;
  final Color? bg;
  final Color? bar;
  const GoalBox({super.key, required this.child, this.bg, this.bar});
  @override
  Widget build(BuildContext context) => ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Container(
          color: bg ?? alpha(Pal.tea, .10),
          child: Stack(children: [
            Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(14, 5, 10, 5),
              child: DefaultTextStyle.merge(style: const TextStyle(fontSize: 14), child: child),
            ),
            PositionedDirectional(start: 0, top: 0, bottom: 0, width: 4, child: ColoredBox(color: bar ?? Pal.tea)),
          ]),
        ),
      );
}

// ---------------------------------------------------------------- tiles
class TileColors {
  final Color a, b, icon;
  const TileColors(this.a, this.b, this.icon);
}

final Map<String, TileColors> kTiles = {
  'tb': TileColors(hex('#d6ebff'), hex('#bcdcff'), hex('#2f8cf0')),
  'tg': TileColors(hex('#d6f4e4'), hex('#b9ecd1'), hex('#2fb872')),
  'to': TileColors(hex('#ffeccf'), hex('#ffdca8'), hex('#f29a2e')),
  'tr': TileColors(hex('#ffdede'), hex('#ffc4c4'), hex('#e24b4b')),
  'tp': TileColors(hex('#e7defc'), hex('#d3c4f8'), hex('#7c55d6')),
  'tt': TileColors(hex('#d2f1ee'), hex('#b2e6e1'), hex('#16a39a')),
};

class Tile extends StatelessWidget {
  final String k, icon, label, value, sub;
  final VoidCallback? onTap;
  final bool medium;
  const Tile(this.k, this.icon, this.label, this.value, this.sub, {super.key, this.onTap, this.medium = false});
  @override
  Widget build(BuildContext context) {
    final c = kTiles[k]!;
    return Material(
      color: Colors.transparent,
      child: Ink(
        decoration: BoxDecoration(borderRadius: BorderRadius.circular(20), gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [c.a, c.b])),
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: onTap == null
              ? null
              : () {
                  haptic();
                  onTap!();
                },
          child: Container(
            constraints: const BoxConstraints(minHeight: 104),
            padding: const EdgeInsets.all(12),
            child: Stack(children: [
              Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                Padding(padding: const EdgeInsetsDirectional.only(end: 40), child: Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF17222B)))),
                const SizedBox(height: 14),
                Text(value, style: TextStyle(fontSize: medium ? 19 : 30, fontWeight: FontWeight.bold, height: 1.1, color: const Color(0xFF17222B))),
                const SizedBox(height: 2),
                Text(sub, style: const TextStyle(fontSize: 12, color: Color(0xB317222B))),
              ]),
              PositionedDirectional(
                top: -2,
                end: -2,
                child: Container(width: 34, height: 34, decoration: BoxDecoration(color: c.icon, borderRadius: BorderRadius.circular(11)), child: Center(child: ic(icon, size: 18, color: Colors.white))),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}

class TileGrid extends StatelessWidget {
  final List<Widget> children;
  const TileGrid(this.children, {super.key});
  @override
  Widget build(BuildContext context) {
    final rows = <Widget>[];
    for (var i = 0; i < children.length; i += 2) {
      rows.add(Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: IntrinsicHeight(
          child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Expanded(child: children[i]),
            const SizedBox(width: 10),
            Expanded(child: i + 1 < children.length ? children[i + 1] : const SizedBox()),
          ]),
        ),
      ));
    }
    return Column(children: rows);
  }
}

// ---------------------------------------------------------------- donut
class Donut extends StatelessWidget {
  final List<List<dynamic>> data; // [count, color]
  const Donut(this.data, {super.key});
  @override
  Widget build(BuildContext context) {
    final p = pal(context);
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 900),
      curve: Curves.easeOut,
      builder: (c, t, _) => CustomPaint(size: const Size(120, 120), painter: _DonutPainter(data, p.line, p.ink, t)),
    );
  }
}

class _DonutPainter extends CustomPainter {
  final List<List<dynamic>> data;
  final Color track, text;
  final double t;
  _DonutPainter(this.data, this.track, this.text, this.t);
  @override
  void paint(Canvas canvas, Size s) {
    final k = s.width / 42;
    final center = Offset(21 * k, 21 * k);
    final r = 15.9 * k;
    final rect = Rect.fromCircle(center: center, radius: r);
    final base = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6 * k
      ..color = track;
    canvas.drawCircle(center, r, base);
    final tot = data.fold<num>(0, (a, x) => a + (x[0] as num));
    var start = -math.pi / 2;
    for (final x in data) {
      final frac = tot > 0 ? (x[0] as num) / tot : 0.0;
      final sweep = 2 * math.pi * frac * t;
      if (sweep > 0) {
        final paint = Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 6 * k
          ..color = x[1] as Color;
        canvas.drawArc(rect, start, sweep, false, paint);
      }
      start += 2 * math.pi * frac;
    }
    final tp = TextPainter(text: TextSpan(text: '$tot', style: TextStyle(color: text, fontSize: 9 * k, fontWeight: FontWeight.bold)), textDirection: TextDirection.ltr)..layout();
    tp.paint(canvas, Offset(center.dx - tp.width / 2, center.dy - tp.height / 2));
  }

  @override
  bool shouldRepaint(covariant _DonutPainter o) => o.t != t || o.data != data;
}

// --------------------------------------------------------------- inputs
InputDecoration inputDeco(BuildContext c, {String? hint, Widget? suffix}) {
  final p = pal(c);
  OutlineInputBorder b(Color col, double w) => OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: col, width: w));
  return InputDecoration(
    hintText: hint,
    hintStyle: TextStyle(color: p.mut),
    filled: true,
    fillColor: p.card,
    isDense: true,
    contentPadding: const EdgeInsets.symmetric(horizontal: 11, vertical: 12),
    enabledBorder: b(p.line, 1),
    focusedBorder: b(p.sec, 2),
    border: b(p.line, 1),
    suffixIcon: suffix,
  );
}

class LField extends StatelessWidget {
  final String? label;
  final TextEditingController controller;
  final int minLines;
  final int? maxLines;
  final TextInputType? keyboard;
  final String? hint;
  final ValueChanged<String>? onChanged;
  final bool obscure;
  final TextInputAction? action;
  final ValueChanged<String>? onSubmitted;
  final FocusNode? focus;
  const LField(this.controller, {super.key, this.label, this.minLines = 1, this.maxLines = 1, this.keyboard, this.hint, this.onChanged, this.obscure = false, this.action, this.onSubmitted, this.focus});
  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      if (label != null) Lbl(label!),
      Padding(
        padding: const EdgeInsets.fromLTRB(0, 3, 0, 8),
        child: TextField(
          controller: controller,
          focusNode: focus,
          minLines: minLines,
          maxLines: obscure ? 1 : maxLines,
          keyboardType: keyboard ?? (minLines > 1 || (maxLines ?? 2) > 1 ? TextInputType.multiline : TextInputType.text),
          obscureText: obscure,
          onChanged: onChanged,
          onSubmitted: onSubmitted,
          textInputAction: action,
          style: const TextStyle(fontSize: 16),
          decoration: inputDeco(context, hint: hint),
        ),
      ),
    ]);
  }
}

/// Date field: stores 'yyyy-MM-dd'.
class DateField extends StatelessWidget {
  final String label;
  final String value;
  final ValueChanged<String> onChanged;
  final DateTime? first, last;
  const DateField(this.label, this.value, this.onChanged, {super.key, this.first, this.last});
  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Lbl(label),
      Padding(
        padding: const EdgeInsets.fromLTRB(0, 3, 0, 8),
        child: _FieldButton(
          text: value.isEmpty ? '—' : value,
          icon: Icons.calendar_today_outlined,
          onTap: () async {
            final init = value.isEmpty ? DateTime.now() : parseD(value);
            final f = first ?? DateTime(1900);
            final l = last ?? DateTime(2100);
            final d = await showDatePicker(context: context, initialDate: init.isBefore(f) ? f : (init.isAfter(l) ? l : init), firstDate: f, lastDate: l);
            if (d != null) onChanged(fmtDate(d));
          },
        ),
      ),
    ]);
  }
}

class TimeField extends StatelessWidget {
  final String label;
  final String value;
  final ValueChanged<String> onChanged;
  const TimeField(this.label, this.value, this.onChanged, {super.key});
  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Lbl(label),
      Padding(
        padding: const EdgeInsets.fromLTRB(0, 3, 0, 8),
        child: _FieldButton(
          text: value.isEmpty ? '—' : value,
          icon: Icons.access_time,
          onTap: () async {
            final parts = value.split(':');
            final init = TimeOfDay(hour: int.tryParse(parts.isNotEmpty ? parts[0] : '') ?? 10, minute: int.tryParse(parts.length > 1 ? parts[1] : '') ?? 0);
            final t = await showTimePicker(context: context, initialTime: init, builder: (c, w) => MediaQuery(data: MediaQuery.of(c).copyWith(alwaysUse24HourFormat: true), child: w!));
            if (t != null) onChanged('${two(t.hour)}:${two(t.minute)}');
          },
        ),
      ),
    ]);
  }
}

class _FieldButton extends StatelessWidget {
  final String text;
  final IconData? icon;
  final VoidCallback onTap;
  const _FieldButton({required this.text, this.icon, required this.onTap});
  @override
  Widget build(BuildContext context) {
    final p = pal(context);
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: Container(
        constraints: const BoxConstraints(minHeight: 48),
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 9),
        decoration: BoxDecoration(color: p.card, borderRadius: BorderRadius.circular(12), border: Border.all(color: p.line)),
        child: Row(children: [
          Expanded(child: Text(text, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 16))),
          if (icon != null) Icon(icon, size: 18, color: p.mut),
        ]),
      ),
    );
  }
}

class PickItem {
  final String v, t;
  const PickItem(this.v, this.t);
}

/// Select replacement: opens a bottom sheet (with search when long). [onAddPlace] adds the "＋ Add new center or daycare" row.
class PickerField extends StatelessWidget {
  final String? label;
  final String value;
  final List<PickItem> items;
  final ValueChanged<String> onChanged;
  final bool searchable;
  final bool addPlace;
  const PickerField({super.key, this.label, required this.value, required this.items, required this.onChanged, this.searchable = false, this.addPlace = false});

  @override
  Widget build(BuildContext context) {
    final cur = items.where((e) => e.v == value).toList();
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      if (label != null) Lbl(label!),
      Padding(
        padding: const EdgeInsets.fromLTRB(0, 3, 0, 8),
        child: _FieldButton(
          text: cur.isEmpty ? '—' : cur.first.t,
          icon: Icons.keyboard_arrow_down,
          onTap: () async {
            final r = await showOptionSheet(context, title: label ?? '', items: items, value: value, search: searchable || items.length > 7, addPlace: addPlace);
            if (r != null) onChanged(r);
          },
        ),
      ),
    ]);
  }
}

const String kAddPlaceKey = '__add__';

Future<String?> showOptionSheet(BuildContext context, {required String title, required List<PickItem> items, required String value, bool search = false, bool addPlace = false}) {
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    constraints: const BoxConstraints(maxWidth: 520),
    builder: (c) => _OptionSheet(title: title, items: items, value: value, search: search, addPlace: addPlace),
  );
}

class _OptionSheet extends StatefulWidget {
  final String title, value;
  final List<PickItem> items;
  final bool search, addPlace;
  const _OptionSheet({required this.title, required this.items, required this.value, required this.search, required this.addPlace});
  @override
  State<_OptionSheet> createState() => _OptionSheetState();
}

class _OptionSheetState extends State<_OptionSheet> {
  String q = '';
  @override
  Widget build(BuildContext context) {
    final p = pal(context);
    final z = q.toLowerCase().trim();
    final list = widget.items.where((e) => z.isEmpty || e.t.toLowerCase().contains(z)).toList();
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        constraints: BoxConstraints(maxHeight: math.min(640, MediaQuery.of(context).size.height * 0.78)),
        decoration: BoxDecoration(color: p.page, borderRadius: const BorderRadius.vertical(top: Radius.circular(26))),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const _Grab(),
          if (widget.title.isNotEmpty) Padding(padding: const EdgeInsets.fromLTRB(18, 0, 18, 8), child: Align(alignment: AlignmentDirectional.centerStart, child: Text(widget.title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)))),
          if (widget.search)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 8),
              child: TextField(onChanged: (s) => setState(() => q = s), decoration: inputDeco(context, hint: l3('Search…', 'Rechercher…', 'بحث…')), style: const TextStyle(fontSize: 16)),
            ),
          Flexible(
            child: ListView(
              shrinkWrap: true,
              padding: const EdgeInsets.fromLTRB(10, 0, 10, 14),
              children: [
                ...list.map((e) {
                  final on = e.v == widget.value;
                  return InkWell(
                    borderRadius: BorderRadius.circular(14),
                    onTap: () {
                      haptic();
                      Navigator.pop(context, e.v);
                    },
                    child: Container(
                      constraints: const BoxConstraints(minHeight: 52),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(color: on ? alpha(p.sec, .12) : Colors.transparent, borderRadius: BorderRadius.circular(14)),
                      child: Row(children: [
                        Expanded(child: Text(e.t, style: TextStyle(fontSize: 15, color: on ? p.sec : p.ink, fontWeight: on ? FontWeight.w700 : FontWeight.w400))),
                        if (on) Icon(Icons.check, size: 18, color: p.sec),
                      ]),
                    ),
                  );
                }),
                if (list.isEmpty) Padding(padding: const EdgeInsets.all(18), child: Center(child: Mut(l3('No results', 'Aucun résultat', 'لا توجد نتائج'), size: 14))),
                if (widget.addPlace)
                  InkWell(
                    borderRadius: BorderRadius.circular(14),
                    onTap: () => Navigator.pop(context, kAddPlaceKey),
                    child: Container(
                      constraints: const BoxConstraints(minHeight: 52),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      child: Text('＋ ${T('Add new center or daycare')}', style: TextStyle(fontSize: 15, color: p.sec, fontWeight: FontWeight.w700)),
                    ),
                  ),
              ],
            ),
          ),
        ]),
      ),
    );
  }
}

class _Grab extends StatelessWidget {
  const _Grab();
  @override
  Widget build(BuildContext context) => SizedBox(height: 28, child: Center(child: Container(width: 42, height: 4, decoration: BoxDecoration(color: pal(context).line, borderRadius: BorderRadius.circular(4)))));
}

/// Inline "add new center or daycare" dialog. Returns the place name added (or existing).
Future<String?> addPlaceDialog(BuildContext context) async {
  final ctl = TextEditingController();
  String type = 'center';
  final r = await showDialog<String>(
    context: context,
    builder: (c) => StatefulBuilder(builder: (c, setS) {
      return AlertDialog(
        title: Text(T('Add new center or daycare')),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(controller: ctl, autofocus: true, decoration: inputDeco(c, hint: T('Name of the center or daycare'))),
          const SizedBox(height: 10),
          Seg([SegItem('center', T('Center')), SegItem('daycare', T('Daycare'))], type, (v) => setS(() => type = v)),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c), child: Text(T('Cancel'))),
          TextButton(
            onPressed: () {
              final n = ctl.text.trim();
              if (n.isEmpty) {
                toast('Enter the name of the center or daycare');
                return;
              }
              Navigator.pop(c, '$type|$n');
            },
            child: Text(T('Add place')),
          ),
        ],
      );
    }),
  );
  if (r == null) return null;
  final i = r.indexOf('|');
  final t = r.substring(0, i), n = r.substring(i + 1);
  final ex = app.places.where((x) => str(x['n']).toLowerCase() == n.toLowerCase()).toList();
  if (ex.isEmpty) {
    app.places.add(<String, dynamic>{'n': n, 't': t, 'my': t == 'daycare' ? 60 : 50, 'fee': 0, 'mode': 'pct', 'mine': 0});
    app.migrate();
    app.save();
    toast('Place added');
    return n;
  }
  return str(ex.first['n']);
}

// ------------------------------------------------------- sheets & dialogs
Future<T?> showSheet<T>(Widget Function(BuildContext) builder) {
  final ctx = navigatorKey.currentContext!;
  return showModalBottomSheet<T>(
    context: ctx,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    constraints: const BoxConstraints(maxWidth: 520),
    builder: (c) => SheetFrame(child: builder(c)),
  );
}

class SheetFrame extends StatelessWidget {
  final Widget child;
  const SheetFrame({super.key, required this.child});
  @override
  Widget build(BuildContext context) {
    final p = pal(context);
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        decoration: BoxDecoration(color: p.page, borderRadius: const BorderRadius.vertical(top: Radius.circular(26))),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const _Grab(),
          Flexible(child: SingleChildScrollView(padding: const EdgeInsets.fromLTRB(16, 0, 16, 20), keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.manual, child: child)),
        ]),
      ),
    );
  }
}

void cs(BuildContext c) {
  if (Navigator.of(c).canPop()) Navigator.of(c).pop();
}

Future<bool> confirmDialog(String msg) async {
  final ctx = navigatorKey.currentContext;
  if (ctx == null) return false;
  final r = await showDialog<bool>(
    context: ctx,
    builder: (c) => AlertDialog(
      content: Text(msg),
      actions: [
        TextButton(onPressed: () => Navigator.pop(c, false), child: Text(l3('Cancel', 'Annuler', 'إلغاء'))),
        TextButton(onPressed: () => Navigator.pop(c, true), child: const Text('OK')),
      ],
    ),
  );
  return r == true;
}

/// Two-field row (`flex-wrap:nowrap`).
Widget twoCol(Widget a, Widget b, {int fa = 1, int fb = 1}) => Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Expanded(flex: fa, child: a),
      const SizedBox(width: 8),
      Expanded(flex: fb, child: b),
    ]);

/// Sheet title.
Widget sheetTitle(String t) => Padding(padding: const EdgeInsets.fromLTRB(0, 4, 0, 8), child: Text(t, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)));

/// Checkbox row with 48dp height.
class CheckRow extends StatelessWidget {
  final bool value;
  final String text;
  final ValueChanged<bool> onChanged;
  const CheckRow(this.value, this.text, this.onChanged, {super.key});
  @override
  Widget build(BuildContext context) => InkWell(
        onTap: () => onChanged(!value),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 48),
          child: Row(children: [
            SizedBox(width: 32, child: Checkbox(value: value, onChanged: (v) => onChanged(v ?? false), activeColor: pal(context).sec, visualDensity: VisualDensity.compact)),
            const SizedBox(width: 6),
            Expanded(child: Text(text, style: const TextStyle(fontSize: 14))),
          ]),
        ),
      );
}

/// Mini spinner used on buttons while working.
class Spin extends StatelessWidget {
  const Spin({super.key});
  @override
  Widget build(BuildContext context) => const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white));
}

Widget typingDots(BuildContext c) {
  final p = pal(c);
  return TweenAnimationBuilder<double>(
    tween: Tween(begin: 0, end: 1),
    duration: const Duration(milliseconds: 1000),
    builder: (context, t, _) => Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(3, (i) => Container(margin: const EdgeInsets.symmetric(horizontal: 2), width: 7, height: 7, decoration: BoxDecoration(color: p.mut, shape: BoxShape.circle))),
    ),
  );
}

/// Standard scrolling page body (extra bottom padding so the FAB / AI button never cover the last control).
Widget screenList(List<Widget> children, {EdgeInsets? padding}) => ListView(
      padding: padding ?? const EdgeInsets.fromLTRB(12, 12, 12, 150),
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      children: children,
    );
