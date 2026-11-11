import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import '../core/data_gen.dart';
import '../core/globals.dart';
import '../core/store.dart';
import '../core/theme.dart';
import '../core/util.dart';
import '../state/app_state.dart';
import 'ai_panel.dart';
import 'widgets.dart';

/// Port of ACT_RUN: the state of the activity currently being played (kept in memory only).
class ActRun {
  String id = '';
  int index = 0, score = 0, choice = -1, seq = 0, scene = 0, q = 0, sound = 0, stage = 0;
  bool revealed = false, finished = false, seqOk = false;
  List<int> order = [];
  String? prompt;
}

final ActRun run = ActRun();
final math.Random _r = math.Random();
FlutterTts? _tts;

Future<void> actSpeak(String text) async {
  try {
    _tts ??= FlutterTts();
    final t = _tts!;
    var ok = false;
    for (final l in ['ar-DZ', 'ar-SA', 'ar']) {
      try {
        final r = await t.isLanguageAvailable(l);
        if (r == true || r == 1) {
          await t.setLanguage(l);
          ok = true;
          break;
        }
      } catch (_) {}
    }
    if (!ok) return toast('اقرأ الكلمة بصوتك، خاصية القراءة غير متاحة في هذا الهاتف.');
    await t.setSpeechRate(0.4);
    await t.stop();
    await t.speak(text);
  } catch (_) {
    toast('اقرأ الكلمة بصوتك، خاصية القراءة غير متاحة.');
  }
}

Map<String, dynamic> readRuns() {
  try {
    final x = jsonDecode(Store.get('speechcare_activity_runs') ?? '{}');
    return x is Map ? Map<String, dynamic>.from(x) : <String, dynamic>{};
  } catch (_) {
    return <String, dynamic>{};
  }
}

void actRecord(String id, int score, int total) {
  try {
    final a = readRuns();
    final cur = a[id] is Map ? Map<String, dynamic>.from(a[id] as Map) : <String, dynamic>{'runs': 0, 'best': 0, 'last': ''};
    cur['runs'] = iv(cur['runs']) + 1;
    final pct = (score / math.max(1, total) * 100).round();
    cur['best'] = math.max(iv(cur['best']), pct);
    cur['last'] = td();
    a[id] = cur;
    Store.set('speechcare_activity_runs', jsonEncode(a));
    app.sync.onActRuns();
  } catch (_) {}
}

void actStart(String id) {
  run
    ..id = id
    ..index = 0
    ..score = 0
    ..choice = -1
    ..revealed = false
    ..finished = false
    ..seqOk = false
    ..scene = 0
    ..q = 0
    ..sound = 0
    ..stage = 0
    ..seq = _r.nextInt(kActSeqs.length)
    ..prompt = null
    ..order = [];
  if (id == 'sequence') run.order = List<int>.generate((kActSeqs[run.seq]['cards'] as List).length, (i) => i)..shuffle(_r);
  app.go();
}

List<Map<String, dynamic>> actBank() => kActBank[run.id] ?? const <Map<String, dynamic>>[];

class ActivitiesScreen extends StatelessWidget {
  const ActivitiesScreen({super.key});
  @override
  Widget build(BuildContext context) {
    return Directionality(textDirection: TextDirection.rtl, child: screenList([run.id.isNotEmpty ? _play(context) : _library(context)]));
  }

  Widget _hero(String top, String title, String sub, {double size = 21}) => Container(
        width: double.infinity,
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(borderRadius: BorderRadius.circular(20), gradient: const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFF0D746E), Color(0xFF214C7E)])),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          if (top.isNotEmpty) Text(top, style: const TextStyle(color: Colors.white70, fontSize: 12)),
          Text(title, style: TextStyle(color: Colors.white, fontSize: size, fontWeight: FontWeight.bold)),
          if (sub.isNotEmpty) Text(sub, style: const TextStyle(color: Colors.white70, fontSize: 13)),
        ]),
      );

  Widget _library(BuildContext context) {
    final p = pal(context);
    final cat = app.v.actCat;
    final runs = readRuns();
    final items = kActList.where((x) => cat == 'all' || x['cat'] == cat).toList();
    final cards = items.map((x) {
      final r = runs[x['id']];
      return Material(
        color: p.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18), side: BorderSide(color: p.line)),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: () {
            haptic();
            actStart(x['id'] as String);
          },
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(x['emoji'] as String, style: const TextStyle(fontSize: 28)),
              const SizedBox(height: 4),
              Text(x['title'] as String, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
              const SizedBox(height: 2),
              Text(x['desc'] as String, style: TextStyle(fontSize: 12, color: p.mut)),
              if (r is Map) Padding(padding: const EdgeInsets.only(top: 6), child: ChipW('تجرّب ${r['runs']} مرات')),
            ]),
          ),
        ),
      );
    }).toList();
    final rows = <Widget>[];
    for (var i = 0; i < cards.length; i += 2) {
      rows.add(Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: IntrinsicHeight(child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [Expanded(child: cards[i]), const SizedBox(width: 10), Expanded(child: i + 1 < cards.length ? cards[i + 1] : const SizedBox())])),
      ));
    }
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _hero('SpeechCare · مكتبة خاصة', 'نتعلّمو باللعب 🎯', 'أنشطة أصلية بالعربية والدارجة الجزائرية للنطق، اللغة، الفهم والتواصل. المعالج يختار النشاط ويكيّفو حسب كل حالة.'),
      AppCard(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('اختار المجال', style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 6),
          Wrap(spacing: 6, runSpacing: 6, children: [
            for (final x in kActCats)
              PillBtn(x[1], cat == x[0], () {
                app.v.actCat = x[0];
                app.go();
              }),
          ]),
        ]),
      ),
      ...rows,
      AppCard(margin: const EdgeInsets.only(top: 2, bottom: 10), child: Text('تقدر تستعمل النشاط فردياً أو مع مجموعة، والمعالج يقرأ التعليمات ويقيّم الاستجابة بالملاحظة. هذي الأنشطة مبنية بمحتوى SpeechCare مستقل؛ ما فيهاش صور أو ملفات من مواقع أخرى.', style: TextStyle(fontSize: 13, color: p.mut))),
      Btn('اسأل المساعد الذكي على نشاط مناسب 🤖', () => agOpen(), kind: BK.teal, full: true),
    ]);
  }

  Widget _play(BuildContext context) {
    final p = pal(context);
    final meta = kActList.firstWhere((x) => x['id'] == run.id, orElse: () => <String, dynamic>{});
    if (meta.isEmpty) {
      run.id = '';
      return _library(context);
    }
    Widget content;
    if (run.id == 'sound') {
      content = _sound(context);
    } else if (run.id == 'sequence') {
      content = _sequence(context);
    } else if (run.id == 'detective' || run.id == 'chat') {
      content = _open(context);
    } else {
      content = _quiz(context);
    }
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Align(
        alignment: AlignmentDirectional.centerStart,
        child: Btn('→ رجوع لمكتبة الأنشطة', () {
          run.id = '';
          app.go();
        }, kind: BK.ghost, small: true),
      ),
      const SizedBox(height: 10),
      _hero('', '${meta['emoji']} ${meta['title']}', meta['goal'] as String, size: 19),
      content,
      Text('ملاحظة مهنية: النشاط وسيلة للممارسة والنقاش فقط. اختاروا الصعوبة حسب قدرات الشخص، ودوّنوا الملاحظة السريرية بشكل مستقل. ما تعتبرش النتيجة تشخيصاً أو مقياساً وحيداً للتقدم.', style: TextStyle(fontSize: 12.5, color: p.mut)),
    ]);
  }

  Widget _choice(BuildContext context, String t, VoidCallback? f, {bool correct = false, bool wrong = false}) {
    final p = pal(context);
    final bg = correct ? alpha(hex('#2fb872'), .22) : (wrong ? alpha(Pal.red, .2) : p.card);
    final bd = correct ? hex('#2fb872') : (wrong ? Pal.red : p.line);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: bg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14), side: BorderSide(color: bd, width: correct || wrong ? 2 : 1)),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: f,
          child: Container(constraints: const BoxConstraints(minHeight: 52), width: double.infinity, alignment: AlignmentDirectional.centerStart, padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10), child: Text(t, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600))),
        ),
      ),
    );
  }

  Widget _feedback(BuildContext context, Widget child) => Container(
        width: double.infinity,
        margin: const EdgeInsets.symmetric(vertical: 8),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(color: alpha(Pal.tea, .12), borderRadius: BorderRadius.circular(12)),
        child: child,
      );

  Widget _quiz(BuildContext context) {
    final bank = actBank();
    if (bank.isEmpty) return const SizedBox.shrink();
    final p = pal(context);
    if (run.finished) {
      return AppCard(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('🎉', style: TextStyle(fontSize: 36)),
          const Text('برافو عليك!', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          Text('جاوبت صح على ${run.score} من ${bank.length}.'),
          const SizedBox(height: 4),
          Text('النتيجة غير مؤشر بسيط على هاد الجولة، وماشي تقييم للتطور أو تشخيص.', style: TextStyle(color: p.mut, fontSize: 13)),
          const SizedBox(height: 8),
          Wrap(spacing: 8, runSpacing: 8, children: [Btn('عاود النشاط', () => actStart(run.id)), Btn('رجوع للأنشطة', () {
            run.id = '';
            app.go();
          }, kind: BK.ghost)]),
        ]),
      );
    }
    final q = bank[run.index];
    final opts = (q['opts'] as List).map((e) => e.toString()).toList();
    final a = q['a'] as int;
    return AppCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [ChipW('السؤال ${run.index + 1} من ${bank.length}'), ChipW('النقاط: ${run.score}')]),
        const SizedBox(height: 8),
        ProgressBar((run.index + (run.revealed ? 1 : 0)) / bank.length),
        const SizedBox(height: 10),
        Text(q['q'] as String, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
        if (truthy(q['prompt'])) Padding(padding: const EdgeInsets.only(top: 4), child: Mut(q['prompt'] as String)),
        const SizedBox(height: 10),
        for (var i = 0; i < opts.length; i++)
          _choice(context, opts[i], run.revealed
              ? null
              : () {
                  if (run.revealed) return;
                  run.choice = i;
                  run.revealed = true;
                  if (i == a) run.score++;
                  app.go();
                }, correct: run.revealed && i == a, wrong: run.revealed && i == run.choice && i != a),
        if (run.revealed) ...[
          _feedback(context, Text('${run.choice == a ? '✅ إجابة صحيحة!' : '💡 نحاولو مرة أخرى.'}\n${q['why']}')),
          Btn(run.index == bank.length - 1 ? 'شوف النتيجة' : 'السؤال التالي', () {
            if (run.index < bank.length - 1) {
              run.index++;
              run.choice = -1;
              run.revealed = false;
            } else {
              actRecord(run.id, run.score, bank.length);
              run.finished = true;
            }
            app.go();
          }),
        ],
      ]),
    );
  }

  Widget _sound(BuildContext context) {
    final x = kActSounds[run.sound];
    final st = ['المقاطع', 'الكلمات', 'الجمل'];
    final list = (run.stage == 0 ? x['sy'] : (run.stage == 1 ? x['words'] : x['sent']) as List).cast<dynamic>().map((e) => e.toString()).toList();
    final p = pal(context);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      AppCard(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('الصوت المستهدف: «${x['s']}»', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 4),
          Mut('اختاروا المرحلة اللي تناسب الطفل. المعالج ينطق النموذج، والطفل يحاول بلا ضغط. إذا ما كانش صوت عربي في الهاتف، اقرا المثال بنفسك.'),
          const SizedBox(height: 8),
          Wrap(spacing: 6, children: [
            for (var i = 0; i < st.length; i++)
              PillBtn(st[i], run.stage == i, () {
                run.stage = i;
                app.go();
              }),
          ]),
          const SizedBox(height: 8),
          for (final w in list) _choice(context, '$w   🔊 اسمع', () => actSpeak(w)),
          _feedback(context, Text('نصيحة: إذا صعبت الكلمة، ارجعوا للمقطع أو الصوت وحده. سجّلوا الملاحظة نوعياً وما تعتمدوش على عدد النقرات وحده.', style: TextStyle(fontSize: 13, color: p.ink))),
        ]),
      ),
      AppCard(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('اختار صوت آخر', style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 6),
          Wrap(spacing: 6, runSpacing: 6, children: [
            for (var i = 0; i < kActSounds.length; i++)
              PillBtn(kActSounds[i]['s'] as String, run.sound == i, () {
                run.sound = i;
                app.go();
              }),
          ]),
        ]),
      ),
    ]);
  }

  Widget _sequence(BuildContext context) {
    final s = kActSeqs[run.seq];
    final cards = (s['cards'] as List).map((e) => (e as List).map((z) => z.toString()).toList()).toList();
    final order = (s['order'] as List).map((e) => e as int).toList();
    final p = pal(context);
    void move(int i, int d) {
      final j = i + d;
      if (j < 0 || j >= run.order.length) return;
      final t = run.order[i];
      run.order[i] = run.order[j];
      run.order[j] = t;
      app.go();
    }

    return AppCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('رتّب الصور من الأول حتى للآخر باستعمال السهمين.'),
        const SizedBox(height: 8),
        for (var i = 0; i < run.order.length; i++)
          Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(color: p.chip, borderRadius: BorderRadius.circular(14)),
            child: Row(children: [
              Text(cards[run.order[i]][0], style: const TextStyle(fontSize: 24)),
              const SizedBox(width: 10),
              Expanded(child: Text(cards[run.order[i]][1], style: const TextStyle(fontSize: 15))),
              IconButton(onPressed: () => move(i, -1), icon: const Icon(Icons.arrow_upward), tooltip: 'طلع'),
              IconButton(onPressed: () => move(i, 1), icon: const Icon(Icons.arrow_downward), tooltip: 'هبط'),
            ]),
          ),
        if (run.revealed) ...[
          _feedback(context, Text('${run.seqOk ? '✅ ترتيب مليح!' : 'الترتيب يحتاج مراجعة. الترتيب المقترح:'}\n${order.map((n) => cards[n][1]).join(' ← ')}')),
          Btn('حكاية جديدة', () => actStart('sequence')),
        ] else
          Btn('تحقّق من الترتيب', () {
            final ok = List.generate(run.order.length, (i) => run.order[i] == order[i]).every((e) => e);
            run.revealed = true;
            run.seqOk = ok;
            if (ok) {
              run.score = 1;
              actRecord('sequence', 1, 1);
            }
            app.go();
          }),
      ]),
    );
  }

  Widget _open(BuildContext context) {
    final det = run.id == 'detective';
    final a = det ? kActScenes[run.scene] : null;
    final title = a != null ? a['title'] as String : 'سؤال للنقاش';
    final qs = det ? (a!['qs'] as List).map((e) => e.toString()).toList() : kActChat;
    final prompt = det ? qs[run.q % qs.length] : (run.prompt ?? kActChat[0]);
    return AppCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Center(child: Text(a != null ? a['emoji'] as String : '🎤 💬 🤔', style: const TextStyle(fontSize: 30))),
        const SizedBox(height: 4),
        Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        const SizedBox(height: 4),
        Text(prompt, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        Mut(det ? 'خلي الطفل يوصف ويخمّم. ما كاش جواب واحد صحيح لكل الأسئلة المفتوحة.' : 'جاوب بتفصيل، ومن بعد اسأل المعالج سؤال على نفس الموضوع.'),
        const SizedBox(height: 8),
        TextField(minLines: 3, maxLines: 5, decoration: inputDeco(context, hint: 'اكتب ملاحظة قصيرة (اختياري)…')),
        const SizedBox(height: 8),
        Wrap(spacing: 8, runSpacing: 8, children: [
          if (det)
            Btn('مشهد آخر', () {
              run.scene = (run.scene + 1) % kActScenes.length;
              run.q = 0;
              app.go();
            }, kind: BK.ghost)
          else
            Btn('سؤال جديد 🎲', () {
              run.prompt = kActChat[_r.nextInt(kActChat.length)];
              app.go();
            }, kind: BK.ghost),
          Btn('السؤال التالي', () {
            final n = det ? qs.length : kActChat.length;
            run.q = (run.q + 1) % n;
            if (!det) run.prompt = kActChat[run.q];
            app.go();
          }),
        ]),
      ]),
    );
  }
}
