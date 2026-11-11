import 'package:flutter/material.dart';
import '../core/i18n.dart';
import '../core/theme.dart';
import '../core/util.dart';
import '../state/app_state.dart';
import '../state/logic.dart';
import 'cards.dart';
import 'widgets.dart';

List<String> homeRange() {
  final t = td();
  final d = parseD(t);
  if (app.v.per == 'day') return [t, t];
  if (app.v.per == 'week') {
    final o = monOffset(d);
    return [addD(t, -o), addD(t, 6 - o)];
  }
  final m = t.substring(0, 7);
  return ['$m-01', '$m-31'];
}

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final r = homeRange();
    final A = app.apts.where((x) => str(x['date']).compareTo(r[0]) >= 0 && str(x['date']).compareTo(r[1]) <= 0).toList();
    int n(String s) => A.where((x) => x['status'] == s).length;
    final t = td();
    final nT = app.apts.where((a) => a['date'] == t && a['status'] != 'cancelled').length;
    final D = app.dayList();
    final CD = app.cons.where((c) => c['date'] == app.v.day && c['status'] != 'cancelled').toList();
    final lb = {'day': 'Today', 'week': 'This week', 'month': 'This month'}[app.v.per]!;
    void toSess(String f) {
      app.v.f = f;
      app.v.sd = false;
      app.nav('sess', d: 1);
    }

    return screenList([
      _Hero(),
      Seg([SegItem('day', T('Day')), SegItem('week', T('Week')), SegItem('month', T('Month'))], app.v.per, (v) {
        app.v.per = v;
        app.go();
      }),
      TileGrid([
        Tile('tb', 'users', T('Patients'), '${app.pats.length}', T('Active profiles'), onTap: () => app.nav('pats', d: 1)),
        Tile('tg', 'cal', T('Sessions'), '${A.length}', T(lb), onTap: () => toSess('all')),
        Tile('to', 'clock', T('Planned'), '${n('scheduled')}', T('Still to come'), onTap: () => toSess('scheduled')),
        Tile('tr', 'x2', T('Absences'), '${n('absent')}', T('Missed sessions'), onTap: () => toSess('absent')),
        Tile('tp', 'check', T('Completed'), '${n('done')}', T(lb), onTap: () => toSess('done')),
        Tile('tt', 'bell', T('Today'), '$nT', T('Open today’s goals'), onTap: () => app.nav('today', d: 1)),
      ]),
      H2(T('Calendar')),
      const DayStrip(),
      DaySummary(D.length + CD.length),
      H2(app.v.day == t ? T('Today’s goals') : T('Appointments')),
      if (D.isEmpty && CD.isEmpty) emptyCard(T('Nothing scheduled this day.')),
      ...sessionCards(D),
      ...CD.map((c) => ConsCard(c, key: ValueKey('cc_${c['id']}'))),
      H2(T('Sessions overview')),
      AppCard(
        child: Row(children: [
          Donut([
            [n('done'), hex('#2fb872')],
            [n('scheduled'), hex('#2f8cf0')],
            [n('absent'), hex('#e24b4b')],
            [n('cancelled'), hex('#9aa5ad')],
          ]),
          const SizedBox(width: 18),
          Expanded(child: _Legend(n('done'), n('scheduled'), n('absent'), n('cancelled'))),
        ]),
      ),
    ]);
  }
}

class _Legend extends StatelessWidget {
  final int d, s, a, c;
  const _Legend(this.d, this.s, this.a, this.c);
  @override
  Widget build(BuildContext context) {
    final m = pal(context).mut;
    Widget row(Color col, String l, int n) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 3),
          child: Row(children: [
            Text('●', style: TextStyle(color: col, fontSize: 13)),
            const SizedBox(width: 6),
            Expanded(child: Text('${T(l)} $n', style: TextStyle(color: m, fontSize: 13))),
          ]),
        );
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      row(hex('#2fb872'), 'Done', d),
      row(hex('#2f8cf0'), 'Planned', s),
      row(hex('#e24b4b'), 'Absent', a),
      row(hex('#9aa5ad'), 'Cancelled', c),
    ]);
  }
}

class _Hero extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: Colors.transparent,
        child: Ink(
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(20), gradient: const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFF0D746E), Color(0xFF214C7E)])),
          child: InkWell(
            borderRadius: BorderRadius.circular(20),
            onTap: () => app.nav('activities', d: 1),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              child: const Directionality(
                textDirection: TextDirection.rtl,
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('مكتبة SpeechCare', style: TextStyle(color: Colors.white70, fontSize: 12)),
                  SizedBox(height: 2),
                  Text('أنشطة علاجية بالعربية والدارجة 🎯', style: TextStyle(color: Colors.white, fontSize: 19, fontWeight: FontWeight.bold)),
                  SizedBox(height: 2),
                  Text('النطق · اللغة · الفهم · التواصل · اللعب — اضغط باش تكتشف الأنشطة', style: TextStyle(color: Colors.white70, fontSize: 12)),
                ]),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class TodayScreen extends StatelessWidget {
  const TodayScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final t = td();
    final L = app.apts.where((x) => x['date'] == t).toList()..sort((x, y) => str(x['time']).compareTo(str(y['time'])));
    final pl = L.where((x) => x['status'] == 'scheduled').toList();
    J? nx;
    for (final x in pl) {
      if (app.mins(x) >= -30) {
        nx = x;
        break;
      }
    }
    nx ??= pl.isEmpty ? null : pl.first;
    int c(String s) => L.where((x) => x['status'] == s).length;
    final m = nx == null ? 0 : (app.mins(nx) < 0 ? 0 : app.mins(nx));
    final p = nx == null ? null : app.P(nx['pid']);
    final room = nx != null
        ? _Room(a: nx, p: p, minutes: m)
        : Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(borderRadius: BorderRadius.circular(22), gradient: const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFF2563EB), Color(0xFF1E40AF)])),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(T('No session waiting'), style: const TextStyle(color: Colors.white, fontSize: 19, fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              Text(T('All of today’s sessions are handled.'), style: const TextStyle(color: Colors.white60)),
            ]),
          );
    return screenList([
      room,
      TileGrid([
        Tile('to', 'clock', T('Waiting'), '${c('scheduled')}', T('Planned')),
        Tile('tg', 'check', T('Completed'), '${c('done')}', T('Done')),
        Tile('tb', 'cal', T('Total'), '${L.length}', T('Today')),
        Tile('tr', 'x2', T('Absent'), '${c('absent')}', T('Missed')),
      ]),
      H2(T('Today’s goals')),
      if (L.isEmpty) emptyCard(T('Nothing scheduled today.')),
      ...sessionCards(L),
    ]);
  }
}

class _Room extends StatelessWidget {
  final J a;
  final J? p;
  final int minutes;
  const _Room({required this.a, required this.p, required this.minutes});
  @override
  Widget build(BuildContext context) {
    Widget box(String v, String l) => Expanded(
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 4),
            padding: const EdgeInsets.symmetric(vertical: 8),
            decoration: BoxDecoration(color: Colors.white.withAlpha(36), borderRadius: BorderRadius.circular(14)),
            child: Column(children: [
              Text(v, style: const TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.bold)),
              Text(T(l), style: const TextStyle(color: Colors.white70, fontSize: 12)),
            ]),
          ),
        );
    const w = TextStyle(color: Colors.white, fontSize: 14);
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(22), gradient: const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFF2563EB), Color(0xFF1E40AF)])),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(T('NEXT SESSION'), style: const TextStyle(color: Colors.white70, fontSize: 12)),
        Text(app.full(p), style: const TextStyle(color: Colors.white, fontSize: 21, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(color: Colors.white.withAlpha(38), borderRadius: BorderRadius.circular(14)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [ic('pin', size: 14, color: Colors.white), const SizedBox(width: 6), Expanded(child: Text('${a['place']} · ${T(kTy[p?['pt']] ?? '')}', style: w))]),
            const SizedBox(height: 4),
            Row(children: [ic('clock', size: 14, color: Colors.white), const SizedBox(width: 6), Text(str(a['time']), style: w)]),
            const SizedBox(height: 6),
            GoalBox(bg: Colors.white.withAlpha(34), bar: Colors.white, child: Text(app.goalText(a, p), style: w)),
          ]),
        ),
        const SizedBox(height: 10),
        Row(children: [box('${minutes ~/ 60}', 'hours'), box('${minutes % 60}', 'min')]),
        const SizedBox(height: 10),
        Material(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () => aptStatus(str(a['id']), 'done'),
            child: Container(constraints: const BoxConstraints(minHeight: 52), alignment: Alignment.center, padding: const EdgeInsets.symmetric(horizontal: 16), child: Text(T('Mark session done'), style: const TextStyle(color: Color(0xFF1E40AF), fontWeight: FontWeight.w700))),
          ),
        ),
      ]),
    );
  }
}
