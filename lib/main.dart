import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'app.dart';
import 'core/store.dart';
import 'state/notifications.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Store.init();
  try {
    await initializeDateFormatting();
  } catch (_) {}
  initNotifications();
  runApp(const SpeechCareApp());
}
