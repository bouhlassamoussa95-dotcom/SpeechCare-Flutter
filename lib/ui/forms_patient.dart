import 'package:flutter/material.dart';
import '../core/data_gen.dart';
import '../core/globals.dart';
import '../core/i18n.dart';
import '../core/theme.dart';
import '../core/util.dart';
import '../state/ai_service.dart';
import '../state/app_state.dart';
import '../state/logic.dart';
import 'ai_panel.dart';
import 'widgets.dart';

/// ptForm(id, pre)
void ptForm({String? id, J? pre}) {
  showSheet<void>((c) => PtForm(id: id, pre: pre));
}

class PtForm extends StatefulWidget {
  final String? id;
  final J? pre;
  const PtForm({super.key, this.id, this.pre});
  @override
  State<PtForm> createState() => _PtFormState();
}

class _PtFormState extends State<PtForm> {
  late final J p;
  late final TextEditingController name, prename, parents, phone, place, symptoms, diag, plan, fee, fn, dv;
  late String birth, start, pt, fu, du;
  final Set<String> conds = {};
  final Set<String> extras = {};
  bool get edit => widget.id != null && widget.id!.isNotEmpty;

  @override
  void initState() {
    super.initState();
    if (edit) {
      p = app.P(widget.id)!;
    } else {
      p = <String, dynamic>{'name': '', 'pre': '', 'birth': '', 'parents': '', 'phone': '', 'pt': 'center', 'place': '', 'start': td(), 'fn': 2, 'fu': 'week', 'dv': 12, 'du': 'weeks', 'symptoms': '', 'diag': '', 'plan': '', 'conds': <dynamic>[], ...(widget.pre ?? <String, dynamic>{})};
    }
    TextEditingController c(String k) => TextEditingController(text: str(p[k]));
    name = c('name');
    prename = c('pre');
    parents = c('parents');
    phone = c('phone');
    place = c('place');
    symptoms = c('symptoms');
    diag = c('diag');
    plan = c('plan');
    fee = c('fee');
    fn = c('fn');
    dv = c('dv');
    birth = str(p['birth']);
    start = str(p['start']);
    pt = truthy(p['pt']) ? str(p['pt']) : 'center';
    fu = truthy(p['fu']) ? str(p['fu']) : 'week';
    du = truthy(p['du']) ? str(p['du']) : 'weeks';
    conds.addAll(app.condIds(p));
    if (p['wpExtra'] is List) extras.addAll((p['wpExtra'] as List).map((e) => str(e)));
    fn.addListener(() => setState(() {}));
    dv.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    for (final c in [name, prename, parents, phone, place, symptoms, diag, plan, fee, fn, dv]) {
      c.dispose();
    }
    super.dispose();
  }

  bool get programManaged => edit && p['prog'] is Map && app.progDays(p['prog'] as J).isNotEmpty;

  int get recN {
    var n = 0;
    for (final i in conds) {
      final k = (int.tryParse(i) ?? 1) - 1;
      if (k >= 0 && k < kRec.length && kRec[k] > n) n = kRec[k];
    }
    return n;
  }

  void save() {
    final J o = <String, dynamic>{
      'name': name.text.trim(),
      'pre': prename.text.trim(),
      'birth': birth,
      'parents': parents.text.trim(),
      'phone': phone.text.trim(),
      'place': place.text.trim(),
      'start': start,
      'fn': fn.text.trim(),
      'dv': dv.text.trim(),
      'symptoms': symptoms.text.trim(),
      'diag': diag.text.trim(),
      'plan': plan.text.trim(),
      'fee': fee.text.trim(),
      'fu': fu,
      'du': du,
      'pt': pt,
      'conds': conds.toList()..sort((a, b) => (int.tryParse(a) ?? 0).compareTo(int.tryParse(b) ?? 0)),
    };
    if (str(o['name']).isEmpty) return toast('Enter the patient’s name');
    // keep the order of the checklist (condition ids ascending), max 4
    app.savePt(edit ? widget.id! : '', o, extras.toList());
    cs(context);
  }

  @override
  Widget build(BuildContext context) {
    final places = app.places.where((x) => x['t'] == pt).map((x) => str(x['n'])).toList();
    final q = place.text.trim().toLowerCase();
    final sugg = places.where((x) => x.toLowerCase().contains(q) && x.toLowerCase() != q).take(8).toList();
    final tot = app.exp(<String, dynamic>{'fn': fn.text, 'fu': fu, 'dv': dv.text, 'du': du});
    final pl = pal(context);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      sheetTitle(edit ? T('Edit patient') : T('New patient')),
      twoCol(LField(name, label: T('Name')), LField(prename, label: T('Prename'))),
      DateField(T('Date of birth'), birth, (v) => setState(() => birth = v), last: DateTime.now()),
      Padding(padding: const EdgeInsets.only(bottom: 8), child: Mut(birth.isNotEmpty ? '${T('Age:')} ${app.age(birth)}' : T('Age is calculated in years and months'))),
      LField(parents, label: T('Parents’ names')),
      LField(phone, label: T('Parents’ phone'), keyboard: TextInputType.phone),
      Lbl(T('Where do you see this patient?')),
      Seg([SegItem('center', T('Center')), SegItem('daycare', T('Daycare'))], pt, (v) => setState(() => pt = v)),
      LField(place, hint: T('Name of the center or daycare'), onChanged: (_) => setState(() {})),
      if (sugg.isNotEmpty) Padding(padding: const EdgeInsets.only(bottom: 8), child: Wrap(spacing: 6, runSpacing: 6, children: sugg.map((x) => ChipW(x, onTap: () => setState(() => place.text = x))).toList())),
      Lbl(T('Conditions (1 to 4)')),
      Container(
        decoration: BoxDecoration(color: pl.card, borderRadius: BorderRadius.circular(12), border: Border.all(color: pl.line)),
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: Column(
          children: kConditions.map((c) => CheckRow(conds.contains(c[0]), shortCond(c[1] as String), (v) => setState(() => v ? conds.add(c[0] as String) : conds.remove(c[0] as String)))).toList(),
        ),
      ),
      if (recN > 0)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Wrap(crossAxisAlignment: WrapCrossAlignment.center, spacing: 6, children: [
            Text.rich(TextSpan(style: TextStyle(color: pl.mut, fontSize: 13), children: [
              TextSpan(text: '${T('Typical starting point:')} '),
              TextSpan(text: '$recN ${T('per week')}', style: const TextStyle(fontWeight: FontWeight.bold)),
              TextSpan(text: '. ${T('Your clinical judgement decides.')} '),
            ])),
            Btn(T('Use'), () => setState(() {
                  fn.text = '$recN';
                  fu = 'week';
                }), small: true),
          ]),
        ),
      LField(symptoms, label: T('Symptoms'), minLines: 2, maxLines: 5),
      LField(diag, label: T('Diagnostic'), minLines: 2, maxLines: 5),
      Lbl(T('Treatment plan (skills / activities)')),
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Align(
          alignment: AlignmentDirectional.centerStart,
          child: Btn(T('Ask AI for a plan'), _askPlan, kind: BK.teal, small: true, icon: ic('chat', size: 14)),
        ),
      ),
      LField(plan, minLines: 2, maxLines: 8),
      DateField(T('Treatment start'), start, (v) => setState(() => start = v)),
      LField(fee, label: T('Session price (optional)'), keyboard: const TextInputType.numberWithOptions(decimal: true)),
      Padding(padding: const EdgeInsets.only(bottom: 8), child: Mut(T('Uses the place price if empty'))),
      AppCard(
        child: programManaged
            ? Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(l3('Sessions schedule', 'Planning des séances', 'جدول الحصص'), style: const TextStyle(fontWeight: FontWeight.bold)),
                Mut(l3('Managed in the treatment program (patient profile → Edit program).', 'Géré dans le programme de traitement (profil → Modifier le programme).', 'يُدار من برنامج العلاج (ملف المريض ← تعديل البرنامج).')),
              ])
            : Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(T('How many sessions?'), style: const TextStyle(fontWeight: FontWeight.bold)),
                twoCol(LField(fn, label: T('Sessions'), keyboard: TextInputType.number), PickerField(label: T('Per'), value: fu, items: [PickItem('day', T('Day')), PickItem('week', T('Week')), PickItem('month', T('Month'))], onChanged: (v) => setState(() => fu = v)), fb: 1),
                twoCol(LField(dv, label: T('For'), keyboard: TextInputType.number), PickerField(label: T('Unit'), value: du, items: [PickItem('weeks', T('Weeks')), PickItem('months', T('Months'))], onChanged: (v) => setState(() => du = v))),
                Text('≈ $tot ${T('sessions planned')}', style: const TextStyle(fontWeight: FontWeight.bold, color: Pal.tea)),
              ]),
      ),
      AppCard(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(l3('Additional workplaces', 'Lieux supplémentaires', 'أماكن عمل إضافية'), style: const TextStyle(fontWeight: FontWeight.bold)),
          Mut(l3('Same patient, same profile: sessions keep their own location.', 'Même patient, même dossier : chaque séance garde son propre lieu.', 'نفس المريض ونفس الملف: كل حصة تحتفظ بمكانها.')),
          if (app.places.isEmpty)
            Mut(l3('Add workplaces first (menu → Workplaces).', 'Ajoutez d’abord des lieux (menu → Lieux de travail).', 'أضيفي أماكن العمل أولاً (القائمة → أماكن العمل).'))
          else
            ...app.places.map((w) => CheckRow(extras.contains(w['id']), str(w['n']), (v) => setState(() => v ? extras.add(str(w['id'])) : extras.remove(str(w['id']))))),
        ]),
      ),
      Wrap(spacing: 8, runSpacing: 8, children: [Btn(T('Save'), save), Btn(T('Cancel'), () => cs(context), kind: BK.ghost)]),
    ]);
  }

  void _askPlan() {
    final cn = conds.map((i) => app.condById(i)).whereType<List<dynamic>>().map((c) => shortCond(c[1] as String)).join('; ');
    final ctx = '${l3r('Child age: ', 'Âge de l’enfant : ', 'عمر الطفل: ')}${birth.isNotEmpty ? app.age(birth) : '?'}. ${l3r('Conditions: ', 'Pathologies : ', 'الحالات: ')}${cn.isEmpty ? '-' : cn}. ${l3r('Symptoms: ', 'Symptômes : ', 'الأعراض: ')}${symptoms.text.trim().isEmpty ? '-' : symptoms.text.trim()}. ${l3r('Diagnostic: ', 'Diagnostic : ', 'التشخيص: ')}${diag.text.trim().isEmpty ? '-' : diag.text.trim()}.';
    askAI(
      label: l3r('Treatment plan', 'Plan de traitement', 'خطة علاجية'),
      prompt: '${planQ()}\n\n$ctx',
      target: AiTarget('Treatment plan (skills / activities)', (t) {
        plan.text = '${plan.text.trim().isNotEmpty ? '${plan.text.trim()}\n\n' : ''}${plainText(t)}';
        return true;
      }),
    );
  }
}
