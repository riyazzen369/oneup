import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/services/haptics.dart';
import '../../core/widgets/fx.dart';
import '../results/dimension_detail_screen.dart' show fmtDate;
import 'entitlement.dart';

/// Plus brand accent: fluorescent lime → neon cyan. Always pair with [plusInk] text for contrast.
const plusLime = Color(0xFFC6FF00), plusCyan = Color(0xFF00F0FF), plusInk = Color(0xFF07140F);
const plusGradient = LinearGradient(colors: [plusLime, plusCyan], begin: Alignment.topLeft, end: Alignment.bottomRight);

/// Readable neon tone for text/icons on the plain surface (darker in light theme).
Color plusOn(BuildContext c) => Theme.of(c).brightness == Brightness.dark ? plusLime : const Color(0xFF00796B);

List<BoxShadow> plusGlow([double strength = 1]) => [
      BoxShadow(color: plusLime.withOpacity(0.45 * strength), blurRadius: 14 * strength, spreadRadius: 0.5),
      BoxShadow(color: plusCyan.withOpacity(0.30 * strength), blurRadius: 24 * strength, offset: const Offset(0, 4)),
    ];

/// Neon gradient frame around [child] (1.6 px border + glow).
class PlusFrame extends StatelessWidget {
  const PlusFrame({super.key, required this.child, this.radius = 20, this.glow = 0.6, this.fill});
  final Widget child;
  final double radius, glow;
  final Color? fill;
  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      decoration: BoxDecoration(gradient: plusGradient, borderRadius: BorderRadius.circular(radius), boxShadow: plusGlow(glow)),
      padding: const EdgeInsets.all(1.6),
      child: Container(
        decoration: BoxDecoration(
            color: fill ?? (dark ? const Color(0xFF10141F) : Colors.white), borderRadius: BorderRadius.circular(radius - 1.6)),
        child: child,
      ),
    );
  }
}

/// Neon pill button (dark ink on neon).
class PlusButton extends StatelessWidget {
  const PlusButton({super.key, required this.label, required this.onPressed, this.icon});
  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  @override
  Widget build(BuildContext context) => DecoratedBox(
        decoration: BoxDecoration(gradient: plusGradient, borderRadius: BorderRadius.circular(99), boxShadow: plusGlow(0.8)),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(99),
            onTap: onPressed,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
              child: Row(mainAxisSize: MainAxisSize.min, mainAxisAlignment: MainAxisAlignment.center, children: [
                if (icon != null) ...[Icon(icon, color: plusInk, size: 20), const SizedBox(width: 8)],
                Flexible(
                    child: Text(label,
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: plusInk, fontWeight: FontWeight.w900, letterSpacing: 0.2))),
              ]),
            ),
          ),
        ),
      );
}

class PlusBadge extends StatelessWidget {
  const PlusBadge({super.key, this.small = false});
  final bool small;
  @override
  Widget build(BuildContext context) => Container(
        padding: EdgeInsets.symmetric(horizontal: small ? 7 : 9, vertical: small ? 2 : 3),
        decoration: BoxDecoration(gradient: plusGradient, borderRadius: BorderRadius.circular(99), boxShadow: plusGlow(small ? 0.4 : 0.6)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.lock_rounded, size: small ? 11 : 13, color: plusInk),
          const SizedBox(width: 3),
          Text('PLUS', style: TextStyle(fontSize: small ? 10 : 12, fontWeight: FontWeight.w900, letterSpacing: 0.6, color: plusInk)),
        ]),
      );
}

/// Glowing "OneUP PLUS" wordmark with a slow shimmer (static when reduced motion is on).
class PlusWordmark extends StatefulWidget {
  const PlusWordmark({super.key, this.size = 34});
  final double size;
  @override
  State<PlusWordmark> createState() => _PlusWordmarkState();
}

class _PlusWordmarkState extends State<PlusWordmark> with SingleTickerProviderStateMixin {
  late final _c = AnimationController(vsync: this, duration: const Duration(seconds: 4));

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final reduce = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    if (reduce) {
      _c.stop();
      _c.value = 0.5;
    } else if (!_c.isAnimating) {
      _c.repeat();
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final style = TextStyle(fontSize: widget.size, fontWeight: FontWeight.w900, letterSpacing: 1.2, height: 1.1);
    return Semantics(
      label: 'OneUP PLUS',
      child: ExcludeSemantics(
        child: AnimatedBuilder(
          animation: _c,
          builder: (_, __) {
            final x = -1.5 + 3 * _c.value;
            return Stack(children: [
              // Glow layer.
              Text('OneUP PLUS',
                  style: style.copyWith(color: plusLime, shadows: const [
                    Shadow(color: plusLime, blurRadius: 18),
                    Shadow(color: plusCyan, blurRadius: 30),
                  ])),
              ShaderMask(
                blendMode: BlendMode.srcIn,
                shaderCallback: (r) => LinearGradient(
                  begin: Alignment(x - 1, 0),
                  end: Alignment(x + 1, 0),
                  colors: const [plusLime, Colors.white, plusCyan],
                  stops: const [0.3, 0.5, 0.7],
                  tileMode: TileMode.clamp,
                ).createShader(r),
                child: Text('OneUP PLUS', key: const Key('plus-wordmark'), style: style.copyWith(color: Colors.white)),
              ),
            ]);
          },
        ),
      ),
    );
  }
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
              PlusButton(
                key: const Key('upsell-see-plus'),
                onPressed: () {
                  Navigator.pop(c);
                  context.push('/plus');
                },
                label: 'See OneUP Plus',
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
    return Padding(
      key: Key('plus-lock-${feature.name}'),
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: PlusFrame(
        radius: 18,
        glow: 0.35,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const PlusBadge(),
            const SizedBox(height: 8),
            Text(message, style: t.textTheme.bodyMedium),
            const SizedBox(height: 10),
            PlusButton(onPressed: Haptics.tap(() => context.push('/plus')), label: 'See what Plus adds'),
          ]),
        ),
      ),
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
      child: PlusFrame(
        glow: 0.6,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 10, 4, 10),
          child: Row(children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(gradient: plusGradient, shape: BoxShape.circle, boxShadow: plusGlow(0.5)),
              child: const Icon(Icons.auto_awesome_rounded, color: plusInk, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('OneUP PLUS',
                    style: t.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w900, letterSpacing: 0.6, color: plusOn(context))),
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
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: PlusFrame(
        glow: 0.5,
        child: Column(children: [
          ListTile(
            key: const Key('profile-plus'),
            leading: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(gradient: plusGradient, shape: BoxShape.circle, boxShadow: plusGlow(0.5)),
              child: const Icon(Icons.auto_awesome_rounded, color: plusInk, size: 20),
            ),
            title: Text('OneUP PLUS', style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 0.6, color: plusOn(context))),
            subtitle: Text(plusStatusText(e, c.now), key: const Key('plus-status')),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: Haptics.tap(() => context.push('/plus')),
          ),
          for (final (f, icon, route) in [
            (PlusFeature.reportDashboard, Icons.dashboard_rounded, '/reports'),
            (PlusFeature.consultation, Icons.medical_services_outlined, '/consult'),
            (PlusFeature.coaching, Icons.sports_rounded, '/coaching'),
            (PlusFeature.prioritySupport, Icons.support_agent_rounded, '/support'),
          ])
            ListTile(
              key: Key('profile-service-${f.name}'),
              dense: true,
              leading: Icon(icon),
              title: Text(f.title),
              subtitle: Text(plus ? f.plus : f.free),
              trailing: plus ? const Icon(Icons.chevron_right_rounded) : const PlusBadge(small: true),
              onTap: Haptics.tap(() => context.push(route)),
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
      ),
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
    final dark = t.brightness == Brightness.dark;
    Widget row(String a, String b, String c, {bool head = false}) {
      final st = head ? t.textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w800) : t.textTheme.bodySmall;
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(flex: 4, child: Text(a, style: head ? st : t.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600))),
          Expanded(flex: 3, child: Text(b, style: st)),
          Expanded(
              flex: 3,
              child: head
                  ? const Align(alignment: Alignment.centerLeft, child: PlusBadge(small: true))
                  : Text(c, style: st?.copyWith(fontWeight: FontWeight.w700))),
        ]),
      );
    }

    Widget price(PlusPlan p, String label, String main, String sub, {bool best = false}) => Expanded(
          child: Stack(clipBehavior: Clip.none, children: [
            PlusFrame(
              radius: 18,
              glow: best ? 0.9 : 0.25,
              child: InkWell(
                key: Key('plus-buy-${p.name}'),
                borderRadius: BorderRadius.circular(16),
                onTap: () => _checkout(context, ref, p),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(10, 22, 10, 14),
                  child: Column(children: [
                    Text(label, style: t.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w900)),
                    const SizedBox(height: 6),
                    Text(main, textAlign: TextAlign.center, style: t.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900)),
                    const SizedBox(height: 2),
                    Text(sub, textAlign: TextAlign.center, style: t.textTheme.bodySmall),
                  ]),
                ),
              ),
            ),
            if (best)
              Positioned(
                top: -10,
                left: 0,
                right: 0,
                child: Center(
                  child: Container(
                    key: const Key('plus-best-value'),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                    decoration: BoxDecoration(gradient: plusGradient, borderRadius: BorderRadius.circular(99), boxShadow: plusGlow(0.8)),
                    child: Text('BEST VALUE · SAVE ~$sampleYearlySavePct%',
                        style: const TextStyle(color: plusInk, fontSize: 10.5, fontWeight: FontWeight.w900, letterSpacing: 0.4)),
                  ),
                ),
              ),
          ]),
        );

    final total = sampleTotalValue;
    final totalLabel = '${rupees(total ~/ 100 * 100)}+';
    return Scaffold(
      appBar: AppBar(title: const Text('OneUP Plus')),
      body: ListView(key: const Key('plus-screen'), padding: const EdgeInsets.all(16), children: [
        // Hero: always dark so the neon reads in both themes.
        Container(
          key: const Key('plus-hero'),
          padding: const EdgeInsets.fromLTRB(20, 22, 20, 20),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            gradient: const LinearGradient(
                colors: [Color(0xFF0B0F1C), Color(0xFF0F2A2E), Color(0xFF1A2B05)], begin: Alignment.topLeft, end: Alignment.bottomRight),
            border: Border.all(color: plusLime.withOpacity(0.55), width: 1.4),
            boxShadow: plusGlow(0.7),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const PlusWordmark(),
            const SizedBox(height: 10),
            Text('Go a little further', style: t.textTheme.titleLarge?.copyWith(color: Colors.white, fontWeight: FontWeight.w800)),
            const SizedBox(height: 4),
            Text(plus ? plusStatusText(e, now) : 'Experts, coaching, deeper reports and more. The essentials stay free, always.',
                key: const Key('plus-screen-status'), style: t.textTheme.bodyMedium?.copyWith(color: Colors.white70)),
          ]),
        ),
        const SizedBox(height: 16),
        PlusFrame(
          glow: 0.35,
          child: Padding(
            key: const Key('plus-value-stack'),
            padding: const EdgeInsets.all(16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Value you get', style: t.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900)),
              Text('SAMPLE values per month [VERIFY], for illustration only', style: t.textTheme.bodySmall),
              const SizedBox(height: 8),
              for (final (name, v) in sampleValues)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 5),
                  child: Row(children: [
                    Icon(Icons.check_circle_rounded, size: 18, color: plusOn(context)),
                    const SizedBox(width: 8),
                    Expanded(child: Text(name)),
                    Text('SAMPLE ${rupees(v)}', style: t.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w700)),
                  ]),
                ),
              const Divider(height: 20),
              Row(children: [
                const Expanded(child: Text('SAMPLE total value', style: TextStyle(fontWeight: FontWeight.w700))),
                Text('$totalLabel/month',
                    key: const Key('plus-total-value'),
                    style: t.textTheme.titleMedium
                        ?.copyWith(decoration: TextDecoration.lineThrough, decorationThickness: 2, color: t.colorScheme.onSurfaceVariant)),
              ]),
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(gradient: plusGradient, borderRadius: BorderRadius.circular(14), boxShadow: plusGlow(0.6)),
                child: Text('Yours for SAMPLE ${rupees(sampleMonthlyRupees)}/month [VERIFY]',
                    key: const Key('plus-yours-for'),
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: plusInk, fontWeight: FontWeight.w900, fontSize: 16)),
              ),
            ]),
          ),
        ),
        const SizedBox(height: 20),
        if (!plus && !e.trialUsed) ...[
          PlusButton(
            key: const Key('plus-trial'),
            icon: Icons.card_giftcard_rounded,
            onPressed: () async {
              await ref.read(entitlementProvider.notifier).startTrial();
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Your 7-day trial has started (demo)')));
              }
            },
            label: 'Start 7-day free trial (demo)',
          ),
          const SizedBox(height: 20),
        ],
        if (plus && !e.cancelled) ...[
          OutlinedButton(
              key: const Key('plus-screen-cancel'), onPressed: () => confirmCancelPlus(context, ref), child: const Text('Cancel Plus')),
          const SizedBox(height: 20),
        ],
        Row(key: const Key('plus-pricing'), crossAxisAlignment: CrossAxisAlignment.start, children: [
          price(PlusPlan.monthly, 'Monthly', 'SAMPLE ${rupees(sampleMonthlyRupees)}', 'per month [VERIFY]'),
          const SizedBox(width: 12),
          price(PlusPlan.yearly, 'Yearly', 'SAMPLE ${rupees(sampleYearlyRupees)}',
              'per year [VERIFY]\n≈ ${rupees((sampleYearlyRupees / 12).round())}/month',
              best: true),
        ]),
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
                  Icon(Icons.check_circle_rounded, size: 18, color: dark ? Colors.greenAccent : Colors.green),
                  const SizedBox(width: 8),
                  Expanded(child: Text(s))
                ]),
              ),
          ]),
        ),
        const SizedBox(height: 12),
        Text(
            'All prices and values are SAMPLE placeholders [VERIFY] and not final. $plusDemoNote OneUP is for wellness awareness, not medical advice or diagnosis.',
            key: const Key('plus-demo-note'),
            style: t.textTheme.bodySmall,
            textAlign: TextAlign.center),
      ]),
    );
  }
}
