import 'dart:math' as math;
import '../../core/widgets/fx.dart';
import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';

class RadarSeries {
  const RadarSeries(this.label, this.color, this.values, {this.dashed = false});
  final String label;
  final Color color;
  final Map<WellnessDimension, int> values;
  final bool dashed;
}

/// Radar chart in the style of the reference: alternating grey rings (0–100),
/// 8 axes with labels, one polyline per series. Missing values plot at 0.
class RadarChart extends StatelessWidget {
  const RadarChart({super.key, required this.series, this.size = 320});
  final List<RadarSeries> series;
  final double size;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    return Column(children: [
      RepaintBoundary(
        child: TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: 1),
          duration: motion(context, const Duration(milliseconds: 900)),
          curve: Curves.easeOutCubic,
          builder: (_, p, __) => CustomPaint(
            size: Size.square(size),
            painter:
                _RadarPainter(series, p, t.colorScheme.onSurface, t.brightness, MediaQuery.textScalerOf(context).scale(1).clamp(1.0, 1.3)),
          ),
        ),
      ),
      const SizedBox(height: 12),
      Wrap(spacing: 16, runSpacing: 8, alignment: WrapAlignment.center, children: [
        for (final s in series)
          Row(mainAxisSize: MainAxisSize.min, children: [
            Container(width: 14, height: 14, decoration: BoxDecoration(color: s.color, borderRadius: BorderRadius.circular(4))),
            const SizedBox(width: 6),
            Text(s.label, style: t.textTheme.bodySmall),
          ]),
      ]),
    ]);
  }
}

class _RadarPainter extends CustomPainter {
  _RadarPainter(this.series, this.p, this.ink, this.b, this.scale);
  final List<RadarSeries> series;
  final double p;
  final Color ink;
  final Brightness b;
  final double scale;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.width / 2 - 34 * scale;
    const n = 8;
    Offset pt(int i, double v) {
      final a = -math.pi / 2 + i * 2 * math.pi / n;
      return c + Offset(math.cos(a), math.sin(a)) * (r * v / 100);
    }

    for (var k = 5; k >= 1; k--) {
      canvas.drawCircle(c, r * k / 5, Paint()..color = (k.isOdd ? ink.withOpacity(0.10) : ink.withOpacity(0.04)));
    }
    final axis = Paint()
      ..color = ink.withOpacity(0.25)
      ..strokeWidth = 1;
    for (var i = 0; i < n; i++) {
      canvas.drawLine(c, pt(i, 100), axis);
      final d = WellnessDimension.values[i];
      final tp = TextPainter(
        text: TextSpan(text: d.label, style: TextStyle(fontSize: 10 * scale, fontWeight: FontWeight.w600, color: d.color(b))),
        textDirection: TextDirection.ltr,
      )..layout();
      final lp = pt(i, 100 + 16 * scale * 100 / r);
      tp.paint(canvas, lp - Offset(tp.width / 2, tp.height / 2));
    }
    for (var k = 1; k <= 5; k++) {
      final tp = TextPainter(
        text: TextSpan(text: '${k * 20}', style: TextStyle(fontSize: 8 * scale, color: ink.withOpacity(0.5))),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, c - Offset(tp.width / 2, r * k / 5 + tp.height - 2));
    }
    for (final s in series) {
      if (s.values.isEmpty) continue;
      final path = Path();
      for (var i = 0; i < n; i++) {
        final v = (s.values[WellnessDimension.values[i]] ?? 0) * p;
        final o = pt(i, v);
        i == 0 ? path.moveTo(o.dx, o.dy) : path.lineTo(o.dx, o.dy);
      }
      path.close();
      canvas.drawPath(path, Paint()..color = s.color.withOpacity(0.10));
      final stroke = Paint()
        ..color = s.color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5
        ..strokeJoin = StrokeJoin.round;
      canvas.drawPath(s.dashed ? _dash(path) : path, stroke);
    }
  }

  Path _dash(Path src) {
    final out = Path();
    for (final m in src.computeMetrics()) {
      for (double d = 0; d < m.length; d += 12) {
        out.addPath(m.extractPath(d, math.min(d + 7, m.length)), Offset.zero);
      }
    }
    return out;
  }

  @override
  bool shouldRepaint(_RadarPainter o) => o.p != p || o.series != series || o.b != b;
}
