import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/services/haptics.dart';
import '../../core/widgets/fx.dart';
import '../results/dimension_detail_screen.dart' show fmtDate;
import 'entitlement.dart';

const _gold = Color(0xFFF5B942);

class PlusBadge extends StatelessWidget {
  const PlusBadge({super.key, this.small = false});
  final bool small;
  @override
  Widget build(BuildContext context) => Container(
        padding: EdgeInsets.symmetric(horizontal: small ? 6 : 8, vertical: small ? 2 : 3),
        decoration: BoxDecoration(color: _gold, borderRadius: BorderRadius.circular(99)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.lock_rounded, size: small ? 11 : 13, color: Colors.black87),
          const SizedBox(width: 3),
          Text('Plus', style: TextStyle(fontSize: small ? 10 : 12, fontWeight: FontWeight.w800, color: Colors.black87)),
        ]),
      );
}

/// Soft upsell sheet for a locked item. One tap to close; no repeat nagging.
Future<void> showPlusUpsell(BuildContext context, PlusFeature f) => showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (c) => SafeArea(
        child: Padding(
          key: const Key('plus-upsell'),
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            const PlusBadge(),
            const SizedBox(height: 10),
            Text(f.title, style: Theme.of(c).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
            const SizedBox(height: 6),
            Text('Free: ${f.free}\nOneUP Plus: ${f.plus}'),
            const SizedBox(height: 8),
            Text('Your assessment, results, daily ritual and safety help always stay free.', style: Theme.of(c).textTheme.bodySmall),
            const SizedBox(height: 16),
            OverflowBar(alignment: MainAxisAlignment.spaceBetween, overflowAlignment: OverflowBarAlignment.end, children: [
              TextButton(onPressed: () => Navigator.pop(c), child: const Text('Not now')),
              FilledButton(
                key: const Key('upsell-see-plus'),
                onPressed: () {
                  Navigator.pop(c);
                  context.push('/plus');
                },
                child: const Text('See OneUP Plus'),
              ),
            ]),
          ]),
        ),
      ),
    );

/// Inline soft lock shown in place of gated content.
class PlusLockCard extends StatelessWidget {
  const PlusLockCard({super.key, required this.feature, required this.message});
  final PlusFeature feature;
  final String message;
  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    return Container(
      key: Key('plus-lock-${feature.name}'),
      width: double.infinity,
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _gold.withOpacity(0.6)),
        color: _gold.withOpacity(0.08),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const PlusBadge(),
        const SizedBox(height: 8),
        Text(message, style: t.textTheme.bodyMedium),
        const SizedBox(height: 8),
        OutlinedButton(onPressed: Haptics.tap(() => context.push('/plus')), child: const Text('See what Plus adds')),
      ]),
    );
  }
}

/// Gentle, dismissable Home banner. Hidden for Plus members and once dismissed.
class PlusHomeBanner extends ConsumerWidget {
  const PlusHomeBanner({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final e = ref.watch(entitlementProvider);
    if (ref.watch(isPlusProvider) || e.bannerDismissed) return const SizedBox.shrink();
    final t = Theme.of(context);
    return PressScale(
      key: const Key('home-plus-banner'),
      semanticLabel: 'OneUP Plus',
      onTap: Haptics.tap(() => context.push('/plus')),
      child: GlassCard(
        padding: const EdgeInsets.fromLTRB(16, 10, 4, 10),
        child: Row(children: [
          const Icon(Icons.auto_awesome_rounded, color: _gold),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('OneUP Plus', style: t.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
              Text(
                  e.trialUsed
                      ? 'More games, full lessons and longer history.'
                      : 'Try more games, full lessons and longer history free for 7 days.',
                  style: t.textTheme.bodySmall),
            ]),
          ),
          IconButton(
            key: const Key('plus-banner-dismiss'),
            tooltip: 'Dismiss',
            icon: const Icon(Icons.close_rounded, size: 20),
            onPressed: Haptics.tap(() => ref.read(entitlementProvider.notifier).dismissBanner()),
          ),
        ]),
      ),
    );
  }
}

String plusStatusText(Entitlement e, DateTime now) {
  if (!e.activeAt(now)) return e.expiresAt != null ? 'Ended ${fmtDate(e.expiresAt!)} · you are on Free' : 'You are on Free';
  final until = fmtDate(e.expiresAt!);
  if (e.cancelled) return '${e.plan!.label} · cancelled, access until $until';
  final renews = e.plan == PlusPlan.monthly || e.plan == PlusPlan.yearly;
  return '${e.plan!.label} · ${renews ? 'renews (demo)' : 'ends'} $until';
}

/// Profile entry: status plus manage / cancel.
class PlusProfileCard extends ConsumerWidget {
  const PlusProfileCard({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final e = ref.watch(entitlementProvider);
    final c = ref.read(entitlementProvider.notifier);
    final plus = ref.watch(isPlusProvider);
    return Card(
      key: const Key('profile-plus'),
      child: Column(children: [
        ListTile(
          leading: const Icon(Icons.auto_awesome_rounded, color: _gold),
          title: const Text('OneUP Plus'),
          subtitle: Text(plusStatusText(e, c.now), key: const Key('plus-status')),
          trailing: const Icon(Icons.chevron_right_rounded),
          onTap: Haptics.tap(() => context.push('/plus')),
        ),
        if (plus)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Row(children: [
              Text('${e.daysLeft(c.now)} days left', style: Theme.of(context).textTheme.bodySmall),
              const Spacer(),
              if (!e.cancelled)
                TextButton(
                    key: const Key('plus-cancel'), onPressed: () => confirmCancelPlus(context, ref), child: const Text('Cancel Plus'))
              else
                TextButton(key: const Key('plus-resume'), onPressed: Haptics.tap(c.resume), child: const Text('Keep Plus')),
            ]),
          ),
      ]),
    );
  }
}

Future<void> confirmCancelPlus(BuildContext context, WidgetRef ref) async {
  final e = ref.read(entitlementProvider);
  final ok = await showDialog<bool>(
    context: context,
    builder: (c) => AlertDialog(
      key: const Key('plus-cancel-dialog'),
      title: const Text('Cancel OneUP Plus?'),
      content: Text('You keep Plus until ${fmtDate(e.expiresAt!)}, then move to Free. Nothing you created is deleted, '
          'and core wellness tools stay free.\n\n$plusDemoNote'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Keep Plus')),
        FilledButton(key: const Key('plus-cancel-confirm'), onPressed: () => Navigator.pop(c, true), child: const Text('Cancel Plus')),
      ],
    ),
  );
  if (ok == true) await ref.read(entitlementProvider.notifier).cancel();
}

class PlusScreen extends ConsumerWidget {
  const PlusScreen({super.key});

  Future<void> _checkout(BuildContext context, WidgetRef ref, PlusPlan plan) async {
    final price = plan == PlusPlan.monthly ? samplePriceMonthly : samplePriceYearly;
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        key: const Key('plus-checkout'),
        icon: const Icon(Icons.science_outlined),
        title: const Text('Demo checkout'),
        content: Text('${plan.label}: $price\n\n$plusDemoNote This only unlocks Plus on this device for ${plan.days} days.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancel')),
          FilledButton(
              key: const Key('plus-checkout-confirm'), onPressed: () => Navigator.pop(c, true), child: const Text('Unlock (demo)')),
        ],
      ),
    );
    if (ok == true) {
      await ref.read(entitlementProvider.notifier).demoPurchase(plan);
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('OneUP Plus unlocked (demo)')));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = Theme.of(context);
    final e = ref.watch(entitlementProvider);
    final plus = ref.watch(isPlusProvider);
    final now = ref.read(entitlementProvider.notifier).now;
    Widget row(String a, String b, String c, {bool head = false}) {
      final s = head ? t.textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w800) : t.textTheme.bodySmall;
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(flex: 4, child: Text(a, style: head ? s : t.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600))),
          Expanded(flex: 3, child: Text(b, style: s)),
          Expanded(flex: 3, child: Text(c, style: head ? s?.copyWith(color: const Color(0xFFB7811A)) : s)),
        ]),
      );
    }

    Widget price(PlusPlan p, String label, String sub) => Expanded(
          child: OutlinedButton(
            key: Key('plus-buy-${p.name}'),
            style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.all(12), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
            onPressed: () => _checkout(context, ref, p),
            child: Column(children: [
              Text(label, textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.w800)),
              const SizedBox(height: 4),
              Text(sub, textAlign: TextAlign.center, style: t.textTheme.bodySmall),
            ]),
          ),
        );

    return Scaffold(
      appBar: AppBar(title: const Text('OneUP Plus')),
      body: ListView(key: const Key('plus-screen'), padding: const EdgeInsets.all(16), children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            gradient:
                const LinearGradient(colors: [Color(0xFF6A4CE0), Color(0xFFF5B942)], begin: Alignment.topLeft, end: Alignment.bottomRight),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Icon(Icons.auto_awesome_rounded, color: Colors.white, size: 32),
            const SizedBox(height: 8),
            Text('Go a little further', style: t.textTheme.headlineSmall?.copyWith(color: Colors.white, fontWeight: FontWeight.w800)),
            const SizedBox(height: 4),
            Text(plus ? plusStatusText(e, now) : 'Extras for curious minds. The essentials stay free, always.',
                key: const Key('plus-screen-status'), style: t.textTheme.bodyMedium?.copyWith(color: Colors.white)),
          ]),
        ),
        const SizedBox(height: 16),
        GlassCard(
          child: Column(children: [
            row('', 'Free', 'Plus', head: true),
            const Divider(height: 1),
            for (final f in PlusFeature.values) row(f.title, f.free, f.plus),
          ]),
        ),
        const SizedBox(height: 12),
        GlassCard(
          child: Column(key: const Key('plus-always-free'), crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Always free, never locked', style: t.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800)),
            const SizedBox(height: 6),
            for (final s in alwaysFree)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Row(children: [
                  const Icon(Icons.check_circle_rounded, size: 18, color: Colors.green),
                  const SizedBox(width: 8),
                  Expanded(child: Text(s))
                ]),
              ),
          ]),
        ),
        const SizedBox(height: 16),
        if (!plus && !e.trialUsed)
          FilledButton.icon(
            key: const Key('plus-trial'),
            style: FilledButton.styleFrom(padding: const EdgeInsets.all(16)),
            icon: const Icon(Icons.card_giftcard_rounded),
            onPressed: () async {
              await ref.read(entitlementProvider.notifier).startTrial();
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Your 7-day trial has started (demo)')));
              }
            },
            label: const Text('Start 7-day free trial (demo)'),
          ),
        if (plus && !e.cancelled)
          OutlinedButton(
              key: const Key('plus-screen-cancel'), onPressed: () => confirmCancelPlus(context, ref), child: const Text('Cancel Plus')),
        const SizedBox(height: 12),
        Row(children: [
          price(PlusPlan.monthly, 'Monthly', samplePriceMonthly),
          const SizedBox(width: 12),
          price(PlusPlan.yearly, 'Yearly', samplePriceYearly),
        ]),
        const SizedBox(height: 12),
        Text(
            'Prices are SAMPLE placeholders [VERIFY] and not final. $plusDemoNote OneUP is for wellness awareness, not medical advice or diagnosis.',
            key: const Key('plus-demo-note'),
            style: t.textTheme.bodySmall,
            textAlign: TextAlign.center),
      ]),
    );
  }
}
