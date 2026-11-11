import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';
import '../core/data_gen.dart';
import '../core/globals.dart';
import '../core/i18n.dart';
import '../core/theme.dart';
import '../core/util.dart';
import '../state/ai_service.dart';
import '../state/app_state.dart';
import '../state/docx_builder.dart';
import '../state/logic.dart';
import 'ai_panel.dart';
import 'cards.dart';
import 'forms_patient.dart';
import 'widgets.dart';

String fLabel(List<String> f) => l3(f[1], f[2], f[3]);

List<PickItem> wpItems({bool withNone = false}) => [
      if (withNone) const PickItem('', '—'),
      ...app.places.map((w) => PickItem(str(w['id']), str(w['n']))),
    ];

// =============================================================== consultation
void coForm({String? id}) => showSheet<void>((c) => CoForm(id: id));

class CoForm extends StatefulWidget {
  final String? id;
  const CoForm({super.key, this.id});
  @override
  State<CoForm> createState() => _CoFormState();
}

class _CoFormState extends State<CoForm> {
  late final J c;
  late String type, date, time, place, status, pid;
  late final TextEditingController name, pre, parent, phone, reason, fee;
  bool get edit => widget.id != null && widget.id!.isNotEmpty;

  @override
  void initState() {
    super.initState();
    c = edit
        ? app.cons.firstWhere((x) => x['id'] == widget.id)
        : <String, dynamic>{'type': 'new', 'name': '', 'pre': '', 'parent': '', 'phone': '', 'pid': '', 'date': ['cal', 'home', 'sess', 'cons'].contains(app.v.t) ? app.v.day : td(), 'time': '10:00', 'place': app.places.isEmpty ? '' : str(app.places.first['n']), 'reason': '', 'fee': '', 'status': 'scheduled'};
    TextEditingController t(String k) => TextEditingController(text: str(c[k]));
    type = str(c['type']);
    date = str(c['date']);
    time = str(c['time']);
    place = str(c['place']);
    status = str(c['status']);
    pid = str(c['pid']);
    name = t('name');
    pre = t('pre');
    parent = t('parent');
    phone = t('phone');
    reason = t('reason');
    fee = t('fee');
  }

  @override
  void dispose() {
    for (final x in [name, pre, parent, phone, reason, fee]) {
      x.dispose();
    }
    super.dispose();
  }

  void save() {
    final J o = <String, dynamic>{
      'type': type,
      'name': name.text.trim(),
      'pre': pre.text.trim(),
      'parent': parent.text.trim(),
      'phone': phone.text.trim(),
      'pid': type == 'parent' ? pid : '',
      'date': date,
      'time': time,
      'place': place,
      'reason': reason.text.trim(),
      'fee': fee.text.trim(),
      'status': status,
    };
    if (type == 'parent' && str(o['pid']).isEmpty) return toast('Choose a patient');
    if (type != 'parent' && str(o['name']).isEmpty) return toast('Enter a name');
    if (date.isEmpty) return toast('Pick a date');
    app.saveCo(edit ? widget.id! : '', o);
    cs(context);
  }

  @override
  Widget build(BuildContext context) {
    final names = <String>{...app.places.map((x) => str(x['n'])), if (place.isNotEmpty) place}.toList();
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      sheetTitle(edit ? T('Edit consultation') : T('New consultation')),
      Seg([SegItem('new', T('New patient')), SegItem('parent', T('Parent meeting')), SegItem('other', T('Other'))], type, (v) => setState(() => type = v)),
      if (type == 'parent')
        PickerField(label: T('Patient'), value: pid, items: [const PickItem('', '—'), ...app.pats.map((p) => PickItem(str(p['id']), app.full(p)))], onChanged: (v) => setState(() => pid = v))
      else ...[
        twoCol(LField(name, label: T('Name')), LField(pre, label: T('Prename'))),
        LField(parent, label: T('Parents’ names')),
        LField(phone, label: T('Parents’ phone'), keyboard: TextInputType.phone),
      ],
      twoCol(DateField(T('Date'), date, (v) => setState(() => date = v)), TimeField(T('Time'), time, (v) => setState(() => time = v))),
      PickerField(
        label: T('Center / daycare'),
        value: place,
        addPlace: true,
        items: names.map((x) => PickItem(x, x)).toList(),
        onChanged: (v) async {
          if (v == kAddPlaceKey) {
            final n = await addPlaceDialog(context);
            if (n != null) setState(() => place = n);
          } else {
            setState(() => place = v);
          }
        },
      ),
      LField(reason, label: T('Reason / topic'), minLines: 2, maxLines: 5),
      LField(fee, label: T('Fee'), keyboard: const TextInputType.numberWithOptions(decimal: true)),
      PickerField(label: T('Status'), value: status, items: [for (final k in ['scheduled', 'done', 'absent', 'cancelled']) PickItem(k, T(kSt[k]!))], onChanged: (v) => setState(() => status = v)),
      if (edit)
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Wrap(spacing: 8, runSpacing: 8, children: [
            if (type != 'parent') Btn(T('Create patient profile'), () {
              cs(context);
              ptForm(pre: <String, dynamic>{'name': c['name'], 'pre': c['pre'], 'parents': c['parent'], 'phone': c['phone'], 'symptoms': c['reason'], 'place': c['place'], 'pt': (app.wpByName(str(c['place'])) ?? <String, dynamic>{})['t'] ?? 'center'});
            }, kind: BK.teal, small: true),
            Btn(T('Ask AI'), () => askAI(cid: str(c['id']), label: l3r('Questions to ask the parents', 'Questions à poser aux parents', 'أسئلة للأولياء'), prompt: l3r('List the key questions to ask the parents and the observations to make during this meeting.', 'Liste les questions clés à poser aux parents et les observations à faire pendant cet entretien.', 'اكتب أهم الأسئلة التي نطرحها على الأولياء والملاحظات أثناء هذا اللقاء.')), kind: BK.ghost, small: true, icon: ic('chat', size: 14)),
          ]),
        ),
      Wrap(spacing: 8, runSpacing: 8, children: [
        Btn(T('Save'), save),
        Btn(T('Cancel'), () => cs(context), kind: BK.ghost),
        if (edit)
          DangerBtn(T('Delete'), () {
            app.delCo(widget.id!);
            cs(context);
          }),
      ]),
    ]);
  }
}

// ======================================================================= toys
void toyForm({String? id}) => showSheet<void>((c) => ToyForm(id: id));

Future<String?> pickToyPhoto(ImageSource src) async {
  try {
    final x = await ImagePicker().pickImage(source: src, maxWidth: 1200, imageQuality: 85);
    if (x == null) return null;
    final bytes = await x.readAsBytes();
    return await compressToDataUrl(bytes);
  } catch (_) {
    return null;
  }
}

Uint8List _resize(Uint8List b) {
  final im = img.decodeImage(b);
  if (im == null) return b;
  final m = im.width > im.height ? im.width : im.height;
  final r = m > 480 ? img.copyResize(im, width: im.width >= im.height ? 480 : null, height: im.height > im.width ? 480 : null) : im;
  return Uint8List.fromList(img.encodeJpg(r, quality: 72));
}

Future<String> compressToDataUrl(Uint8List b) async {
  final out = await compute(_resize, b);
  return 'data:image/jpeg;base64,${base64Encode(out)}';
}

class ToyForm extends StatefulWidget {
  final String? id;
  const ToyForm({super.key, this.id});
  @override
  State<ToyForm> createState() => _ToyFormState();
}

class _ToyFormState extends State<ToyForm> {
  late String cat;
  final List<String> imgs = [];
  late final TextEditingController name;
  bool busy = false;
  bool get edit => widget.id != null && widget.id!.isNotEmpty;

  @override
  void initState() {
    super.initState();
    final t = edit ? app.toysL.firstWhere((x) => x['id'] == widget.id) : <String, dynamic>{'name': '', 'cat': 'speech', 'img': ''};
    cat = truthy(t['cat']) ? str(t['cat']) : 'speech';
    name = TextEditingController(text: str(t['name']));
    if (truthy(t['img'])) imgs.add(str(t['img']));
  }

  @override
  void dispose() {
    name.dispose();
    super.dispose();
  }

  Future<void> add(ImageSource s) async {
    setState(() => busy = true);
    toast('Adding photos…');
    List<String> got = [];
    if (s == ImageSource.gallery) {
      try {
        final xs = await ImagePicker().pickMultiImage(maxWidth: 1200, imageQuality: 85);
        for (final x in xs) {
          got.add(await compressToDataUrl(await x.readAsBytes()));
        }
      } catch (_) {}
    } else {
      final one = await pickToyPhoto(s);
      if (one != null) got = [one];
    }
    if (!mounted) return;
    setState(() {
      busy = false;
      if (edit) {
        if (got.isNotEmpty) imgs
          ..clear()
          ..add(got.first);
      } else {
        imgs.addAll(got);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final multi = !edit && imgs.length > 1;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      sheetTitle(edit ? T('Edit toy') : T('New toy')),
      PickerField(label: T('Category'), value: cat, items: kToyCats.map((c) => PickItem(c[0], T(c[1]))).toList(), onChanged: (v) => setState(() => cat = v)),
      if (imgs.isNotEmpty)
        SizedBox(
          height: 92,
          child: ListView(scrollDirection: Axis.horizontal, children: imgs.map((u) => Padding(padding: const EdgeInsetsDirectional.only(end: 8), child: ClipRRect(borderRadius: BorderRadius.circular(12), child: SizedBox(width: 92, height: 92, child: ToyImage(u))))).toList()),
        ),
      const SizedBox(height: 8),
      Wrap(spacing: 8, runSpacing: 8, children: [
        Btn(T('Take or choose a photo'), busy ? null : () => add(ImageSource.camera), small: true, kind: BK.ghost),
        Btn(edit ? l3('Choose from gallery', 'Choisir dans la galerie', 'اختيار من المعرض') : T('Choose photos (each photo becomes its own toy)'), busy ? null : () => add(ImageSource.gallery), small: true, kind: BK.ghost),
      ]),
      const SizedBox(height: 8),
      if (!multi) LField(name, label: T('Toy name (optional)')) else Mut(T('Each photo will be added as its own toy, without a name.')),
      Wrap(spacing: 8, runSpacing: 8, children: [
        Btn(T('Save'), busy
            ? null
            : () {
                app.saveToy(edit ? widget.id! : '', name: multi ? '' : name.text.trim(), cat: cat, imgs: imgs);
                cs(context);
              }),
        Btn(T('Cancel'), () => cs(context), kind: BK.ghost),
        if (edit)
          DangerBtn(T('Delete'), () {
            app.delToy(widget.id!);
            cs(context);
          }),
      ]),
    ]);
  }
}

/// Shows a toy photo from a data: URL or an https URL.
class ToyImage extends StatelessWidget {
  final String src;
  const ToyImage(this.src, {super.key});
  @override
  Widget build(BuildContext context) {
    if (src.startsWith('data:')) {
      try {
        return Image.memory(base64Decode(src.substring(src.indexOf(',') + 1)), fit: BoxFit.cover, gaplessPlayback: true);
      } catch (_) {}
    } else if (src.startsWith('http')) {
      return Image.network(src, fit: BoxFit.cover, errorBuilder: (c, e, s) => Container(color: pal(context).chip, child: Icon(Icons.broken_image_outlined, color: pal(context).mut)));
    }
    return Container(color: pal(context).chip, child: Icon(Icons.inventory_2_outlined, color: pal(context).mut));
  }
}

// ================================================================== workplace
void wpForm({String? id}) => showSheet<void>((c) => WpForm(id: id));

class WpForm extends StatefulWidget {
  final String? id;
  const WpForm({super.key, this.id});
  @override
  State<WpForm> createState() => _WpFormState();
}

class _WpFormState extends State<WpForm> {
  late final J w;
  late String type, mode, pay;
  late final TextEditingController n, customType, addr, notes, my, inst, mine, fee, payNotes;
  bool get edit => widget.id != null && widget.id!.isNotEmpty;

  @override
  void initState() {
    super.initState();
    w = edit ? app.wpById(widget.id)! : <String, dynamic>{'n': '', 'type': 'daycare', 'my': 50, 'fee': 0, 'mode': 'pct', 'mine': 0, 'addr': '', 'notes': '', 'pay': '', 'payNotes': ''};
    final known = kWTypes.any((t) => t[0] == w['type']);
    type = known ? str(w['type']) : 'other';
    mode = w['mode'] == 'fix' ? 'fix' : 'pct';
    pay = str(w['pay']);
    final myv = w['my'] == null ? 50.0 : nv(w['my']);
    String fnum(double d) => d == d.roundToDouble() ? '${d.round()}' : '$d';
    n = TextEditingController(text: str(w['n']));
    customType = TextEditingController(text: known ? '' : str(w['type']));
    addr = TextEditingController(text: str(w['addr']));
    notes = TextEditingController(text: str(w['notes']));
    my = TextEditingController(text: fnum(myv));
    inst = TextEditingController(text: fnum(100 - myv));
    mine = TextEditingController(text: fnum(nv(w['mine'])));
    fee = TextEditingController(text: fnum(nv(w['fee'])));
    payNotes = TextEditingController(text: str(w['payNotes']));
  }

  @override
  void dispose() {
    for (final x in [n, customType, addr, notes, my, inst, mine, fee, payNotes]) {
      x.dispose();
    }
    super.dispose();
  }

  void sync(TextEditingController from, TextEditingController to) {
    final v = nv(from.text).clamp(0, 100);
    final o = (100 - v).clamp(0, 100);
    to.text = o == o.roundToDouble() ? '${o.round()}' : '$o';
  }

  void save() {
    var t = type;
    if (t == 'other' && customType.text.trim().isNotEmpty) t = customType.text.trim();
    final J f = <String, dynamic>{
      'n': n.text.trim(),
      'type': t,
      'addr': addr.text.trim(),
      'notes': notes.text.trim(),
      'mode': mode,
      'my': nv(my.text).clamp(0, 100),
      'mine': nv(mine.text),
      'fee': nv(fee.text),
      'pay': pay,
      'payNotes': payNotes.text.trim(),
    };
    final err = app.wpSave(edit ? widget.id! : '', f);
    if (err != null) return toast(err);
    cs(context);
  }

  @override
  Widget build(BuildContext context) {
    final payOpts = [
      const PickItem('', '—'),
      PickItem('cash', l3('Cash', 'Espèces', 'نقداً')),
      PickItem('bank', l3('Bank transfer', 'Virement', 'تحويل بنكي')),
      PickItem('cheque', l3('Cheque', 'Chèque', 'شيك')),
      PickItem('invoice', l3('Monthly invoice', 'Facture mensuelle', 'فاتورة شهرية')),
      PickItem('other', l3('Other', 'Autre', 'أخرى')),
    ];
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      sheetTitle(edit ? l3('Edit workplace', 'Modifier le lieu', 'تعديل مكان العمل') : l3('New workplace', 'Nouveau lieu', 'مكان عمل جديد')),
      LField(n, label: l3('Workplace name', 'Nom du lieu', 'اسم مكان العمل')),
      PickerField(label: l3('Type', 'Type', 'النوع'), value: type, items: kWTypes.map((t) => PickItem(t[0], l3(t[1], t[2], t[3]))).toList(), onChanged: (v) => setState(() => type = v)),
      if (type == 'other') LField(customType, hint: l3('Custom type', 'Type personnalisé', 'نوع مخصص')),
      LField(addr, label: l3('Address or notes', 'Adresse ou notes', 'العنوان أو ملاحظات')),
      LField(notes, minLines: 2, maxLines: 4),
      AppCard(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(l3('Financial arrangement', 'Accord financier', 'الترتيب المالي'), style: const TextStyle(fontWeight: FontWeight.bold)),
          Seg([SegItem('pct', l3('Percentage', 'Pourcentage', 'نسبة مئوية')), SegItem('fix', l3('Fixed per session', 'Fixe par séance', 'مبلغ ثابت لكل حصة'))], mode, (v) => setState(() => mode = v)),
          if (mode == 'pct')
            twoCol(
              LField(my, label: l3('Clinician %', '% praticien', 'نسبة الأخصائية %'), keyboard: TextInputType.number, onChanged: (_) => sync(my, inst)),
              LField(inst, label: l3('Institution %', '% établissement', 'نسبة المؤسسة %'), keyboard: TextInputType.number, onChanged: (_) => sync(inst, my)),
            )
          else
            LField(mine, label: l3('My fixed amount per session', 'Mon montant fixe par séance', 'مبلغي الثابت لكل حصة'), keyboard: TextInputType.number),
          LField(fee, label: l3('Price per session', 'Prix par séance', 'سعر الحصة'), keyboard: TextInputType.number),
          PickerField(label: l3('Payment method', 'Mode de paiement', 'طريقة الدفع'), value: pay, items: payOpts, onChanged: (v) => setState(() => pay = v)),
          LField(payNotes, hint: l3('Payment notes / other arrangements', 'Notes de paiement / autres accords', 'ملاحظات الدفع / ترتيبات أخرى'), minLines: 2, maxLines: 4),
        ]),
      ),
      Padding(padding: const EdgeInsets.symmetric(vertical: 8), child: Mut(l3('Past completed sessions keep the terms saved with them.', 'Les séances passées gardent les conditions enregistrées avec elles.', 'تحتفظ الحصص السابقة بالشروط المحفوظة معها.'))),
      Wrap(spacing: 8, runSpacing: 8, children: [
        Btn(l3('Save', 'Enregistrer', 'حفظ'), save),
        Btn(l3('Cancel', 'Annuler', 'إلغاء'), () => cs(context), kind: BK.ghost),
        if (edit)
          DangerBtn(l3('Delete workplace', 'Supprimer le lieu', 'حذف مكان العمل'), () {
            final e = app.wpDelete(widget.id!);
            if (e != null) {
              toast(e);
            } else {
              cs(context);
            }
          }),
      ]),
    ]);
  }
}

// ================================================================ program form
void progForm(String pid) => showSheet<void>((c) => ProgForm(pid: pid));

class ProgForm extends StatefulWidget {
  final String pid;
  const ProgForm({super.key, required this.pid});
  @override
  State<ProgForm> createState() => _ProgFormState();
}

class _ProgFormState extends State<ProgForm> {
  late final J p;
  late final J pr;
  late final Set<int> days;
  late String start, end, unit, wpId;
  late final TextEditingController freq, time, dur;

  @override
  void initState() {
    super.initState();
    p = app.P(widget.pid)!;
    pr = p['prog'] is Map ? p['prog'] as J : app.legacyProg(p);
    days = app.progDays(pr).map((e) => iv(e)).toSet();
    start = truthy(pr['start']) ? str(pr['start']) : td();
    end = str(pr['end']);
    unit = pr['unit'] == 'months' ? 'months' : 'weeks';
    wpId = str(p['wpId']);
    String fnum(double d) => d == 0 ? '' : (d == d.roundToDouble() ? '${d.round()}' : '$d');
    freq = TextEditingController(text: fnum(nv(pr['freq'])));
    time = TextEditingController(text: str(pr['time']));
    dur = TextEditingController(text: fnum(nv(pr['dur'])));
    freq.addListener(() => setState(() {}));
    dur.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    freq.dispose();
    time.dispose();
    dur.dispose();
    super.dispose();
  }

  J tmp() => <String, dynamic>{
        'fn': days.isNotEmpty ? days.length : nv(freq.text),
        'fu': 'week',
        'dv': nv(dur.text),
        'du': unit,
        'prog': <String, dynamic>{'days': days.toList(), 'start': start, 'dur': nv(dur.text), 'unit': unit, 'end': end, 'freq': nv(freq.text), 'per': 'week'},
      };

  @override
  Widget build(BuildContext context) {
    final t = tmp();
    final e = app.endOf(t['prog'] as J);
    final exp = app.expectedFor(t);
    final done = app.doneOf(p).length;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      sheetTitle(l3('Treatment program', 'Programme de traitement', 'برنامج العلاج')),
      Mut(app.full(p)),
      PickerField(label: l3('Main workplace', 'Lieu principal', 'مكان العمل الرئيسي'), value: wpId, items: wpItems(withNone: true), onChanged: (v) => setState(() => wpId = v)),
      Lbl(l3('Weekdays', 'Jours de la semaine', 'أيام الأسبوع')),
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Wrap(spacing: 4, runSpacing: 4, children: [
          for (final d in [1, 2, 3, 4, 5, 6, 0]) PillBtn(app.wdName(d), days.contains(d), () => setState(() => days.contains(d) ? days.remove(d) : days.add(d))),
        ]),
      ),
      twoCol(LField(freq, label: l3('or sessions / week', 'ou séances / semaine', 'أو حصص / أسبوع'), keyboard: TextInputType.number), TimeField(l3('Time', 'Heure', 'الوقت'), time.text, (v) => setState(() => time.text = v))),
      DateField(l3('Start', 'Début', 'البداية'), start, (v) => setState(() => start = v)),
      twoCol(LField(dur, label: l3('Duration', 'Durée', 'المدة'), keyboard: TextInputType.number), PickerField(label: l3('Unit', 'Unité', 'الوحدة'), value: unit, items: [PickItem('weeks', l3('Weeks', 'Semaines', 'أسابيع')), PickItem('months', l3('Months', 'Mois', 'أشهر'))], onChanged: (v) => setState(() => unit = v))),
      DateField(l3('End (optional, overrides duration)', 'Fin (optionnelle, remplace la durée)', 'النهاية (اختياري، يعوّض المدة)'), end, (v) => setState(() => end = v)),
      AppCard(
        child: Text.rich(TextSpan(children: [
          TextSpan(text: '${l3('Ends', 'Fin', 'النهاية')}: ', style: const TextStyle(fontWeight: FontWeight.bold)),
          TextSpan(text: '${app.fmtD(e)} · ${l3('Expected sessions', 'Séances prévues', 'الحصص المتوقعة')}: $exp · ${l3('completed', 'réalisées', 'منجزة')}: $done'),
        ])),
      ),
      Wrap(spacing: 8, runSpacing: 8, children: [
        Btn(l3('Save', 'Enregistrer', 'حفظ'), () {
          final err = app.progSave(widget.pid, days: days.toList(), freq: nv(freq.text), time: time.text.trim(), start: start, dur: nv(dur.text), unit: unit, end: end, wpId: wpId);
          if (err != null) return toast(err);
          cs(context);
        }),
        Btn(l3('Cancel', 'Annuler', 'إلغاء'), () => cs(context), kind: BK.ghost),
      ]),
    ]);
  }
}

// ====================================================== next appointment / resched
void nextForm(String pid) => showSheet<void>((c) => NextForm(pid: pid));

class NextForm extends StatefulWidget {
  final String pid;
  const NextForm({super.key, required this.pid});
  @override
  State<NextForm> createState() => _NextFormState();
}

class _NextFormState extends State<NextForm> {
  late final J p;
  late String date, time, wpId;
  late final TextEditingController goal, acts, mats;
  @override
  void initState() {
    super.initState();
    p = app.P(widget.pid)!;
    final nd = app.nextDate(p, td());
    final pr = p['prog'] is Map ? p['prog'] as J : <String, dynamic>{};
    date = nd.isNotEmpty ? nd : addD(td(), 1);
    time = truthy(pr['time']) ? str(pr['time']) : '10:00';
    wpId = str(p['wpId']);
    goal = TextEditingController();
    acts = TextEditingController();
    mats = TextEditingController();
  }

  @override
  void dispose() {
    goal.dispose();
    acts.dispose();
    mats.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      sheetTitle(l3('Next appointment', 'Prochain rendez-vous', 'الموعد القادم')),
      Mut(app.full(p)),
      twoCol(DateField(l3('Date', 'Date', 'التاريخ'), date, (v) => setState(() => date = v)), TimeField(l3('Time', 'Heure', 'الوقت'), time, (v) => setState(() => time = v))),
      PickerField(label: l3('Workplace / location', 'Lieu', 'المكان'), value: wpId, items: wpItems(withNone: true), onChanged: (v) => setState(() => wpId = v)),
      LField(goal, label: l3('Goals', 'Objectifs', 'الأهداف'), minLines: 2, maxLines: 4),
      LField(acts, label: l3('Activities', 'Activités', 'الأنشطة'), minLines: 2, maxLines: 4),
      LField(mats, label: l3('Materials / preparation notes', 'Matériel / préparation', 'الوسائل / التحضير'), minLines: 2, maxLines: 4),
      Wrap(spacing: 8, runSpacing: 8, children: [
        Btn(l3('Save', 'Enregistrer', 'حفظ'), () {
          if (date.isEmpty) return;
          app.saveNext(widget.pid, date: date, time: time, wpId: wpId, goal: goal.text.trim(), acts: acts.text.trim(), materials: mats.text.trim());
          cs(context);
        }),
        Btn(l3('Cancel', 'Annuler', 'إلغاء'), () => cs(context), kind: BK.ghost),
      ]),
    ]);
  }
}

void reschedForm(String aid) => showSheet<void>((c) => ReschedForm(aid: aid));

class ReschedForm extends StatefulWidget {
  final String aid;
  const ReschedForm({super.key, required this.aid});
  @override
  State<ReschedForm> createState() => _ReschedFormState();
}

class _ReschedFormState extends State<ReschedForm> {
  late final J a;
  late String date, time;
  @override
  void initState() {
    super.initState();
    a = app.apts.firstWhere((x) => x['id'] == widget.aid);
    date = str(a['date']);
    time = str(a['time']);
  }

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      sheetTitle(l3('Reschedule', 'Reprogrammer', 'إعادة جدولة')),
      Mut('${app.full(app.P(a['pid']))} · ${app.fmtD(str(a['date']))} ${a['time']}'),
      twoCol(DateField(l3('New date', 'Nouvelle date', 'تاريخ جديد'), date, (v) => setState(() => date = v)), TimeField(l3('New time', 'Nouvelle heure', 'وقت جديد'), time, (v) => setState(() => time = v))),
      Wrap(spacing: 8, runSpacing: 8, children: [
        Btn(l3('Save', 'Enregistrer', 'حفظ'), () {
          if (app.doResched(widget.aid, date, time)) cs(context);
        }),
        Btn(l3('Cancel', 'Annuler', 'إلغاء'), () => cs(context), kind: BK.ghost),
      ]),
    ]);
  }
}

// ==================================================== complete session / report
void openDone(String aid) {
  final a = app.apts.where((x) => x['id'] == aid).toList();
  if (a.isEmpty || app.P(a.first['pid']) == null) return;
  if (app.srs.any((r) => r['id'] == 'sr_$aid')) {
    toast(l3('This session is already saved.', 'Cette séance est déjà enregistrée.', 'هذه الحصة محفوظة مسبقاً.'));
    viewReport('sr_$aid');
    return;
  }
  showSheet<void>((c) => DoneForm(aid: aid));
}

class DoneForm extends StatefulWidget {
  final String aid;
  const DoneForm({super.key, required this.aid});
  @override
  State<DoneForm> createState() => _DoneFormState();
}

class _DoneFormState extends State<DoneForm> {
  late final J a, p;
  late String wp, nd, nt, nw;
  late bool next;
  late final Map<String, TextEditingController> f;
  late final TextEditingController ng, na, nm;
  bool saving = false;

  @override
  void initState() {
    super.initState();
    a = app.apts.firstWhere((x) => x['id'] == widget.aid);
    p = app.P(a['pid'])!;
    final pr = p['prog'] is Map ? p['prog'] as J : <String, dynamic>{};
    final nd0 = app.nextDate(p, str(a['date']).compareTo(td()) > 0 ? str(a['date']) : td());
    final canNext = nd0.isNotEmpty && app.upcoming(str(p['id'])).where((x) => x['id'] != a['id']).isEmpty;
    wp = str(truthy(a['placeId']) ? a['placeId'] : (app.wpByName(str(a['place']))?['id'] ?? p['wpId']));
    next = canNext;
    nd = nd0.isNotEmpty ? nd0 : addD(td(), 1);
    nt = truthy(pr['time']) ? str(pr['time']) : (truthy(a['time']) ? str(a['time']) : '10:00');
    nw = str(truthy(p['wpId']) ? p['wpId'] : a['placeId']);
    final pre = <String, String>{'acts': str(a['acts']), 'goals': str(a['goal'])};
    f = {for (final x in kReportFields) x[0]: TextEditingController(text: pre[x[0]] ?? '')};
    ng = TextEditingController();
    na = TextEditingController();
    nm = TextEditingController();
  }

  @override
  void dispose() {
    for (final c in [...f.values, ng, na, nm]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> save() async {
    if (saving) return;
    setState(() => saving = true);
    final vals = {for (final k in f.keys) k: f[k]!.text.trim()};
    final filled = vals.values.any((v) => v.isNotEmpty);
    if (!filled && !await confirmDialog(l3('Save this session without any clinical notes?', 'Enregistrer cette séance sans aucune note clinique ?', 'حفظ هذه الحصة دون أي ملاحظات سريرية؟'))) {
      if (mounted) setState(() => saving = false);
      return;
    }
    final msg = app.saveDone(widget.aid, placeId: wp, f: vals, next: next, nd: nd, nt: nt, nw: nw, ng: ng.text.trim(), na: na.text.trim(), nm: nm.text.trim());
    if (mounted) cs(context);
    if (msg.isNotEmpty) toast(msg);
  }

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      sheetTitle(l3('Complete session', 'Terminer la séance', 'إنهاء الحصة')),
      Mut('${app.full(p)} · ${app.fmtD(str(a['date']))} ${a['time']}'),
      PickerField(label: l3('Workplace / location of this session', 'Lieu de cette séance', 'مكان هذه الحصة'), value: wp, items: wpItems(withNone: true), onChanged: (v) => setState(() => wp = v)),
      ...kReportFields.map((x) => LField(f[x[0]]!, label: fLabel(x), minLines: 2, maxLines: 6)),
      AppCard(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          CheckRow(next, l3('Prepare the next appointment', 'Préparer le prochain rendez-vous', 'تحضير الموعد القادم'), (v) => setState(() => next = v)),
          if (next) ...[
            twoCol(DateField(l3('Date', 'Date', 'التاريخ'), nd, (v) => setState(() => nd = v)), TimeField(l3('Time', 'Heure', 'الوقت'), nt, (v) => setState(() => nt = v))),
            PickerField(label: l3('Workplace / location', 'Lieu', 'المكان'), value: nw, items: wpItems(withNone: true), onChanged: (v) => setState(() => nw = v)),
            LField(ng, label: l3('Goals', 'Objectifs', 'الأهداف'), minLines: 2, maxLines: 4),
            LField(na, label: l3('Activities', 'Activités', 'الأنشطة'), minLines: 2, maxLines: 4),
            LField(nm, label: l3('Materials / preparation notes', 'Matériel / préparation', 'الوسائل / التحضير'), minLines: 2, maxLines: 4),
          ],
        ]),
      ),
      Padding(padding: const EdgeInsets.only(bottom: 8), child: Mut(l3('You can save without scheduling another appointment: untick the box above.', 'Vous pouvez enregistrer sans programmer de rendez-vous : décochez la case ci-dessus.', 'يمكنك الحفظ دون جدولة موعد آخر: ألغي تحديد المربع أعلاه.'))),
      Wrap(spacing: 8, runSpacing: 8, children: [
        Btn(l3('Save session', 'Enregistrer la séance', 'حفظ الحصة'), saving ? null : save),
        Btn(l3('Cancel', 'Annuler', 'إلغاء'), () => cs(context), kind: BK.ghost),
      ]),
    ]);
  }
}

void viewReport(String rid) {
  final r = app.srs.where((x) => x['id'] == rid).toList();
  if (r.isEmpty) return;
  showSheet<void>((c) {
    final rep = r.first;
    final p = app.P(rep['pid']);
    final fin = rep['fin'] is Map ? rep['fin'] as Map : null;
    final f = rep['f'] is Map ? rep['f'] as Map : <dynamic, dynamic>{};
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      sheetTitle(l3('Session report', 'Compte rendu de séance', 'تقرير الحصة')),
      Mut('${app.full(p)} · ${app.fmtD(str(rep['date']))} ${rep['time']} · ${rep['place']}'),
      const SizedBox(height: 8),
      ...kReportFields.where((x) => truthy(f[x[0]])).map((x) => secCard(
            hex('#16a39a'),
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Lbl(fLabel(x)),
              Text(str(f[x[0]])),
            ]),
          )),
      if (fin != null)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Mut('${l3('Financial basis saved with this session', 'Base financière enregistrée avec cette séance', 'الأساس المالي المحفوظ مع هذه الحصة')}: ${fin['mode'] == 'fix' ? '${l3('fixed', 'fixe', 'مبلغ ثابت')} ${app.money(nv(fin['mine']))}' : '${fin['pct']}% × ${app.money(nv(fin['price']))} = ${app.money(nv(fin['mine']))}'}'),
        ),
      Btn(l3('Close', 'Fermer', 'إغلاق'), () => cs(c), kind: BK.ghost),
    ]);
  });
}

// ============================================================== AI progress review
bool _reviewBusy = false;

void aiReviewFlow(String pid) {
  final p = app.P(pid);
  if (p == null || _reviewBusy) return;
  final E = historyEntries(p);
  if (E.isEmpty) return toast(l3('No completed sessions to analyse yet.', 'Aucune séance réalisée à analyser.', 'لا توجد حصص منجزة للتحليل بعد.'));
  showSheet<void>((c) => _ReviewSheet(pid: pid, n: E.length));
}

class _ReviewSheet extends StatefulWidget {
  final String pid;
  final int n;
  const _ReviewSheet({required this.pid, required this.n});
  @override
  State<_ReviewSheet> createState() => _ReviewSheetState();
}

class _ReviewSheetState extends State<_ReviewSheet> {
  String status = l3('Preparing the complete history…', 'Préparation de l’historique complet…', 'جاري تجهيز السجل الكامل…');
  String? error;
  final TextEditingController text = TextEditingController();
  bool ready = false;
  bool saved = false;

  @override
  void initState() {
    super.initState();
    _run();
  }

  @override
  void dispose() {
    text.dispose();
    super.dispose();
  }

  Future<void> _run() async {
    _reviewBusy = true;
    try {
      final p = app.P(widget.pid)!;
      final out = await aiProgressReview(p, widget.n, (s) {
        if (mounted) setState(() => status = s);
      });
      if (mounted) {
        setState(() {
          text.text = out;
          ready = true;
        });
      }
    } catch (e) {
      if (mounted) setState(() => error = aiErr(e));
    }
    _reviewBusy = false;
  }

  @override
  Widget build(BuildContext context) {
    if (error != null) {
      return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        sheetTitle(l3('AI progress review', 'Bilan de progrès IA', 'مراجعة التقدم')),
        AppCard(child: Text(error!)),
        Btn(l3('Close', 'Fermer', 'إغلاق'), () => cs(context), kind: BK.ghost),
      ]);
    }
    if (!ready) {
      return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        sheetTitle(l3('AI progress review', 'Bilan de progrès IA', 'مراجعة التقدم بالذكاء الاصطناعي')),
        Mut(status),
        const SizedBox(height: 20),
        const Center(child: CircularProgressIndicator()),
        const SizedBox(height: 20),
      ]);
    }
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      sheetTitle(l3('AI progress review (draft)', 'Bilan de progrès IA (brouillon)', 'مراجعة التقدم (مسودة)')),
      AppCard(
        borderColor: Pal.amb,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(l3('Review before saving', 'À relire avant d’enregistrer', 'راجعي قبل الحفظ'), style: const TextStyle(fontWeight: FontWeight.bold)),
          Mut(l3('Part A should only repeat what you documented; Part B is the AI’s interpretation. Edit anything, then approve. Nothing is saved or shared until you approve.', 'La partie A ne doit reprendre que ce que vous avez documenté ; la partie B est l’interprétation de l’IA. Modifiez puis approuvez. Rien n’est enregistré ni partagé avant votre approbation.', 'يجب أن تكرر الفقرة A ما وثّقتِه فقط؛ الفقرة B تفسير الذكاء الاصطناعي. عدّلي ما شئتِ ثم اعتمدي. لا يُحفظ أو يُشارك شيء قبل اعتمادك.')),
        ]),
      ),
      const SizedBox(height: 8),
      TextField(controller: text, minLines: 14, maxLines: 30, decoration: inputDeco(context), style: const TextStyle(fontSize: 15)),
      const SizedBox(height: 8),
      Wrap(spacing: 8, runSpacing: 8, children: [
        Btn(l3('Approve and save', 'Approuver et enregistrer', 'اعتماد وحفظ'), saved
            ? null
            : () {
                if (text.text.trim().isEmpty) return;
                setState(() => saved = true);
                app.aiApprove(widget.pid, widget.n, text.text);
                cs(context);
              }),
        Btn(l3('Discard', 'Annuler', 'تجاهل'), () => cs(context), kind: BK.ghost),
      ]),
    ]);
  }
}

void viewReview(String id) {
  final r = app.ais.where((x) => x['id'] == id).toList();
  if (r.isEmpty) return;
  showSheet<void>((c) {
    final x = r.first;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      sheetTitle(l3('Approved AI progress review', 'Bilan IA approuvé', 'مراجعة معتمدة')),
      Mut('${app.full(app.P(x['pid']))} · ${str(x['at']).substring(0, 10)}'),
      AppCard(child: SelectableText(str(x['text']))),
      Wrap(spacing: 8, runSpacing: 8, children: [
        Btn(l3('Copy', 'Copier', 'نسخ'), () {
          Clipboard.setData(ClipboardData(text: str(x['text'])));
          toast(l3('Copied', 'Copié', 'تم النسخ'));
        }, kind: BK.ghost, small: true),
        Btn(l3('Share', 'Partager', 'مشاركة'), () => shareText(str(x['text']), l3('AI progress review', 'Bilan de progrès', 'مراجعة التقدم')), kind: BK.ghost, small: true),
        Btn(l3('Close', 'Fermer', 'إغلاق'), () => cs(c), kind: BK.ghost, small: true),
      ]),
    ]);
  });
}
