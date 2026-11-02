import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/services/haptics.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/fx.dart';
import '../assess/assess_page.dart' show showAssessmentDisclaimer, openDimension;
import '../assess/domain/scoring.dart';
import '../consent/consent_screen.dart' show kDisclaimer;
import '../results/wellness_wheel.dart';
import 'quick_check.dart';

/// Entry point used by Home and Assess: same mandatory disclaimer as the full assessment.
Future<void> startQuickCheck(BuildContext context) async {
  if (!await showAssessmentDisclaimer(context)) return;
  if (context.mounted) context.push('/quick');
}

class QuickCheckScreen extends ConsumerStatefulWidget {
  const QuickCheckScreen({super.key});
  @override
  ConsumerState<QuickCheckScreen> createState() => _QuickCheckScreenState();
}

class _QuickCheckScreenState extends ConsumerState<QuickCheckScreen> {
  final _values = {for (final d in WellnessDimension.values) d: ValueNotifier<int>(quickDefault)};
  bool _busy = false;

  @override
  void dispose() {
    for (final v in _values.values) {
      v.dispose();
    }
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() => _busy = true);
    await ref.read(quickCheckProvider.notifier).submit({for (final e in _values.entries) e.key: e.value.value});
    Haptics.success();
    if (mounted) context.pushReplacement('/quick/result');
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('60-second Quick Check')),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 680),
            child: ListView(padding: const EdgeInsets.fromLTRB(16, 8, 16, 24), children: [
              const Card(
                key: Key('quick-disclaimer'),
                child: Padding(
                  padding: EdgeInsets.all(14),
                  child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Icon(Icons.info_outline_rounded),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text('$kDisclaimer\nRate each area from 1 (low) to 10 (high). This is a quick estimate, '
                          'not your full assessment.'),
                    ),
                  ]),
                ),
              ),
              const SizedBox(height: 8),
              for (final d in WellnessDimension.values) _QuickRow(d: d, value: _values[d]!),
              const SizedBox(height: 12),
              FilledButton.icon(
                key: const Key('quick-submit'),
                onPressed: _busy ? null : Haptics.tap(_submit),
                icon: const Icon(Icons.donut_large_rounded),
                label: const Text('See my Quick Wheel'),
              ),
              const SizedBox(height: 8),
              Text('Quick snapshots are stored encrypted on this device, separately from your full assessment.',
                  textAlign: TextAlign.center, style: t.textTheme.bodySmall),
            ]),
          ),
        ),
      ),
    );
  }
}

class _QuickRow extends StatelessWidget {
  const _QuickRow({required this.d, required this.value});
  final WellnessDimension d;
  final ValueNotifier<int> value;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final color = d.color(t.brightness);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: GlassCard(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 4),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            CircleAvatar(radius: 16, backgroundColor: color, foregroundColor: Colors.white, child: Icon(d.icon, size: 18)),
            const SizedBox(width: 10),
            Expanded(child: Text(d.label, style: t.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700))),
            ValueListenableBuilder<int>(
              valueListenable: value,
              builder: (_, v, __) => Text('$v/10', style: t.textTheme.titleMedium?.copyWith(color: color, fontWeight: FontWeight.w800)),
            ),
          ]),
          const SizedBox(height: 6),
          Text(quickPrompts[d]!, style: t.textTheme.bodyMedium),
          // RepaintBoundary keeps slider drags from repainting the rest of the list.
          RepaintBoundary(
            child: ValueListenableBuilder<int>(
              valueListenable: value,
              builder: (_, v, __) => Slider(
                key: Key('quick-slider-${d.name}'),
                value: v.toDouble(),
                min: quickMin.toDouble(),
                max: quickMax.toDouble(),
                divisions: quickMax - quickMin,
                activeColor: color,
                inactiveColor: color.withOpacity(0.2),
                label: '$v',
                semanticFormatterCallback: (x) => '${d.label} ${x.round()} out of 10',
                onChanged: (x) {
                  final n = x.round();
                  if (n != value.value) {
                    Haptics.selection(); // one tick per step
                    value.value = n;
                  }
                },
              ),
            ),
          ),
        ]),
      ),
    );
  }
}

class QuickResultScreen extends ConsumerWidget {
  const QuickResultScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = Theme.of(context);
    final snap = ref.watch(quickCheckProvider).latest;
    if (snap == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Quick snapshot')),
        body: Center(
          child: FilledButton(onPressed: Haptics.tap(() => startQuickCheck(context)), child: const Text('Take the Quick Check')),
        ),
      );
    }
    final low = lowestQuick(snap.scores);
    final lowColor = low.color(t.brightness);
    return Scaffold(
      appBar: AppBar(title: const Text('Your Quick Wheel')),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 680),
            child: ListView(padding: const EdgeInsets.fromLTRB(16, 8, 16, 24), children: [
              Container(
                key: const Key('quick-estimate-tag'),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(borderRadius: BorderRadius.circular(14), border: Border.all(color: t.colorScheme.outline)),
                child: const Row(children: [
                  Icon(Icons.bolt_rounded, size: 18),
                  SizedBox(width: 8),
                  Expanded(child: Text('Quick snapshot: an estimate, not your full assessment')),
                ]),
              ),
              const SizedBox(height: 8),
              LayoutBuilder(
                builder: (_, c) => Center(
                  child: WellnessWheel(
                    scores: snap.scores,
                    size: (c.maxWidth - 24).clamp(200.0, 360.0),
                    estimated: snap.scores.keys.toSet(),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              for (final d in WellnessDimension.values) _BandRow(d: d, score: snap.scores[d]!, lowest: d == low),
              const SizedBox(height: 12),
              FilledButton.icon(
                key: const Key('quick-deep-dive'),
                style: FilledButton.styleFrom(backgroundColor: lowColor, foregroundColor: Colors.white),
                onPressed: Haptics.tap(() => openDimension(context, ref, low)),
                icon: const Icon(Icons.travel_explore_rounded),
                label: Text('Take the deep dive for ${low.label}'),
              ),
              const SizedBox(height: 8),
              OutlinedButton(
                onPressed: Haptics.tap(() => context.canPop() ? context.pop() : context.go('/home')),
                child: const Text('Done'),
              ),
              const SizedBox(height: 8),
              Text(
                  'The full assessment (9 questions per area) gives a more reliable picture. '
                  'Your full scores are never replaced by a Quick Check. $kDisclaimer',
                  textAlign: TextAlign.center,
                  style: t.textTheme.bodySmall),
            ]),
          ),
        ),
      ),
    );
  }
}

class _BandRow extends StatelessWidget {
  const _BandRow({required this.d, required this.score, required this.lowest});
  final WellnessDimension d;
  final int score;
  final bool lowest;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final color = d.color(t.brightness);
    final band = bandFor(score);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Container(
        key: lowest ? const Key('quick-lowest') : null,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          color: color.withOpacity(lowest ? 0.20 : 0.10),
          border: Border.all(color: lowest ? color : Colors.transparent, width: 1.6),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Row(children: [
          Icon(d.icon, color: color),
          const SizedBox(width: 10),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(lowest ? '${d.label} · lowest right now' : d.label,
                  style: t.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
              Text(band.label, style: t.textTheme.bodySmall),
            ]),
          ),
          AnimatedScore(score, style: t.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800, color: color)),
        ]),
      ),
    );
  }
}
