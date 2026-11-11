import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import '../core/globals.dart';
import '../core/i18n.dart';
import '../core/store.dart';
import '../core/util.dart';
import 'app_state.dart';

/// Port of cloud-sync.js.
///  - same Firestore documents: users/{uid}/app/data | toys | backup  ({json, t, v, by})
///  - offline-first with a persistent "pending" flag cleared only after Firestore confirms
///  - every write is a transaction doing a 3-way merge (base / this device / cloud) record by record
///  - live listeners bring the other device's changes in
///  - photos go to Firebase Storage; Firestore keeps only the URL + path

const int kBackupEveryMs = 6 * 3600 * 1000;
const int kMaxDocChars = 950000;
const List<String> kBaseCols = ['p', 'a', 'c', 'sr', 'ai', 'toys', 'me.places'];

// ---------------------------------------------------------------- hashing
String h32(String s) {
  var h = 2166136261;
  for (var i = 0; i < s.length; i++) {
    h ^= s.codeUnitAt(i);
    h = (h * 16777619) & 0xFFFFFFFF;
  }
  return '${h.toRadixString(36)}.${s.length.toRadixString(36)}';
}

String _numStr(num n) {
  if (n is int) return n.toString();
  final d = n.toDouble();
  if (d.isFinite && d == d.truncateToDouble() && d.abs() < 1e15) return d.toInt().toString();
  return d.toString();
}

String stable(dynamic v) {
  if (v == null) return 'null';
  if (v is num) return _numStr(v);
  if (v is String || v is bool) return jsonEncode(v);
  if (v is List) return '[${v.map(stable).join(',')}]';
  if (v is Map) {
    final keys = v.keys.map((k) => k.toString()).where((k) => k != '_u').toList()..sort();
    return '{${keys.map((k) => '${jsonEncode(k)}:${stable(v[k])}').join(',')}}';
  }
  return jsonEncode(v.toString());
}

String H(dynamic v) => h32(stable(v));

dynamic clone(dynamic o) => o == null ? null : jsonDecode(jsonEncode(o));
bool isPlain(dynamic v) => v is Map;
bool isRec(dynamic x) => x is Map && x['id'] != null && x['id'] != '';
List<String> union(Iterable<String> a, Iterable<String> b) {
  final seen = <String>{};
  final r = <String>[];
  for (final k in [...a, ...b]) {
    if (seen.add(k)) r.add(k);
  }
  return r;
}

// ------------------------------------------------------------ path helpers
dynamic getPath(J? s, String p) {
  if (s == null) return null;
  final i = p.indexOf('.');
  if (i < 0) return s[p];
  final o = s[p.substring(0, i)];
  return o is Map ? o[p.substring(i + 1)] : null;
}

void setPath(J s, String p, dynamic v, {bool remove = false}) {
  final i = p.indexOf('.');
  if (i < 0) {
    if (remove) {
      s.remove(p);
    } else {
      s[p] = v;
    }
    return;
  }
  final a = p.substring(0, i), b = p.substring(i + 1);
  if (s[a] is! Map) {
    if (remove) return;
    s[a] = <String, dynamic>{};
  }
  if (remove) {
    (s[a] as Map).remove(b);
  } else {
    (s[a] as Map)[b] = v;
  }
}

List<String> colsOf(List<J?> states) {
  final out = List<String>.from(kBaseCols);
  for (final s in states) {
    if (s == null) continue;
    for (final k in s.keys) {
      final v = s[k];
      if (k != 'toysDoc' && !out.contains(k) && v is List && v.isNotEmpty && v.every(isRec)) out.add(k);
    }
  }
  return out;
}

Map<String, dynamic> atomsOf(J? s, List<String> cols) {
  final o = <String, dynamic>{};
  if (s == null) return o;
  for (final k in s.keys) {
    if (k == 'toysDoc' || k == '_at' || cols.contains(k)) continue;
    final v = s[k];
    if (v is Map) {
      for (final sk in v.keys) {
        final p = '$k.$sk';
        if (!cols.contains(p)) o[p] = v[sk];
      }
    } else {
      o[k] = v;
    }
  }
  return o;
}

class Snap {
  Map<String, Map<String, String>> c = {};
  Map<String, String> a = {};
  int t = 0;
  bool none = false;
}

Snap snapshot(J? s) {
  final cols = colsOf([s]);
  final r = Snap();
  for (final col in cols) {
    final m = <String, String>{};
    final l = getPath(s, col);
    if (l is List) {
      for (final x in l) {
        if (isRec(x)) m[(x as Map)['id'].toString()] = H(x);
      }
    }
    r.c[col] = m;
  }
  final at = atomsOf(s, cols);
  for (final p in at.keys) {
    r.a[p] = H(at[p]);
  }
  return r;
}

J norm(J s) {
  final o = Map<String, dynamic>.from(s);
  o.remove('toysDoc');
  return o;
}

int recCount(J? s) {
  var n = 0;
  for (final c in colsOf([s])) {
    final l = getPath(s, c);
    if (l is List) n += l.length;
  }
  return n;
}

bool isEmptyState(J? s) => recCount(s) == 0 && (s == null || s['act'] is! Map || (s['act'] as Map).isEmpty);

// ------------------------------------------------------------ 3-way merge
List<dynamic> mergeCol(Map<String, String> bH, List<dynamic> lArr, List<dynamic> rArr) {
  final lm = <String, dynamic>{}, rm = <String, dynamic>{};
  final ids = <String>[];
  final extraL = <dynamic>[], extraR = <dynamic>[];
  final out = <dynamic>[];
  for (final r in lArr) {
    if (isRec(r)) {
      lm[(r as Map)['id'].toString()] = r;
    } else {
      extraL.add(r);
    }
  }
  for (final r in rArr) {
    if (isRec(r)) {
      final id = (r as Map)['id'].toString();
      rm[id] = r;
      ids.add(id);
    } else {
      extraR.add(r);
    }
  }
  for (final id in lm.keys) {
    if (!rm.containsKey(id)) ids.add(id);
  }
  for (final id in ids) {
    final l = lm[id], r = rm[id], b = bH[id];
    dynamic pick;
    if (l != null && r != null) {
      final lh = H(l), rh = H(r);
      if (lh == rh) {
        pick = r;
      } else {
        final lc = b == null || lh != b;
        final rc = b == null || rh != b;
        if (lc && !rc) {
          pick = l;
        } else if (rc && !lc) {
          pick = r;
        } else {
          final lu = nv((l as Map)['_u']), ru = nv((r as Map)['_u']);
          pick = lu > ru ? l : r;
        }
      }
    } else if (l != null) {
      pick = (b == null || H(l) != b) ? l : null; // remote deleted it: keep only if edited here
    } else {
      pick = (b == null || H(r) != b) ? r : null; // local deleted it: keep only if edited remotely
    }
    if (pick != null) out.add(pick);
  }
  final seen = <String>{};
  for (final x in [...extraR, ...extraL]) {
    if (seen.add(stable(x))) out.add(x);
  }
  return out;
}

class _Pick {
  final dynamic val;
  final bool has;
  _Pick(this.val, this.has);
}

dynamic resolveAtom(String path, dynamic lv, dynamic rv, num lt, num rt) {
  if (path.startsWith('runs.') && lv is Map && rv is Map) {
    final ll = str(lv['last']), rl = str(rv['last']);
    return <String, dynamic>{
      'runs': nv(lv['runs']) > nv(rv['runs']) ? nv(lv['runs']).round() : nv(rv['runs']).round(),
      'best': nv(lv['best']) > nv(rv['best']) ? nv(lv['best']).round() : nv(rv['best']).round(),
      'last': ll.compareTo(rl) > 0 ? ll : rl,
    };
  }
  return lt > rt ? lv : rv;
}

J mergeStates(Snap? base, J L, J R) {
  final b0 = base ?? Snap();
  final cols = colsOf([L, R]);
  final M = clone(R) as Map<String, dynamic>;
  for (final c in cols) {
    final lA = getPath(L, c);
    final rA = getPath(R, c);
    setPath(M, c, mergeCol(b0.c[c] ?? <String, String>{}, lA is List ? lA : <dynamic>[], rA is List ? rA : <dynamic>[]));
  }
  final la = atomsOf(L, cols), ra = atomsOf(R, cols);
  final lt = L['_at'] is Map ? L['_at'] as Map : <dynamic, dynamic>{};
  final rt = R['_at'] is Map ? R['_at'] as Map : <dynamic, dynamic>{};
  for (final p in union(la.keys, ra.keys)) {
    final hasL = la.containsKey(p), hasR = ra.containsKey(p);
    final lv = la[p], rv = ra[p];
    final b = b0.a[p];
    final lh = hasL ? H(lv) : '~', rh = hasR ? H(rv) : '~';
    _Pick pk;
    if (lh == rh) {
      pk = _Pick(rv, hasR);
    } else if (b == null && !hasL) {
      pk = _Pick(rv, hasR);
    } else if (b == null && !hasR) {
      pk = _Pick(lv, hasL);
    } else {
      final lc = b == null || lh != b;
      final rc = b == null || rh != b;
      if (lc && !rc) {
        pk = _Pick(lv, hasL);
      } else if (rc && !lc) {
        pk = _Pick(rv, hasR);
      } else if (!hasL || !hasR) {
        pk = !hasL ? _Pick(rv, hasR) : _Pick(lv, hasL);
      } else {
        pk = _Pick(resolveAtom(p, lv, rv, nv(lt[p]), nv(rt[p])), true);
      }
    }
    if (pk.has) {
      setPath(M, p, clone(pk.val));
    } else {
      setPath(M, p, null, remove: true);
    }
  }
  final at = <String, dynamic>{};
  rt.forEach((k, v) => at[k.toString()] = v);
  lt.forEach((k, v) {
    final key = k.toString();
    final a = nv(at[key]), bb = nv(v);
    at[key] = a > bb ? at[key] : v;
  });
  if (at.isNotEmpty) M['_at'] = at;
  if (truthy(R['toysDoc']) || truthy(L['toysDoc'])) M['toysDoc'] = 1;
  return M;
}

// ---------------------------------------------------------------- status
class SyncInfo {
  final String s; // idle | saving | saved | pending | offline | photos | error
  final String detail;
  final int lastSync;
  final int photosPending;
  final String storageState;
  const SyncInfo(this.s, this.detail, this.lastSync, this.photosPending, this.storageState);
}

const Map<String, List<String>> kSyncTxt = {
  'saving': ['Saving…', 'Enregistrement…', 'جارٍ الحفظ…'],
  'saved': ['Saved to cloud', 'Enregistré dans le cloud', 'تم الحفظ في السحابة'],
  'pending': ['Saved on device · waiting to sync', 'Enregistré sur l’appareil · en attente', 'محفوظ على الجهاز · بانتظار المزامنة'],
  'offline': ['Offline · saved on device', 'Hors ligne · enregistré sur l’appareil', 'بدون اتصال · محفوظ على الجهاز'],
  'photos': ['Saved · photos waiting to upload', 'Enregistré · photos en attente', 'تم الحفظ · الصور بانتظار الرفع'],
  'error': ['Cloud error · tap for details', 'Erreur cloud · appuyez', 'خطأ في السحابة · اضغط للتفاصيل'],
};

class _Ctx {
  final AppUser u;
  final DocumentReference<Map<String, dynamic>> refData, refToys, refBak;
  final List<StreamSubscription<dynamic>> subs = [];
  DocumentSnapshot<Map<String, dynamic>>? rData, rToys;
  bool queued = false;
  _Ctx(this.u, this.refData, this.refToys, this.refBak);
}

class _CommitOut {
  bool skip = false, blocked = false, noWrite = false, bak = false;
  J? M;
  Snap? lsnap;
  int t = 0;
}

class _SyncErr implements Exception {
  final String code;
  _SyncErr(this.code);
  @override
  String toString() => code;
}

class _Remote {
  final J R;
  final int t;
  _Remote(this.R, this.t);
}

class SyncEngine {
  _Ctx? C;
  Snap BASE = Snap()..none = true;
  Snap LH = Snap();
  int saveSeq = 0;
  bool running = false, again = false;
  Timer? timer, retryTimer, remoteTimer;
  int retryN = 0;
  int photosPending = 0, lastSync = 0;
  String storageState = '';
  Map<String, dynamic> PH = {};
  String seenPref = '';
  String devId = '';
  int lastT = 0;

  final ValueNotifier<SyncInfo> info = ValueNotifier<SyncInfo>(const SyncInfo('idle', '', 0, 0, ''));

  J get S => app.S!;
  String get K => app.K;
  bool get active => C != null;

  // -------------------------------------------------------- local storage
  String get kBase => '${K}_syncbase';
  String get kPend => '${K}_pend';
  String get kPH => '${K}_photos';
  String get kKnown => '${K}_stor';
  bool get isPend => Store.get(kPend) != null;
  void setPend() => Store.set(kPend, DateTime.now().millisecondsSinceEpoch.toString());
  void clrPend() => Store.del(kPend);

  void loadBase() {
    try {
      final raw = Store.get(kBase);
      if (raw != null) {
        final m = jsonDecode(raw);
        if (m is Map && m['c'] is Map) {
          final b = Snap();
          (m['c'] as Map).forEach((col, mm) {
            b.c[col.toString()] = (mm as Map).map((k, v) => MapEntry(k.toString(), v.toString()));
          });
          if (m['a'] is Map) b.a = (m['a'] as Map).map((k, v) => MapEntry(k.toString(), v.toString()));
          b.t = iv(m['t']);
          BASE = b;
          return;
        }
      }
    } catch (_) {}
    BASE = Snap()..none = true;
  }

  void saveBase(J R, int t) {
    final b = snapshot(R);
    b.t = t;
    BASE = b;
    Store.set(kBase, jsonEncode({'c': b.c, 'a': b.a, 't': b.t}));
  }

  void loadPH() {
    try {
      final raw = Store.get(kPH);
      PH = raw == null ? {} : Map<String, dynamic>.from(jsonDecode(raw) as Map);
    } catch (_) {
      PH = {};
    }
  }

  List<String> getKnown() {
    try {
      final raw = Store.get(kKnown);
      return raw == null ? <String>[] : (jsonDecode(raw) as List).map((e) => e.toString()).toList();
    } catch (_) {
      return <String>[];
    }
  }

  void setKnown(List<String> a) => Store.set(kKnown, jsonEncode(a));

  void trackPaths(dynamic toys) {
    final k = getKnown();
    var ch = false;
    if (toys is List) {
      for (final t in toys) {
        if (t is Map && t['imgPath'] != null && !k.contains(t['imgPath'].toString())) {
          k.add(t['imgPath'].toString());
          ch = true;
        }
      }
    }
    if (ch) setKnown(k);
  }

  void _initDevId() {
    var d = Store.get('sc_device_id');
    if (d == null || d.isEmpty) {
      d = 'd${uid()}${DateTime.now().millisecondsSinceEpoch.toRadixString(36)}';
      Store.set('sc_device_id', d);
    }
    devId = d;
  }

  void setStatus(String s, [String detail = '']) {
    info.value = SyncInfo(s, detail, lastSync, photosPending, storageState);
  }

  // ----------------------------------------------------------------- stamp
  void stamp() {
    final snap = snapshot(S);
    final cols = colsOf([S]);
    final now = DateTime.now().millisecondsSinceEpoch;
    if (S['_at'] is! Map) S['_at'] = <String, dynamic>{};
    final at = S['_at'] as Map;
    for (final col in cols) {
      final l = getPath(S, col);
      if (l is List) {
        for (final r in l) {
          if (isRec(r)) {
            final id = (r as Map)['id'].toString();
            if ((LH.c[col] ?? const <String, String>{})[id] != (snap.c[col] ?? const <String, String>{})[id]) r['_u'] = now;
          }
        }
      }
    }
    for (final p in snap.a.keys) {
      if (LH.a[p] != snap.a[p]) at[p] = now;
    }
    for (final p in LH.a.keys) {
      if (!snap.a.containsKey(p)) at[p] = now;
    }
    LH = snap;
  }

  /// Called by AppState.save() BEFORE the local write.
  void onSave() {
    if (C == null || app.S == null) return;
    try {
      stamp();
    } catch (_) {}
    saveSeq++;
    setPend();
    setStatus('saving');
    schedulePush(700);
  }

  void schedulePush(int ms) {
    timer?.cancel();
    timer = Timer(Duration(milliseconds: ms), () => pushNow());
  }

  void onPrefChanged() {
    if (C == null || app.S == null) return;
    final cur = stable({'lang': app.lang, 'theme': app.theme});
    if (seenPref.isNotEmpty && cur != seenPref) {
      seenPref = cur;
      S['prefs'] = <String, dynamic>{'lang': app.lang, 'theme': app.theme};
      app.save();
    }
  }

  /// Activity counters (speechcare_activity_runs) travel with the cloud state.
  void onActRuns() {
    if (C == null || app.S == null) return;
    try {
      final o = jsonDecode(Store.get('speechcare_activity_runs') ?? '{}');
      S['runs'] = o;
      app.save();
    } catch (_) {}
  }

  // ---------------------------------------------------------------- photos
  String _sha(String s) => h32(s).replaceAll('.', '') + h32(String.fromCharCodes(s.codeUnits.reversed)).replaceAll('.', '');

  Future<Map<String, dynamic>> putPhoto(String dataUrl) async {
    final i = dataUrl.indexOf(',');
    final head = dataUrl.substring(5, i);
    final type = head.split(';').first.isEmpty ? 'image/jpeg' : head.split(';').first;
    final bytes = base64Decode(dataUrl.substring(i + 1));
    final sig = _sha(dataUrl);
    final path = 'users/${C!.u.uid}/toys/$sig.jpg';
    final known = PH[sig];
    if (known is Map && known['path'] == path) return {'sig': sig, 'path': known['path'], 'url': known['url']};
    final ref = FirebaseStorage.instance.ref(path);
    await ref.putData(Uint8List.fromList(bytes), SettableMetadata(contentType: type, cacheControl: 'private,max-age=31536000')).timeout(const Duration(seconds: 60));
    final url = await ref.getDownloadURL().timeout(const Duration(seconds: 30));
    PH[sig] = {'path': path, 'url': url};
    Store.set(kPH, jsonEncode(PH));
    return {'sig': sig, 'path': path, 'url': url};
  }

  Future<void> delPhoto(String path) async {
    try {
      await FirebaseStorage.instance.ref(path).delete().timeout(const Duration(seconds: 30));
    } on FirebaseException catch (e) {
      if (e.code == 'object-not-found') return;
      rethrow;
    }
  }

  Future<int> uploadPhotos() async {
    final toys = List<J>.from(app.toysL);
    var fails = 0;
    for (final t in toys) {
      final img = t['img'];
      if (img is! String || !img.startsWith('data:')) continue;
      try {
        final r = await putPhoto(img);
        final cur = app.toysL.where((x) => x['id'] == t['id']).toList();
        if (cur.isNotEmpty && cur.first['img'] == img) {
          cur.first['img'] = r['url'];
          cur.first['imgPath'] = r['path'];
          cur.first['imgH'] = r['sig'];
          (LH.c['toys'] ??= <String, String>{})[cur.first['id'].toString()] = H(cur.first);
        }
        storageState = l3('Photo storage: working', 'Stockage photo : OK', 'تخزين الصور: يعمل');
      } catch (e) {
        fails++;
        storageState = l3('Photo upload failed: ', 'Échec d’envoi photo : ', 'فشل رفع الصورة: ') + _code(e);
      }
    }
    photosPending = app.toysL.where((x) => x['img'] is String && (x['img'] as String).startsWith('data:')).length;
    app.persistLocal();
    return fails;
  }

  Future<void> cleanupOrphans(J? committed) async {
    final refd = <String, bool>{};
    for (final t in [...app.toysL, ...asList(committed == null ? null : committed['toys'])]) {
      if (t['imgPath'] != null) refd[t['imgPath'].toString()] = true;
    }
    final known = getKnown();
    final keep = <String>[];
    for (final p in known) {
      if (refd[p] == true) {
        keep.add(p);
        continue;
      }
      try {
        await delPhoto(p);
        PH.removeWhere((k, v) => v is Map && v['path'] == p);
        Store.set(kPH, jsonEncode(PH));
      } catch (_) {
        keep.add(p);
      }
    }
    setKnown(keep);
  }

  String _code(Object e) {
    if (e is FirebaseException) return e.code;
    if (e is _SyncErr) return e.code;
    if (e is TimeoutException) return 'timeout';
    return e.toString();
  }

  // ------------------------------------------------------------ cloud docs
  _Remote? parseRemote(DocumentSnapshot<Map<String, dynamic>>? dS, DocumentSnapshot<Map<String, dynamic>>? tS) {
    if (dS == null || !dS.exists) return null;
    final d = dS.data() ?? {};
    J R;
    try {
      final x = jsonDecode(d['json'] as String);
      if (x is! Map) return null;
      R = Map<String, dynamic>.from(x);
    } catch (_) {
      return null;
    }
    if (truthy(R['toysDoc'])) {
      R['toys'] = <dynamic>[];
      if (tS != null && tS.exists) {
        try {
          final tj = jsonDecode((tS.data() ?? {})['json'] as String);
          if (tj is List) R['toys'] = tj;
        } catch (_) {}
      }
    }
    final tt = (tS != null && tS.exists) ? iv((tS.data() ?? {})['t']) : 0;
    return _Remote(R, iv(d['t']) > tt ? iv(d['t']) : tt);
  }

  J cloudPayload(J M) {
    final P = clone(M) as Map<String, dynamic>;
    P.remove('_tmp');
    final toys = P['toys'];
    if (toys is List) {
      for (final t in toys) {
        if (t is Map && t['img'] is String && (t['img'] as String).startsWith('data:')) {
          t['img'] = '';
          t['imgPend'] = 1;
        }
      }
    }
    return P;
  }

  int baseCount() {
    var n = 0;
    for (final c in BASE.c.values) {
      n += c.length;
    }
    return n;
  }

  Future<_CommitOut> commit() async {
    final out = _CommitOut();
    final c = C!;
    final bakT = int.tryParse(Store.get('sc_bak_t') ?? '') ?? 0;
    await FirebaseFirestore.instance.runTransaction((tx) async {
      final dS = await tx.get(c.refData);
      final tS = await tx.get(c.refToys);
      final rr = parseRemote(dS, tS);
      final L = cloudPayload(S);
      J M;
      var noWrite = false;
      var blocked = false;
      if (rr == null) {
        if (isEmptyState(L)) {
          out.skip = true;
          return;
        }
        M = L;
      } else if (isEmptyState(L) && recCount(rr.R) > 0 && baseCount() >= 3) {
        M = rr.R;
        noWrite = true;
        blocked = true; // local suddenly empty but we had data: restore, never wipe
      } else {
        M = mergeStates(BASE, L, rr.R);
      }
      final rt = rr == null ? 0 : rr.t;
      final now = DateTime.now().millisecondsSinceEpoch;
      final t = now > rt + 1 ? now : rt + 1;
      final main = jsonEncode(<String, dynamic>{...M, 'toys': <dynamic>[], 'toysDoc': 1});
      if (main.length > kMaxDocChars) throw _SyncErr('size');
      final toysJson = jsonEncode(M['toys'] ?? <dynamic>[]);
      var bak = false;
      if (!noWrite) {
        if (rr != null && now - bakT > kBackupEveryMs) {
          final dd = dS.data() ?? {};
          tx.set(c.refBak, {'json': dd['json'], 't': dd['t'], 'saved': now, 'by': devId});
          bak = true;
        }
        if (!tS.exists || (tS.data() ?? {})['json'] != toysJson) {
          tx.set(c.refToys, {'json': toysJson, 't': t, 'v': 2, 'by': devId});
        }
        tx.set(c.refData, {'json': main, 't': t, 'v': 2, 'by': devId});
      }
      out
        ..M = M
        ..lsnap = snapshot(L)
        ..t = noWrite ? rt : t
        ..noWrite = noWrite
        ..bak = bak
        ..blocked = blocked
        ..skip = false;
    }).timeout(const Duration(seconds: 25));
    if (out.bak) Store.set('sc_bak_t', DateTime.now().millisecondsSinceEpoch.toString());
    return out;
  }

  String classify(Object e) {
    final c = _code(e);
    if (RegExp('size', caseSensitive: false).hasMatch(c)) return 'error';
    if (RegExp('unavailable|network|offline|timeout|deadline|aborted|failed to get|socket', caseSensitive: false).hasMatch(c)) return 'offline';
    return 'error';
  }

  Future<void> pushNow() async {
    final ctx = C;
    if (ctx == null || app.S == null) return;
    if (running) {
      again = true;
      return;
    }
    running = true;
    final seq = saveSeq;
    retryTimer?.cancel();
    if (info.value.s != 'saving') setStatus('saving');
    try {
      final fails = await uploadPhotos();
      _CommitOut out;
      try {
        out = await commit();
      } catch (e) {
        if (RegExp('permission|unauthenticated', caseSensitive: false).hasMatch(_code(e))) {
          await ctx.u.fb?.getIdToken(true); // token / email_verified claim may be stale
          out = await commit();
        } else {
          rethrow;
        }
      }
      if (!identical(C, ctx)) return;
      if (out.skip) {
        lastSync = DateTime.now().millisecondsSinceEpoch;
        if (saveSeq == seq) clrPend();
        setStatus('saved');
        retryN = 0;
        return;
      }
      lastSync = DateTime.now().millisecondsSinceEpoch;
      retryN = 0;
      final M = out.M!;
      trackPaths(M['toys']);
      // fold the confirmed cloud state back in: base = what we sent
      final Snew = out.blocked ? (clone(M) as Map<String, dynamic>) : mergeStates(out.lsnap, S, M);
      final changed = stable(norm(Snew)) != stable(norm(S));
      saveBase(M, out.t);
      lastT = out.t > lastT ? out.t : lastT;
      if (changed) {
        app.S = Snew;
        afterExternal();
      }
      app.persistLocal();
      if (saveSeq == seq && !out.blocked) clrPend();
      if (saveSeq != seq) schedulePush(300);
      try {
        await cleanupOrphans(M);
      } catch (_) {}
      if (out.blocked) {
        setStatus('error', l3('Local data was empty: restored from cloud instead of overwriting it.', 'Données locales vides : restaurées depuis le cloud.', 'البيانات المحلية فارغة: تمت الاستعادة من السحابة.'));
      } else if (fails > 0 || photosPending > 0) {
        setStatus('photos', storageState);
        retryLater();
      } else {
        setStatus('saved');
      }
    } catch (e) {
      if (!identical(C, ctx)) return;
      final k = classify(e);
      setStatus(k == 'offline' ? 'offline' : 'error', _code(e));
      retryLater();
    } finally {
      running = false;
      if (again) {
        again = false;
        schedulePush(300);
      }
      if (C != null && C!.queued) {
        C!.queued = false;
        onRemote();
      }
    }
  }

  void retryLater() {
    retryTimer?.cancel();
    final d = (5000 * _pow3(retryN++)).clamp(0, 300000);
    retryTimer = Timer(Duration(milliseconds: d), () {
      if (C != null && (isPend || photosPending > 0)) pushNow();
    });
  }

  int _pow3(int n) {
    var r = 1;
    for (var i = 0; i < n && i < 6; i++) {
      r *= 3;
    }
    return r;
  }

  Future<void> syncNow() {
    retryN = 0;
    return pushNow();
  }

  /// App resumed / connectivity may be back.
  void resume() {
    if (C != null && (isPend || photosPending > 0)) {
      retryN = 0;
      pushNow();
    }
  }

  void tick() {
    if (C != null && !running && (isPend || photosPending > 0)) pushNow();
  }

  // ---------------------------------------------------------- pull + listen
  void afterExternal() {
    try {
      app.mig();
    } catch (_) {}
    try {
      final pf = S['prefs'];
      if (pf is Map) {
        final nl = pf['lang'], nt = pf['theme'];
        if (nl is String && ['en', 'fr', 'ar'].contains(nl) && (nl != app.lang || (nt is String && nt != app.theme))) {
          app.lang = nl;
          if (nt is String) app.theme = nt;
          Store.set(kPrefKey, jsonEncode({'lang': app.lang, 'theme': app.theme}));
          I18n.lang = app.lang;
        }
        seenPref = stable({'lang': app.lang, 'theme': app.theme});
      }
      if (S['runs'] is Map) Store.set('speechcare_activity_runs', jsonEncode(S['runs']));
    } catch (_) {}
    app.persistLocal();
    LH = snapshot(S);
    app.refreshUI();
  }

  bool integrate(J R, int t, bool force) {
    if (!force && t <= BASE.t) return false;
    if (BASE.none && Store.get('${K}_prebackup') == null) {
      try {
        Store.set('${K}_prebackup', jsonEncode(S));
      } catch (_) {}
    }
    final M2 = mergeStates(BASE, S, R);
    final changed = stable(norm(M2)) != stable(norm(S));
    saveBase(R, t);
    lastT = t > lastT ? t : lastT;
    trackPaths(R['toys']);
    if (changed) {
      app.S = M2;
      afterExternal();
    }
    if (stable(norm(M2)) != stable(norm(R))) {
      setPend();
      schedulePush(500);
    } else if (photosPending == 0) {
      clrPend();
    }
    return changed;
  }

  void onRemote() {
    final c = C;
    if (c == null || c.rData == null || c.rToys == null) return;
    remoteTimer?.cancel();
    remoteTimer = Timer(const Duration(milliseconds: 250), () {
      if (C == null) return;
      if (running) {
        C!.queued = true;
        return;
      }
      final rr = parseRemote(C!.rData, C!.rToys);
      if (rr == null) return;
      if (integrate(rr.R, rr.t, false)) setStatus(isPend ? 'pending' : 'saved');
    });
  }

  void attach() {
    final c = C!;
    void onS(bool data, DocumentSnapshot<Map<String, dynamic>> snap) {
      if (snap.metadata.hasPendingWrites || snap.metadata.isFromCache) return;
      if (data) {
        c.rData = snap;
      } else {
        c.rToys = snap;
      }
      onRemote();
    }

    void onE(Object e) {
      if (RegExp('permission', caseSensitive: false).hasMatch(_code(e))) setStatus('error', _code(e));
    }

    c.subs.add(c.refData.snapshots(includeMetadataChanges: true).listen((s) => onS(true, s), onError: onE));
    c.subs.add(c.refToys.snapshots(includeMetadataChanges: true).listen((s) => onS(false, s), onError: onE));
  }

  Future<bool> initialSync(AppUser u) async {
    stop(quiet: true);
    _initDevId();
    final db = FirebaseFirestore.instance;
    final base = 'users/${u.uid}/app/';
    C = _Ctx(u, db.doc('${base}data'), db.doc('${base}toys'), db.doc('${base}backup'));
    loadBase();
    loadPH();
    LH = snapshot(S);
    var ok = true;
    try {
      final ds = await Future.wait([
        C!.refData.get(const GetOptions(source: Source.server)),
        C!.refToys.get(const GetOptions(source: Source.server)),
      ]).timeout(const Duration(seconds: 9));
      final rr = parseRemote(ds[0], ds[1]);
      if (rr != null) {
        integrate(rr.R, rr.t, true);
      } else if (!isEmptyState(S)) {
        setPend(); // legacy local-only data: upload it (never an empty state)
      }
    } catch (_) {
      ok = false;
      toastOffline();
    }
    attach();
    setStatus(ok ? (isPend ? 'pending' : 'saved') : 'offline');
    if (isPend) schedulePush(ok ? 400 : 8000);
    return ok;
  }

  void toastOffline() => toast('Offline: showing data saved on this device.');

  /// Called at the end of enter(), after mig().
  void ready() {
    if (C == null || app.S == null) return;
    LH = snapshot(S);
    seenPref = stable({'lang': app.lang, 'theme': app.theme});
    final cur = snapshot(S);
    final diff = stable(cur.c) != stable(BASE.c) || stable(cur.a) != stable(BASE.a);
    if (diff && !BASE.none) {
      setPend();
      schedulePush(800);
    } else if (BASE.none && !isEmptyState(S)) {
      setPend();
      schedulePush(800);
    }
  }

  void stop({bool quiet = false}) {
    final c = C;
    if (c != null) {
      for (final s in c.subs) {
        s.cancel();
      }
    }
    timer?.cancel();
    retryTimer?.cancel();
    remoteTimer?.cancel();
    C = null;
    running = false;
    again = false;
    if (!quiet) setStatus('idle');
  }

  /// Real upload + download URL + delete of a 1-pixel image.
  Future<bool> checkStorage() async {
    final c = C;
    if (c == null) return false;
    const png = 'data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR4nGP4z8DwHwAFAAH/q842iQAAAABJRU5ErkJggg==';
    final path = 'users/${c.u.uid}/_probe_${DateTime.now().millisecondsSinceEpoch}.png';
    try {
      final i = png.indexOf(',');
      final bytes = base64Decode(png.substring(i + 1));
      final ref = FirebaseStorage.instance.ref(path);
      await ref.putData(Uint8List.fromList(bytes), SettableMetadata(contentType: 'image/png')).timeout(const Duration(seconds: 30));
      await ref.getDownloadURL().timeout(const Duration(seconds: 20));
      await delPhoto(path);
      storageState = l3('Photo storage: working (upload, download and delete verified)', 'Stockage photo : OK (envoi, lecture, suppression vérifiés)', 'تخزين الصور: يعمل (تم التحقق من الرفع والتنزيل والحذف)');
      setStatus(info.value.s, info.value.detail);
      return true;
    } catch (e) {
      final code = _code(e);
      storageState = l3('Photo storage NOT working ($code). In Firebase Console open Build → Storage → Get started, then publish storage.rules.', 'Stockage photo NON fonctionnel ($code). Console Firebase : Build → Storage → Commencer, puis publiez storage.rules.', 'تخزين الصور لا يعمل ($code). في وحدة تحكم Firebase: Build → Storage → Get started ثم انشر storage.rules.');
      setStatus(info.value.s, info.value.detail);
      return false;
    }
  }
}
