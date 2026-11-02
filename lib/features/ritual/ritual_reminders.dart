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
const weeklyTitle = 'Your OneUP week is ready 🌟';
const weeklyBody = 'A quick, friendly look back at your week.';
const weeklyPayload = 'report';
const _weeklyBaseId = 4200;
const _weeksAhead = 4;
const weeklyHour = 19;
final _allIds = [for (var i = 0; i < _daysAhead; i++) _baseId + i, for (var i = 0; i < _weeksAhead; i++) _weeklyBaseId + i];

String reminderBody(WellnessDimension d) => "Today's small step is about ${d.label}. Check in whenever suits you.";

class PlannedReminder {
  const PlannedReminder(this.id, this.at, this.body, {this.title = reminderTitle, this.payload = reminderPayload});
  final int id;
  final DateTime at; // local wall-clock time
  final String body, title, payload;
}

/// Sunday-evening (7 PM local) "your week is ready" reminders for the next few Sundays.
List<PlannedReminder> planWeeklyReminders({required DateTime now, required RitualSettings settings}) {
  if (!settings.weekly) return const [];
  final firstSunday = DateTime(now.year, now.month, now.day + (DateTime.sunday - now.weekday) % 7, weeklyHour);
  return [
    for (var i = 0; i <= _weeksAhead; i++) DateTime(firstSunday.year, firstSunday.month, firstSunday.day + 7 * i, weeklyHour),
  ]
      .where((t) => t.isAfter(now))
      .take(_weeksAhead)
      .toList()
      .asMap()
      .entries
      .map((e) => PlannedReminder(_weeklyBaseId + e.key, e.value, weeklyBody, title: weeklyTitle, payload: weeklyPayload))
      .toList();
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

  /// [onTap] receives the payload ([reminderPayload] or [weeklyPayload]).
  Future<void> init(void Function(String payload) onTap) async {
    if (kIsWeb || _inited) return;
    try {
      await _p.initialize(
        const InitializationSettings(
          android: AndroidInitializationSettings('@mipmap/ic_launcher'),
          // Permission is requested later, at a sensible moment (see requestPermission).
          iOS: DarwinInitializationSettings(requestAlertPermission: false, requestBadgePermission: false, requestSoundPermission: false),
        ),
        onDidReceiveNotificationResponse: (r) {
          final p = r.payload;
          if (p != null) onTap(p);
        },
      );
      _inited = true;
      final launch = await _p.getNotificationAppLaunchDetails();
      final p = launch?.notificationResponse?.payload;
      if ((launch?.didNotificationLaunchApp ?? false) && p != null) onTap(p);
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
      for (final id in _allIds) {
        await _p.cancel(id);
      }
      for (final r in plan) {
        await _p.zonedSchedule(
          r.id,
          r.title,
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
          payload: r.payload,
        );
      }
    } catch (e) {
      debugPrint('OneUp reminders not scheduled: $e');
    }
  }

  Future<void> cancelAll() async {
    if (!_inited) return;
    try {
      for (final id in _allIds) {
        await _p.cancel(id);
      }
    } catch (_) {}
  }
}

final ritualRemindersProvider = Provider<RitualReminders>((ref) => RitualReminders());
