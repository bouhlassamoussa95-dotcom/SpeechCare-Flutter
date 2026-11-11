import 'package:flutter/material.dart';
import '../core/data_gen.dart';
import '../core/i18n.dart';
import '../core/theme.dart';
import '../core/util.dart';
import '../state/app_state.dart';
import '../state/logic.dart';
import 'forms_misc.dart';
import 'widgets.dart';

String wtLabel(String type) {
  for (final t in kWTypes) {
    if (t[0] == type) return l3(t[1], t[2], t[3]);
  }
  return type;
}

String wpTerms(J w) => w['mode'] == 'fix'
    ? '${l3('Fixed ', 'Fixe ', 'ثابت ')}${app.money(nv(w['mine']))} / ${l3('session', 'séance', 'حصة')}'
    : '${l3('Clinician ', 'Praticien ', 'الأخصائية ')}${w['my'] == null ? 100 : _n(w['my'])}% · ${l3('Institution ', 'Établissement ', 'المؤسسة ')}${100 - (w['my'] == null ? 100 : nv(w['my']).round())}%';

String _n(dynamic v) {
  final d = nv(v);
  return d == d.roundToDouble() ? '${d.round()}' : '$d';
}

class WorkplacesScreen extends StatelessWidget {
  const WorkplacesScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final pl = pal(context);
    int cnt(J w) => app.pats.where((p) => app.patWps(p).contains(w['id'])).length;
    final L = app.places;
    return screenList([
      Padding(
        padding: const EdgeInsets.fromLTRB(2, 0, 2, 10),
        child: Mut(l3('Each workplace has its own financial arrangement. Completed sessions keep the terms that applied when they were saved.', 'Chaque lieu a son propre accord financier. Les séances terminées gardent les conditions en vigueur lors de leur enregistrement.', 'لكل مكان عمل ترتيبه المالي. تحتفظ الحصص المنجزة بالشروط التي كانت سارية عند حفظها.')),
      ),
      if (L.isEmpty) emptyCard(l3('No workplaces yet. Tap + Workplace.', 'Aucun lieu. Appuyez sur + Lieu.', 'لا توجد أماكن عمل بعد. اضغطي + مكان.')),
      for (var i = 0; i < L.length; i++)
        AppCard(
          onTap: () => wpForm(id: str(L[i]['id'])),
          child: Row(children: [
            Avatar('', size: 42, bg: kCol[i % 6], child: ic('pin', size: 18, color: Colors.white)),
            const SizedBox(width: 10),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [Expanded(child: Text(str(L[i]['n']), style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold))), Icon(Icons.chevron_right, size: 18, color: pl.mut)]),
                chips([ChipW(wtLabel(str(L[i]['type']))), ChipW('${cnt(L[i])} ${l3('patients', 'patients', 'مرضى')}')]),
                Mut('${wpTerms(L[i])}${truthy(L[i]['fee']) ? ' · ${app.money(nv(L[i]['fee']))}' : ''}'),
                if (truthy(L[i]['addr'])) Mut(str(L[i]['addr'])),
              ]),
            ),
          ]),
        ),
    ]);
  }
}
