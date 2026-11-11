import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart' as fa;
import '../core/data_gen.dart';
import '../core/globals.dart';
import '../core/i18n.dart';
import '../core/store.dart';
import '../core/theme.dart';
import '../core/util.dart';
import '../firebase_options.dart';
import 'ai_service.dart';
import 'notifications.dart';
import 'sync_engine.dart';

/// Main sections (bottom bar): they exist only there, not in the side menu.
const List<String> kMain = ['home', 'sess', 'pats', 'cons', 'rep'];
const Map<String, String> kTy = {'center': 'Center', 'daycare': 'Daycare'};
const Map<String, String> kSt = {
  'scheduled': 'Planned',
  'done': 'Done',
  'absent': 'Absent',
  'cancelled': 'Cancelled',
  'rescheduled': 'Rescheduled',
};
const String kPrefKey = 'ortho_pref';

class AppUser {
  final String uid;
  final String email;
  final String displayName;
  final bool preview;
  final fa.User? fb;
  AppUser({required this.uid, required this.email, required this.displayName, this.preview = false, this.fb});
}

/// Port of the global `V` view-state object.
class ViewState {
  String t = 'home';
  String prev = 'home';
  int dir = 0;
  String? pid;
  String day = td();
  String mon = td().substring(0, 7);
  String rm = 'parent';
  int rp = 3;
  String rl = 'fr';
  String rr = 'teacher';
  String per = 'day';
  String f = 'all';
  String am = 'in';
  String sq = '';
  String pq = '';
  bool sd = false;
  bool cm = false;
  String cf = 'all';
  String fp = 'month';
  String wf = 'all';
  String sm = 'appts';
  String actCat = 'all';
  bool fe = false;
}

class AppState extends ChangeNotifier {
  // ---- preferences (PR) ----
  String lang = 'en';
  String theme = 'system';

  // ---- session ----
  J? S;
  String K = '';
  AppUser? U;
  final ViewState v = ViewState();
  bool fbOk = false;
  String root = 'splash'; // splash | auth | shell
  final SyncEngine sync = SyncEngine();
  Timer? _remindTimer;
  StreamSubscription<fa.User?>? _authSub;

  Color get secColor => root == 'shell' ? (kSecc[v.t] ?? Pal.pri) : Pal.pri;

  // ------------------------------------------------------------------ prefs
  void loadPref() {
    final dev = WidgetsBinding.instance.platformDispatcher.locale.languageCode;
    lang = (dev == 'fr' || dev == 'ar') ? dev : 'en';
    try {
      final raw = Store.get(kPrefKey);
      if (raw != null) {
        final m = jsonDecode(raw);
        if (m is Map) {
          if (m['lang'] is String && ['en', 'fr', 'ar'].contains(m['lang'])) lang = m['lang'];
          if (m['theme'] is String) theme = m['theme'];
        }
      }
    } catch (_) {}
    I18n.lang = lang;
    v.rl = lang;
  }

  /// Port of applyPref() including the cloud-synced language/theme preference.
  void applyPref() {
    I18n.lang = lang;
    Store.set(kPrefKey, jsonEncode({'lang': lang, 'theme': theme}));
    sync.onPrefChanged();
    notifyListeners();
  }

  void setLang(String l) {
    lang = l;
    v.rl = l;
    applyPref();
  }

  void setTheme(String t) {
    theme = t;
    applyPref();
  }

  ThemeMode get themeMode => theme == 'light' ? ThemeMode.light : (theme == 'dark' ? ThemeMode.dark : ThemeMode.system);

  // --------------------------------------------------------------- data access
  List<J> _list(String k) {
    final x = S![k];
    if (x is List) return x.cast<J>();
    final n = <dynamic>[];
    S![k] = n;
    return n.cast<J>();
  }

  List<J> get pats => _list('p');
  List<J> get apts => _list('a');
  List<J> get cons => _list('c');
  List<J> get toysL => _list('toys');
  List<J> get srs => _list('sr');
  List<J> get ais => _list('ai');
  J get me => S!['me'] as J;
  List<J> get places {
    final x = me['places'];
    if (x is List) return x.cast<J>();
    final n = <dynamic>[];
    me['places'] = n;
    return n.cast<J>();
  }

  J get act {
    final x = S!['act'];
    if (x is Map) return x as J;
    final n = <String, dynamic>{};
    S!['act'] = n;
    return n;
  }

  String get cur => str(me['cur']).isEmpty ? 'DA' : str(me['cur']);

  J? P(dynamic id) {
    final s = str(id);
    if (S == null || s.isEmpty) return null;
    for (final p in pats) {
      if (p['id'] == s) return p;
    }
    return null;
  }

  String rn(J? p) => p == null ? '' : '${str(p['name'])} ${str(p['pre'])}';
  String full(J? p) {
    final r = rn(p).trim();
    return r.isEmpty ? '—' : r;
  }

  String ini(J? p) {
    if (p == null) return '';
    String f(String s) => s.isEmpty ? '' : String.fromCharCode(s.runes.first);
    return f(str(p['name'])) + f(str(p['pre']));
  }

  int mths(String? b, [String? r]) {
    if (b == null || b.isEmpty) return 0;
    final p = b.split('-');
    if (p.length < 3) return 0;
    final y = int.tryParse(p[0]) ?? 0, m = int.tryParse(p[1]) ?? 0, d = int.tryParse(p[2]) ?? 0;
    final n = (r != null && r.isNotEmpty) ? parseD(r) : DateTime.now();
    final x = (n.year - y) * 12 + n.month - m - (n.day < d ? 1 : 0);
    return x < 0 ? 0 : x;
  }

  String age(String? b, [String? r]) {
    if (b == null || b.isEmpty) return '—';
    final m = mths(b, r);
    return '${m ~/ 12} ${T('__y')} ${m % 12} ${T('__m')}';
  }

  List<dynamic>? condById(dynamic id) {
    final s = str(id);
    for (final c in kConditions) {
      if (c[0] == s) return c;
    }
    return null;
  }

  List<String> condIds(J p) => (p['conds'] is List) ? (p['conds'] as List).map((e) => str(e)).toList() : <String>[];

  /// Full condition names (cn).
  List<String> cn(J p) {
    final out = <String>[];
    for (final i in condIds(p)) {
      final c = condById(i);
      if (c != null) out.add(c[1] as String);
    }
    return out;
  }

  double dur(J p) => nv(p['dv']) * (p['du'] == 'months' ? 30 : 7);
  int exp(J p) {
    final n = nv(p['fn']), d = dur(p);
    final x = p['fu'] == 'day' ? n * d : (p['fu'] == 'month' ? n * d / 30 : n * d / 7);
    return x.round();
  }

  int stp(J p) {
    final n = nv(p['fn']) == 0 ? 1.0 : nv(p['fn']);
    final nn = n < 1 ? 1.0 : n;
    if (p['fu'] == 'day') return 1;
    final r = ((p['fu'] == 'month' ? 30 : 7) / nn).round();
    return r < 1 ? 1 : r;
  }

  String fq(J p) {
    final fn = truthy(p['fn']) ? str(p['fn']) : '?';
    final fu = truthy(p['fu']) ? str(p['fu']) : 'week';
    return '$fn / ${T(fu)}';
  }

  int mins(J a) {
    final t = str(a['time']).split(':');
    final h = int.tryParse(t.isNotEmpty ? t[0] : '') ?? 0;
    final m = int.tryParse(t.length > 1 ? t[1] : '') ?? 0;
    final n = DateTime.now();
    return h * 60 + m - (n.hour * 60 + n.minute);
  }

  String fm(int m) => m <= 0 ? 'Now' : (m < 60 ? '$m min' : '${m ~/ 60} h ${m % 60} min');

  String money(num n) => '${fmtNum(lang, (n * 100).round() / 100)} $cur';

  // ------------------------------------------------------------------ storage
  J? load() {
    try {
      final raw = Store.get(K);
      if (raw == null) return null;
      final x = jsonDecode(raw);
      return x is Map ? Map<String, dynamic>.from(x) : null;
    } catch (_) {
      return null;
    }
  }

  void persistLocal() {
    if (S == null || K.isEmpty) return;
    try {
      Store.set(K, jsonEncode(S));
    } catch (_) {}
  }

  J mk() => <String, dynamic>{
        'p': <dynamic>[],
        'a': <dynamic>[],
        'act': <String, dynamic>{},
        'toys': <dynamic>[],
        'me': <String, dynamic>{
          'name': '',
          'title': 'Neurolinguiste clinicienne – Orthophoniste',
          'phone': '',
          'email': '',
          'addr': '',
          'places': <dynamic>[],
        },
      };

  /// Port of save(): stamps edited records, writes locally, schedules the cloud push.
  void save() {
    if (S == null) return;
    sync.onSave();
    persistLocal();
    _remindTimer?.cancel();
    _remindTimer = Timer(const Duration(milliseconds: 700), () => remind());
  }

  /// Port of mig() + CORE.migrate().
  void mig() {
    if (S == null) return;
    S!['c'] ??= <dynamic>[];
    S!['toys'] ??= <dynamic>[];
    if (S!['me'] is! Map) S!['me'] = mk()['me'];
    if (!truthy(me['cur'])) me['cur'] = 'DA';
    final pl = <dynamic>[];
    for (final x in (me['places'] is List ? me['places'] as List : <dynamic>[])) {
      if (x is String) {
        pl.add(<String, dynamic>{'n': x, 't': 'center'});
      } else if (x is Map) {
        pl.add(Map<String, dynamic>.from(x));
      }
    }
    me['places'] = pl;
    for (final x in places) {
      if (x['my'] == null) {
        x['my'] = x['t'] == 'daycare' ? 60 : 50;
        x['fee'] = truthy(x['fee']) ? x['fee'] : 0;
        x['mode'] = truthy(x['mode']) ? x['mode'] : 'pct';
        x['mine'] = truthy(x['mine']) ? x['mine'] : 0;
      }
    }
    for (final p in pats) {
      p['pt'] = truthy(p['pt']) ? p['pt'] : 'center';
      if (!truthy(p['fu'])) {
        p['fn'] = truthy(p['perWeek']) ? p['perWeek'] : 2;
        p['fu'] = 'week';
        p['dv'] = truthy(p['weeks']) ? p['weeks'] : 12;
        p['du'] = 'weeks';
      }
    }
    migrate();
  }

  String _hash(String s) {
    var h = 5381;
    for (var i = 0; i < s.length; i++) {
      h = ((h << 5) + h + s.codeUnitAt(i)) & 0xFFFFFFFF;
    }
    return h.toRadixString(36);
  }

  /// Port of CORE.migrate(): idempotent, non-destructive.
  void migrate() {
    if (S == null || S!['me'] is! Map) return;
    S!['sr'] ??= <dynamic>[];
    S!['ai'] ??= <dynamic>[];
    S!['toys'] ??= <dynamic>[];
    final used = <String, bool>{};
    for (final x in places) {
      if (truthy(x['id'])) used[str(x['id'])] = true;
    }
    for (final x in places) {
      if (!truthy(x['id'])) {
        var id = 'wp_${_hash(str(x['n']))}';
        while (used[id] == true) {
          id += 'x';
        }
        x['id'] = id;
        used[id] = true;
      }
      if (!truthy(x['type'])) x['type'] = x['t'] == 'daycare' ? 'daycare' : 'center';
      for (final k in ['addr', 'notes', 'pay', 'payNotes']) {
        if (x[k] == null) x[k] = '';
      }
    }
    for (final p in pats) {
      syncPatient(p);
    }
    for (final a in apts) {
      if (!truthy(a['placeId'])) {
        final w = wpByName(str(a['place']));
        if (w != null) a['placeId'] = w['id'];
      }
      if (!truthy(a['src'])) a['src'] = 'legacy';
      if (!truthy(a['progId'])) a['progId'] = 'pg_${a['pid']}';
    }
  }

  J? wpById(dynamic id) {
    final s = str(id);
    if (s.isEmpty || S == null) return null;
    for (final x in places) {
      if (x['id'] == s) return x;
    }
    return null;
  }

  J? wpByName(String? n) {
    if (n == null || n.isEmpty || S == null) return null;
    for (final x in places) {
      if (x['n'] == n) return x;
    }
    return null;
  }

  J legacyProg(J p) => <String, dynamic>{
        'freq': nv(p['fn']),
        'per': truthy(p['fu']) ? p['fu'] : 'week',
        'days': <dynamic>[],
        'time': '',
        'start': truthy(p['start']) ? p['start'] : '',
        'dur': nv(p['dv']),
        'unit': truthy(p['du']) ? p['du'] : 'weeks',
        'end': '',
        'status': 'active',
        'legacy': true,
        'log': <dynamic>[],
      };

  List<dynamic> progDays(J pr) => pr['days'] is List ? pr['days'] as List : <dynamic>[];

  void syncPatient(J p) {
    final w = wpByName(str(p['place']));
    if (w != null && p['wpId'] != w['id']) p['wpId'] = w['id'];
    if (p['wpExtra'] is! List) p['wpExtra'] = <dynamic>[];
    p['wpExtra'] = (p['wpExtra'] as List).where((id) => id != p['wpId']).toList();
    if (p['prog'] is! Map) p['prog'] = legacyProg(p);
    final pr = p['prog'] as J;
    final days = progDays(pr);
    if (days.isEmpty) {
      pr['legacy'] = true;
      pr['freq'] = nv(p['fn']) != 0 ? nv(p['fn']) : (nv(pr['freq']));
      pr['per'] = truthy(p['fu']) ? p['fu'] : (truthy(pr['per']) ? pr['per'] : 'week');
      pr['dur'] = nv(p['dv']) != 0 ? nv(p['dv']) : nv(pr['dur']);
      pr['unit'] = truthy(p['du']) ? p['du'] : (truthy(pr['unit']) ? pr['unit'] : 'weeks');
      if (truthy(p['start'])) pr['start'] = p['start'];
    } else {
      p['fn'] = days.length;
      p['fu'] = 'week';
      if (nv(pr['dur']) != 0) {
        p['dv'] = pr['dur'];
        p['du'] = pr['unit'];
      }
      if (truthy(pr['start'])) p['start'] = pr['start'];
    }
  }

  void seed() {
    final id = uid();
    me['places'] = <dynamic>[
      <String, dynamic>{'n': 'Main center', 't': 'center'},
      <String, dynamic>{'n': 'Little Stars daycare', 't': 'daycare'},
    ];
    pats.add(<String, dynamic>{
      'id': id,
      'name': 'Demo',
      'pre': 'Patient',
      'birth': addD(td(), -1900),
      'parents': 'Parent name',
      'phone': '0555 00 00 00',
      'pt': 'daycare',
      'place': 'Little Stars daycare',
      'start': addD(td(), -14),
      'fn': 2,
      'fu': 'week',
      'dv': 16,
      'du': 'weeks',
      'symptoms': 'Few words, points to request things',
      'diag': 'Mixed language delay, moderate',
      'plan': 'Visual perception + auditory memory, then vocabulary in play',
      'conds': <dynamic>['3'],
    });
    final rows = [
      [-14, 'done', 'Joint attention', 'Good eye contact'],
      [-10, 'done', 'Colour matching', 'Needs cues'],
      [0, 'scheduled', 'Auditory memory: 2-item sequences', ''],
      [4, 'scheduled', 'Vocabulary: animals', ''],
    ];
    for (final x in rows) {
      apts.add(<String, dynamic>{
        'id': uid(),
        'pid': id,
        'date': addD(td(), x[0] as int),
        'time': '10:00',
        'place': 'Little Stars daycare',
        'status': x[1],
        'goal': x[2],
        'remark': x[3],
      });
    }
  }

  // ------------------------------------------------------------------ session
  Future<void> enter(AppUser u, {bool preview = false}) async {
    if (!preview && U != null && U!.uid == u.uid) return;
    U = u;
    K = 'ortho_${u.uid}';
    S = load() ?? mk();
    if (S!['me'] is! Map) S!['me'] = mk()['me'];
    if (fbOk && !preview && u.fb != null) {
      try {
        await u.fb!.getIdToken(true).timeout(const Duration(seconds: 8));
      } catch (_) {}
      try {
        await sync.initialSync(u);
      } catch (_) {
        toast('Offline: showing data saved on this device.');
      }
    }
    if (!truthy(me['name'])) me['name'] = u.displayName;
    me['email'] = u.email;
    mig();
    if (preview && pats.isEmpty) {
      seed();
      mig();
    }
    if (!preview) sync.ready();
    v.t = 'home';
    v.prev = 'home';
    v.dir = 0;
    root = 'shell';
    go();
    remind();
  }

  Future<void> logout() async {
    ai.reset();
    try {
      if (sync.active && sync.isPend) await sync.pushNow().timeout(const Duration(seconds: 5));
    } catch (_) {}
    sync.stop();
    try {
      if (fbOk && U != null && !U!.preview) await fa.FirebaseAuth.instance.signOut();
    } catch (_) {}
    await cancelReminders();
    U = null;
    S = null;
    K = '';
    v.am = 'in';
    root = 'auth';
    notifyListeners();
  }

  // --------------------------------------------------------------------- boot
  Future<void> boot() async {
    loadPref();
    var ok = false;
    try {
      await Firebase.initializeApp(options: kFirebaseOptions).timeout(const Duration(seconds: 20));
      ok = true;
    } catch (e) {
      // already initialised (hot restart) counts as ok
      try {
        if (Firebase.apps.isNotEmpty) ok = true;
      } catch (_) {}
    }
    fbOk = ok;
    if (ok) {
      try {
        _authSub?.cancel();
        _authSub = fa.FirebaseAuth.instance.authStateChanges().listen(_onAuth, onError: (_) {
          v.fe = true;
          root = 'auth';
          notifyListeners();
        });
        // safety net: if no auth event arrives, show the sign-in screen
        Future.delayed(const Duration(seconds: 6), () {
          if (root == 'splash') {
            root = 'auth';
            notifyListeners();
          }
        });
      } catch (_) {
        v.fe = true;
        root = 'auth';
        notifyListeners();
      }
    } else {
      v.fe = true;
      root = 'auth';
      notifyListeners();
    }
  }

  void _onAuth(fa.User? u) {
    if (u != null && u.emailVerified) {
      enter(AppUser(uid: u.uid, email: u.email ?? '', displayName: u.displayName ?? '', fb: u));
    } else if (u != null) {
      v.am = 'verify';
      root = 'auth';
      notifyListeners();
    } else if (U == null) {
      if (v.am == 'verify') v.am = 'in';
      root = 'auth';
      notifyListeners();
    }
  }

  void enterPreview() {
    enter(AppUser(uid: 'preview', email: 'preview@local', displayName: 'Preview', preview: true), preview: true);
  }

  // ---------------------------------------------------------------- auth calls
  static const Map<String, String> authErr = {
    'invalid-email': 'Enter a valid email address.',
    'user-not-found': 'No account with this email.',
    'wrong-password': 'Email or password is incorrect.',
    'invalid-credential': 'Email or password is incorrect.',
    'email-already-in-use': 'This email already has an account. Sign in instead.',
    'weak-password': 'Use at least 6 characters.',
    'network-request-failed': 'No connection. Check your internet and try again.',
    'too-many-requests': 'Too many attempts. Try again in a few minutes.',
    'mismatch': 'The two passwords do not match.',
    'empty': 'Fill in all fields.',
  };

  String _errKey(Object e, String fallback) {
    if (e is fa.FirebaseAuthException) return authErr[e.code] ?? fallback;
    if (e is _AuthCode) return authErr[e.code] ?? fallback;
    return fallback;
  }

  /// Returns an error key (translatable) or null on success. [ok] is set for informational success messages.
  Future<String?> doAuth({required String mode, String name = '', String email = '', String pw = '', String pw2 = ''}) async {
    if (!fbOk) return 'Cloud sign-in is unavailable here.';
    try {
      if (email.isEmpty || (mode != 'forgot' && pw.isEmpty) || (mode == 'up' && name.isEmpty)) throw _AuthCode('empty');
      final auth = fa.FirebaseAuth.instance;
      if (mode == 'in') {
        final c = await auth.signInWithEmailAndPassword(email: email, password: pw);
        if (c.user != null && !c.user!.emailVerified) {
          v.am = 'verify';
          notifyListeners();
        }
      } else if (mode == 'up') {
        if (pw != pw2) throw _AuthCode('mismatch');
        final c = await auth.createUserWithEmailAndPassword(email: email, password: pw);
        await c.user?.updateDisplayName(name);
        await c.user?.sendEmailVerification();
        v.am = 'verify';
        notifyListeners();
      } else {
        await auth.sendPasswordResetEmail(email: email);
        return 'OK:Reset link sent. Check your inbox.';
      }
      return null;
    } catch (e) {
      return _errKey(e, 'Something went wrong. Try again.');
    }
  }

  Future<String?> checkVerified() async {
    try {
      final u = fa.FirebaseAuth.instance.currentUser;
      if (u == null) return 'Could not check. Try again.';
      await u.reload();
      final cu = fa.FirebaseAuth.instance.currentUser;
      if (cu != null && cu.emailVerified) {
        await cu.getIdToken(true);
        enter(AppUser(uid: cu.uid, email: cu.email ?? '', displayName: cu.displayName ?? '', fb: cu));
        return null;
      }
      return 'Not verified yet. Open the link in your email first.';
    } catch (_) {
      return 'Could not check. Try again.';
    }
  }

  Future<String?> resendVerification() async {
    try {
      await fa.FirebaseAuth.instance.currentUser?.sendEmailVerification();
      return 'OK:Email sent again.';
    } catch (e) {
      return _errKey(e, 'Wait a moment before resending.');
    }
  }

  Future<void> signOutOnly() async {
    try {
      await fa.FirebaseAuth.instance.signOut();
    } catch (_) {}
    v.am = 'in';
    notifyListeners();
  }

  Future<void> sendResetToSelf() async {
    try {
      await fa.FirebaseAuth.instance.sendPasswordResetEmail(email: str(me['email']));
      toast('Reset email sent. Check your inbox.');
    } catch (e) {
      toast(_errKey(e, 'Something went wrong. Try again.'));
    }
  }

  // --------------------------------------------------------------- navigation
  void go() {
    currentSec = secColor;
    notifyListeners();
  }

  void nav(String t, {int d = 0}) {
    if (kMain.contains(v.t) || v.t == 'me') v.prev = v.t;
    v.dir = d;
    v.t = t;
    go();
  }

  void back() => nav(v.prev.isEmpty ? 'home' : v.prev, d: -1);

  void openPt(String id) {
    v.pid = id;
    nav('pat', d: 1);
  }

  void navMain(String t) {
    final d = kMain.indexOf(t) - kMain.indexOf(v.t) > 0 ? 1 : -1;
    nav(t, d: d);
  }

  void refresh() => notifyListeners();

  String authEmail() {
    try {
      return fa.FirebaseAuth.instance.currentUser?.email ?? '';
    } catch (_) {
      return '';
    }
  }

  /// Called by the sync engine when remote changes were merged into S.
  void refreshUI() {
    go();
    toast(l3('Updated from your other device', 'Mis à jour depuis votre autre appareil', 'تم التحديث من جهازك الآخر'));
  }

  int get todayPlanned => apts.where((a) => a['date'] == td() && a['status'] == 'scheduled').length;
}

class _AuthCode implements Exception {
  final String code;
  _AuthCode(this.code);
}

final AppState app = AppState();
