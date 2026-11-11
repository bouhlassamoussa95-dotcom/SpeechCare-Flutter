import 'package:flutter/material.dart';
import '../core/i18n.dart';
import '../state/app_state.dart';
import 'cards.dart';
import 'widgets.dart';

class ConsultationsScreen extends StatelessWidget {
  const ConsultationsScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final f = app.v.cf;
    final L = app.cons.where((c) => f == 'all' || c['status'] == f).toList()..sort((x, y) => ('${y['date']}${y['time']}').compareTo('${x['date']}${x['time']}'));
    return screenList([
      PillRow([
        for (final x in const [['all', 'All'], ['scheduled', 'Planned'], ['done', 'Done'], ['cancelled', 'Cancelled']])
          PillBtn(T(x[1]), f == x[0], () {
            app.v.cf = x[0];
            app.go();
          }),
      ]),
      const SizedBox(height: 10),
      if (L.isEmpty) emptyCard(T('No consultations yet. Tap + Consultation.')),
      ...L.map((c) => ConsCard(c, key: ValueKey('co_${c['id']}'))),
    ]);
  }
}
