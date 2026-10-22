import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

/// Original OneUp mark: 8 coloured arcs (the 8 dimensions) forming a ring,
/// with an upward chevron in the centre ("one up"). [progress] 0..1 animates it.
class OneUpLogo extends StatelessWidget {
  const OneUpLogo({super.key, this.size = 120, this.progress = 1});
  final double size;
  final double progress;

  @override
  Widget build(BuildContext context) => Semantics(
        label: 'OneUp logo',
        child: CustomPaint(size: Size.square(size), painter: _LogoPainter(progress)),
      );
}

class _LogoPainter extends CustomPainter {
  _LogoPainter(this.p);
  final double p;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final stroke = size.width * 0.09;
    final r = size.width / 2 - stroke / 2;
    final rect = Rect.fromCircle(center: c, radius: r);
    const n = 8;
    const gap = 0.10;
    const seg = 2 * math.pi / n;
    for (var i = 0; i < n; i++) {
      final local = ((p * n) - i).clamp(0.0, 1.0);
      if (local <= 0) continue;
      final paint = Paint()
        ..color = WellnessDimension.values[i].light
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..strokeCap = StrokeCap.round;
      canvas.drawArc(rect, -math.pi / 2 + i * seg + gap / 2, (seg - gap) * local, false, paint);
    }
    // Upward chevron rising into place.
    final t = Curves.easeOutBack.transform(((p - 0.5) * 2).clamp(0.0, 1.0));
    if (t > 0) {
      final w = size.width * 0.34;
      final lift = (1 - t) * size.height * 0.15;
      final path = Path()
        ..moveTo(c.dx - w / 2, c.dy + w * 0.25 + lift)
        ..lineTo(c.dx, c.dy - w * 0.25 + lift)
        ..lineTo(c.dx + w / 2, c.dy + w * 0.25 + lift);
      final paint = Paint()
        ..shader = AppColors.brandGradient.createShader(rect)
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke * 1.2
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round;
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(_LogoPainter old) => old.p != p;
}
