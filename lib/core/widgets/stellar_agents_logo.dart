import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Hand-drawn vector recreation of the Stellar Agents wheel mark (not the original artwork):
/// a ring of 12 boxy modules joined by segmented links, 6 panelled spokes and a concentric hub,
/// thin outline strokes in a teal → blue → purple gradient.
class StellarWheelPainter extends CustomPainter {
  const StellarWheelPainter();
  static const teal = Color(0xFF34E3C6);
  static const blue = Color(0xFF3B7BD8);
  static const purple = Color(0xFF7A45F0);

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.shortestSide;
    final c = size.center(Offset.zero);
    final rect = Rect.fromCircle(center: c, radius: s / 2);
    final shader = const LinearGradient(
      begin: Alignment.topRight,
      end: Alignment.bottomLeft,
      colors: [teal, Color(0xFF2FB0C8), blue, purple],
      stops: [0.15, 0.42, 0.62, 0.9],
    ).createShader(rect);
    final line = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(0.8, s * 0.006)
      ..strokeJoin = StrokeJoin.round
      ..color = Colors.white;
    final thin = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(0.5, s * 0.0035)
      ..color = Colors.white;
    final fill = Paint()..color = const Color(0x2EFFFFFF);
    // Draw the mark in white, then tint it with one screen-space gradient (srcIn) so the
    // teal→purple sweep stays fixed across the rotated sub-shapes. Cached by the caller's
    // RepaintBoundary, so this runs once.
    canvas.saveLayer(rect, Paint());

    final ringR = s * 0.37;
    final mod = s * 0.14; // module edge

    // Segmented links between modules (short boxes along the ring).
    for (var i = 0; i < 12; i++) {
      final a0 = 2 * math.pi * i / 12;
      for (final f in [0.32, 0.5, 0.68]) {
        final a = a0 + 2 * math.pi / 12 * f;
        canvas.save();
        canvas.translate(c.dx + ringR * math.cos(a), c.dy + ringR * math.sin(a));
        canvas.rotate(a);
        final r = Rect.fromCenter(center: Offset.zero, width: s * 0.03, height: s * 0.045);
        canvas.drawRect(r, fill);
        canvas.drawRect(r, thin);
        canvas.restore();
      }
    }

    // 6 spokes: long panelled rectangles from hub to ring.
    final hubR = s * 0.085;
    for (var i = 0; i < 6; i++) {
      final a = math.pi * i / 3;
      canvas.save();
      canvas.translate(c.dx, c.dy);
      canvas.rotate(a);
      final x0 = hubR * 1.05, x1 = ringR - mod * 0.55, w = s * 0.05;
      final r = Rect.fromLTRB(x0, -w / 2, x1, w / 2);
      canvas.drawRect(r, fill);
      canvas.drawRect(r, line);
      canvas.drawLine(Offset(x0, 0), Offset(x1, 0), thin);
      for (var k = 1; k < 6; k++) {
        final x = x0 + (x1 - x0) * k / 6;
        canvas.drawLine(Offset(x, -w / 2), Offset(x, w / 2), thin);
      }
      canvas.restore();
    }

    // Hub: concentric circles with a toothed rim.
    canvas.drawCircle(c, hubR * 1.15, fill);
    for (final f in [1.15, 0.92, 0.68, 0.48, 0.3, 0.16]) {
      canvas.drawCircle(c, hubR * f, f == 1.15 ? line : thin);
    }
    for (var k = 0; k < 16; k++) {
      final a = 2 * math.pi * k / 16;
      final d = Offset(math.cos(a), math.sin(a));
      canvas.drawLine(c + d * hubR * 0.92, c + d * hubR * 1.15, thin);
    }

    // 12 cube-like modules with port circles on the outer face.
    for (var i = 0; i < 12; i++) {
      final a = 2 * math.pi * i / 12;
      canvas.save();
      canvas.translate(c.dx + ringR * math.cos(a), c.dy + ringR * math.sin(a));
      canvas.rotate(a + math.pi / 2); // local -y points outward
      final body = Rect.fromCenter(center: Offset(0, mod * 0.08), width: mod, height: mod * 0.84);
      final top = Rect.fromLTWH(body.left, body.top - mod * 0.3, mod, mod * 0.3);
      canvas.drawRect(body, fill);
      canvas.drawRect(body, line);
      canvas.drawRect(top, fill);
      canvas.drawRect(top, line);
      // panel seams
      canvas.drawLine(Offset(0, body.top), Offset(0, body.bottom), thin);
      canvas.drawLine(Offset(body.left, body.center.dy), Offset(body.right, body.center.dy), thin);
      // ports: 2 x 3 small circles on the outer face
      for (var px = 0; px < 3; px++) {
        for (var py = 0; py < 2; py++) {
          canvas.drawCircle(Offset(top.left + mod * (0.2 + 0.3 * px), top.top + top.height * (0.3 + 0.4 * py)), mod * 0.06, thin);
        }
      }
      canvas.restore();
    }
    canvas.drawRect(
        rect,
        Paint()
          ..blendMode = BlendMode.srcIn
          ..shader = shader);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Static faint star field for deep-space backgrounds (deterministic positions).
class StarFieldPainter extends CustomPainter {
  const StarFieldPainter({this.count = 70});
  final int count;
  @override
  void paint(Canvas canvas, Size size) {
    final rnd = math.Random(7);
    final p = Paint();
    for (var i = 0; i < count; i++) {
      final o = Offset(rnd.nextDouble() * size.width, rnd.nextDouble() * size.height);
      final big = rnd.nextDouble() < 0.12;
      p.color = (rnd.nextBool() ? const Color(0xFF9FE8E0) : Colors.white).withOpacity(0.15 + rnd.nextDouble() * 0.35);
      canvas.drawCircle(o, big ? 1.4 : 0.7, p);
      if (big) {
        p.strokeWidth = 0.6;
        canvas.drawLine(o - const Offset(3, 0), o + const Offset(3, 0), p);
        canvas.drawLine(o - const Offset(0, 3), o + const Offset(0, 3), p);
      }
    }
  }

  @override
  bool shouldRepaint(covariant StarFieldPainter oldDelegate) => oldDelegate.count != count;
}

/// The wheel mark. When [turns] is given it rotates as a cached layer (RepaintBoundary),
/// so each frame is only a transform — no repaint.
class StellarWheel extends StatelessWidget {
  const StellarWheel({super.key, required this.size, this.turns});
  final double size;
  final Animation<double>? turns;
  @override
  Widget build(BuildContext context) {
    final wheel = RepaintBoundary(
      child: CustomPaint(size: Size.square(size), isComplex: true, willChange: false, painter: const StellarWheelPainter()),
    );
    return Semantics(
      label: 'Stellar Agents logo',
      image: true,
      child: turns == null ? wheel : RotationTransition(turns: turns!, child: wheel),
    );
  }
}

/// "S T E L L A R" with "A G E N T S" between two thin teal-to-grey rules.
class StellarWordmark extends StatelessWidget {
  const StellarWordmark({super.key, this.width = 240, this.fontFamily});
  final double width;
  final String? fontFamily;
  @override
  Widget build(BuildContext context) {
    final big = width * 0.115;
    Widget rule(bool left) => Expanded(
          child: Container(
            height: 1,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                  colors: left
                      ? const [Color(0x002EC4B6), Color(0xFF2EC4B6), Color(0xFF8A8F98)]
                      : const [Color(0xFF8A8F98), Color(0xFF2EC4B6), Color(0x002EC4B6)]),
            ),
          ),
        );
    return Semantics(
      label: 'Stellar Agents',
      excludeSemantics: true,
      child: SizedBox(
        width: width,
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          FittedBox(
            child: Text('STELLAR',
                style: TextStyle(
                    fontFamily: fontFamily,
                    fontSize: big,
                    fontWeight: FontWeight.w200,
                    letterSpacing: big * 0.9,
                    color: const Color(0xFFB8BCC4))),
          ),
          SizedBox(height: big * 0.25),
          Row(children: [
            rule(true),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: big * 0.5),
              child: Text('AGENTS',
                  style: TextStyle(
                      fontFamily: fontFamily,
                      fontSize: big * 0.42,
                      fontWeight: FontWeight.w300,
                      letterSpacing: big * 0.5,
                      color: const Color(0xFF9EA3AC))),
            ),
            rule(false),
          ]),
        ]),
      ),
    );
  }
}
