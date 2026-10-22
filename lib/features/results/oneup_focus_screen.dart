import 'package:flutter/material.dart';
import '../../core/widgets/fx.dart';
import '../../core/services/haptics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';
import '../assess/assess_page.dart' show openDimension;
import '../assess/domain/assessment_controller.dart';
import '../assess/domain/focus.dart';
import '../consent/consent_screen.dart' show kDisclaimer;
import '../consult/domain/consult_logic.dart';
import '../../core/safety/safety_state.dart';
import '../assess/domain/history.dart' show shouldEscalate;
import '../companion/data/playbook.dart';
import '../companion/ui/companion_button.dart';

class OneUpFocusScreen extends ConsumerWidget {
  const OneUpFocusScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(assessmentProvider);
    final t = Theme.of(context);
    final items = rankFocus(s.latest, s.goals);
    return Scaffold(
      floatingActionButton: const CompanionButton(),
      appBar: AppBar(title: const Text('Your OneUP Focus')),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(gradient: AppColors.brandGradient, borderRadius: BorderRadius.circular(24)),
          child: Text(
            items.isEmpty
                ? 'Complete at least one dimension to see where a small step could help most.'
                : 'Here are the areas where a small step could make the biggest difference for you right now.',
            style: t.textTheme.titleMedium?.copyWith(color: Colors.white),
          ),
        ),
        const SizedBox(height: 16),
        for (var i = 0; i < items.length; i++) _FocusCard(rank: i + 1, item: items[i]),
        const SizedBox(height: 8),
        Text(
          'Ranking: areas in "Needs Attention" come first, then the largest gap between your score and your goal '
          '(or $kDefaultTarget if no goal is set).',
          style: t.textTheme.bodySmall,
        ),
        const SizedBox(height: 8),
        Text(kDisclaimer, style: t.textTheme.bodySmall?.copyWith(fontStyle: FontStyle.italic)),
      ]),
    );
  }
}

class _FocusCard extends ConsumerWidget {
  const _FocusCard({required this.rank, required this.item});
  final int rank;
  final FocusItem item;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = Theme.of(context);
    final d = item.dimension;
    final color = d.color(t.brightness);
    final crisis = ref.watch(crisisModeProvider);
    final gapText = item.gap > 0
        ? '${item.gap} points to ${item.hasGoal ? 'your goal' : 'target'} (${item.target})'
        : 'At or above ${item.hasGoal ? 'your goal' : 'target'} (${item.target})';
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            CircleAvatar(backgroundColor: color, foregroundColor: Colors.white, child: Text('$rank')),
            const SizedBox(width: 12),
            Icon(d.icon, color: color),
            const SizedBox(width: 6),
            Expanded(child: Text(d.label, style: t.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700))),
            AnimatedScore(item.score, style: t.textTheme.headlineSmall?.copyWith(color: color, fontWeight: FontWeight.w800)),
          ]),
          const SizedBox(height: 8),
          Wrap(spacing: 8, runSpacing: 4, children: [
            Chip(label: Text(item.band.label), backgroundColor: color.withOpacity(0.15)),
            Chip(label: Text(gapText)),
          ]),
          const SizedBox(height: 4),
          Text(item.band.guidance, style: t.textTheme.bodyMedium),
          const SizedBox(height: 8),
          if (!crisis) ...[
            Text('Small things to try', style: t.textTheme.labelLarge),
            const SizedBox(height: 4),
            for (final tip in kPlaybook[d]!)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Icon(Icons.check_circle_outline_rounded, size: 18, color: color),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text.rich(
                        TextSpan(children: [
                          TextSpan(
                              text: '${tip[0].toUpperCase()}${tip.substring(1)}: ', style: const TextStyle(fontWeight: FontWeight.w700)),
                          TextSpan(text: kSkillHowTo[tip]),
                        ]),
                        style: t.textTheme.bodySmall),
                  ),
                ]),
              ),
            const SizedBox(height: 8),
          ],
          FilledButton.tonalIcon(
            onPressed: Haptics.tap(() => openDimension(context, ref, d)),
            icon: const Icon(Icons.replay_rounded),
            label: const Text('Retake this dimension'),
          ),
          Row(children: [
            TextButton(
              onPressed: Haptics.tap(() => context.push('/results/dim/${d.name}')),
              child: const Text('View details'),
            ),
            const Spacer(),
            // Escalation only when Needs Attention persisted in 2+ attempts (spec).
            if (!crisis && shouldEscalate(ref.watch(assessmentProvider).attempts, d))
              TextButton.icon(
                onPressed: Haptics.tap(() => context.go('/consult?type=${typesForDimension(d).first.name}')),
                icon: const Icon(Icons.support_agent_rounded),
                label: const Text('Ask an expert'),
              ),
          ]),
        ]),
      ),
    );
  }
}
