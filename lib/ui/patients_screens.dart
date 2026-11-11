import 'package:flutter/material.dart';
import '../core/data_gen.dart';
import '../core/i18n.dart';
import '../core/theme.dart';
import '../core/util.dart';
import '../state/ai_service.dart';
import '../state/app_state.dart';
import '../state/logic.dart';
import 'ai_panel.dart';
import 'cards.dart';
import 'forms_appt.dart';
import 'forms_misc.dart';
import 'forms_patient.dart';
import 'sessions_screens.dart';
import 'widgets.dart';

const List<int> kWOrder = [1, 2, 3, 4, 5, 6, 0];

String patSub(J p) {
  final w = app.wpById(p['wpId']) ?? app.wpByName(str(p['place'])) ?? <String, dynamic>{};
  final ex = (p['wpExtra'] is List ? (p['wpExtra'] as List).length : 0);
  final a = truthy(p['birth']) ? app.age(str(p['birth'])) : '';
  final place = truthy(w['n']) ? str(w['n']) : str(p['place']);
  return '$a${a.isNotEmpty && place.isNotEmpty ? ' · ' : ''}$place${ex > 0 ? ' +$ex' : ''}';
}

class PatientsScreen extends StatelessWidget {
  const PatientsScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final q = app.v.pq.toLowerCase(), f = app.v.wf;
    final L = app.pats.where((p) => ('${app.rn(p)}${app.cn(p).join(' ')}${str(p['place'])}').toLowerCase().contains(q) && app.inWp(p, f)).toList();
    return screenList([
      SearchBox(T('Search name, condition or place'), app.v.pq, (s) {
        app.v.pq = s;
        app.go();
      }),
      const WfBar(),
      const SizedBox(height: 10),
      if (L.isEmpty)
        emptyCard(app.pats.isNotEmpty ? l3('No patients in this workplace.', 'Aucun patient dans ce lieu.', 'لا يوجد مرضى في هذا المكان.') : l3('No patients yet. Tap + Patient.', 'Aucun patient. Appuyez sur + Patient.', 'لا يوجد مرضى بعد. اضغطي + مريض.'))
      else
        PatientGrid(L.map((p) => PCard(p, Mut(patSub(p), size: 12))).toList()),
    ]);
  }
}

class PatientScreen extends StatelessWidget {
  const PatientScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final p = app.P(app.v.pid);
    if (p == null) return const PatientsScreen();
    app.syncPatient(p);
    final pid = str(p['id']);
    final pl = pal(context);
    final A = app.apts.where((a) => a['pid'] == pid).toList()..sort((x, y) => ('${y['date']}${y['time']}').compareTo('${x['date']}${x['time']}'));
    return screenList([
      // header
      secCard(
        hex('#7c55d6'),
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Avatar(app.ini(p), size: 54),
            const SizedBox(width: 10),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(app.full(p), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                Mut('${app.age(str(p['birth']))} · ${T('since')} ${truthy(p['start']) ? p['start'] : '—'}'),
              ]),
            ),
            Btn(T('Edit'), () => ptForm(id: pid), kind: BK.ghost, small: true),
          ]),
          chips([
            ChipW('${T(kTy[p['pt']] ?? '')}: ${truthy(p['place']) ? p['place'] : '—'}', icon: ic('pin', size: 13)),
            ...app.cn(p).map((x) => ChipW(shortCond(x))),
          ]),
        ]),
      ),
      _NextCard(p),
      _ProgCard(p),
      // info
      secCard(
        hex('#2f8cf0'),
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _kv('Parents:', str(p['parents']), phone: str(p['phone'])),
          _kv('Symptoms:', str(p['symptoms'])),
          _kv('Diagnostic:', str(p['diag'])),
          _kv('Treatment plan:', str(p['plan'])),
          const SizedBox(height: 4),
          Wrap(spacing: 6, runSpacing: 6, children: [
            Btn(T('Ask AI for a plan'), () => askAI(pid: pid, label: l3r('Treatment plan', 'Plan de traitement', 'خطة علاجية'), prompt: planQ(), target: AiTarget('Treatment plan (skills / activities)', (t) {
                  final q = app.P(pid);
                  if (q == null) return false;
                  q['plan'] = '${truthy(q['plan']) ? '${q['plan']}\n\n' : ''}${plainText(t)}';
                  app.save();
                  app.go();
                  return true;
                })), kind: BK.ghost, small: true, icon: ic('chat', size: 14)),
            Btn(T('Ask AI for activities'), () => askAI(pid: pid, label: l3r('Activities for the next session', 'Activités pour la prochaine séance', 'أنشطة للحصة القادمة'), prompt: actsQ(), target: AiTarget('Treatment plan (skills / activities)', (t) {
                  final q = app.P(pid);
                  if (q == null) return false;
                  q['plan'] = '${truthy(q['plan']) ? '${q['plan']}\n\n' : ''}${plainText(t)}';
                  app.save();
                  app.go();
                  return true;
                })), kind: BK.ghost, small: true, icon: ic('chat', size: 14)),
          ]),
        ]),
      ),
      Row(children: [
        Expanded(child: Btn('+ ${T('Sessions')}', () => apForm(pid: pid))),
        const SizedBox(width: 8),
        Expanded(
          child: Btn(T('Make report'), () {
            app.v.pid = pid;
            app.nav('rep', d: 1);
          }, kind: BK.teal),
        ),
      ]),
      _HistoryBlock(p),
      H2(T('Suggested activities')),
      if (app.condIds(p).isEmpty) emptyCard(T('Pick conditions in the profile to see suggestions.')),
      ...app.condIds(p).map((i) {
        final c = app.condById(i);
        if (c == null) return const SizedBox.shrink();
        final extra = app.act[i] is List ? (app.act[i] as List).map((e) => str(e)).toList() : <String>[];
        final acts = <String>[...(c[3] as List).map((e) => e.toString()), ...extra];
        final col = kCol[(int.tryParse(i) ?? 0) % 6];
        return secCard(
          col,
          Theme(
            data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
            child: ExpansionTile(
              initiallyExpanded: true,
              tilePadding: EdgeInsets.zero,
              childrenPadding: EdgeInsets.zero,
              title: Text(shortCond(c[1] as String), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
              children: [
                Align(alignment: AlignmentDirectional.centerStart, child: Mut('${T('Neuro-geo focus:')} ${c[2]}')),
                const SizedBox(height: 6),
                ...acts.map((x) => Padding(padding: const EdgeInsets.symmetric(vertical: 2), child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [const Text('•  '), Expanded(child: Text(x, style: const TextStyle(fontSize: 14)))]))),
                _AddAct(i),
              ],
            ),
          ),
        );
      }),
      H2(T('Session log')),
      if (A.isEmpty) emptyCard(T('No sessions yet.')),
      ...sessionCards(A, hideName: true),
      Align(alignment: AlignmentDirectional.centerStart, child: DangerBtn(T('Delete patient'), () => app.delPt(pid), small: true)),
    ]);
  }

  Widget _kv(String k, String v, {String phone = ''}) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Builder(
          builder: (c) => Text.rich(TextSpan(children: [
            TextSpan(text: '${T(k)} ', style: const TextStyle(fontWeight: FontWeight.bold)),
            TextSpan(text: v),
            if (phone.isNotEmpty) ...[
              const TextSpan(text: ' · '),
              WidgetSpan(alignment: PlaceholderAlignment.baseline, baseline: TextBaseline.alphabetic, child: GestureDetector(onTap: () => callPhone(phone), child: Text(phone, style: const TextStyle(color: Color(0xFF2F8CF0), decoration: TextDecoration.underline)))),
            ],
          ])),
        ),
      );
}

class _AddAct extends StatefulWidget {
  final String cond;
  const _AddAct(this.cond);
  @override
  State<_AddAct> createState() => _AddActState();
}

class _AddActState extends State<_AddAct> {
  final c = TextEditingController();
  @override
  void dispose() {
    c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 6, bottom: 4),
      child: Row(children: [
        Expanded(child: TextField(controller: c, decoration: inputDeco(context, hint: T('Add your own activity')), style: const TextStyle(fontSize: 15))),
        const SizedBox(width: 8),
        Btn(T('Add'), () {
          final t = c.text.trim();
          if (t.isEmpty) return;
          c.clear();
          app.addAct(widget.cond, t);
        }, small: true),
      ]),
    );
  }
}

class _NextCard extends StatelessWidget {
  final J p;
  const _NextCard(this.p);
  @override
  Widget build(BuildContext context) {
    final pid = str(p['id']);
    final up = app.upcoming(pid);
    final a = up.isEmpty ? null : up.first;
    final lr = app.lastReports(pid);
    final last = lr.isEmpty ? null : lr.first;
    final lf = last == null ? <String, dynamic>{} : (last['f'] is Map ? Map<String, dynamic>.from(last['f'] as Map) : <String, dynamic>{});
    Widget prev = const SizedBox.shrink();
    if (last != null) {
      prev = Padding(
        padding: const EdgeInsets.only(top: 6),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Mut('${l3('Previous session', 'Séance précédente', 'الحصة السابقة')} (${app.fmtD(str(last['date']))})', size: 13),
          if (truthy(lf['prog'])) Mut(str(lf['prog'])),
          if (truthy(lf['rec'])) Text('${l3('Recommendation: ', 'Recommandation : ', 'توصية: ')}${lf['rec']}', style: TextStyle(fontStyle: FontStyle.italic, fontSize: 13, color: pal(context).mut)),
        ]),
      );
    }
    if (a == null) {
      final nd = app.nextDate(p, td());
      return secCard(
        hex('#e8a33d'),
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(l3('Next appointment', 'Prochain rendez-vous', 'الموعد القادم'), style: const TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Mut('${l3('No appointment scheduled.', 'Aucun rendez-vous programmé.', 'لا يوجد موعد مجدول.')}${nd.isNotEmpty ? ' ${l3('Suggested by the program: ', 'Proposé par le programme : ', 'يقترح البرنامج: ')}${app.fmtD(nd)}' : ''}'),
          prev,
          const SizedBox(height: 8),
          Wrap(spacing: 6, runSpacing: 6, children: [
            Btn(l3('Schedule next appointment', 'Programmer le prochain rendez-vous', 'جدولة الموعد القادم'), () => nextForm(pid), small: true),
            Btn(l3('Review program', 'Revoir le programme', 'مراجعة البرنامج'), () => progForm(pid), kind: BK.ghost, small: true),
          ]),
        ]),
      );
    }
    final today = a['date'] == td();
    final w = app.wpById(a['placeId']) ?? app.wpByName(str(a['place'])) ?? <String, dynamic>{};
    Widget line(String label, String v) => Padding(padding: const EdgeInsets.only(top: 6), child: Text.rich(TextSpan(children: [TextSpan(text: '$label: ', style: const TextStyle(fontWeight: FontWeight.bold)), TextSpan(text: v)])));
    return secCard(
      today ? hex('#2fb872') : hex('#e8a33d'),
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(child: Text(today ? l3('Today’s appointment', 'Rendez-vous d’aujourd’hui', 'موعد اليوم') : l3('Next appointment', 'Prochain rendez-vous', 'الموعد القادم'), style: const TextStyle(fontWeight: FontWeight.bold))),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
            decoration: BoxDecoration(color: kTag['scheduled']![0], borderRadius: BorderRadius.circular(20)),
            child: Text('${app.fmtD(str(a['date']))} · ${a['time']}', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: kTag['scheduled']![1])),
          ),
        ]),
        const SizedBox(height: 4),
        Row(children: [ic('pin', size: 13, color: pal(context).mut), const SizedBox(width: 4), Expanded(child: Mut(truthy(w['n']) ? str(w['n']) : (truthy(a['place']) ? str(a['place']) : '—')))]),
        if (truthy(a['goal'])) line(l3('Goals', 'Objectifs', 'الأهداف'), str(a['goal'])),
        if (truthy(a['acts'])) line(l3('Activities', 'Activités', 'الأنشطة'), str(a['acts'])),
        if (truthy(a['materials'])) (today ? line(l3('Materials required', 'Matériel requis', 'الوسائل المطلوبة'), str(a['materials'])) : Padding(padding: const EdgeInsets.only(top: 4), child: Mut(str(a['materials'])))),
        if (today) prev,
        const SizedBox(height: 8),
        Wrap(spacing: 6, runSpacing: 6, children: [
          if (today) Btn(l3('Complete session', 'Terminer la séance', 'إنهاء الحصة'), () => aptStatus(str(a['id']), 'done'), small: true),
          Btn(l3('Reschedule', 'Reprogrammer', 'إعادة جدولة'), () => reschedForm(str(a['id'])), kind: BK.ghost, small: true),
          Btn(l3('Edit', 'Modifier', 'تعديل'), () => apForm(id: str(a['id'])), kind: BK.ghost, small: true),
        ]),
      ]),
    );
  }
}

class _ProgCard extends StatelessWidget {
  final J p;
  const _ProgCard(this.p);
  @override
  Widget build(BuildContext context) {
    final pid = str(p['id']);
    final pr = p['prog'] is Map ? p['prog'] as J : app.legacyProg(p);
    final exp = app.expectedFor(p), done = app.doneOf(p).length;
    final rem = exp - done < 0 ? 0 : exp - done;
    final pct = exp > 0 ? ((done / exp * 100).round() > 100 ? 100 : (done / exp * 100).round()) : 0;
    final end = app.endOf(pr);
    final st = truthy(pr['status']) ? str(pr['status']) : 'active';
    final stL = {'active': l3('Active', 'Actif', 'نشط'), 'paused': l3('Paused', 'En pause', 'متوقف مؤقتاً'), 'ended': l3('Ended', 'Terminé', 'منتهٍ')}[st] ?? st;
    final days = app.progDays(pr).map((e) => iv(e)).toList();
    final freq = days.isNotEmpty ? '${days.length} / ${l3('week', 'semaine', 'أسبوع')} · ${kWOrder.where(days.contains).map(app.wdName).join(', ')}' : app.fq(p);
    final dur = nv(pr['dur']) != 0 ? '${str(pr['dur']).replaceAll(RegExp(r'\.0$'), '')} ${pr['unit'] == 'months' ? l3('months', 'mois', 'أشهر') : l3('weeks', 'semaines', 'أسابيع')}' : '—';
    final wps = app.patWps(p).map((id) {
      final w = app.wpById(id);
      return w == null ? null : ChipW('${w['n']}${id == p['wpId'] ? ' ★' : ''}', icon: ic('pin', size: 13));
    }).whereType<Widget>().toList();
    Widget numBox(int v, String l) => Expanded(
          child: Column(children: [
            Text('$v', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
            Mut(l, size: 12),
          ]),
        );
    final tg = kTag[st == 'active' ? 'done' : 'cancelled']!;
    return secCard(
      hex('#16a39a'),
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(child: Text(l3('Treatment program', 'Programme de traitement', 'برنامج العلاج'), style: const TextStyle(fontWeight: FontWeight.bold))),
          Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2), decoration: BoxDecoration(color: tg[0], borderRadius: BorderRadius.circular(20)), child: Text(stL, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: tg[1]))),
        ]),
        if (wps.isNotEmpty) chips(wps),
        const SizedBox(height: 4),
        Mut('$freq${truthy(pr['time']) ? ' · ${pr['time']}' : ''}'),
        Mut('${app.fmtD(str(pr['start']))} → ${app.fmtD(end)} · $dur'),
        const SizedBox(height: 8),
        Row(children: [numBox(exp, l3('Expected', 'Prévues', 'المتوقعة')), numBox(done, l3('Completed', 'Réalisées', 'المنجزة')), numBox(rem, l3('Remaining', 'Restantes', 'المتبقية'))]),
        const SizedBox(height: 6),
        ProgressBar(pct / 100),
        Padding(padding: const EdgeInsets.fromLTRB(0, 4, 0, 8), child: Mut('$pct% · ${l3('only completed sessions are counted', 'seules les séances réalisées sont comptées', 'تُحتسب الحصص المنجزة فقط')}')),
        Wrap(spacing: 6, runSpacing: 6, children: [
          Btn(l3('Edit program', 'Modifier', 'تعديل البرنامج'), () => progForm(pid), kind: BK.ghost, small: true),
          st == 'paused' ? Btn(l3('Resume', 'Reprendre', 'استئناف'), () => app.pgStatus(pid, 'active'), kind: BK.teal, small: true) : Btn(l3('Pause', 'Pause', 'إيقاف مؤقت'), () => app.pgStatus(pid, 'paused'), kind: BK.ghost, small: true),
          Btn(l3('Extend 4 wk', 'Prolonger 4 sem.', 'تمديد 4 أسابيع'), () => app.pgShift(pid, 28), kind: BK.ghost, small: true),
          Btn(l3('Shorten 4 wk', 'Raccourcir 4 sem.', 'تقصير 4 أسابيع'), () => app.pgShift(pid, -28), kind: BK.ghost, small: true),
        ]),
      ]),
    );
  }
}

class _HistoryBlock extends StatelessWidget {
  final J p;
  const _HistoryBlock(this.p);
  @override
  Widget build(BuildContext context) {
    final pid = str(p['id']);
    final R = app.lastReports(pid);
    final AI = app.ais.where((x) => x['pid'] == pid).toList()..sort((x, y) => str(y['at']).compareTo(str(x['at'])));
    final pl = pal(context);
    Widget row(Widget lead, Widget body, VoidCallback f) => AppCard(
          onTap: f,
          child: Row(children: [
            lead,
            if (lead is! SizedBox) const SizedBox(width: 10),
            Expanded(child: body),
            Icon(Icons.chevron_right, size: 18, color: pl.mut),
          ]),
        );
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(0, 18, 0, 8),
        child: Row(children: [Flexible(child: Text(l3('Completed sessions and reports', 'Séances réalisées et comptes rendus', 'الحصص المنجزة والتقارير'), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold))), const SizedBox(width: 8), ChipW('${R.length}')]),
      ),
      if (R.isEmpty) emptyCard(l3('No structured reports yet. Use “Complete session” to create one.', 'Aucun compte rendu structuré. Utilisez « Terminer la séance » pour en créer un.', 'لا توجد تقارير منظمة بعد. استعملي «إنهاء الحصة» لإنشاء واحد.')),
      ...R.map((r) {
        final f = r['f'] is Map ? r['f'] as Map : <dynamic, dynamic>{};
        final txt = [f['prog'], f['obs'], f['acts']].firstWhere((e) => truthy(e), orElse: () => '—');
        return row(
          TimeBox(str(r['time'])),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text.rich(TextSpan(children: [TextSpan(text: app.fmtD(str(r['date'])), style: const TextStyle(fontWeight: FontWeight.bold)), TextSpan(text: ' · ${r['place']}', style: TextStyle(color: pl.mut, fontSize: 13))])),
            Text(str(txt), maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: pl.mut, fontSize: 13)),
          ]),
          () => viewReport(str(r['id'])),
        );
      }),
      if (AI.isNotEmpty) H2(l3('Approved AI progress reviews', 'Bilans IA approuvés', 'تقارير التقدم المعتمدة')),
      ...AI.map((x) => row(
            const SizedBox(),
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(app.fmtD(str(x['at']).substring(0, 10)), style: const TextStyle(fontWeight: FontWeight.bold)),
              Mut('${l3('Based on ', 'Basé sur ', 'استناداً إلى ')}${x['n']} ${l3('report(s)', 'compte(s) rendu(s)', 'تقرير')}'),
            ]),
            () => viewReview(str(x['id'])),
          )),
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Align(alignment: AlignmentDirectional.centerStart, child: Btn(l3('AI progress review', 'Bilan de progrès IA', 'مراجعة التقدم بالذكاء الاصطناعي'), () => aiReviewFlow(pid), kind: BK.ghost, small: true, icon: ic('chat', size: 14))),
      ),
    ]);
  }
}
