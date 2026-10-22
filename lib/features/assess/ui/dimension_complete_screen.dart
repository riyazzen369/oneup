import 'dart:math' as math;
import '../../../core/widgets/fx.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/services/haptics.dart';
import '../../../core/theme/app_colors.dart';
import '../domain/assessment_controller.dart';
import '../domain/scoring.dart';

/// Short celebration + simple score summary (full results wheel comes in a later module).
class DimensionCompleteScreen extends ConsumerStatefulWidget {
  const DimensionCompleteScreen({super.key, required this.dimension, required this.score});
  final WellnessDimension dimension;
  final int score;
  @override
  ConsumerState<DimensionCompleteScreen> createState() => _State();
}

class _State extends ConsumerState<DimensionCompleteScreen> with SingleTickerProviderStateMixin {
  late final _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1400))..forward();

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (reducedMotion(context)) {
      _c.stop();
      _c.value = 1; // show final state, no animation
    }
  }

  @override
  void initState() {
    super.initState();
    Haptics.medium();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final color = widget.dimension.color(t.brightness);
    final band = bandFor(widget.score);
    final done = ref.watch(assessmentProvider).doneCount;
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(children: [
            const Spacer(),
            AnimatedBuilder(
              animation: _c,
              builder: (_, __) => CustomPaint(
                size: const Size.square(200),
                painter: _Burst(Curves.easeOut.transform(_c.value), color),
                child: SizedBox.square(
                  dimension: 200,
                  child: Center(
                    child: Text('${(widget.score * Curves.easeOutCubic.transform(_c.value)).round()}',
                        style: t.textTheme.displayMedium?.copyWith(fontWeight: FontWeight.w800, color: color)),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),
            Text('${widget.dimension.label} complete!', style: t.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            Chip(label: Text(band.label), backgroundColor: color.withOpacity(0.18)),
            const SizedBox(height: 8),
            Text(band.guidance, textAlign: TextAlign.center, style: t.textTheme.bodyLarge),
            const SizedBox(height: 8),
            Text('$done of 8 dimensions done', style: t.textTheme.bodyMedium),
            const Spacer(),
            FilledButton(onPressed: Haptics.tap(() => context.canPop() ? context.pop() : context.go('/assess')), child: const Text('Done')),
            const SizedBox(height: 8),
            OutlinedButton(
              onPressed: Haptics.tap(() => context.pushReplacement('/results/dim/${widget.dimension.name}')),
              child: const Text('See details'),
            ),
          ]),
        ),
      ),
    );
  }
}

class _Burst extends CustomPainter {
  _Burst(this.p, this.color);
  final double p;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.width / 2 - 10;
    canvas.drawArc(
        Rect.fromCircle(center: c, radius: r),
        -math.pi / 2,
        2 * math.pi * p,
        false,
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = 12
          ..strokeCap = StrokeCap.round);
    const dots = WellnessDimension.values;
    for (var i = 0; i < 16; i++) {
      final ang = i * math.pi / 8;
      final d = r + 6 + 24 * p;
      canvas.drawCircle(
          c + Offset(math.cos(ang), math.sin(ang)) * d, 5 * (1 - p * 0.6), Paint()..color = dots[i % 8].light.withOpacity(1 - p * 0.5));
    }
  }

  @override
  bool shouldRepaint(_Burst o) => o.p != p;
}
