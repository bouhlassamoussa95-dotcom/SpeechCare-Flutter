import 'package:flutter/material.dart';
import '../core/i18n.dart';
import '../core/globals.dart';
import '../core/theme.dart';
import '../core/util.dart';
import '../state/ai_service.dart';
import '../state/app_state.dart';
import '../state/logic.dart';
import 'ai_panel.dart';
import 'forms_patient.dart';
import 'widgets.dart';

/// apForm(id, pid)
void apForm({String? id, String? pid}) {
  if (app.pats.isEmpty) {
    showSheet<void>((c) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          sheetTitle(T('Add a patient first')),
          Btn(T('New patient'), () {
            cs(c);
            ptForm();
          }),
        ]));
    return;
  }
  showSheet<void>((c) => ApForm(id: id, pid: pid));
}

class ApForm extends StatefulWidget {
  final String? id, pid;
  const ApForm({super.key, this.id, this.pid});
  @override
  State<ApForm> createState() => _ApFormState();
}

class _ApFormState extends State<ApForm> {
  late String pid, date, time, place, status;
  late final TextEditingController goal, remark, nCtl, stepCtl;
  bool group = false;
  bool applyAll = true;
  final Set<String> gsel = {};
  late final J a;

  bool get edit => widget.id != null && widget.id!.isNotEmpty;

  @override
  void initState() {
    super.initState();
    final p0 = app.P(widget.pid ?? app.v.pid) ?? app.pats.first;
    if (edit) {
      a = app.apts.firstWhere((x) => x['id'] == widget.id);
    } else {
      a = <String, dynamic>{
        'pid': p0['id'],
        'date': ['cal', 'home', 'sess'].contains(app.v.t) ? app.v.day : td(),
        'time': '10:00',
        'place': str(p0['place']),
        'goal': '',
        'remark': '',
        'status': 'scheduled',
      };
    }
    pid = str(a['pid']);
    date = str(a['date']);
    time = str(a['time']);
    place = str(a['place']);
    status = str(a['status']);
    goal = TextEditingController(text: str(a['goal']));
    remark = TextEditingController(text: str(a['remark']));
    final old = app.apts.where((x) => x['pid'] == p0['id']).length;
    final n = (app.exp(p0) - old).clamp(1, 60);
    nCtl = TextEditingController(text: '$n');
    stepCtl = TextEditingController(text: '${app.stp(p0)}');
  }

  @override
  void dispose() {
    goal.dispose();
    remark.dispose();
    nCtl.dispose();
    stepCtl.dispose();
    super.dispose();
  }

  void save() {
    if (date.isEmpty) return toast('Pick a date');
    final J o = <String, dynamic>{'pid': pid, 'date': date, 'time': time, 'place': place, 'goal': goal.text.trim(), 'remark': remark.text.trim(), 'status': status};
    app.saveAp(
      edit ? widget.id! : '',
      o,
      applyAll: truthy(a['grp']) && applyAll,
      n: iv(nCtl.text) == 0 ? 1 : iv(nCtl.text),
      step: iv(stepCtl.text) == 0 ? 7 : iv(stepCtl.text),
      group: group ? gsel.where((x) => x != pid).toList() : const <String>[],
    );
    cs(context);
  }

  @override
  Widget build(BuildContext context) {
    final names = <String>[...app.places.map((x) => str(x['n'])), if (place.isNotEmpty) place];
    final pl = <String>{...names}.toList();
    final others = app.pats.where((p) => p['id'] != pid).toList();
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      sheetTitle(edit ? T('Edit session') : T('New session')),
      if (!edit) Seg([SegItem('0', T('Individual')), SegItem('1', T('Group session'))], group ? '1' : '0', (v) => setState(() => group = v == '1')),
      PickerField(
        label: T('Patient'),
        value: pid,
        items: app.pats.map((p) => PickItem(str(p['id']), app.full(p))).toList(),
        onChanged: (v) => setState(() {
          pid = v;
          final p = app.P(v);
          if (p != null && truthy(p['place'])) place = str(p['place']);
          gsel.remove(v);
        }),
      ),
      if (!edit && group)
        AppCard(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          child: Theme(
            data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
            child: ExpansionTile(
              tilePadding: EdgeInsets.zero,
              title: Text('${T('Other patients in the group')} (${gsel.where((x) => x != pid).length})', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
              children: others.isEmpty
                  ? [const Padding(padding: EdgeInsets.all(8), child: Text('—'))]
                  : others.map((p) => CheckRow(gsel.contains(p['id']), app.full(p), (v) => setState(() => v ? gsel.add(str(p['id'])) : gsel.remove(str(p['id']))))).toList(),
            ),
          ),
        ),
      twoCol(DateField(T('Date'), date, (v) => setState(() => date = v)), TimeField(T('Time'), time, (v) => setState(() => time = v))),
      PickerField(
        label: T('Center / daycare'),
        value: place,
        addPlace: true,
        items: pl.map((x) => PickItem(x, x)).toList(),
        onChanged: (v) async {
          if (v == kAddPlaceKey) {
            final n = await addPlaceDialog(context);
            if (n != null) setState(() => place = n);
          } else {
            setState(() => place = v);
          }
        },
      ),
      Lbl(T('Goal of this session')),
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Align(
          alignment: AlignmentDirectional.centerStart,
          child: Btn(T('Suggest goal with AI'), () {
            askAI(
              pid: pid,
              label: l3r('Goal for the session', 'Objectif de la séance', 'هدف الحصة'),
              prompt: goalQ(),
              target: AiTarget('Goal of this session', (t) {
                var x = plainText(t).replaceAll(RegExp('^["“]|["”]\$'), '').trim();
                if (x.length > 300) x = x.substring(0, 300);
                goal.text = x;
                return true;
              }),
            );
          }, kind: BK.teal, small: true, icon: ic('chat', size: 14)),
        ),
      ),
      LField(goal, minLines: 2, maxLines: 5),
      if (truthy(a['grp']) && edit) CheckRow(applyAll, T('Apply date, time, place and goal to the whole group'), (v) => setState(() => applyAll = v)),
      LField(remark, label: T('Remarks'), minLines: 2, maxLines: 5),
      PickerField(label: T('Status'), value: status, items: kSt.keys.map((k) => PickItem(k, T(kSt[k]!))).toList(), onChanged: (v) => setState(() => status = v)),
      if (!edit)
        Builder(builder: (context) {
          final p0 = app.P(pid)!;
          return secCard(
            hex('#f29a2e'),
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(T('Repeat'), style: const TextStyle(fontWeight: FontWeight.bold)),
              Mut('${T('Plan:')} ${app.fq(p0)} → ${app.exp(p0)} ${T('sessions')}. ${T('Change if needed (max 60).')}'),
              const SizedBox(height: 6),
              twoCol(LField(nCtl, label: T('Sessions'), keyboard: TextInputType.number), LField(stepCtl, label: T('Every (days)'), keyboard: TextInputType.number)),
            ]),
          );
        }),
      const SizedBox(height: 4),
      Wrap(spacing: 8, runSpacing: 8, children: [
        Btn(T('Save'), save),
        Btn(T('Cancel'), () => cs(context), kind: BK.ghost),
        if (edit)
          DangerBtn(T('Delete'), () {
            app.delAp(widget.id!);
            cs(context);
          }),
      ]),
    ]);
  }
}
