import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/services/haptics.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/fx.dart';
import 'report_screen.dart';
import 'weekly_report.dart';

/// Home card: "Your week is ready" on Sunday; last week's report stays available until the next one.
/// Hidden when there is no report yet, or last week was empty and it's not Sunday.
class WeeklyReportCard extends ConsumerWidget {
  const WeeklyReportCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(reportsProvider);
    final r = s.latest;
    final now = ref.read(reportsProvider.notifier).now();
    final sunday = now.weekday == DateTime.sunday;
    if (r == null || r.weekStart != currentReportWeek(now) || (r.isEmpty && !sunday)) return const SizedBox.shrink();
    final t = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: PressScale(
        key: const Key('home-weekly-report'),
        semanticLabel: '${sunday ? 'Your week is ready' : "Last week's report"}. ${weekLabel(r)}',
        onTap: Haptics.tap(() => context.push('/report')),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(gradient: AppColors.brandGradient, borderRadius: BorderRadius.circular(24)),
          child: Row(children: [
            Stack(clipBehavior: Clip.none, children: [
              CircleAvatar(
                  radius: 24,
                  backgroundColor: Colors.white.withOpacity(0.2),
                  child: const Icon(Icons.auto_stories_rounded, color: Colors.white)),
              if (s.unseen)
                Positioned(
                    right: -2,
                    top: -2,
                    child: Container(
                        key: const Key('report-unseen-dot'),
                        width: 12,
                        height: 12,
                        decoration: const BoxDecoration(color: Color(0xFFFFD54F), shape: BoxShape.circle))),
            ]),
            const SizedBox(width: 14),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(sunday ? 'Your week is ready' : "Last week's report",
                    style: t.textTheme.titleMedium?.copyWith(color: Colors.white, fontWeight: FontWeight.w800)),
                const SizedBox(height: 2),
                Text(
                    r.isEmpty
                        ? '${weekLabel(r)} · a quiet week'
                        : '${weekLabel(r)} · ${r.ritualsDone} small steps · ${r.checkIns} check-ins',
                    style: t.textTheme.bodySmall?.copyWith(color: Colors.white.withOpacity(0.9))),
              ]),
            ),
            const Icon(Icons.chevron_right_rounded, color: Colors.white),
          ]),
        ),
      ),
    );
  }
}
