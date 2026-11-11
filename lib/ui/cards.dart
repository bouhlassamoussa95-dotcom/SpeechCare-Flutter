import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../core/i18n.dart';
import '../core/theme.dart';
import '../core/util.dart';
import '../state/app_state.dart';
import '../state/logic.dart';
import 'forms_appt.dart';
import 'forms_misc.dart';
import 'widgets.dart';

const Map<String, List<String>> kCT = {
  'new': ['New patient (first visit)', '#2f8cf0'],
  'parent': ['Parent meeting', '#7c55d6'],
  'other': ['Other', '#f29a2e'],
};

String cname(J c) => c['type'] == 'parent' ? app.rn(app.P(c['pid'])) : '${str(c['name'])} ${str(c['pre'])}'.trim();

Future<void> callPhone(String phone) async {
  try {
    await launchUrl(Uri(scheme: 'tel', path: phone));
  } catch (_) {}
}

/// Status change: "done" opens the structured completion form (setSt wrapper in the web app).
void aptStatus(String id, String s) {
  if (s == 'done') {
    openDone(id);
  } else {
    app.setSt(id, s);
  }
}

Widget phoneChip(String phone) => Builder(
      builder: (c) => ChipW(phone, icon: ic('phone', size: 13), onTap: () => callPhone(phone)),
    );

/// `.tbx` time box.
class TimeBox extends StatelessWidget {
  final String time;
  const TimeBox(this.time, {super.key});
  @override
  Widget build(BuildContext context) => Container(
        constraints: const BoxConstraints(minWidth: 52),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
        decoration: BoxDecoration(color: pal(context).sec, borderRadius: BorderRadius.circular(14)),
        child: Text(time, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
      );
}

/// sc(a, hideName)
class SessionCard extends StatelessWidget {
  final J a;
  final bool hideName;
  const SessionCard(this.a, {super.key, this.hideName = false});

  @override
  Widget build(BuildContext context) {
    final p = app.P(a['pid']);
    final pj = p ?? <String, dynamic>{};
    final g = truthy(a['grp']) ? app.apts.where((x) => x['grp'] == a['grp']).length : 0;
    final st = str(a['status']);
    final mut = pal(context).mut;
    return AppCard(
      endBar: kScl[st],
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        InkWell(
          onTap: () {
            haptic();
            if (hideName) {
              apForm(id: str(a['id']));
            } else if (p != null) {
              app.openPt(str(p['id']));
            }
          },
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            TimeBox(str(a['time'])),
            const SizedBox(width: 10),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Expanded(child: Text(app.full(p), style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold))),
                  TagW(st),
                  const SizedBox(width: 4),
                  Icon(Icons.chevron_right, size: 18, color: mut),
                ]),
                if (!hideName) Mut(T(kTy[pj['pt']] ?? '')),
                chips([
                  if (truthy(pj['phone'])) phoneChip(str(pj['phone'])),
                  ChipW(str(a['place']), icon: ic('pin', size: 13)),
                  ChipW(str(a['date']), icon: ic('cal', size: 13)),
                  if (g > 1) ChipW('${T('Group')} · $g', icon: ic('users', size: 13), bg: alpha(hex('#7c55d6'), .2)),
                ]),
              ]),
            ),
          ]),
        ),
        GoalBox(child: Text.rich(TextSpan(children: [TextSpan(text: '${T('Goal:')} ', style: const TextStyle(fontWeight: FontWeight.bold)), TextSpan(text: app.goalText(a, p))]))),
        if (truthy(a['remark'])) Padding(padding: const EdgeInsets.only(top: 6), child: Mut('${T('Remark:')} ${a['remark']}')),
        const SizedBox(height: 8),
        Wrap(spacing: 6, runSpacing: 6, children: [
          if (p != null) Btn(T('Details'), () => app.openPt(str(p['id'])), kind: BK.outline, small: true),
          if (st == 'scheduled' && str(a['date']).compareTo(td()) <= 0) ...[
            Btn(T('Done'), () => aptStatus(str(a['id']), 'done'), kind: BK.teal, small: true),
            Btn(T('Absent'), () => aptStatus(str(a['id']), 'absent'), kind: BK.red, small: true),
          ],
          Btn(T('Edit'), () => apForm(id: str(a['id'])), kind: BK.ghost, small: true),
        ]),
      ]),
    );
  }
}

List<Widget> sessionCards(Iterable<J> l, {bool hideName = false}) => l.map((a) => SessionCard(a, key: ValueKey('sc_${a['id']}'), hideName: hideName)).toList();

/// cc(c)
class ConsCard extends StatelessWidget {
  final J c;
  const ConsCard(this.c, {super.key});
  @override
  Widget build(BuildContext context) {
    final ct = kCT[c['type']] ?? kCT['other']!;
    final st = str(c['status']);
    final nm = cname(c);
    return AppCard(
      startBar: hex(ct[1]),
      endBar: kScl[st],
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        InkWell(
          onTap: () => coForm(id: str(c['id'])),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            TimeBox(str(c['time'])),
            const SizedBox(width: 10),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Expanded(child: Text(nm.isEmpty ? '—' : nm, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold))),
                  TagW(st),
                  const SizedBox(width: 4),
                  Icon(Icons.chevron_right, size: 18, color: pal(context).mut),
                ]),
                Mut('${T('Consultation')} · ${T(ct[0])}'),
                chips([
                  if (truthy(c['phone'])) phoneChip(str(c['phone'])),
                  ChipW(str(c['place']), icon: ic('pin', size: 13)),
                  ChipW(str(c['date']), icon: ic('cal', size: 13)),
                ]),
              ]),
            ),
          ]),
        ),
        if (truthy(c['reason'])) GoalBox(child: Text(str(c['reason']))),
      ]),
    );
  }
}

// ----------------------------------------------------------------- strip
String monthYear(String ds) => fmtLoc(app.lang, ds, 'MMMM y');

/// strip(): two weeks, Monday first, starting with the week of the selected day.
class DayStrip extends StatelessWidget {
  const DayStrip({super.key});

  void pick(String ds) {
    app.v.day = ds;
    app.v.mon = ds.substring(0, 7);
    app.go();
  }

  void sw(int n) {
    app.v.day = addD(app.v.day, 7 * n);
    app.v.mon = app.v.day.substring(0, 7);
    app.go();
  }

  @override
  Widget build(BuildContext context) {
    final p = pal(context);
    final ws = addD(app.v.day, -monOffset(parseD(app.v.day)));
    final cells = <Widget>[];
    for (var i = 0; i < 14; i++) {
      final ds = addD(ws, i);
      final k = app.apts.where((a) => a['date'] == ds && a['status'] != 'cancelled').length + app.cons.where((c) => c['date'] == ds && c['status'] != 'cancelled').length;
      final sel = ds == app.v.day, tod = ds == td(), we = i % 7 > 4;
      cells.add(Padding(
        padding: EdgeInsets.only(top: i == 7 ? 8 : 0),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text(fmtLoc(app.lang, ds, 'E'), style: TextStyle(fontSize: 10.5, color: p.mut)),
          const SizedBox(height: 3),
          GestureDetector(
            onTap: () {
              haptic();
              pick(ds);
            },
            behavior: HitTestBehavior.opaque,
            child: Container(
              width: 42,
              height: 46,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: sel ? p.sec : Colors.transparent,
                borderRadius: BorderRadius.circular(14),
                border: tod && !sel ? Border.all(color: p.sec, width: 2) : null,
              ),
              child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                Text('${int.parse(ds.substring(8))}', style: TextStyle(fontSize: 15, fontWeight: sel || tod ? FontWeight.bold : FontWeight.w500, color: sel ? Colors.white : (we ? alpha(Pal.red, .85) : p.ink))),
                if (k > 0)
                  sel
                      ? Text('$k', style: const TextStyle(fontSize: 9, color: Colors.white))
                      : Container(width: 5, height: 5, margin: const EdgeInsets.only(top: 2), decoration: BoxDecoration(color: p.sec, shape: BoxShape.circle)),
              ]),
            ),
          ),
        ]),
      ));
    }
    final rows = <Widget>[];
    for (var r = 0; r < 2; r++) {
      rows.add(Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: cells.sublist(r * 7, r * 7 + 7)));
    }
    return AppCard(
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 10),
      child: Column(children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          IconBtn(Icon(Icons.arrow_back, size: 18, color: p.ink), () => sw(-1), tooltip: 'Previous'),
          Text(monthYear(app.v.day), style: const TextStyle(fontWeight: FontWeight.bold)),
          IconBtn(Icon(Icons.arrow_forward, size: 18, color: p.ink), () => sw(1), tooltip: 'Next'),
        ]),
        ...rows,
      ]),
    );
  }
}

/// dsum(n)
class DaySummary extends StatelessWidget {
  final int n;
  const DaySummary(this.n, {super.key});
  @override
  Widget build(BuildContext context) {
    return AppCard(
      onTap: () => app.nav('cal', d: 1),
      child: Row(children: [
        ic('cal', size: 20, color: pal(context).sec),
        const SizedBox(width: 10),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(fmtLoc(app.lang, app.v.day, 'EEEE d MMMM y'), style: const TextStyle(fontWeight: FontWeight.bold)),
            Mut('$n ${T(n == 1 ? 'appointment' : 'appointments')}'),
          ]),
        ),
        ChipW('$n'),
        const SizedBox(width: 4),
        Icon(Icons.chevron_right, size: 16, color: pal(context).mut),
      ]),
    );
  }
}

/// Search box (`.srch`). Keeps its own controller so typing is never interrupted by rebuilds.
class SearchBox extends StatefulWidget {
  final String hint;
  final String value;
  final ValueChanged<String> onChanged;
  const SearchBox(this.hint, this.value, this.onChanged, {super.key});
  @override
  State<SearchBox> createState() => _SearchBoxState();
}

class _SearchBoxState extends State<SearchBox> {
  late final TextEditingController c = TextEditingController(text: widget.value);
  @override
  void dispose() {
    c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = pal(context);
    return TextField(
      controller: c,
      onChanged: widget.onChanged,
      style: const TextStyle(fontSize: 16),
      decoration: inputDeco(context, hint: widget.hint).copyWith(prefixIcon: Icon(Icons.search, size: 20, color: p.mut)),
    );
  }
}
