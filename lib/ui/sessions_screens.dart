import 'package:flutter/material.dart';
import '../core/i18n.dart';
import '../core/theme.dart';
import '../core/util.dart';
import '../state/app_state.dart';
import '../state/logic.dart';
import 'cards.dart';
import 'forms_appt.dart';
import 'widgets.dart';

/// wfBar(): workplace filter pills (shared by Sessions and Patients).
class WfBar extends StatelessWidget {
  const WfBar({super.key});
  @override
  Widget build(BuildContext context) {
    if (app.places.isEmpty) return const SizedBox.shrink();
    final f = app.v.wf;
    Widget pill(String v, String l) => PillBtn(l, f == v, () {
          app.v.wf = v;
          app.go();
        });
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: PillRow([
        pill('all', l3('All workplaces', 'Tous les lieux', 'كل أماكن العمل')),
        ...app.places.map((w) => pill(str(w['id']), str(w['n']))),
        if (app.pats.any((p) => !truthy(p['wpId']))) pill('none', l3('No workplace', 'Sans lieu', 'بدون مكان')),
      ]),
    );
  }
}

/// Two-column grid of patient tiles (`.pgrid`).
class PatientGrid extends StatelessWidget {
  final List<Widget> tiles;
  const PatientGrid(this.tiles, {super.key});
  @override
  Widget build(BuildContext context) {
    final rows = <Widget>[];
    for (var i = 0; i < tiles.length; i += 2) {
      rows.add(Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: IntrinsicHeight(
          child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Expanded(child: tiles[i]),
            const SizedBox(width: 10),
            Expanded(child: i + 1 < tiles.length ? tiles[i + 1] : const SizedBox()),
          ]),
        ),
      ));
    }
    return Column(children: rows);
  }
}

/// `.pcard`
class PCard extends StatelessWidget {
  final J p;
  final Widget sub;
  const PCard(this.p, this.sub, {super.key});
  @override
  Widget build(BuildContext context) {
    final pl = pal(context);
    return Material(
      color: pl.card,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18), side: BorderSide(color: pl.line)),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () {
          haptic();
          app.openPt(str(p['id']));
        },
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Row(children: [
              Avatar(app.ini(p), size: 42),
              const Spacer(),
              Icon(Icons.chevron_right, size: 16, color: pl.mut),
            ]),
            const SizedBox(height: 8),
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: Text('${str(p['name'])}${truthy(p['pre']) ? '\n${p['pre']}' : ''}', maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, height: 1.25)),
            ),
            const SizedBox(height: 4),
            Align(alignment: AlignmentDirectional.centerStart, child: sub),
          ]),
        ),
      ),
    );
  }
}

class SessionsScreen extends StatelessWidget {
  const SessionsScreen({super.key});

  List<Widget> _appts(BuildContext context) {
    final q = app.v.sq.toLowerCase(), f = app.v.wf;
    final L = app.apts.where((a) {
      return (app.v.f == 'all' || a['status'] == app.v.f) &&
          (!app.v.sd || a['date'] == app.v.day) &&
          app.rn(app.P(a['pid'])).toLowerCase().contains(q) &&
          (f == 'all' || (f == 'none' ? !truthy(a['placeId']) : a['placeId'] == f));
    }).toList()
      ..sort((x, y) => ('${y['date']}${y['time']}').compareTo('${x['date']}${x['time']}'));
    return [
      const DayStrip(),
      Seg([SegItem('0', T('All days')), SegItem('1', T('Selected day'))], app.v.sd ? '1' : '0', (v) {
        app.v.sd = v == '1';
        app.go();
      }),
      SearchBox(T('Search a patient'), app.v.sq, (s) {
        app.v.sq = s;
        app.go();
      }),
      const WfBar(),
      Padding(
        padding: const EdgeInsets.only(top: 8),
        child: PillRow([
          for (final x in const [['all', 'All'], ['scheduled', 'Planned'], ['done', 'Done'], ['absent', 'Absent'], ['cancelled', 'Cancelled'], ['rescheduled', 'Rescheduled']])
            PillBtn(T(x[1]), app.v.f == x[0], () {
              app.v.f = x[0];
              app.go();
            }),
        ]),
      ),
      const SizedBox(height: 10),
      if (L.isEmpty) emptyCard(l3('No sessions match.', 'Aucune séance.', 'لا توجد حصص مطابقة.')),
      ...sessionCards(L),
    ];
  }

  List<Widget> _patients(BuildContext context) {
    final q = app.v.sq.toLowerCase(), f = app.v.wf;
    final L = app.pats.where((p) => app.rn(p).toLowerCase().contains(q) && app.inWp(p, f)).toList();
    return [
      SearchBox(l3('Search a patient', 'Rechercher un patient', 'ابحثي عن مريض'), app.v.sq, (s) {
        app.v.sq = s;
        app.go();
      }),
      const WfBar(),
      const SizedBox(height: 10),
      if (L.isEmpty)
        emptyCard(l3('No patients in this workplace.', 'Aucun patient dans ce lieu.', 'لا يوجد مرضى في هذا المكان.'))
      else
        PatientGrid(L.map((p) {
          final up = app.upcoming(str(p['id']));
          final a = up.isEmpty ? null : up.first;
          final w = a == null ? null : (app.wpById(a['placeId']) ?? app.wpByName(str(a['place'])));
          Widget sub;
          if (a == null) {
            sub = Mut(l3('No appointment', 'Aucun rendez-vous', 'لا يوجد موعد'), size: 12);
          } else {
            sub = Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text.rich(TextSpan(style: const TextStyle(fontSize: 12), children: [
                if (a['date'] == td()) TextSpan(text: '${l3('Today', 'Aujourd’hui', 'اليوم')} ', style: const TextStyle(fontWeight: FontWeight.bold)) else TextSpan(text: '${app.fmtD(str(a['date']))} '),
                TextSpan(text: str(a['time'])),
              ])),
              if (w != null && truthy(w['n'])) Mut(str(w['n']), size: 12),
            ]);
          }
          return PCard(p, sub);
        }).toList()),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final m = app.v.sm == 'pats' ? 'pats' : 'appts';
    return screenList([
      Seg([SegItem('appts', l3('Appointments', 'Rendez-vous', 'المواعيد')), SegItem('pats', l3('Patients', 'Patients', 'المرضى'))], m, (v) {
        app.v.sm = v;
        app.go();
      }),
      ...(m == 'pats' ? _patients(context) : _appts(context)),
    ]);
  }
}

class CalendarScreen extends StatelessWidget {
  const CalendarScreen({super.key});

  void sh(int n) {
    if (app.v.cm) {
      final p = app.v.mon.split('-');
      final y = int.parse(p[0]), m = int.parse(p[1]);
      final d = DateTime(y, m + n, 15);
      app.v.mon = fmtDate(d).substring(0, 7);
      app.v.day = '${app.v.mon}-01';
    } else {
      app.v.day = addD(app.v.day, 7 * n);
      app.v.mon = app.v.day.substring(0, 7);
    }
    app.go();
  }

  @override
  Widget build(BuildContext context) {
    final p = pal(context);
    final d0 = parseD(app.v.day);
    final ws = addD(app.v.day, -monOffset(d0));
    Widget cell(String ds) {
      final k = app.apts.where((a) => a['date'] == ds).length;
      final sel = ds == app.v.day, tod = ds == td();
      return GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          haptic();
          app.v.day = ds;
          app.v.mon = ds.substring(0, 7);
          app.go();
        },
        child: Container(
          height: 50,
          margin: const EdgeInsets.all(2),
          decoration: BoxDecoration(
            color: sel ? p.sec : p.card,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: tod && !sel ? p.sec : p.line, width: tod && !sel ? 2 : 1),
          ),
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Text('${int.parse(ds.substring(8))}', style: TextStyle(fontWeight: FontWeight.w600, color: sel ? Colors.white : p.ink)),
            if (k > 0) Text('●' * (k > 3 ? 3 : k), style: TextStyle(fontSize: 7, color: sel ? Colors.white : p.sec, height: 1)),
          ]),
        ),
      );
    }

    final cells = <Widget>[];
    if (app.v.cm) {
      final pr = app.v.mon.split('-');
      final y = int.parse(pr[0]), m = int.parse(pr[1]);
      final off = monOffset(DateTime(y, m, 1));
      final n = DateTime(y, m + 1, 0).day;
      for (var i = 0; i < off; i++) {
        cells.add(const SizedBox());
      }
      for (var d = 1; d <= n; d++) {
        cells.add(cell('${app.v.mon}-${two(d)}'));
      }
    } else {
      for (var i = 0; i < 7; i++) {
        cells.add(cell(addD(ws, i)));
      }
    }
    while (cells.length % 7 != 0) {
      cells.add(const SizedBox());
    }
    final rows = <Widget>[];
    for (var i = 0; i < cells.length; i += 7) {
      rows.add(Row(children: cells.sublist(i, i + 7).map((c) => Expanded(child: c)).toList()));
    }
    final L = app.dayList();
    return screenList([
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        IconBtn(Icon(Icons.arrow_back, size: 20, color: p.ink), () => sh(-1), tooltip: 'Previous'),
        Text(monthYear(app.v.day), style: const TextStyle(fontWeight: FontWeight.bold)),
        IconBtn(Icon(Icons.arrow_forward, size: 20, color: p.ink), () => sh(1), tooltip: 'Next'),
      ]),
      const SizedBox(height: 6),
      Row(children: 'MTWTFSS'.split('').map((x) => Expanded(child: Center(child: Text(x, style: TextStyle(fontSize: 12, color: p.mut))))).toList()),
      ...rows,
      TextButton(
        onPressed: () {
          app.v.cm = !app.v.cm;
          app.go();
        },
        child: Text(app.v.cm ? T('Show week') : T('Show month'), style: TextStyle(color: p.sec, fontWeight: FontWeight.w600)),
      ),
      AppCard(
        margin: const EdgeInsets.only(top: 6, bottom: 10),
        child: Row(children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(fmtLoc(app.lang, app.v.day, 'EEEE d MMMM'), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
              Mut('${L.length} ${T(L.length == 1 ? 'session' : 'sessions')}'),
            ]),
          ),
          Btn(T('+ Add'), () => apForm(), small: true),
        ]),
      ),
      ...sessionCards(L),
    ]);
  }
}
