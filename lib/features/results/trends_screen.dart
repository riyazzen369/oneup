import 'package:flutter/material.dart';
import '../../core/widgets/fx.dart';
import '../../core/services/haptics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';
import '../assess/domain/assessment_controller.dart';
import 'dimension_detail_screen.dart' show fmtDate;
import 'goal_sheet.dart';
import 'paradigm_radar.dart';

class TrendsScreen extends ConsumerWidget {
  const TrendsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(assessmentProvider);
    final t = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Trends')),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        LayoutBuilder(
          builder: (_, c) => Center(
            child: ParadigmRadar(size: c.maxWidth.clamp(240.0, 560.0), current: s.latest, goals: s.goals, previous: s.previous),
          ),
        ),
        const SizedBox(height: 8),
        Align(alignment: Alignment.centerLeft, child: ParadigmLegend(current: s.latest, goals: s.goals, previous: s.previous)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          child: Text('Dashed rings mark 40 and 70. Tap a dot to see its score.', style: t.textTheme.bodySmall),
        ),
        const SizedBox(height: 16),
        Text('Goals', style: t.textTheme.titleMedium),
        const SizedBox(height: 8),
        Card(
          child: Column(children: [
            for (final d in WellnessDimension.values)
              ListTile(
                leading: Icon(d.icon, color: d.color(t.brightness)),
                title: Text(d.label),
                subtitle: Text('Now ${s.latest[d] ?? '—'} · Previous ${s.previous[d] ?? '—'}'),
                trailing: Text(s.goals[d] == null ? 'Set' : 'Goal ${s.goals[d]}',
                    style: TextStyle(color: t.colorScheme.primary, fontWeight: FontWeight.w600)),
                onTap: Haptics.tap(() => showGoalSheet(context, ref, d)),
              ),
          ]),
        ),
        const SizedBox(height: 16),
        Text('History', style: t.textTheme.titleMedium),
        const SizedBox(height: 8),
        if (s.attempts.isEmpty) const Card(child: ListTile(title: Text('No completed check-ins yet'))),
        for (final a in s.attempts)
          StaggerIn(
              index: s.attempts.indexOf(a).clamp(0, 10),
              child: Card(
                child: ListTile(
                  leading: CircleAvatar(
                      backgroundColor: a.dimension.color(t.brightness), foregroundColor: Colors.white, child: Icon(a.dimension.icon)),
                  title: Text(a.dimension.label),
                  subtitle: Text(fmtDate(a.completedAt)),
                  trailing: Text('${a.score}', style: t.textTheme.titleLarge),
                  onTap: Haptics.tap(() => context.push('/results/dim/${a.dimension.name}')),
                ),
              )),
      ]),
    );
  }
}
