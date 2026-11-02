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
import '../assess/data/assessment_models.dart';
import '../plus/entitlement.dart';
import '../plus/plus_ui.dart';

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
        Row(children: [Text('Change over time', style: t.textTheme.titleMedium), const SizedBox(width: 8), const PlusBadge(small: true)]),
        const SizedBox(height: 8),
        if (ref.watch(isPlusProvider))
          ChangeOverTimeCard(attempts: s.attempts)
        else
          const PlusLockCard(
              feature: PlusFeature.advancedTrends,
              message: 'See how each dimension has moved from your first check-in to your latest, with your number of check-ins. '
                  'Your wheel, goals and full history below stay free.'),
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

/// Plus: first vs latest score per dimension, from the user's own check-ins. Descriptive only.
class ChangeOverTimeCard extends StatelessWidget {
  const ChangeOverTimeCard({super.key, required this.attempts});
  final List<DimAttempt> attempts; // newest first
  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final rows = <Widget>[];
    for (final d in WellnessDimension.values) {
      final a = attempts.where((x) => x.dimension == d).toList();
      if (a.isEmpty) continue;
      final first = a.last.score, last = a.first.score, delta = last - first;
      rows.add(ListTile(
        key: Key('change-${d.name}'),
        dense: true,
        leading: Icon(d.icon, color: d.color(t.brightness)),
        title: Text(d.label),
        subtitle: Text(a.length == 1 ? '1 check-in · check in again to see change' : '${a.length} check-ins · $first → $last'),
        trailing: a.length == 1
            ? const Text('—')
            : Text(delta == 0 ? '±0' : (delta > 0 ? '+$delta' : '$delta'),
                style: t.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800, color: delta > 0 ? Colors.green : null)),
      ));
    }
    return Card(
      key: const Key('trends-change'),
      child: Column(children: [
        if (rows.isEmpty) const ListTile(title: Text('No completed check-ins yet')) else ...rows,
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          child: Text('A description of your own answers over time, not a diagnosis.', style: t.textTheme.bodySmall),
        ),
      ]),
    );
  }
}
