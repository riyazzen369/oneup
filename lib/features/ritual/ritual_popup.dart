import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/safety/safety_state.dart';
import '../../core/services/haptics.dart';
import '../../core/services/secure_store.dart';
import '../assess/domain/assessment_controller.dart';
import '../quick/quick_check.dart';
import 'ritual.dart';
import 'ritual_reminders.dart';
import 'ritual_settings.dart';
import 'today_card.dart';

bool ritualComplete(DayEntry e) => e.mood != null && e.done;

/// Re-plans the next week of reminders. Optionally asks for notification permission once
/// (called after the user's first check-in, a moment when the reminder makes sense).
Future<void> syncRitualReminders(WidgetRef ref, {bool askPermission = false}) async {
  final settingsCtl = ref.read(ritualSettingsProvider.notifier);
  await settingsCtl.ready;
  final reminders = ref.read(ritualRemindersProvider);
  var s = ref.read(ritualSettingsProvider);
  if (askPermission && s.notify && !s.permissionAsked) {
    await settingsCtl.update((x) => x.copyWith(permissionAsked: true));
    await reminders.requestPermission();
    s = ref.read(ritualSettingsProvider);
  }
  final ritual = ref.read(ritualProvider);
  final now = ref.read(ritualProvider.notifier).now();
  final full = ref.read(assessmentProvider).latest;
  final quick = ref.read(quickCheckProvider).latest?.scores;
  await reminders.replaceAll(planReminders(
    now: now,
    settings: s,
    todayComplete: ritualComplete(ritual.on(now)),
    dimensionFor: (d) => ritualDimension(full, quick, d),
  ));
}

/// Once per local day on Home: skipped when turned off, in crisis mode, or today's ritual is complete.
/// [force] (from tapping the reminder) ignores the once-per-day flag but still respects crisis mode.
Future<void> maybeShowRitualPopup(BuildContext context, WidgetRef ref, {bool force = false}) async {
  if (ref.read(crisisModeProvider)) return;
  await ref.read(ritualSettingsProvider.notifier).ready;
  final ctl = ref.read(ritualProvider.notifier);
  await ctl.ready;
  final store = ref.read(secureStoreProvider);
  final today = dayKey(ctl.now());
  if (!force) {
    if (!ref.read(ritualSettingsProvider).popup) return;
    if (await store.read(RitualSettingsController.popupDayKey) == today) return;
    if (ritualComplete(ref.read(ritualProvider).on(ctl.now()))) return;
  }
  await store.write(RitualSettingsController.popupDayKey, today);
  if (!context.mounted) return;
  Haptics.light();
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (_) => const RitualSheet(),
  );
}

class RitualSheet extends ConsumerWidget {
  const RitualSheet({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = Theme.of(context);
    final ctl = ref.read(ritualProvider.notifier);
    final e = ref.watch(ritualProvider).on(ctl.now());
    final started = e.mood != null || e.done;
    return SingleChildScrollView(
      key: const Key('ritual-sheet'),
      padding: EdgeInsets.fromLTRB(16, 0, 16, 16 + MediaQuery.viewInsetsOf(context).bottom),
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(Icons.spa_rounded, color: t.colorScheme.primary),
          const SizedBox(width: 8),
          Flexible(child: Text('Your 1-minute ritual', style: t.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800))),
        ]),
        const SizedBox(height: 4),
        Text('A quick check-in and one small step for today.',
            textAlign: TextAlign.center, style: t.textTheme.bodyMedium?.copyWith(color: t.colorScheme.onSurfaceVariant)),
        const SizedBox(height: 12),
        const TodayCard(),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(
            child: TextButton(
              key: const Key('ritual-later'),
              onPressed: Haptics.tap(() => Navigator.pop(context)),
              child: const Text('Later'),
            ),
          ),
          if (started) ...[
            const SizedBox(width: 8),
            Expanded(
              child: FilledButton(
                key: const Key('ritual-finish'),
                onPressed: Haptics.tap(() => Navigator.pop(context)),
                child: Text(ritualComplete(e) ? 'Done for today' : 'Save'),
              ),
            ),
          ],
        ]),
      ]),
    );
  }
}
