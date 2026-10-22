import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../assess/domain/assessment_controller.dart';
import 'oneup_button.dart';
import 'paradigm_radar.dart';

/// Full-screen radar in the style of the reference: grey rings 0–100 (labels every 10),
/// 8 spokes, pill-chip dimension labels, Current / Desired / Previous lines with legend.
class CircleParadigmScreen extends ConsumerWidget {
  const CircleParadigmScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(assessmentProvider);
    final t = Theme.of(context);
    final missing = WellnessDimension.values.where((d) => !s.latest.containsKey(d)).toList();
    final legend = Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
      ParadigmLegend(current: s.latest, goals: s.goals, previous: s.previous),
      if (missing.isNotEmpty)
        Padding(
          padding: const EdgeInsets.all(8),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 260),
            child: Text('Not completed yet (shown as 0): ${missing.map((d) => d.label).join(', ')}', style: t.textTheme.bodySmall),
          ),
        ),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        child: Text('Dashed rings mark 40 and 70. Tap a dot to see its score.', style: t.textTheme.bodySmall),
      ),
      if (s.goals.isEmpty)
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Text('Set goals in Trends to draw your Desired State.', style: t.textTheme.bodySmall),
        ),
      const SizedBox(height: 12),
      const OneUpButton(),
    ]);
    return Scaffold(
      appBar: AppBar(title: const Text('Circle Paradigm')),
      body: SafeArea(
        child: LayoutBuilder(builder: (_, c) {
          final landscape = c.maxWidth > c.maxHeight;
          final chartSize = landscape ? math.min(c.maxHeight - 16, c.maxWidth * 0.62) : math.min(c.maxWidth, c.maxHeight * 0.62);
          final chart = ParadigmRadar(size: chartSize, current: s.latest, goals: s.goals, previous: s.previous);
          return landscape
              ? Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [chart, legend])
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(8),
                  child: Column(children: [chart, const SizedBox(height: 8), legend]),
                );
        }),
      ),
    );
  }
}
