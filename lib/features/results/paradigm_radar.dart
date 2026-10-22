import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';

import '../../core/services/haptics.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/fx.dart';

/// Circle Paradigm radar: concentric rings with 40/70 band thresholds, 8 labelled axes
/// (icon + colour), gradient-filled current polygon with glowing stroke, per-dimension
/// vertex dots + values, dashed goal overlay, faint previous line, draw-in animation,
/// tap a vertex to show that dimension's score. [compact] = small Home-card version.
class ParadigmRadar extends StatefulWidget {
  const ParadigmRadar({
    super.key,
    required this.current,
    this.goals = const {},
    this.previous = const {},
    this.size = 320,
    this.compact = false,
    this.fontFamily,
  });
  final Map<WellnessDimension, int> current, goals, previous;
  final double size;
  final bool compact;
  final String? fontFamily;

  static const currentA = AppColors.primary;
  static const currentB = AppColors.secondary;
  static const goal = AppColors.accent;
  static const previousColor = Color(0xFF9AA3C7);

  @override
  State<ParadigmRadar> createState() => _ParadigmRadarState();
}

class _ParadigmRadarState extends State<ParadigmRadar> with SingleTickerProviderStateMixin {
  late final _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1100))..forward();
  WellnessDimension? _sel;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (reducedMotion(context)) {
      _c.stop();
      _c.value = 1;
    }
  }

  @override
  void didUpdateWidget(ParadigmRadar old) {
    super.didUpdateWidget(old);
    if (old.current.toString() != widget.current.toString() && !reducedMotion(context)) _c.forward(from: 0);
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  void _tap(Offset local) {
    final g = RadarGeometry(Size.square(widget.size), compact: false, scale: _scale(context));
    WellnessDimension? best;
    var bestD = double.infinity;
    for (final d in WellnessDimension.values) {
      final p = g.point(d.index, (widget.current[d] ?? 0).toDouble());
      final dist = (p - local).distance;
      if (dist < bestD) {
        bestD = dist;
        best = d;
      }
    }
    if (best != null && bestD < 36) {
      Haptics.selection();
      setState(() => _sel = _sel == best ? null : best);
    } else if (_sel != null) {
      setState(() => _sel = null);
    }
  }

  double _scale(BuildContext c) => MediaQuery.textScalerOf(c).scale(1).clamp(1.0, 1.3);

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    RadarPainter painter(double p) => RadarPainter(
          current: widget.current,
          goals: widget.goals,
          previous: widget.previous,
          progress: p,
          brightness: t.brightness,
          surface: t.colorScheme.surface,
          ink: t.colorScheme.onSurface,
          compact: widget.compact,
          selected: _sel,
          scale: _scale(context),
          fontFamily: widget.fontFamily ?? t.textTheme.bodyMedium?.fontFamily,
        );
    final chart = RepaintBoundary(
      child: AnimatedBuilder(
        animation: _c,
        builder: (_, __) => CustomPaint(
          size: Size.square(widget.size),
          painter: painter(Curves.easeOutCubic.transform(_c.value)),
        ),
      ),
    );
    if (widget.compact) return ExcludeSemantics(child: chart);
    return Semantics(
      label: 'Circle Paradigm radar. ${WellnessDimension.values.map((d) => '${d.label} ${widget.current[d] ?? 0}').join(', ')}',
      child: GestureDetector(behavior: HitTestBehavior.opaque, onTapUp: (e) => _tap(e.localPosition), child: chart),
    );
  }
}

class RadarGeometry {
  RadarGeometry(Size size, {required this.compact, required double scale})
      : c = size.center(Offset.zero),
        r = compact ? size.width / 2 - 4 : size.width / 2 - 46 * scale;
  final Offset c;
  final double r;
  final bool compact;
  static double angle(int i) => -math.pi / 2 + i * math.pi / 4;
  Offset dir(int i) => Offset(math.cos(angle(i)), math.sin(angle(i)));
  Offset point(int i, double v) => c + dir(i) * (r * v.clamp(0, 100) / 100);
}

class RadarPainter extends CustomPainter {
  RadarPainter({
    required this.current,
    required this.goals,
    required this.previous,
    required this.progress,
    required this.brightness,
    required this.surface,
    required this.ink,
    required this.compact,
    required this.selected,
    required this.scale,
    this.fontFamily,
  });
  final Map<WellnessDimension, int> current, goals, previous;
  final double progress, scale;
  final Brightness brightness;
  final Color surface, ink;
  final bool compact;
  final WellnessDimension? selected;
  final String? fontFamily;

  bool get dark => brightness == Brightness.dark;

  @override
  void paint(Canvas canvas, Size size) {
    final g = RadarGeometry(size, compact: compact, scale: scale);
    final c = g.c, r = g.r;
    final grid = compact ? Colors.white : ink;

    // Band fills (0–40 / 40–70 / 70–100), very subtle, then rings.
    if (!compact) {
      for (final (lim, col) in [(100.0, const Color(0xFF2ECC9A)), (70.0, const Color(0xFFF5B83D)), (40.0, const Color(0xFFFF6B8B))]) {
        canvas.drawCircle(c, r * lim / 100, Paint()..color = col.withOpacity(dark ? 0.07 : 0.06));
      }
    }
    for (var k = 1; k <= 5; k++) {
      final v = k * 20.0;
      canvas.drawCircle(
          c,
          r * v / 100,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1
            ..color = grid.withOpacity(compact ? 0.22 : 0.12));
    }
    // Threshold rings 40 / 70 (dashed, labelled).
    for (final (v, label) in [(40.0, '40'), (70.0, '70')]) {
      final ring = Path()..addOval(Rect.fromCircle(center: c, radius: r * v / 100));
      canvas.drawPath(
          _dash(ring, compact ? 4 : 6, compact ? 3 : 4),
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = compact ? 1 : 1.4
            ..color = (compact ? Colors.white : AppColors.primary).withOpacity(compact ? 0.5 : (dark ? 0.75 : 0.55)));
      if (!compact) {
        // Place between the Emotional and Physical axes so it never collides with a vertex.
        const a = -math.pi / 2 + math.pi / 8;
        _text(canvas, label, c + Offset(math.cos(a), math.sin(a)) * (r * v / 100),
            TextStyle(fontSize: 9 * scale, fontWeight: FontWeight.w700, color: AppColors.primary.withOpacity(dark ? 0.95 : 0.8)),
            bg: surface.withOpacity(0.9));
      }
    }
    // Axes.
    for (var i = 0; i < 8; i++) {
      final d = WellnessDimension.values[i];
      canvas.drawLine(
          c,
          g.point(i, 100),
          Paint()
            ..strokeWidth = 1
            ..color = (compact ? Colors.white.withOpacity(0.25) : d.color(brightness).withOpacity(0.35)));
    }

    // Previous (thin, faint).
    if (!compact && previous.isNotEmpty) {
      canvas.drawPath(
          _poly(g, previous, progress),
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.5
            ..color = const Color(0xFF9AA3C7).withOpacity(0.8));
    }

    // Current polygon: gradient fill + glow + crisp stroke.
    if (current.isNotEmpty) {
      final poly = _poly(g, current, progress);
      final bounds = Rect.fromCircle(center: c, radius: r);
      canvas.drawPath(
          poly,
          Paint()
            ..shader = ui.Gradient.radial(c, r, [
              AppColors.secondary.withOpacity(compact ? 0.55 : 0.45),
              AppColors.primary.withOpacity(compact ? 0.65 : 0.55),
            ]));
      canvas.drawPath(
          poly,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = compact ? 5 : 7
            ..color = AppColors.secondary.withOpacity(compact ? 0.25 : 0.45)
            // Blur glow only on the full-size radar; the Home mini radar uses a cheap halo.
            ..maskFilter = compact ? null : const MaskFilter.blur(BlurStyle.normal, 6));
      canvas.drawPath(
          poly,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = compact ? 1.6 : 2.4
            ..strokeJoin = StrokeJoin.round
            ..shader = ui.Gradient.linear(bounds.topLeft, bounds.bottomRight,
                [compact ? Colors.white : const Color(0xFF8C7BFF), compact ? const Color(0xFFB9FFF4) : AppColors.secondary]));
    }

    // Goal overlay (dashed), revealed after the polygon draws in.
    if (goals.isNotEmpty) {
      final gp = _poly(g, {for (final d in WellnessDimension.values) d: goals[d] ?? current[d] ?? 0}, 1);
      final reveal = ((progress - 0.5) * 2).clamp(0.0, 1.0);
      if (reveal > 0) {
        canvas.drawPath(
            _dash(gp, compact ? 4 : 7, compact ? 3 : 5),
            Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = compact ? 1.4 : 2
              ..color = AppColors.accent.withOpacity(0.95 * reveal));
      }
    }

    // Vertex dots + values.
    for (var i = 0; i < 8; i++) {
      final d = WellnessDimension.values[i];
      final v = current[d];
      if (v == null) continue;
      final col = d.color(brightness);
      final p = g.point(i, v * progress);
      final sel = selected == d;
      final rad = compact ? 2.4 : (sel ? 7.0 : 5.0);
      canvas.drawCircle(p, rad + (compact ? 1 : 2), Paint()..color = compact ? Colors.white : surface);
      canvas.drawCircle(p, rad, Paint()..color = col);
      if (!compact && progress > 0.85) {
        final o = p + g.dir(i) * 14 * scale;
        _text(canvas, '$v', o,
            TextStyle(fontSize: 10 * scale, fontWeight: FontWeight.w800, color: dark ? Colors.white : const Color(0xFF1B1840)),
            bg: surface.withOpacity(0.85));
      }
    }

    // Axis labels: icon + name in dimension colour.
    if (!compact) {
      for (var i = 0; i < 8; i++) {
        final d = WellnessDimension.values[i];
        final col = d.color(brightness);
        final dir = g.dir(i);
        final anchor = c + dir * (r + 24 * scale);
        final icon = TextPainter(
            text: TextSpan(
                text: String.fromCharCode(d.icon.codePoint),
                style: TextStyle(fontFamily: d.icon.fontFamily, package: d.icon.fontPackage, fontSize: 16 * scale, color: col)),
            textDirection: TextDirection.ltr)
          ..layout();
        final name = TextPainter(
            text: TextSpan(
                text: d.label, style: TextStyle(fontFamily: fontFamily, fontSize: 10 * scale, fontWeight: FontWeight.w700, color: col)),
            textDirection: TextDirection.ltr)
          ..layout();
        final w = math.max(icon.width, name.width), h = icon.height + name.height;
        var tl = anchor - Offset(w / 2, h / 2) + Offset(dir.dx * w * 0.35, dir.dy * h * 0.25);
        tl = Offset(tl.dx.clamp(0, size.width - w), tl.dy.clamp(0, size.height - h));
        icon.paint(canvas, tl + Offset((w - icon.width) / 2, 0));
        name.paint(canvas, tl + Offset((w - name.width) / 2, icon.height));
      }
    }

    // Selected tooltip.
    final s = selected;
    if (!compact && s != null && current[s] != null) {
      final v = current[s]!;
      final p = g.point(s.index, v.toDouble());
      final goal = goals[s];
      final text = '${s.label}  $v${goal == null ? '' : '  ·  goal $goal'}';
      final tp = TextPainter(
          text: TextSpan(
              text: text, style: TextStyle(fontFamily: fontFamily, fontSize: 12 * scale, fontWeight: FontWeight.w700, color: Colors.white)),
          textDirection: TextDirection.ltr)
        ..layout();
      final w = tp.width + 20, h = tp.height + 12;
      var rect = Rect.fromCenter(center: p - Offset(0, h + 6), width: w, height: h);
      rect = rect.shift(Offset(rect.left < 0 ? -rect.left : (rect.right > size.width ? size.width - rect.right : 0),
          rect.top < 0 ? (p.dy + h + 6 - rect.center.dy) : 0));
      canvas.drawRRect(RRect.fromRectAndRadius(rect, const Radius.circular(10)), Paint()..color = s.color(Brightness.light));
      tp.paint(canvas, rect.center - Offset(tp.width / 2, tp.height / 2));
    }
  }

  Path _poly(RadarGeometry g, Map<WellnessDimension, int> m, double p) {
    final path = Path();
    for (var i = 0; i < 8; i++) {
      final o = g.point(i, (m[WellnessDimension.values[i]] ?? 0) * p);
      i == 0 ? path.moveTo(o.dx, o.dy) : path.lineTo(o.dx, o.dy);
    }
    return path..close();
  }

  Path _dash(Path src, double on, double off) {
    final out = Path();
    for (final m in src.computeMetrics()) {
      for (double d = 0; d < m.length; d += on + off) {
        out.addPath(m.extractPath(d, math.min(d + on, m.length)), Offset.zero);
      }
    }
    return out;
  }

  void _text(Canvas canvas, String s, Offset center, TextStyle style, {Color? bg}) {
    final tp = TextPainter(
        text: TextSpan(text: s, style: style.copyWith(fontFamily: style.fontFamily ?? fontFamily)), textDirection: TextDirection.ltr)
      ..layout();
    if (bg != null) {
      canvas.drawRRect(
          RRect.fromRectAndRadius(Rect.fromCenter(center: center, width: tp.width + 8, height: tp.height + 2), const Radius.circular(6)),
          Paint()..color = bg);
    }
    tp.paint(canvas, center - Offset(tp.width / 2, tp.height / 2));
  }

  @override
  bool shouldRepaint(RadarPainter oldDelegate) {
    final o = oldDelegate;
    return o.progress != progress ||
        o.selected != selected ||
        o.brightness != brightness ||
        o.current != current ||
        o.goals != goals ||
        o.previous != previous ||
        o.scale != scale;
  }
}

/// Legend shared by Circle Paradigm and Trends.
class ParadigmLegend extends StatelessWidget {
  const ParadigmLegend({super.key, required this.current, required this.goals, required this.previous});
  final Map<WellnessDimension, int> current, goals, previous;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final rows = [
      ('Current State', ParadigmRadar.currentA, current),
      ('Desired State', ParadigmRadar.goal, goals),
      ('Previous', ParadigmRadar.previousColor, previous),
    ];
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          for (final x in rows)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Container(width: 18, height: 18, color: x.$2),
                const SizedBox(width: 8),
                Flexible(child: Text(x.$1 + (x.$3.isEmpty ? ' (none yet)' : ''), style: t.textTheme.bodyMedium)),
              ]),
            ),
        ]),
      ),
    );
  }
}
