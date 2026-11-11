import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../core/globals.dart';
import '../core/i18n.dart';
import '../core/theme.dart';
import '../core/util.dart';
import '../state/ai_service.dart';
import '../state/app_state.dart';
import '../state/sync_engine.dart';
import 'activities_screen.dart';
import 'ai_panel.dart';
import 'consultations_screen.dart';
import 'finance_screen.dart';
import 'forms_appt.dart';
import 'forms_misc.dart';
import 'forms_patient.dart';
import 'home_screens.dart';
import 'patients_screens.dart';
import 'reports_screen.dart';
import 'sessions_screens.dart';
import 'settings_screens.dart';
import 'toys_screen.dart';
import 'widgets.dart';
import 'workplaces_screen.dart';

const List<List<String>> kTabs = [
  ['home', 'home', 'Home'],
  ['sess', 'cal', 'Sessions'],
  ['pats', 'users', 'Patients'],
  ['cons', 'chat', 'Consultations'],
  ['rep', 'doc', 'Reports'],
];

String screenTitle(String t) {
  switch (t) {
    case 'home':
      return 'SpeechCare';
    case 'sess':
      return T('Sessions');
    case 'pats':
      return T('Patients');
    case 'rep':
      return T('Reports');
    case 'me':
      return T('Profile');
    case 'cal':
      return T('Calendar');
    case 'today':
      return T('Today');
    case 'pat':
      return T('Patient');
    case 'set':
      return T('Settings');
    case 'cons':
      return T('Consultations');
    case 'fin':
      return T('Finance');
    case 'activities':
      return 'الأنشطة العلاجية';
    case 'toys':
      return T('Toys & materials');
    case 'wps':
      return T('Workplaces');
  }
  return 'SpeechCare';
}

Widget buildScreen(String t) {
  switch (t) {
    case 'home':
      return const HomeScreen();
    case 'sess':
      return const SessionsScreen();
    case 'cal':
      return const CalendarScreen();
    case 'today':
      return const TodayScreen();
    case 'pats':
      return const PatientsScreen();
    case 'pat':
      return const PatientScreen();
    case 'rep':
      return const ReportsScreen();
    case 'me':
      return const ProfileScreen();
    case 'set':
      return const SettingsScreen();
    case 'cons':
      return const ConsultationsScreen();
    case 'fin':
      return const FinanceScreen();
    case 'activities':
      return const ActivitiesScreen();
    case 'toys':
      return const ToysScreen();
    case 'wps':
      return const WorkplacesScreen();
  }
  return const HomeScreen();
}

class ShellScreen extends StatefulWidget {
  const ShellScreen({super.key});
  @override
  State<ShellScreen> createState() => _ShellScreenState();
}

class _ShellScreenState extends State<ShellScreen> {
  final GlobalKey<ScaffoldState> sk = GlobalKey<ScaffoldState>();
  double dx = 0;

  bool get isMenu {
    final t = app.v.t;
    return kMain.contains(t) || ['me', 'cons', 'fin', 'ai', 'activities', 'toys', 'wps'].contains(t);
  }

  void onBack() {
    final t = app.v.t;
    if (kMain.contains(t) && t != 'home') {
      app.nav('home', d: -1);
    } else if (t == 'home') {
      SystemNavigator.pop();
    } else {
      app.back();
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([app, ai]),
      builder: (context, _) {
        currentSec = app.secColor;
        final p = Pal(Theme.of(context).brightness == Brightness.dark, currentSec);
        final t = app.v.t;
        final nT = app.todayPlanned;
        final dir = isRtl ? -app.v.dir : app.v.dir;
        return PopScope(
          canPop: false,
          onPopInvokedWithResult: (didPop, result) {
            if (!didPop) onBack();
          },
          child: AnnotatedRegion<SystemUiOverlayStyle>(
            value: SystemUiOverlayStyle.light.copyWith(statusBarColor: Colors.transparent),
            child: Scaffold(
              key: sk,
              backgroundColor: p.page,
              drawer: const AppDrawer(),
              body: Column(children: [
                _Header(title: screenTitle(t), menu: isMenu, onMenu: () => sk.currentState?.openDrawer(), nToday: nT),
                Expanded(
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 520),
                      child: Stack(children: [
                        GestureDetector(
                          behavior: HitTestBehavior.translucent,
                          onHorizontalDragStart: (_) => dx = 0,
                          onHorizontalDragUpdate: (d) => dx += d.delta.dx,
                          onHorizontalDragEnd: (d) {
                            final v = d.primaryVelocity ?? 0;
                            if (kMain.contains(app.v.t) && dx.abs() >= 70 && v.abs() > 150) {
                              final fwd = (dx < 0) != isRtl;
                              final i = kMain.indexOf(app.v.t) + (fwd ? 1 : -1);
                              if (i >= 0 && i < kMain.length) app.nav(kMain[i], d: fwd ? 1 : -1);
                            }
                            dx = 0;
                          },
                          child: AnimatedSwitcher(
                            duration: Duration(milliseconds: dir == 0 ? 0 : 220),
                            switchInCurve: Curves.easeOut,
                            layoutBuilder: (cur, prev) => Stack(fit: StackFit.expand, children: [...prev, if (cur != null) cur]),
                            transitionBuilder: (child, anim) => FadeTransition(
                              opacity: anim,
                              child: SlideTransition(position: Tween<Offset>(begin: Offset(dir == 0 ? 0 : (dir > 0 ? 0.08 : -0.08), 0), end: Offset.zero).animate(anim), child: child),
                            ),
                            child: KeyedSubtree(key: ValueKey(t == 'pat' ? 'pat|${app.v.pid}' : t), child: buildScreen(t)),
                          ),
                        ),
                        const PositionedDirectional(top: 6, start: 0, end: 0, child: Center(child: SyncPill())),
                        if (!ai.open) PositionedDirectional(start: 12, bottom: 16, child: _Orb(onTap: agOpen)),
                        _fab(t),
                      ]),
                    ),
                  ),
                ),
                _NavBar(),
              ]),
            ),
          ),
        );
      },
    );
  }

  Widget _fab(String t) {
    String? label;
    VoidCallback? fn;
    switch (t) {
      case 'home':
      case 'sess':
        label = 'Session';
        fn = () => apForm();
        break;
      case 'pats':
        label = 'Patient';
        fn = () => ptForm();
        break;
      case 'cons':
        label = 'Consultation';
        fn = () => coForm();
        break;
      case 'toys':
        label = 'Toy';
        fn = () => toyForm();
        break;
      case 'wps':
        label = 'Workplace';
        fn = () => wpForm();
        break;
    }
    if (label == null) return const SizedBox.shrink();
    return PositionedDirectional(
      end: 16,
      bottom: 16,
      child: Material(
        color: currentSec,
        elevation: 6,
        shadowColor: alpha(currentSec, .5),
        borderRadius: BorderRadius.circular(28),
        child: InkWell(
          borderRadius: BorderRadius.circular(28),
          onTap: () {
            haptic();
            fn!();
          },
          child: Container(
            height: 54,
            padding: const EdgeInsets.symmetric(horizontal: 18),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              ic('plus', size: 22, color: Colors.white),
              const SizedBox(width: 6),
              Text(T(label), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 15)),
            ]),
          ),
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  final String title;
  final bool menu;
  final VoidCallback onMenu;
  final int nToday;
  const _Header({required this.title, required this.menu, required this.onMenu, required this.nToday});
  @override
  Widget build(BuildContext context) {
    final t = app.v.t;
    Widget trailing = const SizedBox(width: 48);
    if (t == 'home') {
      trailing = Stack(children: [
        IconBtn(ic('bell', size: 22, color: Colors.white), () => app.nav('today', d: 1), tooltip: T('Today')),
        if (nToday > 0)
          PositionedDirectional(
            top: 4,
            end: 4,
            child: Container(
              constraints: const BoxConstraints(minWidth: 18),
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
              decoration: BoxDecoration(color: Pal.red, borderRadius: BorderRadius.circular(10)),
              child: Text('$nToday', textAlign: TextAlign.center, style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
            ),
          ),
      ]);
    } else if (t == 'sess') {
      trailing = IconBtn(ic('cal', size: 22, color: Colors.white), () => app.nav('cal', d: 1), tooltip: T('Calendar'));
    }
    return Container(
      decoration: BoxDecoration(color: currentSec, boxShadow: const [BoxShadow(color: Color(0x33000000), blurRadius: 6, offset: Offset(0, 2))]),
      child: SafeArea(
        bottom: false,
        child: SizedBox(
          height: 58,
          child: Row(children: [
            const SizedBox(width: 4),
            IconBtn(ic(menu ? 'menu' : 'back', size: 22, color: Colors.white), menu ? onMenu : app.back, tooltip: menu ? 'Menu' : 'Back'),
            const SizedBox(width: 4),
            Expanded(child: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontSize: 19, fontWeight: FontWeight.bold))),
            trailing,
            const SizedBox(width: 4),
          ]),
        ),
      ),
    );
  }
}

class _NavBar extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final p = pal(context);
    final cur = app.v.t == 'pat' ? 'pats' : app.v.t;
    return Container(
      decoration: BoxDecoration(color: p.card, border: Border(top: BorderSide(color: p.line))),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(6, 6, 6, 6),
          child: Row(
            children: kTabs.map((x) {
              final on = x[0] == cur;
              return Expanded(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () {
                    haptic();
                    if (x[0] == app.v.t) return;
                    app.nav(x[0], d: kMain.indexOf(x[0]) - kMain.indexOf(app.v.t) > 0 ? 1 : -1);
                  },
                  child: Container(
                    height: 52,
                    margin: const EdgeInsets.symmetric(horizontal: 2),
                    decoration: BoxDecoration(color: on ? alpha(p.sec, .16) : Colors.transparent, borderRadius: BorderRadius.circular(14)),
                    child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                      ic(x[1], size: 22, color: on ? p.sec : p.mut),
                      const SizedBox(height: 2),
                      Text(T(x[2]), maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 10.5, color: on ? p.sec : p.mut, fontWeight: on ? FontWeight.w700 : FontWeight.w400)),
                    ]),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ),
    );
  }
}

class _Orb extends StatelessWidget {
  final VoidCallback onTap;
  const _Orb({required this.onTap});
  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'AI assistant',
      button: true,
      child: GestureDetector(
        onTap: () {
          haptic();
          onTap();
        },
        child: Container(
          width: 48,
          height: 48,
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Pal.pri, Pal.tea]),
            boxShadow: [BoxShadow(color: Color(0x55000000), blurRadius: 10, offset: Offset(0, 4))],
          ),
          child: Center(child: ic('spark', size: 24, color: Colors.white)),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------- sync pill
class SyncPill extends StatelessWidget {
  const SyncPill({super.key});
  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<SyncInfo>(
      valueListenable: app.sync.info,
      builder: (context, i, _) {
        if (!app.sync.active || !['pending', 'offline', 'photos', 'error'].contains(i.s)) return const SizedBox.shrink();
        final txt = kSyncTxt[i.s]!;
        final col = i.s == 'error' ? Pal.red : (i.s == 'offline' ? Pal.amb : Pal.tea);
        return GestureDetector(
          onTap: () => showSyncSheet(),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(color: pal(context).card, borderRadius: BorderRadius.circular(20), border: Border.all(color: col), boxShadow: const [BoxShadow(color: Color(0x22000000), blurRadius: 6)]),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Container(width: 8, height: 8, decoration: BoxDecoration(color: col, shape: BoxShape.circle)),
              const SizedBox(width: 6),
              Flexible(child: Text(txt[langIx(I18n.lang)], style: const TextStyle(fontSize: 12))),
            ]),
          ),
        );
      },
    );
  }
}

void showSyncSheet() {
  showSheet<void>((c) => const _SyncSheet());
}

class _SyncSheet extends StatefulWidget {
  const _SyncSheet();
  @override
  State<_SyncSheet> createState() => _SyncSheetState();
}

class _SyncSheetState extends State<_SyncSheet> {
  bool busy = false;
  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<SyncInfo>(
      valueListenable: app.sync.info,
      builder: (context, i, _) {
        final txt = kSyncTxt[i.s];
        final last = app.sync.lastSync == 0 ? '—' : DateTime.fromMillisecondsSinceEpoch(app.sync.lastSync).toString().substring(0, 16);
        return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          sheetTitle(l3('Cloud sync', 'Synchronisation cloud', 'مزامنة السحابة')),
          AppCard(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(txt == null ? (i.s == 'idle' ? '—' : kSyncTxt['saved']![langIx(I18n.lang)]) : txt[langIx(I18n.lang)], style: const TextStyle(fontWeight: FontWeight.bold)),
              if (i.detail.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 4), child: Mut(i.detail)),
              Padding(padding: const EdgeInsets.only(top: 4), child: Mut('${l3('Last sync', 'Dernière synchro', 'آخر مزامنة')}: $last')),
              if (app.sync.photosPending > 0) Padding(padding: const EdgeInsets.only(top: 4), child: Mut('${l3('Photos waiting', 'Photos en attente', 'صور بانتظار الرفع')}: ${app.sync.photosPending}')),
              if (app.sync.storageState.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 4), child: Mut(app.sync.storageState)),
            ]),
          ),
          Row(children: [
            Expanded(
              child: Btn(l3('Sync now', 'Synchroniser', 'مزامنة الآن'), busy
                  ? null
                  : () async {
                      setState(() => busy = true);
                      await app.sync.syncNow();
                      if (mounted) setState(() => busy = false);
                    }),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Btn(l3('Test photo storage', 'Tester le stockage photo', 'اختبار تخزين الصور'), busy
                  ? null
                  : () async {
                      setState(() => busy = true);
                      await app.sync.checkStorage();
                      if (mounted) setState(() => busy = false);
                    }, kind: BK.ghost),
            ),
          ]),
        ]);
      },
    );
  }
}

// ------------------------------------------------------------------ drawer
class AppDrawer extends StatefulWidget {
  const AppDrawer({super.key});
  @override
  State<AppDrawer> createState() => _AppDrawerState();
}

class _AppDrawerState extends State<AppDrawer> {
  String q = '';

  Widget mi(Color c, String icon, String title, String sub, VoidCallback onTap) {
    final p = pal(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: p.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: p.line)),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () {
            haptic();
            onTap();
          },
          child: Container(
            constraints: const BoxConstraints(minHeight: 58),
            padding: const EdgeInsets.all(10),
            child: Row(children: [
              Container(width: 38, height: 38, decoration: BoxDecoration(color: alpha(c, .14), borderRadius: BorderRadius.circular(12)), child: Center(child: ic(icon, size: 20, color: c))),
              const SizedBox(width: 10),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                  Text(sub, style: TextStyle(fontSize: 12, color: p.mut)),
                ]),
              ),
              ic('chev', size: 16, color: p.mut),
            ]),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = pal(context);
    final m = app.me;
    final em = str(m['email']);
    final nm = str(m['name']).isNotEmpty ? str(m['name']) : (em.split('@').first.isNotEmpty ? em.split('@').first : 'Speech therapist');
    final items = <List<String>>[
      ['me', 'user', 'Profile', 'Account and places', '#64748b'],
      ['home', 'home', 'Dashboard', 'Overview', '#2f8cf0'],
      ['activities', 'list', 'أنشطة علاجية', 'ألعاب وتمارين بالعربية والدارجة', '#0f7a72'],
      ['toys', 'box', 'Toys & materials', 'Equipment for sessions', '#c9407a'],
      ['wps', 'pin', 'Workplaces', 'Locations, fees and arrangements', '#2f6fe4'],
      ['today', 'clock', 'Today’s sessions', 'Goals and countdown', '#16a39a'],
      ['cal', 'cal', 'Calendar', 'Week and month', '#f29a2e'],
      ['fin', 'doc', 'Finance', 'Earnings by place and patient', '#b8860b'],
      ['set', 'gear', 'Settings', 'Appearance, language and account', '#0f7a72'],
    ].where((x) => T(x[2]).toLowerCase().contains(q.toLowerCase())).toList();
    return Drawer(
      width: (MediaQuery.of(context).size.width * .84).clamp(0, 340).toDouble(),
      backgroundColor: p.page,
      shape: const RoundedRectangleBorder(),
      child: Column(children: [
        Container(
          width: double.infinity,
          padding: EdgeInsets.fromLTRB(18, MediaQuery.of(context).padding.top + 18, 18, 18),
          decoration: const BoxDecoration(gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomRight, colors: [Color(0xFF6B4BA3), Color(0xFF3E2A78), Color(0xFF0F7A72)], stops: [0, .6, 1])),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Container(width: 54, height: 54, decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white.withAlpha(60)), child: Center(child: Text(nm.isEmpty ? '' : String.fromCharCode(nm.runes.first).toUpperCase(), style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)))),
            const SizedBox(height: 8),
            Text(nm, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
            Text(em, style: const TextStyle(color: Colors.white70, fontSize: 12)),
            const SizedBox(height: 6),
            ChipW(T('Speech therapist'), icon: ic('user', size: 14), bg: Colors.white.withAlpha(48), fg: Colors.white),
          ]),
        ),
        Expanded(
          child: ListView(padding: const EdgeInsets.all(12), children: [
            TextField(
              onChanged: (s) => setState(() => q = s),
              decoration: inputDeco(context, hint: T('Search a menu…')).copyWith(prefixIcon: Icon(Icons.search, color: p.mut)),
            ),
            const SizedBox(height: 10),
            Padding(padding: const EdgeInsets.fromLTRB(4, 4, 4, 6), child: Mut(T('MAIN'), size: 11)),
            ...items.map((x) => mi(hex(x[4]), x[1], T(x[2]), T(x[3]), () {
                  Navigator.pop(context);
                  app.nav(x[0], d: 1);
                })),
            Padding(padding: const EdgeInsets.fromLTRB(4, 10, 4, 6), child: Mut(T('QUICK ACTIONS'), size: 11)),
            mi(hex('#2fb872'), 'cal', T('New session'), T('Add to the calendar'), () {
              Navigator.pop(context);
              apForm();
            }),
            mi(hex('#f29a2e'), 'user', T('New patient'), T('Create a profile'), () {
              Navigator.pop(context);
              ptForm();
            }),
          ]),
        ),
      ]),
    );
  }
}
