import 'package:go_router/go_router.dart';
import 'package:flutter/material.dart';
import '../../core/widgets/fx.dart';
import '../../core/services/haptics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../assess/assess_page.dart' show openDimension;
import '../assess/data/assessment_models.dart';
import '../assess/domain/assessment_controller.dart';
import '../assess/domain/history.dart';
import '../assess/domain/scoring.dart';
import 'goal_sheet.dart';
import 'score_line_chart.dart';

String fmtDate(DateTime d) => '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

class DimensionDetailScreen extends ConsumerWidget {
  const DimensionDetailScreen({super.key, required this.dimension});
  final WellnessDimension dimension;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(assessmentProvider);
    final t = Theme.of(context);
    final d = dimension;
    final color = d.color(t.brightness);
    final score = s.latest[d];
    final hist = historyFor(s.attempts, d);
    final band = score == null ? null : bandFor(score);
    final goal = s.goals[d];
    return Scaffold(
      appBar: AppBar(title: Text(d.label)),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            gradient: LinearGradient(colors: [color, Color.lerp(color, Colors.black, 0.25)!]),
          ),
          child: Row(children: [
            Hero(tag: 'dim-${d.name}', child: Icon(d.icon, color: Colors.white, size: 40)),
            const SizedBox(width: 16),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(band?.label ?? 'Not assessed yet',
                    style: t.textTheme.titleLarge?.copyWith(color: Colors.white, fontWeight: FontWeight.w700)),
                if (band != null) Text(band.guidance, style: t.textTheme.bodyMedium?.copyWith(color: Colors.white)),
              ]),
            ),
            TweenAnimationBuilder<int>(
              tween: IntTween(begin: 0, end: score ?? 0),
              duration: motion(context, const Duration(milliseconds: 900)),
              builder: (_, v, __) => Text(score == null ? '—' : '$v',
                  style: t.textTheme.displaySmall?.copyWith(color: Colors.white, fontWeight: FontWeight.w800)),
            ),
          ]),
        ),
        if (hist.isNotEmpty) ...[
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Your reflection', style: t.textTheme.titleMedium),
                const SizedBox(height: 8),
                _Reflection(attempt: hist.last),
              ]),
            ),
          ),
        ],
        const SizedBox(height: 16),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Text('History', style: t.textTheme.titleMedium),
                const Spacer(),
                TextButton.icon(
                  onPressed: Haptics.tap(() => showGoalSheet(context, ref, d)),
                  icon: const Icon(Icons.flag_rounded),
                  label: Text(goal == null ? 'Set goal' : 'Goal $goal'),
                ),
              ]),
              const SizedBox(height: 8),
              ScoreLineChart(history: hist, color: color, goal: goal),
              for (final a in hist.reversed)
                ExpansionTile(
                  tilePadding: EdgeInsets.zero,
                  title: Text(fmtDate(a.completedAt)),
                  subtitle: Text('${bandFor(a.score).label} · ${a.score}'),
                  childrenPadding: const EdgeInsets.only(bottom: 12),
                  expandedAlignment: Alignment.centerLeft,
                  children: [_Reflection(attempt: a)],
                ),
            ]),
          ),
        ),
        const SizedBox(height: 8),
        FilledButton.icon(
          onPressed: Haptics.tap(() => openDimension(context, ref, d)),
          icon: const Icon(Icons.replay_rounded),
          label: Text(score == null ? 'Take ${d.label} check-in' : 'Redo ${d.label}'),
        ),
        const SizedBox(height: 12),
        Card(
          child: ListTile(
            leading: const Icon(Icons.menu_book_rounded),
            title: Text('Learn about ${d.label} wellness'),
            subtitle: const Text('Book-based lessons in the Learn tab'),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: Haptics.tap(() => context.go('/learn')),
          ),
        ),
        Card(
          child: ListTile(
            leading: const Icon(Icons.storefront_rounded),
            title: Text('${d.label} items in Market'),
            subtitle: const Text('SAMPLE demo listings'),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: Haptics.tap(() => context.go('/market')),
          ),
        ),
      ]),
    );
  }
}

/// Decrypts and shows the user's own open-text reflection for one attempt.
class _Reflection extends ConsumerWidget {
  const _Reflection({required this.attempt});
  final DimAttempt attempt;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = Theme.of(context);
    return FutureBuilder<String?>(
      future: ref.read(assessmentProvider.notifier).attemptReflection(attempt),
      builder: (_, snap) {
        if (snap.connectionState != ConnectionState.done) return const LinearProgressIndicator();
        final text = snap.data;
        return Text(
          text == null || text.isEmpty ? 'No reflection saved for this attempt.' : '“$text”',
          style: text == null ? t.textTheme.bodyMedium?.copyWith(fontStyle: FontStyle.italic) : t.textTheme.bodyLarge,
        );
      },
    );
  }
}
