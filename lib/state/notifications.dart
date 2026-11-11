import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;
import '../core/util.dart';
import 'app_state.dart';

final FlutterLocalNotificationsPlugin _fln = FlutterLocalNotificationsPlugin();
bool _inited = false;

Future<void> initNotifications() async {
  if (_inited) return;
  try {
    tzdata.initializeTimeZones();
    const android = AndroidInitializationSettings('@mipmap/speechcare_icon');
    await _fln.initialize(const InitializationSettings(android: android));
    _inited = true;
  } catch (_) {}
}

Future<void> cancelReminders() async {
  try {
    await _fln.cancelAll();
  } catch (_) {}
}

/// Port of remind(): 15 minutes before each planned session (max 50) + a 07:30 summary for the next 7 days.
Future<void> remind() async {
  if (app.S == null) return;
  try {
    await initNotifications();
    if (!_inited) return;
    final impl = _fln.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    await impl?.requestNotificationsPermission();
    await _fln.cancelAll();
    const details = NotificationDetails(
      android: AndroidNotificationDetails(
        'speechcare_sessions',
        'Session reminders',
        channelDescription: 'Reminders for planned speech therapy sessions',
        importance: Importance.high,
        priority: Priority.high,
      ),
    );
    final now = DateTime.now();
    var id = 1;
    var count = 0;
    final planned = app.apts.where((a) => a['status'] == 'scheduled').toList()
      ..sort((x, y) => ('${x['date']}${x['time']}').compareTo('${y['date']}${y['time']}'));
    for (final a in planned) {
      if (count >= 50) break;
      DateTime? at;
      try {
        at = DateTime.parse('${a['date']}T${a['time']}:00').subtract(const Duration(minutes: 15));
      } catch (_) {
        continue;
      }
      if (at.isAfter(now)) {
        final p = app.P(a['pid']);
        await _fln.zonedSchedule(
          id++,
          '${a['time']} – ${app.rn(p)}',
          truthy(a['goal']) ? str(a['goal']) : 'Session in 15 minutes',
          tz.TZDateTime.from(at, tz.UTC),
          details,
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
          uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
        );
        count++;
      }
    }
    for (var d = 0; d < 7; d++) {
      final ds = addD(td(), d);
      final n = app.apts.where((a) => a['date'] == ds && a['status'] == 'scheduled').length;
      final t = DateTime.parse('${ds}T07:30:00');
      if (n > 0 && t.isAfter(now)) {
        await _fln.zonedSchedule(
          900 + d,
          'Today: $n session${n > 1 ? 's' : ''}',
          'Open the app to see the goals for each patient.',
          tz.TZDateTime.from(t, tz.UTC),
          details,
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
          uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
        );
      }
    }
  } catch (_) {}
}
