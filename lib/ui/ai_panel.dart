import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../core/data_gen.dart';
import '../core/globals.dart';
import '../core/i18n.dart';
import '../core/theme.dart';
import '../core/util.dart';
import '../state/ai_service.dart';
import '../state/app_state.dart';
import 'widgets.dart';

String agU(String k) {
  final d = kAgTx[I18n.lang] ?? kAgTx['en']!;
  return d[k] ?? kAgTx['en']![k] ?? k;
}

/// agOpen(): the assistant is a full-height sheet above the current screen.
Future<void> agOpen({bool keep = false}) async {
  if (ai.open) return;
  ai.open = true;
  if (!keep) {
    final np = app.v.t == 'pat' ? (app.v.pid ?? '') : '';
    if (np != ai.pid) {
      ai.pid = np;
      ai.msgs.clear();
      ai.cid = '';
    }
  }
  ai.ping();
  final ctx = navigatorKey.currentContext;
  if (ctx == null) {
    ai.open = false;
    return;
  }
  await showModalBottomSheet<void>(
    context: ctx,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    constraints: const BoxConstraints(maxWidth: 520),
    builder: (c) => const AiPanel(),
  );
  ai.open = false;
  ai.ping();
}

/// askAI(): open the assistant for a patient / consultation and send a prompt right away.
Future<void> askAI({String pid = '', String cid = '', String label = '', String prompt = '', AiTarget? target}) async {
  ai.target = target;
  ai.pid = pid;
  ai.cid = cid;
  ai.msgs.clear();
  ai.busy = false;
  final wasOpen = ai.open;
  if (wasOpen) {
    ai.ping();
  } else {
    agOpen(keep: true);
  }
  await Future<void>.delayed(const Duration(milliseconds: 250));
  if (prompt.isNotEmpty) await ai.send(prompt, label: label.isEmpty ? null : label);
}

class MdText extends StatelessWidget {
  final String text;
  const MdText(this.text, {super.key});

  List<InlineSpan> inline(String s, TextStyle base) {
    final out = <InlineSpan>[];
    final re = RegExp(r'\*\*(.+?)\*\*');
    var last = 0;
    for (final m in re.allMatches(s)) {
      if (m.start > last) out.add(TextSpan(text: s.substring(last, m.start)));
      out.add(TextSpan(text: m.group(1), style: const TextStyle(fontWeight: FontWeight.bold)));
      last = m.end;
    }
    if (last < s.length) out.add(TextSpan(text: s.substring(last)));
    return out;
  }

  @override
  Widget build(BuildContext context) {
    const base = TextStyle(fontSize: 14.5, height: 1.45);
    final rows = <Widget>[];
    for (final line in text.split('\n')) {
      final h = RegExp(r'^#{1,4}\s*(.+)$').firstMatch(line);
      final b = RegExp(r'^\s*[-*•]\s+(.+)$').firstMatch(line);
      if (h != null) {
        rows.add(Padding(padding: const EdgeInsets.only(top: 4), child: Text.rich(TextSpan(children: inline(h.group(1)!, base), style: base.copyWith(fontWeight: FontWeight.bold)))));
      } else if (b != null) {
        rows.add(Padding(padding: const EdgeInsetsDirectional.only(start: 8, top: 1), child: Text.rich(TextSpan(style: base, children: [const TextSpan(text: '• '), ...inline(b.group(1)!, base)]))));
      } else if (line.trim().isEmpty) {
        rows.add(const SizedBox(height: 6));
      } else {
        rows.add(Text.rich(TextSpan(style: base, children: inline(line, base))));
      }
    }
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: rows);
  }
}

class AiPanel extends StatefulWidget {
  const AiPanel({super.key});
  @override
  State<AiPanel> createState() => _AiPanelState();
}

class _AiPanelState extends State<AiPanel> {
  final TextEditingController input = TextEditingController();
  final ScrollController scroll = ScrollController();
  int lastCount = -1;
  bool lastBusy = false;

  @override
  void dispose() {
    input.dispose();
    scroll.dispose();
    super.dispose();
  }

  void send() {
    final t = input.text.trim();
    if (t.isEmpty || ai.busy) return;
    input.clear();
    ai.send(t);
  }

  void chip(AiChip c) {
    if (c.act == 'polish') {
      Navigator.of(context).pop();
      ai.polishHandler?.call();
      return;
    }
    ai.send(c.prompt, label: c.label, act: c.act);
  }

  Widget bubble(int i, AiMsg m) {
    final p = pal(context);
    if (m.r == 'u') {
      return Align(
        alignment: AlignmentDirectional.centerEnd,
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 6),
          constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * .78),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
          decoration: BoxDecoration(color: p.sec, borderRadius: BorderRadius.circular(16)),
          child: Text(m.s ?? m.t, style: const TextStyle(color: Colors.white, fontSize: 14.5)),
        ),
      );
    }
    if (m.err) {
      return AppCard(margin: const EdgeInsets.symmetric(vertical: 6), borderColor: Pal.red, child: Text(m.t));
    }
    final hasP = app.P(ai.pid) != null;
    return AppCard(
      margin: const EdgeInsets.symmetric(vertical: 6),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Directionality(textDirection: ai.responseLang == 'ar' ? TextDirection.rtl : Directionality.of(context), child: MdText(m.t)),
        const SizedBox(height: 8),
        Wrap(spacing: 6, runSpacing: 6, children: [
          Btn(agU('copy'), () {
            Clipboard.setData(ClipboardData(text: m.t));
            toast('Copied');
          }, kind: BK.ghost, small: true),
          if (hasP && m.act == 'goal') Btn(agU('setGoal'), () {
            final r = ai.setGoal(i);
            if (r.isNotEmpty) toast(r);
          }, kind: BK.teal, small: true),
          if (hasP && m.act != 'goal') Btn(agU('addPlan'), () {
            ai.addToPlan(i);
            toast('Added to the treatment plan');
          }, kind: BK.ghost, small: true),
          if (ai.target != null)
            Btn('${T('Insert into')} ${T(ai.target!.label)}', () {
              if (ai.target!.apply(plainText(m.t))) {
                toast('Inserted');
                Navigator.of(context).pop();
              }
            }, kind: BK.teal, small: true),
        ]),
      ]),
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = pal(context);
    return ListenableBuilder(
      listenable: ai,
      builder: (context, _) {
        if (ai.msgs.length != lastCount || ai.busy != lastBusy) {
          lastCount = ai.msgs.length;
          lastBusy = ai.busy;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (scroll.hasClients) scroll.animateTo(scroll.position.maxScrollExtent, duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
          });
        }
        final chs = ai.chips();
        final pj = app.P(ai.pid);
        final h = MediaQuery.of(context).size.height;
        return Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
          child: Container(
            height: h * 0.92,
            decoration: BoxDecoration(color: p.page, borderRadius: const BorderRadius.vertical(top: Radius.circular(26))),
            child: Column(children: [
              // header
              Container(
                padding: const EdgeInsets.fromLTRB(14, 12, 6, 8),
                child: Row(children: [
                  Container(width: 38, height: 38, decoration: const BoxDecoration(shape: BoxShape.circle, gradient: LinearGradient(colors: [Pal.pri, Pal.tea])), child: Center(child: ic('spark', size: 20, color: Colors.white))),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      const Text('SpeechCare AI', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      Text(agU('subtitle'), style: TextStyle(fontSize: 12, color: p.mut)),
                    ]),
                  ),
                  IconBtn(ic('refresh', size: 20), () {
                    ai.newChat();
                  }, tooltip: agU('newChat')),
                  IconBtn(ic('x', size: 22), () => Navigator.of(context).pop(), tooltip: 'Close'),
                ]),
              ),
              // context + language
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 0, 14, 4),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  PickerField(
                    label: agU('context'),
                    value: ai.pid,
                    searchable: true,
                    items: [PickItem('', agU('general')), ...app.pats.map((x) => PickItem(str(x['id']), app.full(x)))],
                    onChanged: (v) => ai.pickPatient(v),
                  ),
                  Row(children: [
                    Text('${agU('answer')}  ', style: TextStyle(fontSize: 12, color: p.mut)),
                    Expanded(
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(children: [
                          PillBtn(agU('auto'), ai.lang == 'auto', () => ai.setLang('auto')),
                          PillBtn(agU('arabic'), ai.lang == 'ar', () => ai.setLang('ar')),
                          PillBtn(agU('french'), ai.lang == 'fr', () => ai.setLang('fr')),
                        ]),
                      ),
                    ),
                  ]),
                ]),
              ),
              // messages
              Expanded(
                child: ListView(
                  controller: scroll,
                  padding: const EdgeInsets.fromLTRB(14, 4, 14, 8),
                  children: [
                    if (ai.msgs.isEmpty) AppCard(margin: const EdgeInsets.symmetric(vertical: 4), child: Directionality(textDirection: ai.responseLang == 'ar' ? TextDirection.rtl : Directionality.of(context), child: Text(agU('welcome'), style: const TextStyle(fontSize: 14.5, height: 1.45)))),
                    for (var i = 0; i < ai.msgs.length; i++) bubble(i, ai.msgs[i]),
                    if (ai.busy) AppCard(child: Center(child: typingDots(context))),
                  ],
                ),
              ),
              // composer
              Container(
                padding: const EdgeInsets.fromLTRB(12, 6, 12, 8),
                decoration: BoxDecoration(color: p.card, border: Border(top: BorderSide(color: p.line))),
                child: SafeArea(
                  top: false,
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    if (chs.isNotEmpty)
                      PillRow(chs.map((c) => PillBtn(c.label, false, () => chip(c))).toList()),
                    Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
                      Expanded(
                        child: TextField(
                          controller: input,
                          minLines: 1,
                          maxLines: 4,
                          textInputAction: TextInputAction.send,
                          onSubmitted: (_) => send(),
                          decoration: inputDeco(context, hint: agU('placeholder')),
                          style: const TextStyle(fontSize: 15),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Btn(null, ai.busy ? null : send, child: ic('send', size: 20, color: Colors.white)),
                    ]),
                    Padding(padding: const EdgeInsets.only(top: 6), child: Text(agU('disclaimer'), style: TextStyle(fontSize: 11, color: p.mut))),
                    Text(agU('privacy'), style: TextStyle(fontSize: 11, color: p.mut)),
                  ]),
                ),
              ),
              if (pj != null) const SizedBox.shrink(),
            ]),
          ),
        );
      },
    );
  }
}
