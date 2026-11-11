import 'package:flutter/material.dart';
import '../core/globals.dart';
import '../core/i18n.dart';
import '../core/theme.dart';
import '../core/util.dart';
import '../state/app_state.dart';
import '../state/logic.dart';
import 'widgets.dart';

/// Number field that commits on blur / submit (the web app used `onchange`).
class CommitField extends StatefulWidget {
  final String label;
  final String value;
  final ValueChanged<String> onCommit;
  const CommitField({super.key, required this.label, required this.value, required this.onCommit});
  @override
  State<CommitField> createState() => _CommitFieldState();
}

class _CommitFieldState extends State<CommitField> {
  late final TextEditingController c = TextEditingController(text: widget.value);
  final FocusNode fn = FocusNode();
  late String last = widget.value;
  @override
  void initState() {
    super.initState();
    fn.addListener(() {
      if (!fn.hasFocus) commit();
    });
  }

  void commit() {
    if (c.text != last) {
      last = c.text;
      widget.onCommit(c.text);
    }
  }

  @override
  void dispose() {
    fn.dispose();
    c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => LField(c, label: widget.label, focus: fn, keyboard: const TextInputType.numberWithOptions(decimal: true), onSubmitted: (_) => commit());
}

String _fn(num d) => d == d.roundToDouble() ? '${d.round()}' : '$d';

class FinanceScreen extends StatelessWidget {
  const FinanceScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final R = app.fdata();
    double sum(String k) => R.fold(0.0, (a, x) => a + nv(x[k]));
    final fp = app.v.fp;
    final lb = {'week': 'This week', 'month': 'This month', 'year': 'This year', 'all': 'All time'}[fp] ?? 'This month';
    final bP = <String, Map<String, dynamic>>{};
    final bC = <String, Map<String, dynamic>>{};
    for (final x in R) {
      final o = bP.putIfAbsent(str(x['pl']), () => <String, dynamic>{'n': x['pl'], 'c': 0, 'price': 0.0, 'mine': 0.0, 'owner': 0.0});
      o['c'] = (o['c'] as int) + 1;
      o['price'] = (o['price'] as double) + nv(x['price']);
      o['mine'] = (o['mine'] as double) + nv(x['mine']);
      o['owner'] = (o['owner'] as double) + nv(x['owner']);
      if (truthy(x['pid'])) {
        final q = bC.putIfAbsent(str(x['pid']), () => <String, dynamic>{'pid': x['pid'], 'c': 0, 'mine': 0.0});
        q['c'] = (q['c'] as int) + 1;
        q['mine'] = (q['mine'] as double) + nv(x['mine']);
      }
    }
    final pl = bP.values.toList()..sort((a, b) => (b['mine'] as double).compareTo(a['mine'] as double));
    final pc = bC.values.toList()..sort((a, b) => (b['mine'] as double).compareTo(a['mine'] as double));
    final m = pal(context).mut;
    // calculation basis
    final a = app.frng()[0], b = app.frng()[1];
    final rows = <String, List<int>>{};
    for (final x in app.apts.where((x) => x['status'] == 'done' && str(x['date']).compareTo(a) >= 0 && str(x['date']).compareTo(b) <= 0)) {
      final r = rows.putIfAbsent(truthy(x['place']) ? str(x['place']) : '—', () => [0, 0]);
      if (x['fin'] != null) {
        r[0]++;
      } else {
        r[1]++;
      }
    }
    final legacyAll = app.apts.where((x) => x['status'] == 'done' && x['fin'] == null).length;

    return screenList([
      Seg([SegItem('week', T('Week')), SegItem('month', T('Month')), SegItem('year', T('Year')), SegItem('all', T('All time'))], fp, (v) {
        app.v.fp = v;
        app.go();
      }),
      TileGrid([
        Tile('tg', 'check', T('My earnings'), app.money(sum('mine')), T(lb), medium: true),
        Tile('tb', 'doc', T('Billed'), app.money(sum('price')), T(lb), medium: true),
        Tile('to', 'users', T('Owner’s share'), app.money(sum('owner')), T(lb), medium: true),
        Tile('tp', 'cal', T('Counted sessions'), '${R.length}', T(lb)),
      ]),
      Padding(padding: const EdgeInsets.fromLTRB(2, 0, 2, 8), child: Mut(T('Only done sessions and paid consultations are counted.'))),
      H2(T('By place')),
      if (pl.isEmpty) emptyCard(T('Nothing counted yet.')),
      for (var i = 0; i < pl.length; i++)
        secCard(
          kCol[i % 6],
          Builder(builder: (context) {
            final x = pl[i];
            final w = (x['price'] as double) > 0 ? (x['mine'] as double) / (x['price'] as double) * 100 : 0.0;
            final c = x['c'] as int;
            return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [Expanded(child: Text(str(x['n']), style: const TextStyle(fontWeight: FontWeight.bold))), Mut('$c ${T(c == 1 ? 'session' : 'sessions')}')]),
              const SizedBox(height: 6),
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: SizedBox(
                  height: 8,
                  child: Row(children: [
                    Expanded(flex: (w * 10).round().clamp(0, 1000), child: Container(color: hex('#2fb872'))),
                    Expanded(flex: ((100 - w) * 10).round().clamp(0, 1000), child: Container(color: hex('#f29a2e'))),
                  ]),
                ),
              ),
              const SizedBox(height: 6),
              Text.rich(TextSpan(style: TextStyle(color: m, fontSize: 13), children: [
                TextSpan(text: '${T('My earnings')} '),
                TextSpan(text: app.money(x['mine'] as double), style: const TextStyle(fontWeight: FontWeight.bold)),
                TextSpan(text: ' · ${T('Owner’s share')} '),
                TextSpan(text: app.money(x['owner'] as double), style: const TextStyle(fontWeight: FontWeight.bold)),
                TextSpan(text: ' · ${T('Billed')} ${app.money(x['price'] as double)}'),
              ])),
            ]);
          }),
        ),
      H2(T('By patient')),
      if (pc.isEmpty) emptyCard(T('Nothing counted yet.')),
      ...pc.map((x) => AppCard(
            child: Row(children: [
              Expanded(child: Row(children: [Flexible(child: Text(app.full(app.P(x['pid'])))), const SizedBox(width: 6), ChipW('${x['c']}')])),
              Text(app.money(x['mine'] as double), style: const TextStyle(fontWeight: FontWeight.bold)),
            ]),
          )),
      // calculation basis
      H2(l3('Calculation basis', 'Base de calcul', 'أساس الحساب')),
      AppCard(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          if (rows.isEmpty) Mut(l3('Nothing counted in this period.', 'Rien de compté sur cette période.', 'لا شيء محتسب في هذه الفترة.')),
          ...rows.entries.map((e) {
            final w = app.wpByName(e.key) ?? <String, dynamic>{};
            final t = w['mode'] == 'fix'
                ? '${l3('fixed ', 'fixe ', 'ثابت ')}${app.money(nv(w['mine']))} / ${l3('session', 'séance', 'حصة')}'
                : '${w['my'] == null ? 100 : _fn(nv(w['my']))}% ${l3('clinician', 'praticien', 'الأخصائية')} / ${100 - (w['my'] == null ? 100 : nv(w['my']).round())}% ${l3('institution', 'établissement', 'المؤسسة')}';
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(e.key, style: const TextStyle(fontWeight: FontWeight.bold)),
                Mut('${l3('Current terms: ', 'Conditions actuelles : ', 'الشروط الحالية: ')}$t'),
                Mut('${e.value[0]} ${l3('session(s) use their saved terms', 'séance(s) avec conditions enregistrées', 'حصة بشروطها المحفوظة')}${e.value[1] > 0 ? ' · ${e.value[1]} ${l3('older session(s) follow the current terms', 'ancienne(s) séance(s) suivent les conditions actuelles', 'حصة أقدم تتبع الشروط الحالية')}' : ''}'),
              ]),
            );
          }),
          Mut(l3('Only completed sessions are counted. Planned, missed, cancelled and rescheduled ones never are.', 'Seules les séances réalisées sont comptées. Les séances prévues, manquées, annulées ou reprogrammées ne le sont jamais.', 'تُحتسب الحصص المنجزة فقط. الحصص المجدولة أو الغائبة أو الملغاة أو المعاد جدولتها لا تُحتسب.')),
          if (legacyAll > 0)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Btn(l3('Freeze current terms on $legacyAll older session(s)', 'Figer les conditions sur $legacyAll ancienne(s) séance(s)', 'تثبيت الشروط على $legacyAll حصة أقدم'), () async {
                if (await confirmDialog(l3('Freeze the current terms on older sessions so future rate changes do not affect them?', 'Figer les conditions actuelles sur les anciennes séances pour que les futurs changements de tarif ne les affectent pas ?', 'تثبيت الشروط الحالية على الحصص الأقدم حتى لا تتأثر بتغيير الأسعار مستقبلاً؟'))) app.freezeAll();
              }, kind: BK.ghost, small: true),
            ),
        ]),
      ),
      H2(T('Places and percentages')),
      for (var i = 0; i < app.places.length; i++) _PlaceCard(i, key: ValueKey('pc_${app.places[i]['id']}_${app.places[i]['mode']}')),
      const _AddPlaceCard(),
      CommitField(label: T('Currency'), value: app.cur, onCommit: (v) {
        app.me['cur'] = v.trim().isEmpty ? 'DA' : v.trim();
        app.save();
        app.go();
      }),
    ]);
  }
}

class _PlaceCard extends StatelessWidget {
  final int i;
  const _PlaceCard(this.i, {super.key});
  @override
  Widget build(BuildContext context) {
    final x = app.places[i];
    final fx = x['mode'] == 'fix';
    final fee = nv(x['fee']), mine = nv(x['mine']), my = x['my'] == null ? 100.0 : nv(x['my']);
    return secCard(
      kCol[i % 6],
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(child: Row(children: [Flexible(child: Text(str(x['n']), style: const TextStyle(fontWeight: FontWeight.bold))), const SizedBox(width: 6), ChipW(T(kTy[x['t']] ?? 'Center'))])),
          DangerBtn(T('Remove'), () => app.rmPl(i), iconOnly: true),
        ]),
        Seg([SegItem('pct', T('Percentage')), SegItem('fix', T('Fixed amount'))], fx ? 'fix' : 'pct', (v) => app.setPl(i, 'mode', v)),
        twoCol(
          CommitField(label: fx ? T('My fixed amount per session') : T('My % of the price'), value: _fn(fx ? mine : my), onCommit: (v) => app.setPl(i, fx ? 'mine' : 'my', v)),
          CommitField(label: T('Price per session'), value: _fn(fee), onCommit: (v) => app.setPl(i, 'fee', v)),
        ),
        Mut(fx ? '${T('My share')} ${app.money(fee < mine ? fee : mine)} · ${T('Owner')} ${app.money((fee - mine) < 0 ? 0 : fee - mine)}' : '${T('My share')} ${_fn(my)}% · ${T('Owner')} ${100 - my.round()}%'),
      ]),
    );
  }
}

class _AddPlaceCard extends StatefulWidget {
  const _AddPlaceCard();
  @override
  State<_AddPlaceCard> createState() => _AddPlaceCardState();
}

class _AddPlaceCardState extends State<_AddPlaceCard> {
  final n = TextEditingController(), my = TextEditingController(text: '50'), fee = TextEditingController(text: '0');
  String t = 'center';
  @override
  void dispose() {
    n.dispose();
    my.dispose();
    fee.dispose();
    super.dispose();
  }

  void add() {
    final name = n.text.trim();
    if (name.isEmpty) return toast('Enter the name of the center or daycare');
    app.addPl(name, t, nv(my.text), nv(fee.text));
    if (app.places.any((x) => str(x['n']).toLowerCase() == name.toLowerCase())) {
      n.clear();
    }
  }

  @override
  Widget build(BuildContext context) {
    return secCard(
      hex('#2fb872'),
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        H3(T('Add a center or daycare')),
        const SizedBox(height: 6),
        LField(n, hint: T('Name of the center or daycare'), onSubmitted: (_) => add(), action: TextInputAction.done),
        Seg([SegItem('center', T('Center')), SegItem('daycare', T('Daycare'))], t, (v) => setState(() {
              t = v;
              my.text = v == 'daycare' ? '60' : '50';
            })),
        twoCol(LField(my, label: T('My % of the price'), keyboard: TextInputType.number), LField(fee, label: T('Price per session'), keyboard: TextInputType.number)),
        Btn(T('Add place'), add, small: true),
      ]),
    );
  }
}
