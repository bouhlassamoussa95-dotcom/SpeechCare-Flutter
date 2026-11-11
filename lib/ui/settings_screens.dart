import 'package:firebase_auth/firebase_auth.dart' as fa;
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../core/globals.dart';
import '../core/i18n.dart';
import '../core/store.dart';
import '../core/theme.dart';
import '../core/util.dart';
import '../state/ai_service.dart';
import '../state/app_state.dart';
import '../state/sync_engine.dart';
import 'shell.dart';
import 'widgets.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});
  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  late final Map<String, TextEditingController> c;
  @override
  void initState() {
    super.initState();
    c = {for (final k in ['name', 'title', 'phone', 'addr']) k: TextEditingController(text: str(app.me[k]))};
  }

  @override
  void dispose() {
    for (final x in c.values) {
      x.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final m = app.me;
    final nm = str(m['name']);
    return screenList([
      AppCard(
        child: Row(children: [
          Avatar(nm.isEmpty ? '?' : String.fromCharCode(nm.runes.first), size: 56),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [H3(nm), Mut(str(m['email']))])),
        ]),
      ),
      AppCard(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          LField(c['name']!, label: T('Full name')),
          LField(c['title']!, label: T('Title')),
          LField(c['phone']!, label: T('Phone'), keyboard: TextInputType.phone),
          LField(c['addr']!, label: T('Location')),
          Btn(T('Save profile'), () {
            for (final k in c.keys) {
              app.me[k] = c[k]!.text.trim();
            }
            app.save();
            app.go();
            toast('Profile saved');
          }),
        ]),
      ),
    ]);
  }
}

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final pv = app.U == null || app.U!.preview || !app.fbOk;
    fa.User? u;
    try {
      u = pv ? null : fa.FirebaseAuth.instance.currentUser;
    } catch (_) {}
    final m = app.me;
    final created = u?.metadata.creationTime;
    final rows = <List<String>>[
      ['Full name', str(m['name']).isEmpty ? '—' : str(m['name'])],
      ['Email', str(m['email']).isEmpty ? '—' : str(m['email'])],
      ['Email verified', pv ? '—' : (u?.emailVerified == true ? 'Yes' : 'No')],
      ['Sign-in method', pv ? 'Offline preview' : 'Email and password'],
      ['Member since', created == null ? '—' : fmtLoc(app.lang, fmtDate(created), 'd MMM y')],
    ];
    final p = pal(context);
    return screenList([
      secCard(
        hex('#7c55d6'),
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          H3(T('Appearance')),
          Seg([SegItem('system', T('System')), SegItem('light', T('Light')), SegItem('dark', T('Dark'))], app.theme, app.setTheme),
        ]),
      ),
      secCard(
        hex('#2f8cf0'),
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          H3(T('Language')),
          Seg(const [SegItem('en', 'English'), SegItem('fr', 'Français'), SegItem('ar', 'العربية')], app.lang, app.setLang),
        ]),
      ),
      secCard(
        hex('#16a39a'),
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          H3(T('Account information')),
          const SizedBox(height: 6),
          for (final r in rows)
            Container(
              padding: const EdgeInsets.symmetric(vertical: 7),
              decoration: BoxDecoration(border: Border(bottom: BorderSide(color: p.line))),
              child: Row(children: [Expanded(child: Mut(T(r[0]))), Flexible(child: Text(T(r[1]), style: const TextStyle(fontWeight: FontWeight.bold), textAlign: TextAlign.end))]),
            ),
          const SizedBox(height: 10),
          Wrap(spacing: 8, runSpacing: 8, children: [
            Btn(T('Edit profile'), () => app.nav('me', d: 1), small: true),
            if (!pv) Btn(T('Send password reset email'), app.sendResetToSelf, kind: BK.ghost, small: true),
          ]),
        ]),
      ),
      if (!orKeyBuiltIn) const _AiCard(),
      if (app.sync.active) secCard(hex('#1b7a4b'), const _CloudCard()),
      Btn(null, () => app.logout(), kind: BK.red, full: true, child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [ic('out', size: 18, color: Colors.white), const SizedBox(width: 8), Text(T('Log out'), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700))])),
    ]);
  }
}

class _CloudCard extends StatelessWidget {
  const _CloudCard();
  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<SyncInfo>(
      valueListenable: app.sync.info,
      builder: (context, i, _) {
        final t = kSyncTxt[i.s];
        final line = (i.s == 'saved' || i.s == 'idle' || t == null) ? l3('Everything is saved to the cloud automatically.', 'Tout est enregistré automatiquement dans le cloud.', 'يتم حفظ كل شيء تلقائياً في السحابة.') : t[langIx(I18n.lang)];
        final last = app.sync.lastSync == 0 ? '—' : DateTime.fromMillisecondsSinceEpoch(app.sync.lastSync).toString().substring(0, 16);
        return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          H3(l3('Cloud sync', 'Synchronisation cloud', 'مزامنة السحابة')),
          const SizedBox(height: 4),
          Text(line),
          Mut('${l3('Last confirmed by Firebase: ', 'Dernière confirmation Firebase : ', 'آخر تأكيد من Firebase: ')}$last'),
          if (app.sync.storageState.isNotEmpty) Mut(app.sync.storageState),
          const SizedBox(height: 8),
          Wrap(spacing: 8, runSpacing: 8, children: [
            Btn(l3('Sync now', 'Synchroniser', 'مزامنة الآن'), () async {
              await app.sync.syncNow();
              app.go();
            }, small: true),
            Btn(l3('Test photo storage', 'Tester le stockage photo', 'اختبار تخزين الصور'), () async {
              await app.sync.checkStorage();
              app.go();
            }, small: true),
          ]),
        ]);
      },
    );
  }
}

/// AI key card: shown only when the build has no OPENROUTER_API_KEY baked in.
class _AiCard extends StatefulWidget {
  const _AiCard();
  @override
  State<_AiCard> createState() => _AiCardState();
}

class _AiCardState extends State<_AiCard> {
  late final TextEditingController key = TextEditingController(text: orKey());
  late final TextEditingController model = TextEditingController(text: orModel());
  String msg = '';
  bool ok = true, busy = false;
  @override
  void dispose() {
    key.dispose();
    model.dispose();
    super.dispose();
  }

  Future<void> saveTest() async {
    final m = model.text.trim().isEmpty ? 'openrouter/free' : model.text.trim();
    if (!isFreeModel(m)) {
      setState(() {
        ok = false;
        msg = T('To avoid charges, use openrouter/free or a model ID ending in :free.');
      });
      return;
    }
    Store.set('speechcare_or_key', key.text.trim());
    Store.set('speechcare_or_model', m);
    setState(() {
      busy = true;
      msg = T('Thinking…');
    });
    final r = await aiTest();
    if (!mounted) return;
    setState(() {
      busy = false;
      msg = r[0] as String;
      ok = r[1] as bool;
    });
  }

  @override
  Widget build(BuildContext context) {
    return secCard(
      hex('#0ea5e9'),
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        H3('AI (OpenRouter)'),
        const SizedBox(height: 4),
        Mut(T('Direct connection from this personal app. Your API key is stored in this app on this device. Anyone who can inspect or extract the app data may be able to retrieve it. Do not share this APK.')),
        const SizedBox(height: 6),
        LField(key, label: T('OpenRouter API key'), obscure: true, hint: 'sk-or-v1-...'),
        LField(model, label: T('Model ID (free only)'), hint: 'openrouter/free'),
        Btn(T('Save and test'), busy ? null : saveTest, small: true),
        if (msg.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 6), child: Text(msg, style: TextStyle(color: ok ? Pal.tea : Pal.red, fontSize: 13))),
        const SizedBox(height: 6),
        Mut(T('To prevent accidental charges, SpeechCare accepts openrouter/free or a model ID ending in :free only. Free-model availability and request limits can change.')),
        TextButton(onPressed: () => launchUrl(Uri.parse('https://openrouter.ai/collections/free-models'), mode: LaunchMode.externalApplication), child: Text(T('Browse free models'))),
        Mut(T('Do not send patient names, contact details, or other identifying information. AI prompts are sent to OpenRouter.')),
      ]),
    );
  }
}
