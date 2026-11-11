import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../core/data_gen.dart';
import '../core/i18n.dart';
import '../core/store.dart';
import '../core/util.dart';
import 'app_state.dart';
import 'logic.dart';

/// Optional build-time key:  flutter build apk --dart-define=OPENROUTER_API_KEY=sk-or-v1-...
const String kBuildOrKey = String.fromEnvironment('OPENROUTER_API_KEY');
const String kOrEndpoint = 'https://openrouter.ai/api/v1/chat/completions';

bool isFreeModel(String? m) => m == 'openrouter/free' || RegExp(r':free$', caseSensitive: false).hasMatch(m ?? '');
String orKey() => kBuildOrKey.isNotEmpty ? kBuildOrKey : (Store.get('speechcare_or_key') ?? '');
bool get orKeyBuiltIn => kBuildOrKey.isNotEmpty;
String orModel() {
  final saved = Store.get('speechcare_or_model') ?? '';
  return isFreeModel(saved) && saved.isNotEmpty ? saved : 'openrouter/free';
}

String langName(String l) => {'en': 'English', 'fr': 'French', 'ar': 'Arabic'}[l] ?? 'English';

class AiError implements Exception {
  final dynamic code;
  final String msg;
  AiError(this.code, [this.msg = '']);
}

/// SYS(): system prompt, identical text to the web app.
String sysPrompt(String? l, [String mode = 'auto']) {
  final target = (mode != 'auto') ? mode : ((l != null && ['en', 'fr', 'ar'].contains(l)) ? l : 'auto');
  final rule = target == 'ar'
      ? 'Reply entirely in natural Algerian Arabic/Darija (Dzairi), not Moroccan or Egyptian. Use simple Modern Standard Arabic only for formal clinical terminology when needed. Write child-facing prompts and parent advice in everyday Algerian Darija; keep therapist guidance clear and respectful.'
      : target == 'fr'
          ? 'Réponds entièrement en français clair et professionnel, avec un vocabulaire d’orthophonie accessible. Les consignes destinées aux enfants et aux parents doivent être simples, naturelles et bienveillantes.'
          : 'Detect the language of the latest user message and answer in that same language (Arabic/Algerian Darija, French, or English). If the user writes Algerian Darija, answer in Algerian Darija; do not switch to English unless requested.';
  return 'You are SpeechCare Assistant, a warm, expert clinical co-pilot for a speech-language therapist (orthophoniste, neurolinguist) in Algeria who works in French, Arabic (including Algerian Darija) and English with children and adults. $rule Scope: articulation and phonological disorders, apraxia of speech, language delay, developmental language disorder, ADHD, learning difficulties (dyslexia, dyscalculia, dysgraphia, dysorthographia), stuttering, voice, hearing loss, aphasia, Alzheimer, Parkinson, post-stroke, TBI, cerebral palsy. Be practical: concrete activities, materials, example words or sentences in the patient\'s language, grade difficulty, measure progress, SMART goals, session structure, parent coaching, and behaviour tips. Ask at most one short clarifying question, only if essential. Mention red flags that need referral when relevant. Give options, never a final diagnosis: the therapist decides. Keep answers concise and organised with useful headings and bullets.';
}

/// One chat turn: r = 'u' (user) | 'm' (model)
class AiMsg {
  final String r;
  final String t;
  final String? s;
  final bool err;
  final String? act;
  AiMsg(this.r, this.t, {this.s, this.err = false, this.act});
}

class AiChip {
  final String label, prompt;
  final String? act;
  AiChip(this.label, this.prompt, [this.act]);
}

class AiTarget {
  final String label;
  final bool Function(String text) apply;
  AiTarget(this.label, this.apply);
}

String plainText(String t) {
  return t
      .replaceAllMapped(RegExp(r'\*\*(.+?)\*\*'), (m) => m.group(1)!)
      .replaceAll(RegExp(r'^#{1,6}\s*', multiLine: true), '')
      .replaceAll(RegExp(r'^\s*[*\u2022]\s+', multiLine: true), '- ')
      .replaceAll('`', '')
      .replaceAll(RegExp(r'\n{3,}'), '\n\n')
      .trim();
}

class AiState extends ChangeNotifier {
  bool open = false;
  bool busy = false;
  final List<AiMsg> msgs = [];
  String pid = '';
  String cid = '';
  String lang = 'auto';
  AiTarget? target;

  /// Registered by the report screen so the AI can see the current draft.
  List<Map<String, String>> Function()? reportDraft;

  /// Registered by the report screen: runs "Polish this report".
  Future<void> Function()? polishHandler;

  AiState() {
    lang = Store.get('speechcare_ai_lang') ?? 'auto';
    if (!['auto', 'ar', 'fr'].contains(lang)) lang = 'auto';
  }

  String get responseLang => lang == 'auto' ? app.lang : lang;

  void setLang(String l) {
    lang = ['auto', 'ar', 'fr'].contains(l) ? l : 'auto';
    Store.set('speechcare_ai_lang', lang);
    notifyListeners();
  }

  void reset() {
    msgs.clear();
    pid = '';
    cid = '';
    busy = false;
    open = false;
    target = null;
    notifyListeners();
  }

  void newChat() {
    msgs.clear();
    notifyListeners();
  }

  void pickPatient(String id) {
    pid = id;
    cid = '';
    msgs.clear();
    notifyListeners();
  }

  void ping() => notifyListeners();

  // ---------------------------------------------------------------- chips
  List<AiChip> chips() {
    final p = app.P(pid);
    final l = responseLang;
    final t = app.v.t;
    if (l == 'ar') {
      if (cid.isNotEmpty) return [AiChip('أسئلة نطرحها على الأولياء', 'حضّرلي أهم الأسئلة والملاحظات اللي لازم نسقسي عليهم في هاد اللقاء.')];
      if (p != null) {
        return [
          AiChip('أنا عالقة في الحصة، واش نقدر نجرّب؟', 'المريض ما راهوش يتقدّم أو ما راهوش متعاون. اقترح 5 حلول عملية نقدر نجرّبهم الآن، من الأسهل للأكثر تعقيداً، وكيّفهم حسب الحالة.'),
          AiChip('اقترح خطة علاجية', 'اقترح خطة علاجية منظمة فيها 3 إلى 4 أهداف وأنشطة لكل هدف وطريقة بسيطة لقياس التقدم.', 'plan'),
          AiChip('5 أنشطة للحصة الجاية', 'اقترح 5 أنشطة عملية للحصة القادمة مع هدف كل نشاط والوسائل اللازمة.'),
          AiChip('اكتبلي هدف للحصة الجاية', 'اكتب هدف واحد محدد وقابل للقياس، في 25 كلمة كحد أقصى. أعطني الهدف فقط.', 'goal'),
          AiChip('تمارين منزلية للأولياء', 'اقترح تمارين منزلية بسيطة للأولياء مع التكرار والنصائح.'),
          AiChip('اشرح التشخيص للأولياء', 'اشرح التشخيص والعلاج بكلام بسيط ولطيف للأولياء.'),
          AiChip('واش نقيّم من بعد؟', 'اقترح المهارات والمهام اللي لازم نقيّمها في المرحلة القادمة.'),
        ];
      }
      if (t == 'rep') {
        return [
          AiChip('حسّن صياغة التقرير', 'حسّن صياغة التقرير مع الحفاظ على كل المعلومات والنتائج.', 'polish'),
          AiChip('بسّط التقرير للأولياء', 'عاود اكتب التقرير بكلام بسيط ولطيف للأولياء من غير ما تبدّل الحقائق.'),
        ];
      }
      if (t == 'fin') return [AiChip('لخّص المداخيل', 'لخّص المداخيل في 3 نقاط وقدّم نصيحة عملية واحدة.')];
      if (t == 'cons') return [AiChip('أسئلة للأولياء', 'حضّر أسئلة أول لقاء مع أولياء طفل عنده صعوبات في النطق أو اللغة.')];
      return [
        AiChip('ساعدني نخطط حصة', 'عاونّي نخطط حصة علاج نطق مدتها 45 دقيقة.'),
        AiChip('الطفل ما يحبش يتعاون، واش ندير؟', 'طفل ما راهوش يحب يتعاون في الحصة. أعطيني أفكار باش نرجّع انتباهه.'),
        AiChip('اكتب رسالة للأولياء', 'اكتب رسالة قصيرة ولطيفة للأولياء على تقدم الطفل والتمرين المنزلي.'),
      ];
    }
    if (l == 'fr') {
      if (cid.isNotEmpty) return [AiChip('Questions à poser aux parents', 'Prépare les questions et observations clés pour cette consultation.')];
      if (p != null) {
        return [
          AiChip('Que puis-je essayer pendant la séance ?', 'Le patient ne progresse pas ou ne coopère pas. Propose 5 stratégies concrètes, de la plus simple à la plus élaborée, adaptées à ce patient.'),
          AiChip('Proposer un plan thérapeutique', 'Propose un plan structuré avec 3 à 4 objectifs, des activités et des critères de suivi.', 'plan'),
          AiChip('5 activités pour la prochaine séance', 'Propose 5 activités concrètes avec leur objectif et le matériel nécessaire.'),
          AiChip('Rédiger un objectif de séance', 'Rédige UN objectif précis et mesurable (25 mots maximum). Donne uniquement l’objectif.', 'goal'),
          AiChip('Exercices à domicile', 'Propose des exercices simples pour les parents, avec fréquence et conseils.'),
          AiChip('Expliquer le diagnostic aux parents', 'Explique le diagnostic et la prise en charge avec des mots simples et bienveillants.'),
          AiChip('Que faut-il évaluer ensuite ?', 'Propose les compétences et tâches à évaluer ensuite.'),
        ];
      }
      if (t == 'rep') {
        return [
          AiChip('Améliorer le rapport', 'Améliore la formulation sans modifier aucune information ni aucun résultat.', 'polish'),
          AiChip('Simplifier le rapport pour les parents', 'Réécris le rapport en termes simples et bienveillants sans changer les faits.'),
        ];
      }
      if (t == 'fin') return [AiChip('Résumer mes revenus', 'Résume les revenus en 3 points et donne un conseil pratique.')];
      if (t == 'cons') return [AiChip('Questions pour les parents', 'Liste les questions clés pour un premier entretien concernant les difficultés de parole ou de langage d’un enfant.')];
      return [
        AiChip('M’aider à préparer une séance', 'Aide-moi à préparer une séance d’orthophonie de 45 minutes.'),
        AiChip('Un enfant refuse de coopérer', 'Un enfant refuse de coopérer. Propose des idées pour retrouver son engagement.'),
        AiChip('Écrire aux parents', 'Rédige un message court et bienveillant aux parents sur les progrès et l’exercice à la maison.'),
      ];
    }
    if (cid.isNotEmpty) return [AiChip('Questions to ask the parents', 'List the key questions to ask and the observations to make during this meeting.')];
    if (p != null) {
      return [
        AiChip('I’m stuck in a session. What can I try now?', 'The patient is not progressing or is not cooperating in the session. Give me 5 immediate, practical strategies I can try right now, from simplest to more elaborate, adapted to this patient.'),
        AiChip('Suggest a treatment plan', 'Propose a structured treatment plan with 3 to 4 goals, activities for each goal and how to measure progress.', 'plan'),
        AiChip('5 activities for the next session', 'Propose 5 concrete activities for the next session, with the goal of each and the material needed.'),
        AiChip('Write a goal for my next session', 'Write ONE specific, measurable goal (max 25 words) for the next session. Output only the goal.', 'goal'),
        AiChip('Home exercises for parents', 'Write simple home exercises for the parents in plain language, with frequency and tips.'),
        AiChip('Explain the diagnosis simply for the parents', 'Explain this diagnosis and what the therapy does in simple, kind words for the parents.'),
        AiChip('What should I assess next?', 'What should I assess next, and with which tasks?'),
      ];
    }
    if (t == 'rep') {
      return [
        AiChip('Polish this report', '', 'polish'),
        AiChip('Make this report simpler for parents', 'Rewrite the current report draft in simple, kind language for the parents, keeping every fact.'),
      ];
    }
    if (t == 'fin') return [AiChip('Summarize my earnings', 'Summarize these earnings in 3 short bullet points and give one practical tip.')];
    if (t == 'cons') return [AiChip('Questions to ask the parents', 'List the key questions to ask the parents in a first meeting about a child with speech or language concerns.')];
    return [
      AiChip('Help me plan a session', 'Help me plan a 45-minute speech therapy session. Ask me for the age and condition if you need it.'),
      AiChip('A child refuses to cooperate. Ideas?', 'A child refuses to cooperate in the session. Give me practical ideas to regain engagement.'),
      AiChip('Write a message to the parents', 'Write a short, kind message to the parents about the child’s progress and the home task.'),
    ];
  }

  // ---------------------------------------------------------------- context
  String context() {
    final p = app.P(pid);
    final o = <String>['Screen: ${app.v.t}. Today: ${td()}.'];
    if (p != null) {
      final focus = app.condIds(p).map((i) => (app.condById(i)?[2] ?? '').toString()).join(' | ');
      o.add('PATIENT:\n${pctx(p)}\nNeuro-geo focus (affected regions and skills): $focus');
    }
    final c = app.cons.where((x) => x['id'] == cid).toList();
    if (c.isNotEmpty) {
      final q = app.P(c.first['pid']);
      o.add('CONSULTATION: type ${c.first['type']}; reason: ${truthy(c.first['reason']) ? c.first['reason'] : '-'}.${q != null ? '\nRelated patient:\n${pctx(q)}' : ''}');
    }
    if (['home', 'sess', 'today', 'cal'].contains(app.v.t)) {
      final L = app.apts.where((a) => a['date'] == app.v.day && a['status'] != 'cancelled').toList();
      if (L.isNotEmpty) {
        o.add('SESSIONS ON ${app.v.day}:\n${L.map((a) {
          final q = app.P(a['pid']) ?? <String, dynamic>{};
          final conds = q.isEmpty ? '' : app.cn(q).join('+');
          return '- ${a['time']}, ${conds.isEmpty ? 'condition?' : conds}, age ${app.age(q['birth'] as String?)}, goal: ${truthy(a['goal']) ? a['goal'] : '-'}${truthy(a['grp']) ? ' (group)' : ''}';
        }).join('\n')}');
      }
    }
    if (app.v.t == 'rep' && reportDraft != null) {
      final draft = reportDraft!();
      if (draft.isNotEmpty) {
        final nm = app.rn(app.P(app.v.pid));
        final txt = draft.map((s) => '## ${s['t']}\n${nm.trim().isNotEmpty ? (s['v'] ?? '').split(nm).join('[PATIENT]') : s['v']}').join('\n');
        o.add('REPORT DRAFT (${kModels[app.v.rm]![0]}):\n${txt.length > 2500 ? txt.substring(0, 2500) : txt}');
      }
    }
    if (app.v.t == 'fin') {
      final R = app.fdata();
      double sum(String k) => R.fold(0.0, (a, x) => a + nv(x[k]));
      o.add('FINANCE (${app.v.fp}): billed ${app.money(sum('price'))}, therapist share ${app.money(sum('mine'))}, sessions ${R.length}.');
    }
    return o.join('\n\n');
  }

  // -------------------------------------------------------------------- send
  Future<void> send(String txt, {String? label, String? act}) async {
    txt = txt.trim();
    if (txt.isEmpty || busy) return;
    msgs.add(AiMsg('u', txt, s: label));
    busy = true;
    notifyListeners();
    try {
      final hist = msgs.length > 14 ? msgs.sublist(msgs.length - 14) : List<AiMsg>.from(msgs);
      final out = await gem(hist.map((m) => <String, String>{'r': m.r, 't': m.t}).toList(), '${sysPrompt(null, lang)}\n\nCONTEXT (anonymous):\n${context()}');
      msgs.add(AiMsg('m', out, act: act));
    } catch (e) {
      msgs.add(AiMsg('m', aiErr(e), err: true));
    }
    busy = false;
    notifyListeners();
  }

  /// "Add to plan"
  void addToPlan(int i) {
    final p = app.P(pid);
    if (p == null) return;
    p['plan'] = '${truthy(p['plan']) ? '${p['plan']}\n\n' : ''}${msgs[i].t}';
    app.save();
    app.go();
  }

  /// "Set as next session goal". Returns a toast key.
  String setGoal(int i) {
    final p = app.P(pid);
    if (p == null) return '';
    final up = app.apts.where((a) => a['pid'] == p['id'] && a['status'] == 'scheduled' && str(a['date']).compareTo(td()) >= 0).toList()
      ..sort((x, y) => ('${x['date']}${x['time']}').compareTo('${y['date']}${y['time']}'));
    if (up.isEmpty) return 'No upcoming session for this patient.';
    var t = msgs[i].t.replaceAll(RegExp(r'^["“]|["”]$'), '').trim();
    if (t.length > 300) t = t.substring(0, 300);
    up.first['goal'] = t;
    app.save();
    app.go();
    return 'Goal set for the next session';
  }
}

final AiState ai = AiState();

// ================================================================= network
Future<String> gem(List<Map<String, String>> msgs, String sys) async {
  final key = orKey(), model = orModel();
  if (key.isEmpty) throw AiError('nokey');
  if (!isFreeModel(model)) throw AiError('paidmodel');
  final payload = <String, dynamic>{
    'model': model,
    'messages': [
      {'role': 'system', 'content': sys},
      ...msgs.map((m) => {'role': m['r'] == 'u' ? 'user' : 'assistant', 'content': m['t']}),
    ],
    'temperature': 0.4,
  };
  http.Response res;
  try {
    res = await http
        .post(Uri.parse(kOrEndpoint),
            headers: {'Content-Type': 'application/json', 'Authorization': 'Bearer $key', 'X-OpenRouter-Title': 'SpeechCare'}, body: jsonEncode(payload))
        .timeout(const Duration(seconds: 90));
  } catch (e) {
    throw AiError('net', e.toString());
  }
  Map<String, dynamic> d = {};
  try {
    final x = jsonDecode(utf8.decode(res.bodyBytes));
    if (x is Map) d = Map<String, dynamic>.from(x);
  } catch (_) {}
  if (res.statusCode < 200 || res.statusCode >= 300) {
    String m = 'OpenRouter request failed';
    final e = d['error'];
    if (e is Map && e['message'] != null) {
      m = e['message'].toString();
    } else if (e != null) {
      m = e.toString();
    } else if (d['message'] != null) {
      m = d['message'].toString();
    }
    throw AiError(res.statusCode, m);
  }
  final ch = d['choices'];
  String? answer;
  if (ch is List && ch.isNotEmpty && ch.first is Map) {
    final m = (ch.first as Map)['message'];
    if (m is Map && m['content'] is String) answer = m['content'] as String;
  }
  if (answer == null || answer.isEmpty) throw AiError('empty');
  return answer;
}

String aiErr(Object e) {
  dynamic c;
  var m = '';
  if (e is AiError) {
    c = e.code;
    m = e.msg;
  }
  var t = 'AI request failed. Please try again.';
  if (c == 'nokey') {
    t = 'SpeechCare AI is not available right now. Please try again later.';
  } else if (c == 401) {
    t = 'OpenRouter API key is invalid. Check your key in Settings → AI.';
  } else if (c == 402) {
    t = 'OpenRouter could not serve this free model right now. Try again later.';
  } else if (c == 429) {
    t = 'OpenRouter free request limit reached. Please wait and try again.';
  } else if (c == 'paidmodel') {
    t = 'To avoid charges, use openrouter/free or a model ID ending in :free.';
  } else if (c == 'net') {
    t = 'Could not connect to OpenRouter. Check internet connection.';
  } else if (c == 'empty') {
    t = 'AI returned no answer. Please try again.';
  } else if (c == 'format') {
    t = 'AI returned an unexpected report format. Please try again.';
  }
  return T(t) + (m.isNotEmpty ? ' [${m.length > 180 ? m.substring(0, 180) : m}]' : '');
}

/// Returns (message, ok)
Future<List<dynamic>> aiTest() async {
  try {
    await gem([
      {'r': 'u', 't': 'Reply with the single word OK.'}
    ], 'You are a connection test.');
    return ['${T('Connected. Model:')} ${orModel()}', true];
  } catch (e) {
    return [aiErr(e), false];
  }
}

// =========================================================== history / privacy
String deid(String text, J p) {
  var t = text;
  final names = <String>[str(p['name']), str(p['pre']), ...str(p['parents']).split(RegExp(r'[,;/&+]|\bet\b|\band\b|و'))].map((x) => x.trim()).where((x) => x.length > 2).toList();
  names.sort((a, b) => b.length.compareTo(a.length));
  for (var i = 0; i < names.length; i++) {
    t = t.split(names[i]).join(i < 2 ? '[PATIENT]' : '[PARENT]');
  }
  t = t.replaceAll(RegExp(r'(\+?\d[\d\s().-]{6,}\d)'), '[NUMBER]');
  t = t.replaceAll(RegExp(r'[\w.+-]+@[\w-]+\.[\w.-]+'), '[EMAIL]');
  return t;
}

String _line(dynamic s, int n) {
  final x = str(s).replaceAll(RegExp(r'\s+'), ' ').trim();
  return x.length > n ? '${x.substring(0, n - 1)}…' : x;
}

class HistEntry {
  final String date, place, src;
  final Map<String, dynamic> f;
  HistEntry(this.date, this.place, this.f, this.src);
}

List<HistEntry> historyEntries(J p) {
  final reps = app.srs.where((r) => r['pid'] == p['id']).toList();
  final byAid = <String, bool>{for (final r in reps) str(r['aid']): true};
  final out = reps.map((r) => HistEntry(str(r['date']), str(r['place']), r['f'] is Map ? Map<String, dynamic>.from(r['f'] as Map) : <String, dynamic>{}, 'report')).toList();
  for (final a in app.apts.where((a) => a['pid'] == p['id'] && a['status'] == 'done' && byAid[str(a['id'])] != true && (truthy(a['goal']) || truthy(a['remark'])))) {
    out.add(HistEntry(str(a['date']), str(a['place']), <String, dynamic>{'goals': str(a['goal']), 'obs': str(a['remark'])}, 'legacy'));
  }
  out.sort((x, y) => x.date.compareTo(y.date));
  return out;
}

String fmtEntry(HistEntry e, int i, J p, bool full) {
  final n = full ? 600 : 160;
  const keys = [
    ['acts', 'activities'],
    ['goals', 'goals'],
    ['resp', 'response'],
    ['prog', 'progress'],
    ['diff', 'difficulties'],
    ['ach', 'achievements'],
    ['obs', 'observations'],
    ['rec', 'recommendations'],
  ];
  final parts = keys.where((k) => truthy(e.f[k[0]])).map((k) => '${k[1]}: ${_line(deid(str(e.f[k[0]]), p), n)}').toList();
  return '#${i + 1} ${e.date}${e.place.isNotEmpty ? ' @${deid(e.place, p)}' : ''}${e.src == 'legacy' ? ' (brief note)' : ''} | ${parts.isEmpty ? 'no notes' : parts.join(' | ')}';
}

/// Compact context for the chat assistant: every completed session, newest first, capped.
String pctx(J p) {
  final E = historyEntries(p).reversed.toList();
  final D = app.apts.where((a) => a['pid'] == p['id'] && a['status'] == 'done').toList();
  const cap = 6500;
  var used = 0;
  final shown = <String>[];
  for (var i = 0; i < E.length; i++) {
    final l = '- ${fmtEntry(E[i], E.length - 1 - i, p, false)}';
    if (used + l.length > cap) break;
    used += l.length;
    shown.add(l);
  }
  final omitted = E.length - shown.length;
  final conds = app.cn(p).join('; ');
  return 'Age: ${app.age(p['birth'] as String?)}.\nConditions: ${conds.isEmpty ? 'not specified' : conds}.\nSymptoms: ${truthy(p['symptoms']) ? p['symptoms'] : '-'}.\nDiagnostic: ${truthy(p['diag']) ? p['diag'] : '-'}.\nCurrent treatment plan: ${truthy(p['plan']) ? p['plan'] : '-'}.\nFrequency: ${app.fq(p)}; sessions done: ${D.length}.\nSession history (newest first):\n${shown.isEmpty ? '- none' : shown.join('\n')}${omitted > 0 ? '\n($omitted older session(s) not shown here; the "AI progress review" button analyses the complete history.)' : ''}';
}

String _lname() => I18n.lang == 'ar' ? 'Algerian Arabic (Darija), clear and professional' : (I18n.lang == 'fr' ? 'French' : 'English');

Future<String> _ask(String prompt) => gem([
      {'r': 'u', 't': prompt}
    ], sysPrompt(I18n.lang));

String _struct() =>
    'Write a PROGRESS REPORT for the clinician with EXACTLY two parts, in ${_lname()}, using the headings "PART A — DOCUMENTED FACTS" and "PART B — AI INTERPRETATION".\n'
    'PART A may contain ONLY information explicitly present in the clinical history below (cite the date in brackets, e.g. [2026-03-04]). If something is not documented write "Not documented".\n'
    'PART B contains your analysis and recommendations; every statement there is an interpretation, not a fact.\n'
    'Cover, in this order: 1) initial performance, 2) current documented performance, 3) improvements over time, 4) areas with the strongest progress, 5) remaining difficulties, 6) activities associated with progress (only if the reports support it), 7) goals achieved, 8) goals not yet achieved, 9) suggested future activities, 10) recommendations for the next treatment period.\n'
    'Put items 1,2,3,5,7,8 mainly in PART A (facts) and 4,6,9,10 mainly in PART B; add a short interpretation under PART B for 1-3 and 5.\n'
    'NEVER invent diagnoses, scores, dates, observations, patient responses, activities, improvements or outcomes. Keep the placeholders [PATIENT], [PARENT], [NUMBER] unchanged. Plain text, no tables.';

/// AI analysis over the patient's COMPLETE history (chunked + summarised when large).
Future<String> aiProgressReview(J p, int entryCount, void Function(String) progress) async {
  final E = historyEntries(p);
  final conds = app.cn(p).join('; ');
  final head =
      'Patient: [PATIENT], age ${app.age(p['birth'] as String?)}. Conditions: ${conds.isEmpty ? 'not specified' : conds}. Initial symptoms: ${deid(truthy(p['symptoms']) ? str(p['symptoms']) : '-', p)}. Initial diagnostic/assessment: ${deid(truthy(p['diag']) ? str(p['diag']) : '-', p)}. Treatment plan/goals: ${deid(truthy(p['plan']) ? str(p['plan']) : '-', p)}. Program: ${app.fq(p)}, start ${truthy(p['start']) ? p['start'] : '?'}. Completed sessions on record: ${E.length}.';
  final lines = <String>[for (var i = 0; i < E.length; i++) fmtEntry(E[i], i, p, true)];
  final total = lines.join('\n').length;
  String history;
  if (total <= 14000) {
    history = lines.join('\n');
  } else {
    final keep = lines.sublist(lines.length > 6 ? lines.length - 6 : 0);
    final old = lines.sublist(0, lines.length > 6 ? lines.length - 6 : 0);
    final chunks = <List<String>>[];
    var cur = <String>[];
    var len = 0;
    for (final l in old) {
      if (len + l.length > 6000 && cur.isNotEmpty) {
        chunks.add(cur);
        cur = <String>[];
        len = 0;
      }
      cur.add(l);
      len += l.length;
    }
    if (cur.isNotEmpty) chunks.add(cur);
    final sums = <String>[];
    for (var i = 0; i < chunks.length; i++) {
      progress('${l3('Summarising earlier sessions ', 'Résumé des séances précédentes ', 'تلخيص الحصص السابقة ')}${i + 1}/${chunks.length}…');
      sums.add(await _ask('Summarise ONLY the documented facts in these session notes (keep dates in brackets, keep measurable details, do not interpret, do not add anything). Plain bullets, in ${_lname()}.\n\n${chunks[i].join('\n')}'));
    }
    history = 'EARLIER SESSIONS (summaries of documented facts):\n${sums.join('\n---\n')}\n\nMOST RECENT SESSIONS (full notes):\n${keep.join('\n')}';
  }
  progress(l3('Analysing…', 'Analyse en cours…', 'جاري التحليل…'));
  final out = await _ask('${_struct()}\n\nCLINICAL HISTORY\n$head\n\n$history');
  return out.replaceAllMapped(RegExp(r'\*\*(.+?)\*\*'), (m) => m.group(1)!).trim();
}

/// Report polishing: returns the raw JSON array decoded (list of strings) or throws AiError('format').
Future<List<dynamic>> aiPolishSections(String langCode, List<Map<String, String>> sections, String patientName) async {
  String mk(String x) => patientName.trim().isNotEmpty ? x.split(patientName).join('[PATIENT]') : x;
  final prompt =
      'You are editing a speech-language therapy report. Improve ONLY grammar, clarity, organisation, readability and professional tone, in ${langName(langCode)}. STRICT RULES: do not add, remove or change any clinical observation, diagnosis, patient performance, score, number, date, achievement or outcome; do not add information that is not in the text; keep every section\'s meaning; leave empty sections empty; if unsure keep the original wording. Keep the [PATIENT] placeholder unchanged. Return only a valid JSON array of strings: one polished text per section, same number and order. Sections:\n${jsonEncode(sections.map((x) => {'title': x['t'], 'text': mk(x['v'] ?? '')}).toList())}';
  final out = await gem([
    {'r': 'u', 't': prompt}
  ], sysPrompt(langCode));
  dynamic arr;
  try {
    arr = jsonDecode(out.replaceAll(RegExp(r'```json|```', caseSensitive: false), '').trim());
  } catch (_) {
    final m = RegExp(r'\[[\s\S]*\]').firstMatch(out);
    if (m != null) {
      try {
        arr = jsonDecode(m.group(0)!);
      } catch (_) {}
    }
  }
  if (arr is! List) throw AiError('format');
  return arr;
}

// ---- prompts used by the "Ask AI" buttons (always in the AI response language) ----
String l3r(String en, String fr, String ar) => l3x(ai.responseLang, en, fr, ar);

String planQ() => l3r(
    'Suggest a structured speech-therapy treatment plan: 3 to 4 goals, activities for each goal and a simple way to measure progress. Plain text only, no tables.',
    'Propose un plan de traitement orthophonique structuré : 3 à 4 objectifs, des activités pour chaque objectif et une façon simple de mesurer les progrès. Texte simple, sans tableaux.',
    'اقترح خطة علاجية منظمة فيها 3 إلى 4 أهداف وأنشطة لكل هدف وطريقة بسيطة لقياس التقدم. نص عادي بدون جداول.');

String actsQ() => l3r(
    'Suggest 6 practical activities for the next session. For each: the activity, its goal and the materials needed. Short plain text.',
    'Propose 6 activités pratiques pour la prochaine séance. Pour chacune : l’activité, son objectif et le matériel nécessaire. Texte court.',
    'اقترح 6 أنشطة عملية للحصة القادمة. لكل نشاط: النشاط وهدفه والوسائل اللازمة. نص قصير.');

String goalQ() => l3r(
    'Suggest ONE specific, measurable goal (max 25 words) for the next session. Output only the goal.',
    'Propose UN objectif thérapeutique précis et mesurable pour la prochaine séance (25 mots maximum). Donne uniquement l’objectif.',
    'اقترح هدفاً علاجياً واحداً محدداً وقابلاً للقياس للحصة القادمة (25 كلمة كحد أقصى). أعطني الهدف فقط.');
