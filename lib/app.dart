import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'core/globals.dart';
import 'core/i18n.dart';
import 'core/theme.dart';
import 'state/app_state.dart';
import 'ui/auth_screen.dart';
import 'ui/shell.dart';

class SpeechCareApp extends StatefulWidget {
  const SpeechCareApp({super.key});
  @override
  State<SpeechCareApp> createState() => _SpeechCareAppState();
}

class _SpeechCareAppState extends State<SpeechCareApp> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    app.boot();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState s) {
    if (s == AppLifecycleState.resumed) app.sync.resume();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: app,
      builder: (context, _) {
        currentSec = app.secColor;
        Widget home;
        switch (app.root) {
          case 'shell':
            home = const ShellScreen();
            break;
          case 'auth':
            home = const AuthScreen();
            break;
          default:
            home = const SplashScreen();
        }
        return MaterialApp(
          title: 'SpeechCare',
          debugShowCheckedModeBanner: false,
          navigatorKey: navigatorKey,
          scaffoldMessengerKey: messengerKey,
          locale: Locale(app.lang),
          supportedLocales: const [Locale('en'), Locale('fr'), Locale('ar')],
          localizationsDelegates: const [GlobalMaterialLocalizations.delegate, GlobalWidgetsLocalizations.delegate, GlobalCupertinoLocalizations.delegate],
          themeMode: app.themeMode,
          theme: buildTheme(Brightness.light),
          darkTheme: buildTheme(Brightness.dark),
          home: home,
        );
      },
    );
  }
}
