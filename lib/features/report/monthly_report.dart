import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/services/haptics.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/fx.dart';
import '../plus/entitlement.dart';
import '../plus/plus_ui.dart';
import '../ritual/ritual.dart';
import 'report_screen.dart' show weekLabel;
import 'weekly_report.dart';

const _months = ['January', 'February', 'March', 'April', 'May', 'June', 'July', 'August', 'September', 'October', 'November', 'December'];

/// Aggregate of the stored weekly reports whose week starts in [month]. Counts only; no clinical meaning.
class MonthlyReport {
  const MonthlyReport({
    required this.month,
    required this.weeks,
    this.ritualsDone = 0,
    this.checkIns = 0,
    this.bestStreak = 0,
    this.moods = const {},
    this.active = const {},
    this.lessons = 0,
    this.games = 0,
    this.scoreChanges = const {},
  });
  final DateTime month;
  final int weeks, ritualsDone, checkIns, bestStreak, lessons, games;
  final Map<Mood, int> moods;
  final Map<WellnessDimension, int> active;
  final Map<WellnessDimension, int> scoreChanges;
  String get label => '${_months[month.month - 1]} ${month.year}';
  bool get isEmpty => checkIns == 0 && ritualsDone == 0 && active.isEmpty && scoreChanges.isEmpty;
}

MonthlyReport buildMonthlyReport(DateTime month, List<WeeklyReport> all) {
  final ws = all.where((w) => w.weekStart.year == month.year && w.weekStart.month == month.month).toList()
    ..sort((a, b) => a.weekStart.compareTo(b.weekStart));
  final moods = <Mood, int>{}, active = <WellnessDimension, int>{}, changes = <WellnessDimension, int>{};
  var r = 0, c = 0, s = 0, l = 0, g = 0;
  for (final w in ws) {
    r += w.ritualsDone;
    c += w.checkIns;
    l += w.lessons;
    g += w.games;
    if (w.streak > s) s = w.streak;
    for (final m in w.moods) {
      if (m != null) moods[m] = (moods[m] ?? 0) + 1;
    }
    for (final e in w.active.entries) {
      active[e.key] = (active[e.key] ?? 0) + e.value;
    }
    for (final e in w.scoreChanges.entries) {
      changes[e.key] = (changes[e.key] ?? 0) + e.value;
    }
  }
  final sorted = Map.fromEntries(active.entries.toList()..sort((a, b) => b.value.compareTo(a.value)));
  return MonthlyReport(
      month: DateTime(month.year, month.month),
      weeks: ws.length,
      ritualsDone: r,
      checkIns: c,
      bestStreak: s,
      moods: moods,
      active: sorted,
      lessons: l,
      games: g,
      scoreChanges: changes);
}

/// Months covered by the stored weekly reports, newest first.
List<MonthlyReport> monthlyReports(List<WeeklyReport> weeks) {
  final keys = <DateTime>{for (final w in weeks) DateTime(w.weekStart.year, w.weekStart.month)}.toList()..sort((a, b) => b.compareTo(a));
  return [for (final m in keys) buildMonthlyReport(m, weeks)];
}

class ReportsDashboard extends ConsumerStatefulWidget {
  const ReportsDashboard({super.key, this.monthly = false});
  final bool monthly;
  @override
  ConsumerState<ReportsDashboard> createState() => _ReportsDashboardState();
}

class _ReportsDashboardState extends ConsumerState<ReportsDashboard> {
  late bool _monthly = widget.monthly;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) ref.read(reportsProvider.notifier).refresh();
    });
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final s = ref.watch(reportsProvider);
    final plus = ref.watch(isPlusProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Reports')),
      body: ListView(key: const Key('reports-dashboard'), padding: const EdgeInsets.all(16), children: [
        SegmentedButton<bool>(
          key: const Key('reports-toggle'),
          segments: [
            const ButtonSegment(value: false, label: Text('Weekly'), icon: Icon(Icons.view_week_rounded)),
            ButtonSegment(
                value: true, label: const Text('Monthly'), icon: Icon(plus ? Icons.calendar_month_rounded : Icons.lock_outline_rounded)),
          ],
          selected: {_monthly},
          onSelectionChanged: Haptics.pick((v) => setState(() => _monthly = v.first)),
        ),
        const SizedBox(height: 12),
        if (s.reports.isEmpty)
          const Card(child: ListTile(title: Text('Your first report appears on Sunday.')))
        else if (!_monthly)
          for (final (i, r) in s.reports.indexed)
            if (i >= freeReportWeeks && !plus)
              Card(
                child: ListTile(
                  key: Key('dash-week-${r.id}'),
                  leading: const Icon(Icons.lock_outline_rounded),
                  title: Text(weekLabel(r)),
                  subtitle: const Text('Kept for you · open with OneUP Plus'),
                  trailing: const PlusBadge(small: true),
                  onTap: () => showPlusUpsell(context, PlusFeature.reportHistory),
                ),
              )
            else
              Card(
                child: ListTile(
                  key: Key('dash-week-${r.id}'),
                  leading: const Icon(Icons.calendar_view_week_rounded),
                  title: Text(weekLabel(r)),
                  subtitle:
                      Text(r.isEmpty ? 'A quiet week' : '${r.ritualsDone} small steps · ${r.checkIns} check-ins · ${r.streak}-day streak'),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: Haptics.tap(() => context.push('/report?week=${r.id}')),
                ),
              )
        else if (!plus)
          const PlusLockCard(
              feature: PlusFeature.reportDashboard,
              message: 'Monthly reports add up your weeks: small steps, check-ins, moods, most active areas and score changes. '
                  'Your latest 2 weekly reports stay free.')
        else
          for (final m in monthlyReports(s.reports)) _MonthCard(m),
        const SizedBox(height: 8),
        Text(reportDisclaimer, style: t.textTheme.bodySmall),
      ]),
    );
  }
}

class _MonthCard extends StatelessWidget {
  const _MonthCard(this.m);
  final MonthlyReport m;
  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    Widget stat(String n, String l) => Expanded(
          child: Column(children: [
            Text(n, style: t.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800)),
            Text(l, textAlign: TextAlign.center, style: t.textTheme.bodySmall),
          ]),
        );
    final moodTotal = m.moods.values.fold(0, (a, b) => a + b);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: GlassCard(
        key: Key('month-${m.month.year}-${m.month.month}'),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(m.label, style: t.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
          Text('${m.weeks} week${m.weeks == 1 ? '' : 's'} of reports', style: t.textTheme.bodySmall),
          const SizedBox(height: 12),
          if (m.isEmpty)
            const Text('A quiet month. Whenever you are ready, one small step is enough.')
          else ...[
            Row(children: [
              stat('${m.ritualsDone}', 'small steps'),
              stat('${m.checkIns}', 'check-ins'),
              stat('${m.bestStreak}', 'best streak'),
              stat('${m.lessons + m.games}', 'lessons + games'),
            ]),
            if (moodTotal > 0) ...[
              const SizedBox(height: 12),
              Text('Moods', style: t.textTheme.labelLarge),
              const SizedBox(height: 6),
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: Row(children: [
                  for (final mo in Mood.values)
                    if ((m.moods[mo] ?? 0) > 0) Expanded(flex: m.moods[mo]!, child: Container(height: 12, color: mo.color)),
                ]),
              ),
              const SizedBox(height: 4),
              Wrap(spacing: 10, children: [
                for (final mo in Mood.values)
                  if ((m.moods[mo] ?? 0) > 0) Text('${mo.label} ${m.moods[mo]}', style: t.textTheme.bodySmall?.copyWith(color: mo.color)),
              ]),
            ],
            if (m.active.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text('Most active', style: t.textTheme.labelLarge),
              const SizedBox(height: 4),
              Wrap(spacing: 6, runSpacing: 6, children: [
                for (final e in m.active.entries.take(3))
                  Chip(
                      visualDensity: VisualDensity.compact,
                      avatar: Icon(e.key.icon, size: 16, color: e.key.color(t.brightness)),
                      label: Text('${e.key.label} ${e.value}')),
              ]),
            ],
            if (m.scoreChanges.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text('Score changes: ${m.scoreChanges.entries.map((e) => '${e.key.label} ${e.value >= 0 ? '+' : ''}${e.value}').join(' · ')}',
                  style: t.textTheme.bodySmall),
            ],
          ],
        ]),
      ),
    );
  }
}
