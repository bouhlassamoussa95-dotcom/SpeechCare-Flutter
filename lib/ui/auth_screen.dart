import 'package:flutter/material.dart';
import '../core/i18n.dart';
import '../core/theme.dart';
import '../state/app_state.dart';
import 'widgets.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});
  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final an = TextEditingController(), ae = TextEditingController(), ap = TextEditingController(), ap2 = TextEditingController();
  String msg = '';
  bool ok = false;
  bool busy = false;
  bool show1 = false, show2 = false;
  String lastMode = '';

  @override
  void dispose() {
    an.dispose();
    ae.dispose();
    ap.dispose();
    ap2.dispose();
    super.dispose();
  }

  void setMsg(String x, {bool good = false}) => setState(() {
        msg = x;
        ok = good;
      });

  Future<void> submit() async {
    if (busy) return;
    setState(() {
      busy = true;
      msg = '';
    });
    final r = await app.doAuth(mode: app.v.am, name: an.text.trim(), email: ae.text.trim(), pw: ap.text, pw2: ap2.text);
    if (!mounted) return;
    setState(() => busy = false);
    if (r != null) {
      if (r.startsWith('OK:')) {
        setMsg(r.substring(3), good: true);
      } else {
        setMsg(r);
      }
    }
  }

  void setMode(String m) {
    app.v.am = m;
    setState(() => msg = '');
    app.refresh();
  }

  Widget field(TextEditingController c, String label, IconData icon, {bool pw = false, bool shown = false, VoidCallback? toggle, TextInputType? kb}) {
    final p = pal(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: TextField(
        controller: c,
        obscureText: pw && !shown,
        keyboardType: kb,
        autocorrect: false,
        enableSuggestions: !pw,
        style: const TextStyle(fontSize: 16),
        decoration: inputDeco(context, hint: T(label)).copyWith(
          prefixIcon: Icon(icon, size: 20, color: p.mut),
          suffixIcon: pw ? IconButton(icon: Icon(shown ? Icons.visibility_off_outlined : Icons.visibility_outlined, size: 20, color: p.mut), onPressed: toggle) : null,
          contentPadding: const EdgeInsets.symmetric(horizontal: 11, vertical: 15),
        ),
      ),
    );
  }

  Widget linkBtn(String t, VoidCallback f, {Color? color, bool bold = true}) => TextButton(
        onPressed: f,
        style: TextButton.styleFrom(minimumSize: const Size(48, 44), padding: const EdgeInsets.symmetric(horizontal: 10)),
        child: Text(T(t), style: TextStyle(color: color ?? pal(context).sec, fontWeight: bold ? FontWeight.w600 : FontWeight.w400, fontSize: 14)),
      );

  @override
  Widget build(BuildContext context) {
    final p = Pal(Theme.of(context).brightness == Brightness.dark, Pal.pri);
    final m = app.v.am;
    final body = <Widget>[];
    if (m == 'verify') {
      final email = (app.fbOk ? _currentEmail() : '');
      body.addAll([
        Center(child: Container(width: 76, height: 76, decoration: BoxDecoration(color: p.chip, shape: BoxShape.circle), child: Center(child: ic('mail', size: 34, color: Pal.pri)))),
        const SizedBox(height: 10),
        Center(child: Text(T('Verify your email'), style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold))),
        const SizedBox(height: 6),
        Center(child: Text('${T('We sent a confirmation link to')}\n${email.isEmpty ? T('your email') : email}\n${T('Open it, then come back here.')}', textAlign: TextAlign.center, style: TextStyle(color: p.mut, height: 1.5))),
        const SizedBox(height: 12),
        _msgBox(),
        Btn(T('I verified my email'), busy
            ? null
            : () async {
                setState(() => busy = true);
                final r = await app.checkVerified();
                if (!mounted) return;
                setState(() => busy = false);
                if (r != null) setMsg(r);
              }, full: true),
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          linkBtn('Resend email', () async {
            final r = await app.resendVerification();
            if (r != null) setMsg(r.startsWith('OK:') ? r.substring(3) : r, good: r.startsWith('OK:'));
          }),
          linkBtn('Use another account', () async {
            await app.signOutOnly();
            setMsg('');
          }),
        ]),
      ]);
    } else {
      body.addAll([
        Seg([SegItem('in', T('Sign in')), SegItem('up', T('Create account'))], m == 'up' ? 'up' : 'in', setMode),
        Padding(
          padding: const EdgeInsets.only(top: 4, bottom: 10),
          child: Text(m == 'in' ? T('Welcome back') : (m == 'up' ? T('Create your account') : T('Reset password')), style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
        ),
        if (m == 'up') field(an, 'Full name', Icons.person_outline),
        field(ae, 'Email', Icons.mail_outline, kb: TextInputType.emailAddress),
        if (m != 'forgot') field(ap, 'Password', Icons.lock_outline, pw: true, shown: show1, toggle: () => setState(() => show1 = !show1)),
        if (m == 'up') field(ap2, 'Confirm password', Icons.lock_outline, pw: true, shown: show2, toggle: () => setState(() => show2 = !show2)),
        _msgBox(),
        Btn(busy ? T('Please wait') : (m == 'in' ? T('Sign in') : (m == 'up' ? T('Create account') : T('Send reset link'))), busy ? null : submit, full: true),
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          if (m == 'in') linkBtn('Forgot password?', () => setMode('forgot')),
          if (m == 'forgot') linkBtn('Back to sign in', () => setMode('in')),
        ]),
        const SizedBox(height: 14),
        Center(child: Text(T('Your patients are saved to your private account.'), textAlign: TextAlign.center, style: TextStyle(color: p.mut, fontSize: 13))),
        Center(child: linkBtn('Try the offline preview', app.enterPreview, color: p.mut, bold: false)),
      ]);
    }
    return Scaffold(
      backgroundColor: p.bg,
      body: SingleChildScrollView(
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Column(children: [
              _Hero(),
              Transform.translate(
                offset: const Offset(0, -22),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.fromLTRB(18, 18, 18, 22),
                  decoration: BoxDecoration(color: p.bg, borderRadius: const BorderRadius.vertical(top: Radius.circular(28))),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: body),
                ),
              ),
            ]),
          ),
        ),
      ),
    );
  }

  String _currentEmail() {
    try {
      return app.authEmail();
    } catch (_) {
      return '';
    }
  }

  Widget _msgBox() {
    final fe = app.v.fe && msg.isEmpty;
    final text = fe ? T('Cloud sign-in is unavailable here (no connection to Firebase).') : T(msg);
    if (text.trim().isEmpty) return const SizedBox(height: 6);
    final col = ok ? Pal.tea : Pal.red;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(color: alpha(col, .12), borderRadius: BorderRadius.circular(12), border: Border.all(color: alpha(col, .5))),
      child: Row(children: [
        Expanded(child: Text(text, style: TextStyle(color: col, fontSize: 13))),
        if (fe) linkBtn('Retry', () async {
          app.v.fe = false;
          app.root = 'splash';
          app.refresh();
          await app.boot();
        }),
      ]),
    );
  }
}

class _Hero extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      height: 250,
      width: double.infinity,
      decoration: const BoxDecoration(gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomRight, colors: [Color(0xFF6B4BA3), Color(0xFF3E2A78), Color(0xFF0F7A72)], stops: [0, .55, 1])),
      child: SafeArea(
        bottom: false,
        child: Stack(children: [
          PositionedDirectional(start: -30, top: 40, child: _bubble(120)),
          PositionedDirectional(end: 30, top: 70, child: _bubble(70)),
          PositionedDirectional(end: -10, bottom: 50, child: _bubble(46)),
          Positioned(
            top: 6,
            left: 0,
            right: 0,
            child: Center(
              child: Container(
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(color: Colors.white.withAlpha(36), borderRadius: BorderRadius.circular(20)),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  for (final x in const [['en', 'EN'], ['fr', 'FR'], ['ar', 'عربي']])
                    GestureDetector(
                      onTap: () => app.setLang(x[0]),
                      child: Container(
                        constraints: const BoxConstraints(minWidth: 52, minHeight: 40),
                        alignment: Alignment.center,
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        decoration: BoxDecoration(color: app.lang == x[0] ? Colors.white : Colors.transparent, borderRadius: BorderRadius.circular(17)),
                        child: Text(x[1], style: TextStyle(color: app.lang == x[0] ? Pal.pri : Colors.white, fontWeight: FontWeight.w700, fontSize: 13)),
                      ),
                    ),
                ]),
              ),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 38,
            child: Column(children: [
              Container(
                width: 76,
                height: 76,
                clipBehavior: Clip.antiAlias,
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(22), boxShadow: const [BoxShadow(color: Color(0x44000000), blurRadius: 14, offset: Offset(0, 6))]),
                child: Image.asset('assets/images/logo.png', width: 72, height: 72, fit: BoxFit.contain),
              ),
              const SizedBox(height: 8),
              const Text('SpeechCare', style: TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.bold)),
              Text(T('Patients, sessions and reports in one place'), style: const TextStyle(color: Colors.white70, fontSize: 13)),
            ]),
          ),
        ]),
      ),
    );
  }

  Widget _bubble(double s) => Container(width: s, height: s, decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white.withAlpha(22)));
}

class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomRight, colors: [Color(0xFF6B4BA3), Color(0xFF3E2A78), Color(0xFF0F7A72)], stops: [0, .55, 1])),
        child: Center(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(
              width: 96,
              height: 96,
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(26)),
              child: Image.asset('assets/images/logo.png', fit: BoxFit.contain),
            ),
            const SizedBox(height: 14),
            const Text('SpeechCare', style: TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold)),
            const SizedBox(height: 18),
            const SizedBox(width: 26, height: 26, child: CircularProgressIndicator(strokeWidth: 3, color: Colors.white)),
          ]),
        ),
      ),
    );
  }
}
