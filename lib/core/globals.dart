import 'package:flutter/material.dart';
import 'i18n.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
final GlobalKey<ScaffoldMessengerState> messengerKey = GlobalKey<ScaffoldMessengerState>();

/// Port of toast(): the text is translated with T().
void toast(String x) {
  final m = messengerKey.currentState;
  if (m == null) return;
  m.hideCurrentSnackBar();
  m.showSnackBar(SnackBar(
    content: Text(T(x), textAlign: TextAlign.center, style: const TextStyle(color: Colors.white, fontSize: 14)),
    behavior: SnackBarBehavior.floating,
    backgroundColor: const Color(0xFF222222),
    duration: const Duration(milliseconds: 2600),
    margin: const EdgeInsets.fromLTRB(28, 0, 28, 96),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    elevation: 0,
  ));
}
