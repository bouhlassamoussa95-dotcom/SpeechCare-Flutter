import 'package:flutter/material.dart';
import '../core/data_gen.dart';
import '../core/i18n.dart';
import '../core/theme.dart';
import '../core/util.dart';
import '../state/ai_service.dart';
import '../state/app_state.dart';
import 'ai_panel.dart';
import 'forms_misc.dart';
import 'widgets.dart';

String toyCat(String k) {
  for (final c in kToyCats) {
    if (c[0] == k) return T(c[1]);
  }
  return T(kToyCats.last[1]);
}

class ToysScreen extends StatelessWidget {
  const ToysScreen({super.key});

  List<String> acts(J t) => t['acts'] is List ? (t['acts'] as List).map((e) => str(e)).toList() : <String>[];

  void askActs(J t) {
    final id = str(t['id']);
    final cat = toyCat(str(t['cat']));
    final what = truthy(t['name']) ? '"${t['name']}" ($cat)' : '${l3('a therapy toy in the category ', 'un jouet thérapeutique de la catégorie ', 'لعبة علاجية من فئة ')}"$cat"';
    askAI(
      label: l3('Activities with this toy', 'Activités avec ce jouet', 'أنشطة بهذه اللعبة'),
      prompt: '${l3('Suggest 6 short speech-therapy activities that use this toy or material: ', 'Propose 6 courtes activités d’orthophonie utilisant ce jouet ou matériel : ', 'اقترح 6 أنشطة قصيرة للنطق تستعمل هذه اللعبة أو الأداة: ')}$what${l3('. One activity per line, at most 8 words each, no numbering, no explanations.', '. Une activité par ligne, 8 mots maximum, sans numérotation ni explications.', '. نشاط واحد في كل سطر، 8 كلمات كحد أقصى، بدون ترقيم أو شرح.')}',
      target: AiTarget('Linked activities', (txt) {
        final tt = app.toysL.where((x) => x['id'] == id).toList();
        if (tt.isEmpty) return false;
        final lines = txt
            .split('\n')
            .where((l) => !RegExp(r'^\s*(#{1,6}\s|\*\*[^*]+\*\*:?\s*$)').hasMatch(l) && !RegExp(r':\s*$').hasMatch(l.trim()))
            .map((l) => plainText(l).replaceFirst(RegExp(r'^\s*(?:[-\u2022*]|\d+[.)\-])\s*'), '').trim())
            .where((l) => l.length > 1 && l.length < 100)
            .take(8)
            .toList();
        if (lines.isEmpty) return false;
        final cur = acts(tt.first).where((a) => a.trim().isNotEmpty).toList();
        for (final l in lines) {
          if (!cur.contains(l)) cur.add(l);
        }
        tt.first['acts'] = cur;
        app.save();
        app.go();
        return true;
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = pal(context);
    final L = app.toysL;
    return screenList([
      Padding(padding: const EdgeInsets.fromLTRB(2, 0, 2, 10), child: Mut(T('Therapy toys and materials'))),
      if (L.isEmpty) emptyCard(T('No toys yet. Tap + Toy.')),
      for (final t in L)
        secCard(
          hex('#c9407a'),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            InkWell(
              onTap: () => toyForm(id: str(t['id'])),
              child: Row(children: [
                ClipRRect(borderRadius: BorderRadius.circular(14), child: SizedBox(width: 84, height: 84, child: truthy(t['img']) ? ToyImage(str(t['img'])) : Container(color: p.chip, child: Icon(Icons.inventory_2_outlined, size: 34, color: Pal.pri)))),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [
                      Expanded(child: truthy(t['name']) ? Text(str(t['name']), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)) : Mut(T('Untitled toy'), size: 15)),
                      Icon(Icons.chevron_right, size: 18, color: p.mut),
                    ]),
                    const SizedBox(height: 4),
                    ChipW(toyCat(str(t['cat']))),
                  ]),
                ),
              ]),
            ),
            Padding(padding: const EdgeInsets.fromLTRB(0, 8, 0, 6), child: Mut(T('Linked activities'))),
            for (var i = 0; i < acts(t).length; i++) _ActRow(key: ValueKey('ar_${t['id']}_${i}_${acts(t)[i]}'), toy: t, index: i),
            Wrap(spacing: 6, runSpacing: 6, children: [
              Btn(T('Add activity'), () {
                final a = (t['acts'] is List) ? t['acts'] as List : <dynamic>[];
                a.add('');
                t['acts'] = a;
                app.go();
              }, small: true, icon: ic('plus', size: 16)),
              Btn(T('Suggest activities with AI'), () => askActs(t), kind: BK.ghost, small: true, icon: ic('chat', size: 14)),
            ]),
          ]),
        ),
    ]);
  }
}

class _ActRow extends StatefulWidget {
  final J toy;
  final int index;
  const _ActRow({super.key, required this.toy, required this.index});
  @override
  State<_ActRow> createState() => _ActRowState();
}

class _ActRowState extends State<_ActRow> {
  late final TextEditingController c;
  final FocusNode fn = FocusNode();

  List get acts => widget.toy['acts'] as List;

  @override
  void initState() {
    super.initState();
    c = TextEditingController(text: str(acts[widget.index]));
    fn.addListener(() {
      if (!fn.hasFocus) commit();
    });
  }

  void commit() {
    if (widget.index >= acts.length) return;
    final v = c.text.trim();
    if (v.isEmpty) {
      acts.removeAt(widget.index);
      app.save();
      app.go();
    } else if (v != str(acts[widget.index])) {
      acts[widget.index] = v;
      app.save();
    }
  }

  @override
  void dispose() {
    fn.dispose();
    c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(children: [
        Expanded(
          child: TextField(
            controller: c,
            focusNode: fn,
            autofocus: c.text.isEmpty,
            onSubmitted: (_) => commit(),
            style: const TextStyle(fontSize: 15),
            decoration: inputDeco(context, hint: T('Activity name')),
          ),
        ),
        DangerBtn(T('Remove'), () {
          if (widget.index < acts.length) {
            acts.removeAt(widget.index);
            app.save();
            app.go();
          }
        }, iconOnly: true),
      ]),
    );
  }
}
