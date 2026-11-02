import '../experts/experts.dart';
import 'package:flutter/material.dart';
import '../../core/widgets/fx.dart';
import '../../core/services/haptics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';
import '../assess/domain/assessment_controller.dart';
import '../assess/domain/scoring.dart';
import 'oneup_button.dart';
import 'wellness_wheel.dart';

class ResultsScreen extends ConsumerWidget {
  const ResultsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(assessmentProvider);
    final t = Theme.of(context);
    final latest = s.latest;
    return Scaffold(
      appBar: AppBar(title: const Text('Your wellness wheel'), actions: [
        IconButton(tooltip: 'Trends', onPressed: Haptics.tap(() => context.push('/trends')), icon: const Icon(Icons.insights_rounded)),
      ]),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        const Center(child: ReviewedBadge()),
        const SizedBox(height: 8),
        Center(
          child: LayoutBuilder(
            builder: (_, c) => Hero(
              tag: 'wellness-wheel',
              child: WellnessWheel(
                scores: latest,
                overall: s.overall,
                size: c.maxWidth.clamp(240, 560),
                onTapDimension: Haptics.pick((d) => context.push('/results/dim/${d.name}')),
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(s.overall == null ? '${latest.length} of 8 dimensions have a score' : 'Tap a segment for details',
            textAlign: TextAlign.center, style: t.textTheme.bodyMedium),
        const SizedBox(height: 16),
        const OneUpButton(),
        const SizedBox(height: 16),
        for (final d in WellnessDimension.values)
          StaggerIn(
              index: d.index,
              child: Card(
                child: ListTile(
                  leading: CircleAvatar(backgroundColor: d.color(t.brightness), foregroundColor: Colors.white, child: Icon(d.icon)),
                  title: Text(d.label),
                  subtitle: Text(latest[d] == null ? 'Not assessed yet' : bandFor(latest[d]!).label),
                  trailing: latest[d] == null
                      ? Text('—', style: t.textTheme.titleLarge)
                      : AnimatedScore(latest[d]!, style: t.textTheme.titleLarge),
                  onTap: Haptics.tap(() => context.push('/results/dim/${d.name}')),
                ),
              )),
      ]),
    );
  }
}
