import 'package:shared_preferences/shared_preferences.dart';

/// Thin wrapper over SharedPreferences (the equivalent of the web app's localStorage).
class Store {
  static SharedPreferences? _p;

  static Future<void> init() async {
    _p = await SharedPreferences.getInstance();
  }

  static String? get(String k) {
    try {
      return _p?.getString(k);
    } catch (_) {
      return null;
    }
  }

  static bool set(String k, String v) {
    try {
      _p?.setString(k, v);
      return _p != null;
    } catch (_) {
      return false;
    }
  }

  static void del(String k) {
    try {
      _p?.remove(k);
    } catch (_) {}
  }

  static List<String> keys() {
    try {
      return _p?.getKeys().toList() ?? <String>[];
    } catch (_) {
      return <String>[];
    }
  }
}
