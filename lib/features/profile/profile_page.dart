import '../ritual/ritual.dart';
import '../quick/quick_check.dart';
import '../learn/reader_prefs.dart';
import '../games/game_scores.dart';
import '../market/market_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../ritual/ritual_reminders.dart';
import '../ritual/ritual_settings.dart';
import '../activity/activity.dart';
import '../report/weekly_report.dart';
import 'package:go_router/go_router.dart';

import '../../core/router/app_router.dart';
import '../../core/services/auth_service.dart';
import '../../core/services/settings_service.dart';
import '../../core/services/haptics.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/config/env.dart';
import '../../core/safety/safety_state.dart';
import '../../core/services/secure_store.dart';
import '../assess/domain/assessment_controller.dart';
import '../companion/domain/companion_controller.dart';
import '../consult/data/consult_repository.dart';
import 'data/profile_repository.dart';
import 'domain/user_profile.dart';
import 'ui/profile_avatar.dart';
import '../../core/widgets/fx.dart';

/// Profile: details header (photo, name, contact, completeness) above the settings.
class ProfilePage extends ConsumerWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mode = ref.watch(themeModeProvider);
    final haptics = ref.watch(hapticsProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Profile'), backgroundColor: Colors.transparent),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        const _ProfileHeader(),
        const SizedBox(height: 8),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Theme'),
              const SizedBox(height: 8),
              SegmentedButton<ThemeMode>(
                segments: const [
                  ButtonSegment(value: ThemeMode.light, label: Text('Light')),
                  ButtonSegment(value: ThemeMode.system, label: Text('System')),
                  ButtonSegment(value: ThemeMode.dark, label: Text('Dark')),
                ],
                selected: {mode},
                onSelectionChanged: Haptics.pick((s) => ref.read(themeModeProvider.notifier).set(s.first)),
              ),
            ]),
          ),
        ),
        Card(
          child: SwitchListTile(
            secondary: const Icon(Icons.vibration_rounded),
            title: const Text('Haptics'),
            subtitle: const Text('Gentle vibration on taps and milestones'),
            value: haptics,
            onChanged: (v) => ref.read(hapticsProvider.notifier).set(v),
          ),
        ),
        const _RitualSettingsCard(),
        Card(
          child: ListTile(
            leading: const Icon(Icons.info_outline_rounded),
            title: const Text('About OneUp'),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: Haptics.tap(() => context.push('/about')),
          ),
        ),
        Card(
          child: ListTile(
            leading: Icon(Icons.delete_forever_rounded, color: Theme.of(context).colorScheme.error),
            title: const Text('Delete my data'),
            subtitle:
                const Text('Removes assessments, goals, sessions and Companion chat from this phone (and your account, if connected).'),
            onTap: Haptics.tap(() async {
              final ok = await showDialog<bool>(
                context: context,
                builder: (c) => AlertDialog(
                  title: const Text('Delete all my data?'),
                  content: const Text('This cannot be undone.'),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancel')),
                    FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Delete')),
                  ],
                ),
              );
              if (ok != true) return;
              await deleteMyData(ref);
              if (context.mounted) context.go(Routes.splash);
            }),
          ),
        ),
        Card(
          child: ListTile(
            leading: const Icon(Icons.logout_rounded),
            title: const Text('Log out'),
            onTap: Haptics.tap(() async {
              try {
                await ref.read(authServiceProvider).signOut();
              } catch (_) {}
              if (context.mounted) context.go(Routes.login);
            }),
          ),
        ),
      ]),
    );
  }
}

/// Delete my data: server-side RPC when connected, then wipe all on-device secure storage
/// (assessment drafts/history, goals, bookings, Companion settings + chat, encryption key).
Future<void> deleteMyData(WidgetRef ref) async {
  if (Env.isConfigured) {
    await ref.read(profileRepositoryProvider).deleteRemoteAvatar();
    try {
      await Supabase.instance.client.rpc('delete_my_data');
      await Supabase.instance.client.auth.signOut();
    } catch (_) {}
  }
  await ref.read(secureStoreProvider).deleteAll();
  ref.invalidate(assessmentProvider);
  ref.invalidate(companionProvider);
  ref.invalidate(bookingsProvider);
  ref.invalidate(profileProvider);
  ref.invalidate(avatarProvider);
  ref.invalidate(gameScoresProvider);
  ref.invalidate(marketProvider);
  ref.invalidate(readerPrefsProvider);
  ref.invalidate(readingPositionsProvider);
  ref.invalidate(quickCheckProvider);
  ref.invalidate(ritualProvider);
  ref.invalidate(activityProvider);
  ref.invalidate(reportsProvider);
  ref.read(pendingReportProvider.notifier).state = false;
  await ref.read(ritualRemindersProvider).cancelAll();
  ref.invalidate(ritualSettingsProvider);
  ref.read(pendingRitualPopupProvider.notifier).state = false;
  ref.read(crisisModeProvider.notifier).state = false;
}

class _ProfileHeader extends ConsumerWidget {
  const _ProfileHeader();
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = Theme.of(context);
    final p = ref.watch(profileProvider).valueOrNull ?? const UserProfile();
    final pct = p.completeness;
    Widget row(IconData i, String v) => Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Row(children: [
            Icon(i, size: 18, color: t.colorScheme.onSurfaceVariant),
            const SizedBox(width: 10),
            Expanded(child: Text(v, style: t.textTheme.bodyMedium)),
          ]),
        );
    return GlassCard(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
      child: Column(children: [
        ProfileAvatar(
          initials: p.initials,
          size: 120,
          completeness: pct,
          onEdit: Haptics.tap(() => showPhotoSheet(context, ref, hasPhoto: p.hasAvatar)),
        ),
        const SizedBox(height: 12),
        Text(p.name.isEmpty ? 'Your name' : p.name,
            textAlign: TextAlign.center, style: t.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
        const SizedBox(height: 4),
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          AnimatedScore(pct, style: t.textTheme.labelLarge?.copyWith(color: t.colorScheme.primary, fontWeight: FontWeight.w700)),
          Text('% profile complete', style: t.textTheme.labelLarge?.copyWith(color: t.colorScheme.primary)),
        ]),
        const SizedBox(height: 12),
        if (p.phone.isNotEmpty) row(Icons.phone_iphone_rounded, '${ProfileValidators.formatPhone(p.phone)}  ·  Verified'),
        if (p.email.isNotEmpty) row(Icons.alternate_email_rounded, '${p.email}  ·  Unverified'),
        if (p.profession.isNotEmpty) row(Icons.work_outline_rounded, p.profession),
        if (p.ageRange != null || p.gender != null)
          row(Icons.badge_outlined, [if (p.ageRange != null) p.ageRange!, if (p.gender != null) p.gender!].join('  ·  ')),
        if (p.city.isNotEmpty) row(Icons.location_on_outlined, p.city),
        const SizedBox(height: 14),
        SizedBox(
          width: double.infinity,
          child: FilledButton.tonalIcon(
            onPressed: Haptics.tap(() => context.push('/profile/edit')),
            icon: const Icon(Icons.edit_rounded),
            label: Text(pct < 100 ? 'Complete your profile' : 'Edit profile'),
          ),
        ),
      ]),
    );
  }
}

class _RitualSettingsCard extends ConsumerWidget {
  const _RitualSettingsCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(ritualSettingsProvider);
    final ctl = ref.read(ritualSettingsProvider.notifier);
    final time = TimeOfDay(hour: s.hour, minute: s.minute);
    return Card(
      key: const Key('ritual-settings'),
      child: Column(children: [
        SwitchListTile(
          key: const Key('ritual-popup-toggle'),
          secondary: const Icon(Icons.wb_twilight_rounded),
          title: const Text('Daily ritual pop-up'),
          subtitle: const Text('Once a day when you open Home'),
          value: s.popup,
          onChanged: (v) {
            Haptics.selection();
            ctl.update((x) => x.copyWith(popup: v));
          },
        ),
        SwitchListTile(
          key: const Key('ritual-notify-toggle'),
          secondary: const Icon(Icons.notifications_active_outlined),
          title: const Text('Daily reminder'),
          subtitle: const Text("A gentle nudge, skipped once today's ritual is done"),
          value: s.notify,
          onChanged: (v) async {
            Haptics.selection();
            await ctl.update((x) => x.copyWith(notify: v, permissionAsked: v ? true : null));
            if (v) await ref.read(ritualRemindersProvider).requestPermission();
          },
        ),
        SwitchListTile(
          key: const Key('weekly-notify-toggle'),
          secondary: const Icon(Icons.auto_stories_outlined),
          title: const Text('Weekly report reminder'),
          subtitle: const Text('Sundays at 7 PM, when your week is ready'),
          value: s.weekly,
          onChanged: (v) async {
            Haptics.selection();
            await ctl.update((x) => x.copyWith(weekly: v, permissionAsked: v ? true : null));
            if (v) await ref.read(ritualRemindersProvider).requestPermission();
          },
        ),
        ListTile(
          key: const Key('ritual-time'),
          enabled: s.notify,
          leading: const Icon(Icons.schedule_rounded),
          title: const Text('Reminder time'),
          trailing: Text(time.format(context), style: Theme.of(context).textTheme.titleSmall),
          onTap: Haptics.tap(() async {
            final picked = await showTimePicker(context: context, initialTime: time, helpText: 'Daily reminder time');
            if (picked != null) await ctl.update((x) => x.copyWith(hour: picked.hour, minute: picked.minute));
          }),
        ),
      ]),
    );
  }
}
