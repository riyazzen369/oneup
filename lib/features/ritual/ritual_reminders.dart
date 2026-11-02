import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:timezone/timezone.dart' as tz;

import '../../core/theme/app_colors.dart';
import 'ritual_settings.dart';

const reminderTitle = 'Your 1-minute OneUP ritual is ready 🌱';
const reminderPayload = 'ritual';
const _daysAhead = 7;
const _baseId = 4100;

String reminderBody(WellnessDimension d) => "Today's small step is about ${d.label}. Check in whenever suits you.";

class PlannedReminder {
  const PlannedReminder(this.id, this.at, this.body);
  final int id;
  final DateTime at; // local wall-clock time
  final String body;
}

/// One inexact reminder per day for the next week at the chosen local time.
/// Skips times already past, and today when today's ritual is complete.
List<PlannedReminder> planReminders({
  required DateTime now,
  required RitualSettings settings,
  required bool todayComplete,
  required WellnessDimension Function(DateTime day) dimensionFor,
}) {
  if (!settings.notify) return const [];
  final out = <PlannedReminder>[];
  for (var i = 0; i < _daysAhead; i++) {
    final at = DateTime(now.year, now.month, now.day + i, settings.hour, settings.minute);
    if (!at.isAfter(now)) continue;
    if (i == 0 && todayComplete) continue;
    out.add(PlannedReminder(_baseId + i, at, reminderBody(dimensionFor(at))));
  }
  return out;
}

/// Thin wrapper over flutter_local_notifications; every call is best-effort (tests have no plugin).
class RitualReminders {
  final _p = FlutterLocalNotificationsPlugin();
  bool _inited = false;

  Future<void> init(void Function() onTap) async {
    if (kIsWeb || _inited) return;
    try {
      await _p.initialize(
        const InitializationSettings(
          android: AndroidInitializationSettings('@mipmap/ic_launcher'),
          // Permission is requested later, at a sensible moment (see requestPermission).
          iOS: DarwinInitializationSettings(requestAlertPermission: false, requestBadgePermission: false, requestSoundPermission: false),
        ),
        onDidReceiveNotificationResponse: (r) {
          if (r.payload == reminderPayload) onTap();
        },
      );
      _inited = true;
      final launch = await _p.getNotificationAppLaunchDetails();
      if ((launch?.didNotificationLaunchApp ?? false) && launch?.notificationResponse?.payload == reminderPayload) onTap();
    } catch (e) {
      debugPrint('OneUp reminders unavailable: $e');
    }
  }

  Future<bool> requestPermission() async {
    try {
      final android = _p.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
      final ios = _p.resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>();
      final a = await android?.requestNotificationsPermission();
      final i = await ios?.requestPermissions(alert: true, badge: false, sound: true);
      return (a ?? i) ?? false;
    } catch (_) {
      return false;
    }
  }

  Future<void> replaceAll(List<PlannedReminder> plan) async {
    if (!_inited) return;
    try {
      for (var i = 0; i < _daysAhead; i++) {
        await _p.cancel(_baseId + i);
      }
      for (final r in plan) {
        await _p.zonedSchedule(
          r.id,
          reminderTitle,
          r.body,
          // Absolute instant of the local wall-clock time; UTC avoids needing the device zone name.
          tz.TZDateTime.from(r.at, tz.UTC),
          const NotificationDetails(
            android: AndroidNotificationDetails('daily_ritual', 'Daily ritual',
                channelDescription: 'A gentle daily reminder for your OneUP check-in', importance: Importance.defaultImportance),
            iOS: DarwinNotificationDetails(),
          ),
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
          uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
          payload: reminderPayload,
        );
      }
    } catch (e) {
      debugPrint('OneUp reminders not scheduled: $e');
    }
  }

  Future<void> cancelAll() async {
    if (!_inited) return;
    try {
      for (var i = 0; i < _daysAhead; i++) {
        await _p.cancel(_baseId + i);
      }
    } catch (_) {}
  }
}

final ritualRemindersProvider = Provider<RitualReminders>((ref) => RitualReminders());
