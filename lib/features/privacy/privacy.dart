import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/router/app_router.dart' show Routes;
import '../../core/services/haptics.dart';
import '../../core/services/secure_store.dart';
import '../../core/widgets/fx.dart';
import '../games/game_catalog.dart';
import '../games/game_scores.dart';
import '../org/org.dart';
import '../plus/plus_ui.dart';
import '../profile/profile_page.dart' show deleteMyData;

/// One kind of data OneUP keeps on this device, mapped to its real storage key.
class DataItem {
  const DataItem(this.label, this.key, this.count, {this.note});
  final String label, key;
  final int Function(Object? decoded) count;
  final String? note;
}

int _list(Object? d) => d is List ? d.length : 0;
int _map(Object? d) => d is Map ? d.length : 0;
int Function(Object?) _field(String f) => (d) => d is Map && d[f] is List ? (d[f] as List).length : 0;
int _one(Object? d) => d == null ? 0 : 1;

/// Everything shown in "Your data at a glance", derived from the actual storage keys.
const dataInventory = <DataItem>[
  DataItem('Assessments completed', 'assess_attempts_v2', _list, note: 'answers + reflections AES-256-GCM encrypted'),
  DataItem('Assessments in progress', 'assess_drafts_v2', _list, note: 'answers encrypted'),
  DataItem('Goals', 'goals_v1', _map),
  DataItem('Quick checks', 'quick_check_v1', _list),
  DataItem('Daily ritual days (mood, tag)', 'ritual_v1', _map),
  DataItem('Weekly reports', 'weekly_reports_v1', _reports),
  DataItem('Activity log', 'wheel_activity_v1', _events),
  DataItem('Lessons completed', 'learn_done_v1', _list),
  DataItem('Companion chat messages', 'companion_history_v1', _list),
  DataItem('Consultation bookings (demo)', 'consult_bookings_v1', _list),
  DataItem('Market orders (demo)', 'market_v1', _orders),
  DataItem('Coaching / support requests (demo)', 'plus_requests_v1', _list),
  DataItem('Content issue reports', 'content_feedback_v1', _list),
  DataItem('OneUP Plus status (demo)', 'plus_entitlement_v1', _one),
  DataItem('Invite code & challenge (demo)', 'referral_v1', _one),
  DataItem('Company team membership', 'org_membership_v1', _one),
  DataItem('Profile details', 'demo_profile_v1', _one),
  DataItem('Profile photo', 'avatar_v1', _one, note: 'AES-256-GCM encrypted'),
];
int _reports(Object? d) => _field('reports')(d);
int _events(Object? d) => _field('events')(d);
int _orders(Object? d) => _field('orders')(d);

/// Settings-type keys (no personal content) also kept locally.
const settingsKeys = [
  'assess_cycle_v2',
  'ritual_settings_v1',
  'ritual_popup_day_v1',
  'reader_prefs_v1',
  'learn_pos_v1',
  'companion_settings_v1',
  'haptics_enabled',
  SecureStore.kTheme,
  SecureStore.kOnboarded,
  SecureStore.kConsentVersion,
  'consent_at',
  'welcome_shown_v1',
  'demo_user_v1',
];

/// Every key OneUP writes (the encryption key `answer_key_v1` is included so delete covers it; it is never exported).
List<String> get allKnownKeys => [
      for (final d in dataInventory) d.key,
      ...settingsKeys,
      'answer_key_v1',
      for (final g in games) GameScores.key(g.id),
    ];

Future<Map<String, int>> dataCounts(SecureStore s) async {
  final out = <String, int>{};
  for (final d in dataInventory) {
    final raw = await s.read(d.key);
    Object? v;
    if (raw != null) {
      try {
        v = jsonDecode(raw);
      } catch (_) {
        v = raw;
      }
    }
    out[d.key] = raw == null ? 0 : d.count(v);
  }
  var best = 0;
  for (final g in games) {
    if (await s.read(GameScores.key(g.id)) != null) best++;
  }
  out['games'] = best;
  return out;
}

/// Export as JSON. Encrypted answers stay as ciphertext; the encryption key and photo bytes are never exported.
Future<String> exportJson(SecureStore s, DateTime now) async {
  final data = <String, Object?>{};
  for (final k in allKnownKeys) {
    if (k == 'answer_key_v1' || k == 'avatar_v1' || k == 'demo_user_v1') continue;
    final raw = await s.read(k);
    if (raw == null) continue;
    try {
      data[k] = jsonDecode(raw);
    } catch (_) {
      data[k] = raw;
    }
  }
  return const JsonEncoder.withIndent('  ').convert({
    'app': 'OneUP',
    'exportedAt': now.toIso8601String(),
    'note': 'Assessment answers are exported as AES-GCM ciphertext; the device key is not exported.',
    'data': data,
  });
}

/// Overridable for tests.
final exportSharerProvider =
    Provider<Future<void> Function(String json)>((ref) => (json) => Share.share(json, subject: 'My OneUP data export'));

final dataCountsProvider = FutureProvider.autoDispose<Map<String, int>>((ref) => dataCounts(ref.read(secureStoreProvider)));

/// "Private by design" trust badge; opens /privacy.
class PrivateBadge extends StatelessWidget {
  const PrivateBadge({super.key, this.compact = false});
  final bool compact;
  @override
  Widget build(BuildContext context) {
    final c = plusOn(context);
    return Semantics(
      button: true,
      label: 'Private by design. Opens Privacy Center',
      child: InkWell(
        key: const Key('private-badge'),
        borderRadius: BorderRadius.circular(99),
        onTap: Haptics.tap(() => context.push('/privacy')),
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: compact ? 8 : 10, vertical: compact ? 3 : 5),
          decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(99), color: c.withOpacity(0.10), border: Border.all(color: c.withOpacity(0.55))),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.shield_rounded, size: compact ? 14 : 16, color: c),
            const SizedBox(width: 4),
            Text('Private by design', style: TextStyle(fontSize: compact ? 11 : 12, fontWeight: FontWeight.w800, color: c)),
          ]),
        ),
      ),
    );
  }
}

class PrivacyScreen extends ConsumerWidget {
  const PrivacyScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = Theme.of(context);
    final counts = ref.watch(dataCountsProvider).valueOrNull;
    Widget card(String k, IconData icon, String title, String body) => Padding(
          padding: const EdgeInsets.only(top: 10),
          child: GlassCard(
            child: Row(key: Key('privacy-$k'), crossAxisAlignment: CrossAxisAlignment.start, children: [
              Icon(icon, color: plusOn(context)),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(title, style: t.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800)),
                  const SizedBox(height: 4),
                  Text(body, style: t.textTheme.bodySmall),
                ]),
              ),
            ]),
          ),
        );
    return Scaffold(
      appBar: AppBar(title: const Text('Privacy Center')),
      body: ListView(key: const Key('privacy-screen'), padding: const EdgeInsets.all(16), children: [
        Container(
          key: const Key('privacy-hero'),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            gradient:
                const LinearGradient(colors: [Color(0xFF0B0F1C), Color(0xFF0F2A2E)], begin: Alignment.topLeft, end: Alignment.bottomRight),
            border: Border.all(color: plusCyan.withOpacity(0.5), width: 1.2),
            boxShadow: plusGlow(0.4),
          ),
          child: Row(children: [
            ShaderMask(
              blendMode: BlendMode.srcIn,
              shaderCallback: (r) => plusGradient.createShader(r),
              child: const Icon(Icons.shield_rounded, size: 56, color: Colors.white),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Your data, locked', style: t.textTheme.headlineSmall?.copyWith(color: Colors.white, fontWeight: FontWeight.w900)),
                const SizedBox(height: 4),
                Text('Stored on your device, encrypted, and deletable in one tap.',
                    style: t.textTheme.bodyMedium?.copyWith(color: Colors.white70)),
              ]),
            ),
          ]),
        ),
        card(
            'encrypted',
            Icons.lock_rounded,
            'Encrypted on your device',
            'Everything OneUP saves lives in secure storage (Android Keystore-backed EncryptedSharedPreferences / iOS Keychain). '
                'Assessment answers, reflections and your profile photo are additionally encrypted with AES-256-GCM using a key created on this device.'),
        card('minimal', Icons.inventory_2_outlined, 'Minimal data collected',
            'Only what the app needs: the items listed below under "Your data at a glance", plus a few settings (theme, reminders, reading preferences). No contacts, no location, no ads tracking.'),
        card('never-sold', Icons.money_off_rounded, 'Never sold', 'We do not sell your data or share it with advertisers.'),
        card('employer', Icons.apartment_rounded, 'Employers see only anonymous averages',
            'If you join a company team, your employer sees only aggregated team averages for groups of $orgMinGroup or more. Never your answers, scores, reflections, mood or crisis-help use.'),
        card(
            'sharing',
            Icons.ios_share_rounded,
            'What\'s shared, and when',
            'Nothing leaves your phone unless you choose to. Sharing a weekly report sends only the page you see on screen, after a privacy note. '
                'If you sign in with an account, your profile and assessment results sync to it (answers stay encrypted), and Delete removes them there too.'),
        card('dpdp', Icons.gavel_rounded, 'Built with the DPDP Act, 2023 in mind',
            'Consent first, purpose limitation, access (export) and erasure (delete) for you [VERIFY with legal counsel].'),
        const SizedBox(height: 16),
        GlassCard(
          child: Column(key: const Key('privacy-glance'), crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Your data at a glance', style: t.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
            Text('Stored on this device right now', style: t.textTheme.bodySmall),
            const SizedBox(height: 6),
            if (counts == null)
              const LinearProgressIndicator()
            else ...[
              for (final d in dataInventory)
                Padding(
                  key: Key('glance-${d.key}'),
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(children: [
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(d.label),
                        if (d.note != null) Text(d.note!, style: t.textTheme.labelSmall),
                      ]),
                    ),
                    Text('${counts[d.key]}', style: const TextStyle(fontWeight: FontWeight.w800)),
                  ]),
                ),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(children: [
                  const Expanded(child: Text('Game best scores')),
                  Text('${counts['games']}', style: const TextStyle(fontWeight: FontWeight.w800)),
                ]),
              ),
            ],
          ]),
        ),
        const SizedBox(height: 16),
        OutlinedButton.icon(
          key: const Key('privacy-export'),
          style: OutlinedButton.styleFrom(padding: const EdgeInsets.all(14)),
          icon: const Icon(Icons.download_rounded),
          label: const Text('Export my data (JSON)'),
          onPressed: () async {
            final json = await exportJson(ref.read(secureStoreProvider), DateTime.now());
            await ref.read(exportSharerProvider)(json);
          },
        ),
        const SizedBox(height: 12),
        FilledButton.icon(
          key: const Key('privacy-delete'),
          style: FilledButton.styleFrom(
              padding: const EdgeInsets.all(16), backgroundColor: t.colorScheme.error, foregroundColor: t.colorScheme.onError),
          icon: const Icon(Icons.delete_forever_rounded),
          label: const Text('Delete all my data'),
          onPressed: () async {
            final ok = await showDialog<bool>(
              context: context,
              builder: (c) => AlertDialog(
                key: const Key('privacy-delete-dialog'),
                title: const Text('Delete all my data?'),
                content: const Text('This wipes everything OneUP stored on this phone (and your account data, if signed in). '
                    'It cannot be undone.'),
                actions: [
                  TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancel')),
                  FilledButton(
                      key: const Key('privacy-delete-confirm'), onPressed: () => Navigator.pop(c, true), child: const Text('Delete')),
                ],
              ),
            );
            if (ok != true) return;
            await deleteMyData(ref);
            ref.invalidate(dataCountsProvider);
            if (context.mounted) context.go(Routes.splash);
          },
        ),
        const SizedBox(height: 12),
        Text('OneUP is for wellness awareness, not medical advice or diagnosis. Legal statements are drafts [VERIFY with legal counsel].',
            key: const Key('privacy-disclaimer'), style: t.textTheme.bodySmall, textAlign: TextAlign.center),
      ]),
    );
  }
}
