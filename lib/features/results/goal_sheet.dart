import 'package:flutter/material.dart';
import '../../core/services/haptics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_colors.dart';
import '../assess/domain/assessment_controller.dart';

Future<void> showGoalSheet(BuildContext context, WidgetRef ref, WellnessDimension d) async {
  final s = ref.read(assessmentProvider);
  var value = (s.goals[d] ?? ((s.latest[d] ?? 50) + 10).clamp(0, 100)).toDouble();
  final color = d.color(Theme.of(context).brightness);
  await showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (c) => StatefulBuilder(
      builder: (c, set) => Padding(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text('${d.label} goal', style: Theme.of(c).textTheme.titleLarge),
          const SizedBox(height: 8),
          Text('${value.round()}',
              textAlign: TextAlign.center, style: Theme.of(c).textTheme.displaySmall?.copyWith(color: color, fontWeight: FontWeight.w800)),
          Slider(
            value: value,
            max: 100,
            divisions: 20,
            label: '${value.round()}',
            activeColor: color,
            semanticFormatterCallback: (v) => 'Goal ${v.round()}',
            onChanged: (v) {
              if (v.round() != value.round()) Haptics.selection(); // tick per step
              set(() => value = v);
            },
          ),
          const SizedBox(height: 8),
          Row(children: [
            if (s.goals[d] != null)
              Expanded(
                child: OutlinedButton(
                  onPressed: Haptics.tap(() {
                    ref.read(assessmentProvider.notifier).setGoal(d, null);
                    Navigator.pop(c);
                  }),
                  child: const Text('Clear'),
                ),
              ),
            if (s.goals[d] != null) const SizedBox(width: 12),
            Expanded(
              child: FilledButton(
                onPressed: Haptics.tap(() {
                  Haptics.success();
                  ref.read(assessmentProvider.notifier).setGoal(d, value.round());
                  Navigator.pop(c);
                }),
                child: const Text('Save goal'),
              ),
            ),
          ]),
        ]),
      ),
    ),
  );
}
