import 'dart:math' as math;
import '../core/data_gen.dart';
import '../core/globals.dart';
import '../core/i18n.dart';
import '../core/util.dart';
import 'app_state.dart';

String isoNow() => DateTime.now().toUtc().toIso8601String();

extension Logic on AppState {
  /// fmtD(): short weekday, day, short month in the UI language.
  String fmtD(String? ds) => (ds == null || ds.isEmpty) ? '—' : fmtLoc(lang, ds, 'EEE d MMM');
  String wdName(int d) => fmtLoc(lang, '2024-01-${two(7 + d)}', 'EEE');
  bool inWp(J p, String f) => f == 'all' || f.isEmpty || (f == 'none' ? !truthy(p['wpId']) : patWps(p).contains(f));

  // ================================================================ programs
  String endOf(J? pr) {
    if (pr == null) return '';
    if (truthy(pr['end'])) return str(pr['end']);
    if (!truthy(pr['start']) || !(nv(pr['dur']) > 0)) return '';
    final d = parseD(str(pr['start']));
    DateTime e;
    if (pr['unit'] == 'months') {
      e = DateTime(d.year, d.month + nv(pr['dur']).toInt(), d.day, 12);
    } else {
      e = DateTime(d.year, d.month, d.day + 7 * nv(pr['dur']).toInt(), 12);
    }
    e = DateTime(e.year, e.month, e.day - 1, 12);
    return fmtDate(e);
  }

  int expectedFor(J p) {
    final pr = p['prog'];
    if (pr is Map && progDays(pr as J).isNotEmpty && truthy(pr['start'])) {
      final end = endOf(pr);
      if (end.isEmpty || end.compareTo(str(pr['start'])) < 0) return 0;
      var n = 0;
      var d = str(pr['start']);
      final days = progDays(pr).map((e) => iv(e)).toList();
      for (var i = 0; i < 1200 && d.compareTo(end) <= 0; i++) {
        if (days.contains(jsDay(parseD(d)))) n++;
        d = addD(d, 1);
      }
      return n;
    }
    return exp(p);
  }

  List<J> doneOf(J p) {
    final pr = p['prog'];
    final st = pr is Map ? str(pr['start']) : '';
    return apts.where((a) => a['pid'] == p['id'] && a['status'] == 'done' && (st.isEmpty || str(a['date']).compareTo(st) >= 0)).toList();
  }

  String nextDate(J p, String from) {
    final pr = p['prog'];
    if (pr is! Map || pr['status'] != 'active') return '';
    final prj = pr as J;
    final end = endOf(prj);
    final days = progDays(prj).map((e) => iv(e)).toList();
    if (days.isNotEmpty) {
      for (var i = 1; i <= 400; i++) {
        final d = addD(from, i);
        if (end.isNotEmpty && d.compareTo(end) > 0) return '';
        if (days.contains(jsDay(parseD(d)))) return d;
      }
      return '';
    }
    final f = math.max(1, nv(prj['freq']).round());
    final step = prj['per'] == 'day' ? 1 : (prj['per'] == 'month' ? (30 / f).round() : math.max(1, (7 / f).round()));
    final d = addD(from, step);
    return end.isNotEmpty && d.compareTo(end) > 0 ? '' : d;
  }

  List<J> upcoming(String pid) {
    final L = apts.where((a) => a['pid'] == pid && a['status'] == 'scheduled' && str(a['date']).compareTo(td()) >= 0).toList();
    L.sort((x, y) => ('${x['date']}${x['time']}').compareTo('${y['date']}${y['time']}'));
    return L;
  }

  List<J> lastReports(String pid) {
    final L = srs.where((r) => r['pid'] == pid).toList();
    L.sort((x, y) => ('${y['date']}${y['time']}').compareTo('${x['date']}${x['time']}'));
    return L;
  }

  // ================================================================= finance
  J earn(double price, String? pn) {
    final pl = wpByName(pn) ?? <String, dynamic>{};
    final mine = pl['mode'] == 'fix' ? math.min(price, nv(pl['mine'])) : price * (pl['my'] == null ? 100 : nv(pl['my'])) / 100;
    return <String, dynamic>{'price': price, 'mine': mine, 'owner': price - mine};
  }

  List<String> frng() {
    final t = td();
    final d = parseD(t);
    if (v.fp == 'week') {
      final o = monOffset(d);
      return [addD(t, -o), addD(t, 6 - o)];
    }
    if (v.fp == 'year') return ['${t.substring(0, 4)}-01-01', '${t.substring(0, 4)}-12-31'];
    if (v.fp == 'all') return ['0000', '9999'];
    return ['${t.substring(0, 7)}-01', '${t.substring(0, 7)}-31'];
  }

  List<J> fdata() {
    final r = frng();
    final a = r[0], b = r[1];
    final R = <J>[];
    for (final x in apts.where((x) => x['status'] == 'done' && str(x['date']).compareTo(a) >= 0 && str(x['date']).compareTo(b) <= 0)) {
      final p = P(x['pid']);
      final pl = wpByName(str(x['place']));
      final pf = p == null ? null : numOrNull(p['fee']);
      final pr = pf ?? nv(pl == null ? 0 : pl['fee']);
      final J e = x['fin'] is Map
          ? <String, dynamic>{'price': nv(x['fin']['price']), 'mine': nv(x['fin']['mine']), 'owner': nv(x['fin']['owner'])}
          : earn(pr, str(x['place']));
      R.add(<String, dynamic>{'pl': str(x['place']), 'pid': str(x['pid']), ...e});
    }
    for (final x in cons.where((x) => x['status'] == 'done' && numOrNull(x['fee']) != null && str(x['date']).compareTo(a) >= 0 && str(x['date']).compareTo(b) <= 0)) {
      R.add(<String, dynamic>{'pl': str(x['place']), 'pid': str(x['pid']), ...earn(nv(x['fee']), str(x['place']))});
    }
    return R;
  }

  J finSnap(String placeName, J? p) {
    final pl = wpByName(placeName) ?? <String, dynamic>{};
    final pf = p == null ? null : numOrNull(p['fee']);
    final price = pf ?? nv(pl['fee']);
    final e = earn(price, placeName);
    return <String, dynamic>{
      'price': e['price'],
      'mine': e['mine'],
      'owner': e['owner'],
      'mode': truthy(pl['mode']) ? pl['mode'] : 'pct',
      'pct': pl['my'] == null ? 100 : nv(pl['my']),
      'fixed': nv(pl['mine']),
      'placeId': str(pl['id']),
      'place': placeName,
      'cur': cur,
      'at': isoNow(),
    };
  }

  int freezePlace(String name) {
    var n = 0;
    for (final a in apts) {
      if (a['status'] == 'done' && a['place'] == name && a['fin'] == null) {
        final f = finSnap(name, P(a['pid']));
        f['frozen'] = 1;
        a['fin'] = f;
        n++;
      }
    }
    return n;
  }

  void freezeAll() {
    var n = 0;
    for (final x in List<J>.from(places)) {
      n += freezePlace(str(x['n']));
    }
    if (n > 0) save();
    toast(l3('$n past session(s) now keep their current terms.', '$n séance(s) passée(s) conservent maintenant leurs conditions actuelles.', 'تم تثبيت الشروط الحالية لـ $n حصة سابقة.'));
    go();
  }

  void setPl(int i, String k, dynamic val) {
    final x = places[i];
    if (freezePlace(str(x['n'])) > 0) save();
    x[k] = k == 'mode' ? val : math.max(0, nv(val));
    if (k == 'my') x['my'] = math.min(100, nv(x['my']));
    save();
    go();
  }

  void rmPl(int i) {
    final x = places[i];
    if (freezePlace(str(x['n'])) > 0) save();
    places.removeAt(i);
    save();
    go();
  }

  void addPl(String n, String t, double my, double fee) {
    if (n.isEmpty) return toast('Enter the name of the center or daycare');
    if (places.any((x) => str(x['n']).toLowerCase() == n.toLowerCase())) return toast('This place already exists');
    places.add(<String, dynamic>{'n': n, 't': t, 'my': math.min(100, my), 'fee': fee, 'mode': 'pct', 'mine': 0});
    migrate();
    save();
    go();
    toast('Place added');
  }

  /// Returns null on success or an error toast key.
  String? wpSave(String id, J f) {
    final n = str(f['n']);
    if (n.isEmpty) return l3('Enter the workplace name', 'Saisissez le nom du lieu', 'أدخلي اسم مكان العمل');
    if (places.any((x) => x['id'] != id && str(x['n']).toLowerCase() == n.toLowerCase())) {
      return l3('This workplace already exists', 'Ce lieu existe déjà', 'مكان العمل موجود بالفعل');
    }
    J? w = id.isEmpty ? null : wpById(id);
    final old = w == null ? null : str(w['n']);
    if (w != null) {
      freezePlace(old!);
    } else {
      w = <String, dynamic>{'id': 'wp_${uid()}${DateTime.now().millisecondsSinceEpoch.toRadixString(36)}'};
      places.add(w);
    }
    final type = str(f['type']);
    w.addAll(<String, dynamic>{
      'n': n,
      'type': type,
      't': type == 'daycare' ? 'daycare' : 'center',
      'addr': f['addr'],
      'notes': f['notes'],
      'mode': f['mode'],
      'my': f['my'],
      'mine': f['mine'],
      'fee': f['fee'],
      'pay': f['pay'],
      'payNotes': f['payNotes'],
    });
    if (old != null && old != n) {
      for (final p in pats) {
        if (p['place'] == old) p['place'] = n;
      }
      for (final a in apts) {
        if (a['place'] == old) a['place'] = n;
      }
      for (final c in cons) {
        if (c['place'] == old) c['place'] = n;
      }
    }
    save();
    go();
    return null;
  }

  List<String> patWps(J p) => <dynamic>[p['wpId'], ...(p['wpExtra'] is List ? p['wpExtra'] as List : <dynamic>[])].where((e) => truthy(e)).map((e) => str(e)).toList();

  /// Returns an error message or null.
  String? wpDelete(String id) {
    final w = wpById(id);
    if (w == null) return null;
    final users = pats.where((p) => patWps(p).contains(id)).length;
    final appts = apts.where((a) => a['placeId'] == id || a['place'] == w['n']).length;
    if (users > 0 || appts > 0) {
      return l3('Cannot delete: used by $users patient(s) and $appts appointment(s).', 'Suppression impossible : utilisé par $users patient(s) et $appts rendez-vous.', 'لا يمكن الحذف: مستعمل من $users مريض و$appts موعد.');
    }
    me['places'] = places.where((x) => x['id'] != id).toList();
    save();
    go();
    return null;
  }

  // ============================================================== appointments
  J mkAppt(J o) {
    for (final a in apts) {
      if (a['id'] == o['id'] ||
          (a['pid'] == o['pid'] && a['date'] == o['date'] && a['time'] == o['time'] && a['status'] != 'cancelled' && a['status'] != 'rescheduled')) {
        return a;
      }
    }
    final J a = <String, dynamic>{
      'id': truthy(o['id']) ? o['id'] : uid(),
      'pid': o['pid'],
      'date': o['date'],
      'time': o['time'],
      'place': str(o['place']),
      'placeId': str(o['placeId']),
      'goal': str(o['goal']),
      'remark': '',
      'status': 'scheduled',
      'acts': str(o['acts']),
      'materials': str(o['materials']),
      'src': truthy(o['src']) ? o['src'] : 'manual',
      'progId': 'pg_${o['pid']}',
    };
    if (truthy(o['from'])) a['from'] = o['from'];
    apts.add(a);
    return a;
  }

  /// Non-"done" status change (done goes through the structured completion form).
  void setSt(String id, String s) {
    final a = apts.firstWhere((x) => x['id'] == id, orElse: () => <String, dynamic>{});
    if (a.isEmpty) return;
    a['status'] = s;
    save();
    go();
    toast(s == 'done' ? 'Session marked done' : 'Marked ${kSt[s]!.toLowerCase()}');
  }

  /// Creates or edits appointments. [o] = pid,date,time,place,goal,remark,status.
  void saveAp(String id, J o, {bool applyAll = false, int n = 1, int step = 7, List<String> group = const []}) {
    final w = wpByName(str(o['place']));
    o['placeId'] = w == null ? '' : w['id'];
    if (id.isNotEmpty) {
      final a = apts.firstWhere((x) => x['id'] == id);
      a.addAll(o);
      if (truthy(a['grp']) && applyAll) {
        for (final x in apts.where((x) => x['grp'] == a['grp'] && x['id'] != id)) {
          x['date'] = o['date'];
          x['time'] = o['time'];
          x['place'] = o['place'];
          x['placeId'] = o['placeId'];
          x['goal'] = o['goal'];
        }
      }
    } else {
      final count = math.min(60, math.max(1, n));
      final st = step < 1 ? 7 : step;
      final ids = <String>[str(o['pid']), ...group];
      for (var i = 0; i < count; i++) {
        final g = ids.length > 1 ? uid() : null;
        for (final pid in ids) {
          final J x = <String, dynamic>{...o, 'pid': pid, 'id': uid(), 'date': addD(str(o['date']), i * st)};
          if (g != null) x['grp'] = g;
          if (!truthy(x['src'])) x['src'] = 'manual';
          x['progId'] = 'pg_$pid';
          apts.add(x);
        }
      }
    }
    save();
    go();
    toast('Saved');
  }

  void delAp(String id) {
    S!['a'] = apts.where((a) => a['id'] != id).toList();
    save();
    go();
  }

  // ---------------------------------------------------------- structured done
  /// Returns the toast message. [f] holds the 8 clinical fields.
  String saveDone(String aid, {required String placeId, required Map<String, String> f, required bool next, String nd = '', String nt = '', String nw = '', String ng = '', String na = '', String nm = ''}) {
    final a = apts.firstWhere((x) => x['id'] == aid);
    final p = P(a['pid'])!;
    final rid = 'sr_${a['id']}';
    if (srs.any((r) => r['id'] == rid)) return '';
    final w = wpById(placeId) ?? wpByName(str(a['place'])) ?? <String, dynamic>{};
    final place = truthy(w['n']) ? str(w['n']) : str(a['place']);
    final fin = finSnap(place, p);
    srs.add(<String, dynamic>{
      'id': rid,
      'aid': a['id'],
      'pid': a['pid'],
      'progId': 'pg_${a['pid']}',
      'placeId': str(w['id']),
      'place': place,
      'date': a['date'],
      'time': a['time'],
      'doneOn': td(),
      'createdAt': isoNow(),
      'f': Map<String, dynamic>.from(f),
      'fin': fin,
      'rev': 1,
    });
    a['status'] = 'done';
    a['rid'] = rid;
    a['place'] = place;
    a['placeId'] = truthy(w['id']) ? w['id'] : a['placeId'];
    a['fin'] = fin;
    if (!truthy(a['remark'])) a['remark'] = (f['obs'] ?? '').isNotEmpty ? f['obs'] : (f['prog'] ?? '');
    if (!truthy(a['goal'])) a['goal'] = f['goals'] ?? '';
    var msg = l3('Session saved', 'Séance enregistrée', 'تم حفظ الحصة');
    if (next && nd.isNotEmpty) {
      final nwp = wpById(nw) ?? <String, dynamic>{};
      final ex = upcoming(str(a['pid'])).where((x) => x['id'] != a['id']).toList();
      if (ex.isEmpty) {
        mkAppt(<String, dynamic>{
          'id': 'na_pg_${a['pid']}_$nd',
          'pid': a['pid'],
          'date': nd,
          'time': nt.isEmpty ? '10:00' : nt,
          'place': truthy(nwp['n']) ? nwp['n'] : p['place'],
          'placeId': str(nwp['id']),
          'goal': ng,
          'acts': na,
          'materials': nm,
          'src': 'program',
        });
        msg += ' · ${l3('next appointment ', 'prochain rdv ', 'الموعد القادم ')}${fmtLoc(lang, nd, 'EEE d MMM')}';
      }
    }
    save();
    go();
    return msg;
  }

  void saveNext(String pid, {required String date, required String time, required String wpId, required String goal, required String acts, required String materials}) {
    final p = P(pid);
    if (p == null) return;
    final w = wpById(wpId) ?? <String, dynamic>{};
    final up = upcoming(pid);
    final ex = up.isEmpty ? null : up.first;
    if (ex != null && ex['date'] != date) {
      ex['date'] = date;
      ex['time'] = time.isEmpty ? ex['time'] : time;
      ex['place'] = truthy(w['n']) ? w['n'] : ex['place'];
      ex['placeId'] = truthy(w['id']) ? w['id'] : ex['placeId'];
      ex['goal'] = goal;
      ex['acts'] = acts;
      ex['materials'] = materials;
    } else {
      mkAppt(<String, dynamic>{
        'id': 'na_pg_${pid}_$date',
        'pid': pid,
        'date': date,
        'time': time.isEmpty ? '10:00' : time,
        'place': truthy(w['n']) ? w['n'] : p['place'],
        'placeId': str(w['id']),
        'goal': goal,
        'acts': acts,
        'materials': materials,
        'src': 'program',
      });
    }
    save();
    go();
    toast(l3('Appointment saved', 'Rendez-vous enregistré', 'تم حفظ الموعد'));
  }

  /// Returns false when nothing changed.
  bool doResched(String aid, String d, String t) {
    final a = apts.firstWhere((x) => x['id'] == aid, orElse: () => <String, dynamic>{});
    if (a.isEmpty || d.isEmpty || (d == a['date'] && t == a['time'])) {
      toast(l3('Choose a different date or time', 'Choisissez une autre date ou heure', 'اختاري تاريخاً أو وقتاً مختلفاً'));
      return false;
    }
    if (a['status'] == 'scheduled') {
      a['status'] = 'rescheduled';
      mkAppt(<String, dynamic>{
        'id': 'rs_${a['id']}_${d}_${t.replaceAll(':', '')}',
        'pid': a['pid'],
        'date': d,
        'time': t,
        'place': a['place'],
        'placeId': a['placeId'],
        'goal': a['goal'],
        'acts': a['acts'],
        'materials': a['materials'],
        'src': a['src'] == 'legacy' ? 'legacy' : 'manual',
        'from': a['id'],
      });
    }
    save();
    go();
    toast(l3('Rescheduled', 'Reprogrammé', 'تمت إعادة الجدولة'));
    return true;
  }

  // ================================================================= programs UI logic
  String? progSave(String pid, {required List<int> days, required double freq, required String time, required String start, required double dur, required String unit, required String end, required String wpId}) {
    final p = P(pid);
    if (p == null) return null;
    if (start.isEmpty) return l3('Pick a start date', 'Choisissez une date de début', 'اختاري تاريخ البداية');
    if (days.isEmpty && freq == 0) return l3('Choose weekdays or sessions per week', 'Choisissez des jours ou un nombre de séances par semaine', 'اختاري أياماً أو عدد الحصص في الأسبوع');
    final pr = p['prog'] is Map ? p['prog'] as J : legacyProg(p);
    final before = <String, dynamic>{'days': pr['days'], 'start': pr['start'], 'end': pr['end'], 'freq': pr['freq']};
    pr.addAll(<String, dynamic>{'days': days, 'freq': freq, 'per': 'week', 'time': time, 'start': start, 'dur': dur, 'unit': unit, 'end': end, 'legacy': days.isEmpty});
    pr['log'] = <dynamic>[...(pr['log'] is List ? pr['log'] as List : <dynamic>[]), <String, dynamic>{'t': isoNow(), 'ch': 'edit', 'from': before, 'to': <String, dynamic>{'days': days, 'start': start, 'end': end, 'freq': freq}}];
    p['prog'] = pr;
    final w = wpById(wpId);
    if (w != null) {
      p['wpId'] = w['id'];
      p['place'] = w['n'];
      p['pt'] = w['t'] == 'daycare' ? 'daycare' : 'center';
    }
    syncPatient(p);
    save();
    go();
    toast(l3('Program saved', 'Programme enregistré', 'تم حفظ البرنامج'));
    return null;
  }

  void pgStatus(String pid, String st) {
    final p = P(pid);
    if (p == null || p['prog'] is! Map) return;
    final pr = p['prog'] as J;
    pr['status'] = st;
    pr['log'] = <dynamic>[...(pr['log'] is List ? pr['log'] as List : <dynamic>[]), <String, dynamic>{'t': isoNow(), 'ch': st}];
    save();
    go();
    toast(st == 'paused' ? l3('Treatment paused', 'Traitement en pause', 'تم إيقاف العلاج مؤقتاً') : l3('Treatment resumed', 'Traitement repris', 'تم استئناف العلاج'));
  }

  void pgShift(String pid, int days) {
    final p = P(pid);
    if (p == null || p['prog'] is! Map) return;
    final pr = p['prog'] as J;
    final end = endOf(pr);
    if (end.isEmpty) return toast(l3('Set an end date first (Edit program).', 'Définissez d’abord une date de fin (Modifier le programme).', 'حدّدي تاريخ النهاية أولاً (تعديل البرنامج).'));
    final ne = addD(end, days);
    final ds = doneOf(p).map((a) => str(a['date'])).toList()..sort();
    final last = ds.isNotEmpty ? ds.last : (truthy(pr['start']) ? str(pr['start']) : td());
    if (days < 0 && ne.compareTo(last.compareTo(td()) > 0 ? last : td()) < 0) {
      return toast(l3('The program cannot end before today or the last completed session.', 'Le programme ne peut pas se terminer avant aujourd’hui ou la dernière séance réalisée.', 'لا يمكن أن ينتهي البرنامج قبل اليوم أو آخر حصة منجزة.'));
    }
    pr['end'] = ne;
    pr['log'] = <dynamic>[...(pr['log'] is List ? pr['log'] as List : <dynamic>[]), <String, dynamic>{'t': isoNow(), 'ch': days > 0 ? 'extend' : 'shorten', 'end': ne}];
    save();
    go();
  }

  // ================================================================== patients
  /// [o] holds the form fields; [extras] the additional workplace ids. Returns the saved id.
  String savePt(String id, J o, List<String> extras) {
    final conds = (o['conds'] as List).map((e) => str(e)).take(4).toList();
    o['conds'] = conds;
    final place = str(o['place']);
    if (place.isNotEmpty && !places.any((x) => x['n'] == place)) {
      places.add(<String, dynamic>{'n': place, 't': o['pt'], 'my': o['pt'] == 'daycare' ? 60 : 50, 'fee': 0, 'mode': 'pct', 'mine': 0});
      migrate();
    }
    J p;
    if (id.isNotEmpty) {
      p = P(id)!;
      final hadProg = p['prog'] is Map && progDays(p['prog'] as J).isNotEmpty;
      final keep = hadProg ? <String, dynamic>{'fn': p['fn'], 'fu': p['fu'], 'dv': p['dv'], 'du': p['du'], 'start': p['start']} : null;
      p.addAll(o);
      if (keep != null) p.addAll(keep);
    } else {
      o['id'] = uid();
      p = o;
      pats.add(p);
      v.pid = str(p['id']);
    }
    p['wpExtra'] = extras;
    syncPatient(p);
    save();
    go();
    toast('Patient saved');
    return str(p['id']);
  }

  void delPt(String id) {
    S!['p'] = pats.where((p) => p['id'] != id).toList();
    S!['a'] = apts.where((a) => a['pid'] != id).toList();
    save();
    nav('pats', d: -1);
  }

  void addAct(String cond, String text) {
    final t = text.trim();
    if (t.isEmpty) return;
    final m = act;
    final l = m[cond] is List ? m[cond] as List : <dynamic>[];
    l.add(t);
    m[cond] = l;
    save();
    go();
  }

  // ============================================================== consultations
  void saveCo(String id, J o) {
    if (o['type'] == 'parent' && truthy(o['pid'])) {
      final p = P(o['pid']);
      if (p != null) {
        o['phone'] = p['phone'];
        o['parent'] = p['parents'];
      }
    }
    if (id.isNotEmpty) {
      cons.firstWhere((x) => x['id'] == id).addAll(o);
    } else {
      o['id'] = uid();
      cons.add(o);
    }
    save();
    go();
    toast('Consultation saved');
  }

  void delCo(String id) {
    S!['c'] = cons.where((c) => c['id'] != id).toList();
    save();
    go();
  }

  void coSt(String id, String st) {
    cons.firstWhere((c) => c['id'] == id)['status'] = st;
    save();
    go();
    toast('Saved');
  }

  // ====================================================================== toys
  void saveToy(String id, {required String name, required String cat, required List<String> imgs}) {
    if (id.isNotEmpty) {
      final t = toysL.firstWhere((x) => x['id'] == id);
      t['name'] = name;
      t['cat'] = cat;
      final ni = imgs.isEmpty ? '' : imgs.first;
      if (ni != str(t['img'])) {
        t['img'] = ni;
        t.remove('imgPath');
        t.remove('imgH');
        t.remove('imgPend');
      }
    } else if (imgs.isNotEmpty) {
      for (final u in imgs) {
        toysL.add(<String, dynamic>{'id': uid(), 'name': imgs.length == 1 ? name : '', 'cat': cat, 'img': u, 'acts': <dynamic>[]});
      }
    } else {
      toysL.add(<String, dynamic>{'id': uid(), 'name': name, 'cat': cat, 'img': '', 'acts': <dynamic>[]});
    }
    save();
    go();
    toast('Toy saved');
  }

  void delToy(String id) {
    S!['toys'] = toysL.where((x) => x['id'] != id).toList();
    save();
    go();
  }

  // ==================================================================== AI review
  void aiApprove(String pid, int n, String text) {
    ais.add(<String, dynamic>{'id': 'ai_${uid()}', 'pid': pid, 'at': isoNow(), 'n': n, 'text': text.trim(), 'approved': true});
    save();
    go();
    toast(l3('Review saved to the patient’s history', 'Bilan enregistré dans le dossier du patient', 'تم حفظ المراجعة في سجل المريض'));
  }

  // ==================================================================== misc
  /// Suggested goal text (goal()).
  String goalText(J a, J? p) {
    if (truthy(a['goal'])) return str(a['goal']);
    String sug = 'Set a goal for this session';
    if (p != null) {
      final ids = condIds(p);
      if (ids.isNotEmpty) {
        final c = condById(ids.first);
        if (c != null) sug = (c[3] as List).first as String;
      }
    }
    return '${T('Suggested:')} $sug';
  }

  List<J> dayList() {
    final L = apts.where((a) => a['date'] == v.day).toList();
    L.sort((x, y) => str(x['time']).compareTo(str(y['time'])));
    return L;
  }

  /// Local-notification friendly list of condition labels.
  String condLabel(String id) {
    final c = condById(id);
    return c == null ? '' : shortCond(c[1] as String);
  }
}
