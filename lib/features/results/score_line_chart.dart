import 'package:flutter/material.dart';
import '../../core/widgets/fx.dart';
import '../assess/data/assessment_models.dart';

/// Score history (0–100) for one dimension, with band guides at 40/70 and optional goal line.
class ScoreLineChart extends StatelessWidget {
  const ScoreLineChart({super.key, required this.history, required this.color, this.goal, this.height = 180});
  final List<DimAttempt> history; // oldest → newest
  final Color color;
  final int? goal;
  final double height;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    if (history.isEmpty) {
      return SizedBox(height: height, child: const Center(child: Text('No attempts yet')));
    }
    return Semantics(
      label: 'Score history: ${history.map((h) => h.score).join(', ')}${goal == null ? '' : '. Goal $goal'}',
      child: RepaintBoundary(
        child: TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: 1),
          duration: motion(context, const Duration(milliseconds: 800)),
          curve: Curves.easeOutCubic,
          builder: (_, p, __) => CustomPaint(
            size: Size(double.infinity, height),
            painter: _LinePainter(history.map((h) => h.score).toList(), color, goal, p, t.colorScheme.onSurface),
          ),
        ),
      ),
    );
  }
}

class _LinePainter extends CustomPainter {
  _LinePainter(this.v, this.color, this.goal, this.p, this.ink);
  final List<int> v;
  final Color color;
  final int? goal;
  final double p;
  final Color ink;

  @override
  void paint(Canvas canvas, Size size) {
    const padL = 28.0, padB = 8.0, padT = 8.0, padR = 12.0;
    final w = size.width - padL - padR, h = size.height - padT - padB;
    double y(num s) => padT + h * (1 - s / 100);
    double x(int i) => padL + (v.length == 1 ? w / 2 : w * i / (v.length - 1));
    final guide = Paint()
      ..color = ink.withOpacity(0.15)
      ..strokeWidth = 1;
    for (final g in [0, 40, 70, 100]) {
      canvas.drawLine(Offset(padL, y(g)), Offset(size.width - padR, y(g)), guide);
      final tp = TextPainter(
        text: TextSpan(text: '$g', style: TextStyle(fontSize: 9, color: ink.withOpacity(0.5))),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(0, y(g) - tp.height / 2));
    }
    if (goal != null) {
      final gp = Paint()
        ..color = ink.withOpacity(0.6)
        ..strokeWidth = 1.5;
      for (double d = padL; d < size.width - padR; d += 10) {
        canvas.drawLine(Offset(d, y(goal!)), Offset(d + 5, y(goal!)), gp);
      }
    }
    final path = Path();
    for (var i = 0; i < v.length; i++) {
      final o = Offset(x(i), y(v[i] * p));
      i == 0 ? path.moveTo(o.dx, o.dy) : path.lineTo(o.dx, o.dy);
    }
    canvas.drawPath(
        path,
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3
          ..strokeJoin = StrokeJoin.round);
    for (var i = 0; i < v.length; i++) {
      final o = Offset(x(i), y(v[i] * p));
      canvas.drawCircle(o, 5, Paint()..color = color);
      canvas.drawCircle(o, 2.5, Paint()..color = Colors.white);
    }
  }

  @override
  bool shouldRepaint(_LinePainter o) => o.p != p || o.v != v || o.goal != goal || o.color != color;
}
