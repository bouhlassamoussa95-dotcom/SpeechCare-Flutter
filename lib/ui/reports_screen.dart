import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../core/data_gen.dart';
import '../core/globals.dart';
import '../core/i18n.dart';
import '../core/theme.dart';
import '../core/util.dart';
import '../state/ai_service.dart';
import '../state/app_state.dart';
import '../state/docx_builder.dart';
import 'ai_panel.dart';
import 'widgets.dart';

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});
  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  List<TextEditingController> ctl = [];
  List<String> titles = [];
  String key = '';
  String msg = '';
  List<String>? undo;

  @override
  void initState() {
    super.initState();
    ai.reportDraft = body;
    ai.polishHandler = polish;
  }

  @override
  void dispose() {
    if (ai.polishHandler == polish) ai.polishHandler = null;
    if (ai.reportDraft == body) ai.reportDraft = null;
    for (final c in ctl) {
      c.dispose();
    }
    super.dispose();
  }

  List<Map<String, String>> body() => [for (var i = 0; i < ctl.length; i++) {'t': titles[i], 'v': ctl[i].text}];

  int get ix => app.v.rl == 'fr' ? 1 : (app.v.rl == 'ar' ? 2 : 0);

  Map<String, dynamic> context_(J p) {
    final lim = app.v.rm == 'eval' ? addD(str(p['start']).isEmpty ? td() : str(p['start']), app.v.rp * 30) : '9999';
    final A = app.apts.where((a) => a['pid'] == p['id'] && str(a['date']).compareTo(lim) <= 0).toList()..sort((x, y) => str(x['date']).compareTo(str(y['date'])));
    final dn = A.where((a) => a['status'] == 'done').toList();
    final ab = A.where((a) => a['status'] == 'absent').length;
    final goals = <String>[];
    for (final a in dn) {
      final g = str(a['goal']);
      if (g.isNotEmpty && !goals.contains(g)) goals.add(g);
    }
    final cd = app.condIds(p).map((i) {
      final c = app.condById(i);
      if (c == null) return '';
      final n = shortCond(c[1] as String);
      return app.v.rl == 'en' ? n : tx(app.v.rl, n);
    }).where((x) => x.isNotEmpty).join(' + ');
    return {
      'dn': dn.length,
      'ab': ab,
      'exp': app.exp(p),
      'log': dn.map((a) => '${a['date']} – ${truthy(a['goal']) ? a['goal'] : '—'}${truthy(a['remark']) ? ' → ${a['remark']}' : ''}').join('\n'),
      'goals': goals.join('\n'),
      'rem': dn.where((a) => truthy(a['remark'])).map((a) => '${a['date']}: ${a['remark']}').join('\n'),
      'id': '${app.rn(p)}, ${app.age(str(p['birth']))}',
      'cd': cd,
    };
  }

  List<List<String>> secs(J p) {
    final c = context_(p);
    String L(String en, String fr, String ar) => [en, fr, ar][ix];
    final tl3 = {'center': ['Center', 'Centre', 'مركز'], 'daycare': ['Daycare', 'Crèche', 'روضة']};
    final pl = '${(tl3[p['pt']] ?? tl3['center']!)[ix]}: ${truthy(p['place']) ? p['place'] : '—'}';
    final cd = c['cd'] as String;
    final co = L('Condition(s)', 'Pathologie(s)', 'الحالة');
    final sn = L('Followed since', 'Suivi depuis le', 'متابعة منذ');
    final start = str(p['start']);
    final dn = c['dn'], ex = c['exp'], ab = c['ab'];
    final att = L(
      '$dn session(s) attended${ex != 0 ? ' out of $ex planned' : ''}${ab != 0 ? ', $ab absence(s)' : ''}.',
      '$dn séance(s) suivie(s)${ex != 0 ? ' sur $ex prévues' : ''}${ab != 0 ? ', $ab absence(s)' : ''}.',
      'حضر $dn حصة${ex != 0 ? ' من أصل $ex مبرمجة' : ''}${ab != 0 ? '، $ab غياب' : ''}.',
    );
    final goals = c['goals'] as String, rem = c['rem'] as String, log = c['log'] as String, id = c['id'] as String;
    final sym = str(p['symptoms']), diag = str(p['diag']), plan = str(p['plan']);
    switch (app.v.rm) {
      case 'school':
        return [
          [L('To / Subject', 'Destinataire / Objet', 'إلى / الموضوع'), '${L('To', 'À', 'إلى')}: ${kRecipients[app.v.rr]![ix]}\n${L('Subject: speech-language therapy report', 'Objet : rapport orthophonique', 'الموضوع: تقرير أرطفوني')}'],
          [L('Follow-up', 'Suivi', 'المتابعة'), '$id ${L('has been followed since', 'est suivi(e) depuis le', 'يخضع للمتابعة منذ')} $start. $att'],
          [L('Diagnosis', 'Diagnostic', 'التشخيص'), '$cd\n$diag'],
          [L('Impact on schoolwork', 'Impact sur la scolarité', 'الأثر على التعلم'), sym],
          [L('Requests to the teacher', 'Demandes à l’enseignant(e)', 'طلبات للمعلم(ة)'), ''],
        ];
      case 'doctor':
        return [
          [L('Subject', 'Objet', 'الموضوع'), '${L('Speech-language therapy report', 'Compte rendu orthophonique', 'تقرير أرطفوني')} – $cd'],
          [L('Identification and referral', 'Identification et motif', 'التعريف'), '$id\n$pl\n$sn $start. $att'],
          [L('Cognitive state (visual / auditory perception, memory, laterality, spatio-corporal orientation)', 'État cognitif (perception visuelle et auditive, mémoire, latéralité, orientation spatio-corporelle)', 'الحالة المعرفية (الإدراك البصري والسمعي، الذاكرة، الجانبية، التوجه الجسدي في الفضاء)'), sym],
          [L('Language state (receptive / expressive)', 'État langagier (réceptif / expressif)', 'الحالة اللغوية (الاستقبالية / التعبيرية)'), diag],
          [L('Progress in sessions', 'Évolution en séances', 'التطور في الحصص'), log],
          [L('Conclusion and recommendations', 'Conclusion et recommandations', 'الخلاصة والتوصيات'), plan],
        ];
      case 'rating':
        return [
          [L('Case card', 'Fiche patient', 'بطاقة الحالة'), '$id\n$co: $cd\nDate: ${td()}'],
          [L('Scores by domain (raw score / developmental age / DQ)', 'Résultats par domaine (note brute / âge développemental / QD)', 'النتائج حسب المجال (النقطة الخام / العمر النمائي / DQ)'), 'SO: \nAU: \nMG: \nMF: \nLEX: \nLCO: \nLE: \nNBRE: '],
          [L('Decision range', 'Zone de décision', 'نطاق القرار'), ''],
          [L('Interpretation', 'Interprétation', 'التفسير'), diag],
        ];
      case 'eval':
        return [
          [L('Period', 'Période', 'الفترة'), '$id\n${L('First ${app.v.rp} month(s) from', 'Les ${app.v.rp} premier(s) mois depuis le', 'أول ${app.v.rp} شهر(أشهر) منذ')} $start'],
          [L('Attendance', 'Présence', 'الحضور'), att],
          [L('Goals worked on', 'Objectifs travaillés', 'الأهداف المعمولة'), goals],
          [L('Progress and remarks', 'Progrès et remarques', 'التقدم والملاحظات'), rem],
          [L('Persistent difficulties', 'Difficultés persistantes', 'الصعوبات المتبقية'), ''],
          [L('Plan for the next period', 'Plan pour la prochaine période', 'خطة الفترة القادمة'), plan],
        ];
      default:
        return [
          [L('Identification', 'Identification', 'التعريف'), '$id\n$co: $cd\n$pl\n$sn $start. $att'],
          [L('Assessment results', 'Résultats de l’évaluation', 'نتائج التقييم'), '$sym\n$diag'],
          [L('Clinical analysis and influencing factors', 'Analyse clinique et facteurs influents', 'التحليل العيادي والعوامل المؤثرة'), ''],
          [L('Objectives and remarks', 'Objectifs et remarques', 'ملاحظات التقييم'), goals + (rem.isNotEmpty ? '\n$rem' : '')],
          [L('Advice for home', 'Conseils pour la maison', 'نصائح للأسرة'), ''],
        ];
    }
  }

  void rebuildControllers(J p) {
    final s = secs(p);
    for (final c in ctl) {
      c.dispose();
    }
    ctl = s.map((x) => TextEditingController(text: x[1])).toList();
    titles = s.map((x) => x[0]).toList();
    msg = '';
    undo = null;
  }

  String get fileName => ('Report_${str(app.P(app.v.pid)?['name']).isEmpty ? 'patient' : app.P(app.v.pid)!['name']}_${app.v.rm}.docx').replaceAll(RegExp(r'[^\w\u0600-\u06FF.-]+'), '_');

  DocxData collect() {
    final p = app.P(app.v.pid)!;
    final place = truthy(p['place']) ? '${[l3x('en', 'Center / daycare', 'Centre / crèche', 'مركز / روضة'), l3x('fr', 'Center / daycare', 'Centre / crèche', 'مركز / روضة'), l3x('ar', 'Center / daycare', 'Centre / crèche', 'مركز / روضة')][ix]}: ${p['place']}' : '';
    return DocxData(
      rtl: app.v.rl == 'ar',
      title: kModels[app.v.rm]![ix],
      patient: app.rn(p),
      age: app.age(str(p['birth'])),
      meta: place,
      sections: body(),
      me: {for (final k in ['name', 'title', 'phone', 'email', 'addr']) k: str(app.me[k])},
      pageWord: [ 'Page', 'Page', 'صفحة'][ix],
      dateLine: fmtLoc(app.v.rl, td(), 'd MMMM y'),
      file: fileName,
    );
  }

  Future<void> export() async {
    try {
      final d = collect();
      final bytes = await buildDocx(d);
      final r = await deliverDocx(d.file, bytes);
      setState(() => msg = T(r == 'shared' ? 'Word file ready. Choose Word, WPS or Drive to open and edit it.' : (r == 'cancelled' ? '' : 'Could not create the Word file. Use Copy instead.')));
    } catch (_) {
      setState(() => msg = T('Could not create the Word file. Use Copy instead.'));
    }
  }

  void copy() {
    final head = [
      'Complete and polish this speech-language therapy report (${kModels[app.v.rm]![0]}). Keep the structure and titles.',
      'Complète et améliore ce compte rendu orthophonique (${kModels[app.v.rm]![1]}). Garde la structure et les titres.',
      'أكمل وحسّن هذا التقرير الأرطفوني (${kModels[app.v.rm]![2]}). حافظ على الهيكل والعناوين.',
    ][ix];
    final tx = '$head\n\n${body().map((s) => '## ${s['t']}\n${s['v']}').join('\n\n')}';
    Clipboard.setData(ClipboardData(text: tx));
    setState(() => msg = 'Report text copied.');
  }

  String _digits(String t) {
    final conv = t.replaceAllMapped(RegExp(r'[\u0660-\u0669]'), (m) => '${m.group(0)!.codeUnitAt(0) - 0x0660}');
    final l = RegExp(r'\d+').allMatches(conv).map((m) => m.group(0)!).toList()..sort();
    return l.join(',');
  }

  Future<void> polish() async {
    final p = app.P(app.v.pid);
    if (p == null || ctl.isEmpty) return;
    final nm = app.rn(p);
    final before = ctl.map((c) => c.text).toList();
    setState(() => msg = T('Thinking…'));
    try {
      final arr = await aiPolishSections(app.v.rl, body(), nm.trim());
      var applied = 0, kept = 0;
      for (var i = 0; i < ctl.length; i++) {
        final n = i < arr.length && arr[i] is String ? (arr[i] as String).split('[PATIENT]').join(nm).trim() : '';
        if (n.isEmpty || before[i].trim().isEmpty) continue;
        if (_digits(before[i]) != _digits(n)) {
          kept++;
          continue;
        }
        ctl[i].text = n;
        applied++;
      }
      undo = applied > 0 ? before : null;
      final keptTxt = kept > 0 ? ' · $kept${[' section(s) kept unchanged because the AI altered numbers or dates.', ' section(s) laissée(s) inchangée(s) car l’IA modifiait des chiffres ou des dates.', ' قسم بقي دون تغيير لأن الذكاء الاصطناعي غيّر أرقاماً أو تواريخ.'][ix]}' : '';
      if (mounted) setState(() => msg = '${T('Report improved by AI. Please review it.')} ${T('Review identifying details before sending.')}$keptTxt');
    } catch (e) {
      if (mounted) setState(() => msg = aiErr(e));
    }
  }

  void undoPolish() {
    final u = undo;
    if (u == null) return;
    for (var i = 0; i < ctl.length && i < u.length; i++) {
      ctl[i].text = u[i];
    }
    setState(() {
      msg = '';
      undo = null;
    });
  }

  void clientMsg() {
    final p = app.P(app.v.pid);
    if (p == null) return;
    String Lr(String en, String fr, String ar) => [en, fr, ar][ix];
    final m = app.me;
    final sec = body().where((x) => (x['v'] ?? '').trim().isNotEmpty).toList();
    final reps = app.srs.where((r) => r['pid'] == p['id']).toList()..sort((a, b) => ('${b['date']}${b['time']}').compareTo('${a['date']}${a['time']}'));
    final rep = reps.isEmpty ? null : reps.first;
    final ups = app.apts.where((a) => a['pid'] == p['id'] && a['status'] == 'scheduled' && str(a['date']).compareTo(td()) >= 0).toList()..sort((a, b) => ('${a['date']}${a['time']}').compareTo('${b['date']}${b['time']}'));
    final nx = ups.isEmpty ? null : ups.first;
    String cut(String t, int n) {
      t = t.replaceAll(RegExp(r'\s+\n'), '\n').trim();
      return t.length > n ? '${t.substring(0, n - 1)}…' : t;
    }

    final rf = rep == null || rep['f'] is! Map ? <dynamic, dynamic>{} : rep['f'] as Map;
    final out = <String>[Lr('Hello,', 'Bonjour,', 'السلام عليكم،'), '', Lr('Here is a summary of the speech therapy follow-up for ${p['name']} (${kModels[app.v.rm]![0]}).', 'Voici un résumé du suivi orthophonique de ${p['name']} (${kModels[app.v.rm]![1]}).', 'هذا ملخص المتابعة الأرطفونية للطفل ${p['name']} (${kModels[app.v.rm]![2]}).')];
    if (rep != null && (truthy(rf['prog']) || truthy(rf['ach']))) {
      out.addAll(['', '▪ ${Lr('Latest progress', 'Derniers progrès', 'آخر تقدم')} (${fmtLoc(app.v.rl, str(rep['date']), 'd MMMM')}):']);
      if (truthy(rf['prog'])) out.add(cut(str(rf['prog']), 400));
      if (truthy(rf['ach'])) out.add('${Lr('Achievements: ', 'Réussites : ', 'الإنجازات: ')}${cut(str(rf['ach']), 300)}');
    } else if (sec.isNotEmpty) {
      for (final x in sec.take(3)) {
        out.addAll(['', '▪ ${x['t']}:', cut(x['v']!, 300)]);
      }
    }
    final adv = sec.where((x) => RegExp(r'advice|conseil|نصائح|توصيات|recommend', caseSensitive: false).hasMatch(x['t']!)).toList();
    final rec = truthy(rf['rec']) ? str(rf['rec']) : (adv.isNotEmpty ? adv.first['v']! : '');
    if (rec.isNotEmpty) out.addAll(['', '▪ ${Lr('Recommendations', 'Recommandations', 'التوصيات')}:', cut(rec, 450)]);
    if (nx != null) out.addAll(['', '▪ ${Lr('Next appointment', 'Prochain rendez-vous', 'الموعد القادم')}: ${fmtLoc(app.v.rl, str(nx['date']), 'EEEE d MMMM')} ${nx['time']}${truthy(nx['place']) ? ' — ${nx['place']}' : ''}']);
    out.addAll(['', Lr('Kind regards,', 'Cordialement,', 'مع أطيب التحيات،'), [m['name'], m['title']].where((e) => truthy(e)).join(' — '), [m['phone'], m['email']].where((e) => truthy(e)).join(' · ')]);
    final text = out.join('\n').replaceAll(RegExp(r'\n{3,}'), '\n\n').trim();
    final c = TextEditingController(text: text);
    showSheet<void>((sc) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          sheetTitle(T('Send to client')),
          Mut(Lr('Review and edit the message. Nothing is sent automatically: you choose the app (WhatsApp, email…) and press send there.', 'Relisez et modifiez le message. Rien n’est envoyé automatiquement : vous choisissez l’application (WhatsApp, e-mail…) et envoyez depuis celle-ci.', 'راجعي الرسالة وعدّليها. لا يُرسل شيء تلقائياً: تختارين التطبيق (واتساب، بريد…) وتضغطين إرسال هناك.')),
          const SizedBox(height: 8),
          TextField(controller: c, minLines: 12, maxLines: 24, decoration: inputDeco(sc), style: const TextStyle(fontSize: 15)),
          const SizedBox(height: 8),
          Wrap(spacing: 8, runSpacing: 8, children: [
            Btn(Lr('Share…', 'Partager…', 'مشاركة…'), () => shareText(c.text, str(p['name']))),
            Btn(T('Copy'), () {
              Clipboard.setData(ClipboardData(text: c.text));
              toast('Report text copied.');
            }, kind: BK.ghost),
            Btn(Lr('Close', 'Fermer', 'إغلاق'), () => cs(sc), kind: BK.ghost),
          ]),
        ])).then((_) => c.dispose());
  }

  void askSection(int i) {
    final title = titles[i];
    final model = kModels[app.v.rm]![ix];
    final langName = app.v.rl == 'ar' ? 'Algerian Arabic (Darija), clear and professional' : (app.v.rl == 'fr' ? 'French' : 'English');
    final draft = ctl[i].text.trim();
    askAI(
      pid: str(app.v.pid),
      label: title,
      prompt: 'Write the section "$title" of a speech-language therapy report ($model) for this patient, using the context. Language: $langName. Output only the text of the section, plain text, concise and professional.${draft.isNotEmpty ? '\n\nCurrent draft to improve:\n$draft' : ''}',
      target: AiTarget(title, (t) {
        if (i >= ctl.length) return false;
        ctl[i].text = plainText(t);
        return true;
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (app.pats.isEmpty) return screenList([emptyCard(T('Add a patient first.'))]);
    if (app.P(app.v.pid) == null) app.v.pid = str(app.pats.first['id']);
    final p = app.P(app.v.pid)!;
    final k = '${app.v.pid}|${app.v.rm}|${app.v.rl}|${app.v.rp}|${app.v.rr}';
    if (k != key) {
      key = k;
      rebuildControllers(p);
    }
    final pl = pal(context);
    return screenList([
      PickerField(label: T('Patient'), value: str(app.v.pid), searchable: true, items: app.pats.map((x) => PickItem(str(x['id']), app.full(x))).toList(), onChanged: (v) {
        app.v.pid = v;
        app.go();
      }),
      PickerField(label: T('Report type'), value: app.v.rm, items: kModels.keys.map((m) => PickItem(m, kModels[m]![0])).toList(), onChanged: (v) {
        app.v.rm = v;
        app.go();
      }),
      if (app.v.rm == 'school')
        PickerField(label: T('Addressed to'), value: app.v.rr, items: [for (final x in const [['teacher', 'Teacher'], ['director', 'School director'], ['counselor', 'School counselor'], ['doctor', 'Doctor'], ['parents', 'Parents']]) PickItem(x[0], T(x[1]))], onChanged: (v) {
        app.v.rr = v;
        app.go();
      }),
      Padding(
        padding: const EdgeInsets.only(top: 4, bottom: 10),
        child: Wrap(crossAxisAlignment: WrapCrossAlignment.center, runSpacing: 6, children: [
          if (app.v.rm == 'eval')
            for (final n in [1, 3, 6])
              PillBtn('$n ${T(n > 1 ? 'months' : 'month')}', app.v.rp == n, () {
                app.v.rp = n;
                app.go();
              }),
          Padding(padding: const EdgeInsetsDirectional.only(end: 6), child: Mut(T('Report language:'))),
          for (final x in const [['en', 'EN'], ['fr', 'FR'], ['ar', 'عربي']])
            PillBtn(x[1], app.v.rl == x[0], () {
              app.v.rl = x[0];
              app.go();
            }),
        ]),
      ),
      Mut(T('Sections are pre-filled from the profile and session log. Edit, then copy the report text or download it as Word.')),
      const SizedBox(height: 8),
      for (var i = 0; i < ctl.length; i++)
        secCard(
          kCol[i % 6],
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Expanded(child: Text(titles[i], style: TextStyle(fontSize: 13, color: pl.mut))),
              Btn('AI', () => askSection(i), kind: BK.ghost, small: true, icon: ic('chat', size: 14)),
            ]),
            const SizedBox(height: 6),
            TextField(
              controller: ctl[i],
              minLines: 4,
              maxLines: 14,
              textDirection: app.v.rl == 'ar' ? TextDirection.rtl : null,
              decoration: inputDeco(context),
              style: const TextStyle(fontSize: 15),
            ),
          ]),
        ),
      Wrap(spacing: 8, runSpacing: 8, crossAxisAlignment: WrapCrossAlignment.center, children: [
        Btn(T('Copy report text'), copy, kind: BK.teal),
        IconBtn(ic('spark', size: 22, color: pl.ink), polish, tooltip: T('Polish with AI'), bg: pl.card),
      ]),
      const SizedBox(height: 8),
      Wrap(spacing: 8, runSpacing: 8, children: [
        Btn(T('Edit / Email report'), export, icon: ic('doc', size: 16)),
        Btn(T('Send to client'), clientMsg, kind: BK.ghost, icon: ic('phone', size: 16)),
        Btn(T('Download Word'), export, kind: BK.ghost, small: true),
      ]),
      if (msg.isNotEmpty)
        Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Wrap(crossAxisAlignment: WrapCrossAlignment.center, children: [
            Text(T(msg), style: TextStyle(color: pl.mut, fontSize: 13)),
            if (undo != null) TextButton(onPressed: undoPolish, child: Text({'en': 'Undo', 'fr': 'Annuler', 'ar': 'تراجع'}[app.v.rl] ?? 'Undo')),
          ]),
        ),
    ]);
  }
}
