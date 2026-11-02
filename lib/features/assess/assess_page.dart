import '../experts/experts.dart';
import 'package:flutter/material.dart';
import '../../core/widgets/fx.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/services/haptics.dart';
import '../../core/theme/app_colors.dart';
import '../consent/consent_screen.dart' show kDisclaimer;
import 'data/assessment_models.dart';
import 'data/question_bank.dart';
import 'domain/assessment_controller.dart';
import 'domain/scoring.dart';
import '../quick/quick_check_screen.dart' show startQuickCheck;

/// Mandatory disclaimer before every assessment. Returns true only if accepted.
Future<bool> showAssessmentDisclaimer(BuildContext context) async {
  final r = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (c) => AlertDialog(
      icon: const Icon(Icons.info_outline_rounded),
      title: const Text('Before you begin'),
      content: const Text(
          '$kDisclaimer\n\nYour results are a reflection based on psychology-informed analysis of your answers. There are no right or wrong answers.'),
      actions: [
        TextButton(onPressed: Haptics.tap(() => Navigator.pop(c, false)), child: const Text('Cancel')),
        FilledButton(onPressed: Haptics.tap(() => Navigator.pop(c, true)), child: const Text('I understand')),
      ],
    ),
  );
  return r ?? false;
}

/// Opens a dimension: handles done (view / redo), resume prompt and disclaimer.
Future<void> openDimension(BuildContext context, WidgetRef ref, WellnessDimension d) async {
  final ctrl = ref.read(assessmentProvider.notifier);
  final st = ref.read(assessmentProvider).statusOf(d);
  var restart = false;
  if (st == DimStatus.done) {
    final choice = await showDialog<String>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text('${d.label} is complete'),
        content: const Text('You can view your result, or redo just this dimension. Your earlier score stays in your history.'),
        actions: [
          TextButton(onPressed: Haptics.tap(() => Navigator.pop(c, 'view')), child: const Text('View result')),
          FilledButton(onPressed: Haptics.tap(() => Navigator.pop(c, 'redo')), child: const Text('Redo')),
        ],
      ),
    );
    if (choice == null || !context.mounted) return;
    if (choice == 'view') {
      context.push('/results/dim/${d.name}');
      return;
    }
    restart = true;
  } else if (st == DimStatus.inProgress) {
    final resume = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Resume where you left off?'),
        content: Text('You have an unfinished ${d.label} check-in.'),
        actions: [
          TextButton(onPressed: Haptics.tap(() => Navigator.pop(c, false)), child: const Text('Start over')),
          FilledButton(onPressed: Haptics.tap(() => Navigator.pop(c, true)), child: const Text('Resume')),
        ],
      ),
    );
    if (resume == null) return;
    restart = !resume;
  }
  if (!context.mounted) return;
  if (!await showAssessmentDisclaimer(context)) return;
  await ctrl.ensureDraft(d, restart: restart);
  if (context.mounted) context.push('/assess/q/${d.name}');
}

class AssessPage extends ConsumerWidget {
  const AssessPage({super.key});

  Future<void> _retake(BuildContext context, WidgetRef ref) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Retake all 8 dimensions?'),
        content: const Text('All dimensions reset to "Not started". Every past score stays in your history.'),
        actions: [
          TextButton(onPressed: Haptics.tap(() => Navigator.pop(c, false)), child: const Text('Cancel')),
          FilledButton(onPressed: Haptics.tap(() => Navigator.pop(c, true)), child: const Text('Retake')),
        ],
      ),
    );
    if (ok == true) await ref.read(assessmentProvider.notifier).retakeAll();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(assessmentProvider);
    final t = Theme.of(context);
    final b = t.brightness;
    final done = s.doneCount;
    return Scaffold(
      appBar: AppBar(title: const Text('Assess'), backgroundColor: Colors.transparent, actions: [
        IconButton(tooltip: 'Trends', onPressed: Haptics.tap(() => context.push('/trends')), icon: const Icon(Icons.insights_rounded)),
      ]),
      body: s.loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: () {
                Haptics.medium(); // refresh triggered
                return ref.read(assessmentProvider.notifier).refreshFromRemote();
              },
              child: ListView(padding: const EdgeInsets.all(16), children: [
                const Align(alignment: Alignment.centerLeft, child: ReviewedBadge()),
                const SizedBox(height: 8),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('$done of 8 complete', style: t.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
                      const SizedBox(height: 12),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: TweenAnimationBuilder<double>(
                          tween: Tween(end: done / 8),
                          duration: motion(context, const Duration(milliseconds: 600)),
                          builder: (_, v, __) => LinearProgressIndicator(value: v, minHeight: 10),
                        ),
                      ),
                      const SizedBox(height: 12),
                      if (s.latest.isNotEmpty)
                        Row(children: [
                          Expanded(
                            child: FilledButton.tonalIcon(
                              onPressed: Haptics.tap(() => context.push('/results')),
                              icon: const Icon(Icons.donut_large_rounded),
                              label: const Text('Results'),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: FilledButton.tonalIcon(
                              onPressed: Haptics.tap(() => context.push('/circle')),
                              icon: const Icon(Icons.radar_rounded),
                              label: const FittedBox(child: Text('Circle Paradigm')),
                            ),
                          ),
                        ]),
                      if (done > 0) ...[
                        const SizedBox(height: 8),
                        OutlinedButton.icon(
                          onPressed: Haptics.tap(() => _retake(context, ref)),
                          icon: const Icon(Icons.restart_alt_rounded),
                          label: const Text('Retake all'),
                        ),
                      ],
                    ]),
                  ),
                ),
                const SizedBox(height: 8),
                Card(
                  key: const Key('assess-quick-check'),
                  child: ListTile(
                    leading: const Icon(Icons.bolt_rounded),
                    title: const Text('60-second Quick Check'),
                    subtitle: const Text('A fast estimate. The 8 areas below are the Deep dive.'),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: Haptics.tap(() => startQuickCheck(context)),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(4, 12, 4, 8),
                  child: Text('Deep dive: full assessment', style: t.textTheme.titleMedium),
                ),
                GridView.count(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisCount: 2,
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  childAspectRatio: 0.95,
                  children: [
                    for (final d in WellnessDimension.values)
                      StaggerIn(
                          index: d.index,
                          child: _DimCard(
                            d: d,
                            color: d.color(b),
                            status: s.statusOf(d),
                            score: s.latest[d],
                            answered: s.drafts[d]?.position ?? 0,
                            onTap: () => openDimension(context, ref, d),
                          )),
                  ],
                ),
              ]),
            ),
    );
  }
}

class _DimCard extends StatelessWidget {
  const _DimCard(
      {required this.d, required this.color, required this.status, required this.score, required this.answered, required this.onTap});
  final WellnessDimension d;
  final Color color;
  final DimStatus status;
  final int? score;
  final int answered;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final total = questionsFor(d).length;
    final label = switch (status) {
      DimStatus.notStarted => score == null ? 'Not started' : 'Not started · last $score',
      DimStatus.inProgress => 'In progress · $answered/$total',
      DimStatus.done => '${bandFor(score!).label} · $score',
    };
    return Semantics(
      button: true,
      label: '${d.label}, $label',
      excludeSemantics: true,
      child: Material(
        color: color.withOpacity(0.14),
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: Haptics.tap(onTap),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Hero(tag: 'dim-${d.name}', child: CircleAvatar(backgroundColor: color, foregroundColor: Colors.white, child: Icon(d.icon))),
                const Spacer(),
                if (status == DimStatus.done) Icon(Icons.check_circle_rounded, color: color),
              ]),
              const Spacer(),
              Text(d.label, style: t.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
              const SizedBox(height: 4),
              Text(label, style: t.textTheme.bodySmall, maxLines: 2),
            ]),
          ),
        ),
      ),
    );
  }
}
