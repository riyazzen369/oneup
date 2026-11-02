import 'dart:math' as math;
import '../../core/widgets/fx.dart';
import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';

/// Animated "Dimensions of Wellness" wheel: 8 coloured segments, icon + label per
/// segment, coloured fill radius proportional to score, overall score in the centre.
class WellnessWheel extends StatefulWidget {
  const WellnessWheel({
    super.key,
    required this.scores,
    this.overall,
    this.size = 320,
    this.showLabels = true,
    this.onTapDimension,
    this.labelFontFamily,
    this.estimated = const {},
    this.glow = const {},
    this.pulse,
  });
  final Map<WellnessDimension, int> scores;

  /// Living wheel: recent-activity glow 0..1 per dimension (visual only; scores are untouched).
  final Map<WellnessDimension, double> glow;

  /// Dimension just boosted: its slice pulses a few times. Change it to replay.
  final WellnessDimension? pulse;
  final int? overall;
  final double size;
  final bool showLabels;
  final ValueChanged<WellnessDimension>? onTapDimension;

  /// Optional; null keeps the platform default font (used by the preview render).
  final String? labelFontFamily;

  /// Dimensions whose score is a Quick Check estimate: drawn lighter with a dashed edge + "Quick" tag.
  final Set<WellnessDimension> estimated;

  @override
  State<WellnessWheel> createState() => _WellnessWheelState();
}

class _WellnessWheelState extends State<WellnessWheel> with TickerProviderStateMixin {
  late final _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1400))..forward();
  late final _p = AnimationController(vsync: this, duration: const Duration(milliseconds: 2400));
  late final _both = Listenable.merge([_c, _p]);

  void _startPulse() {
    if (widget.pulse == null || reducedMotion(context)) return;
    _p.forward(from: 0);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (reducedMotion(context)) {
      _c.stop();
      _c.value = 1; // show final state, no animation
    } else if (widget.pulse != null && !_p.isAnimating && _p.value == 0) {
      _startPulse();
    }
  }

  @override
  void didUpdateWidget(WellnessWheel old) {
    super.didUpdateWidget(old);
    if (old.scores.toString() != widget.scores.toString() && !reducedMotion(context)) _c.forward(from: 0);
    if (widget.pulse != null && widget.pulse != old.pulse) _startPulse();
  }

  @override
  void dispose() {
    _c.dispose();
    _p.dispose();
    super.dispose();
  }

  void _tap(TapUpDetails d) {
    final cb = widget.onTapDimension;
    if (cb == null) return;
    final c = Offset(widget.size / 2, widget.size / 2);
    final v = d.localPosition - c;
    if (v.distance < widget.size * 0.16) return;
    var ang = math.atan2(v.dy, v.dx) + math.pi / 2; // 0 at top, clockwise
    if (ang < 0) ang += 2 * math.pi;
    cb(WellnessDimension.values[(ang / (math.pi / 4)).floor() % 8]);
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final summary = [
      for (final d in WellnessDimension.values)
        '${d.label} ${widget.scores[d]?.toString() ?? "not assessed"}${widget.estimated.contains(d) ? " (quick estimate)" : ""}'
            '${(widget.glow[d] ?? 0) > 0 ? " (recent activity)" : ""}',
    ].join(', ');
    return Semantics(
      label: 'Wellness wheel. ${widget.overall == null ? "" : "Overall ${widget.overall}. "}$summary',
      child: GestureDetector(
        onTapUp: _tap,
        child: RepaintBoundary(
          child: AnimatedBuilder(
            animation: _both,
            builder: (_, __) => CustomPaint(
              size: Size.square(widget.size),
              painter: _WheelPainter(
                scores: widget.scores,
                overall: widget.overall,
                progress: Curves.easeOutCubic.transform(_c.value),
                brightness: t.brightness,
                surface: t.colorScheme.surface,
                onSurface: t.colorScheme.onSurface,
                showLabels: widget.showLabels,
                textScale: MediaQuery.textScalerOf(context).scale(1).clamp(1.0, 1.3),
                fontFamily: widget.labelFontFamily ?? t.textTheme.bodyMedium?.fontFamily,
                estimated: widget.estimated,
                glow: widget.glow,
                pulse: widget.pulse,
                // Three soft beats that fade out.
                pulseT: _p.isAnimating ? math.sin(_p.value * 3 * math.pi).abs() * (1 - _p.value) : 0,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _WheelPainter extends CustomPainter {
  _WheelPainter({
    required this.scores,
    required this.overall,
    required this.progress,
    required this.brightness,
    required this.surface,
    required this.onSurface,
    required this.showLabels,
    required this.textScale,
    this.fontFamily,
    this.estimated = const {},
    this.glow = const {},
    this.pulse,
    this.pulseT = 0,
  });
  final Set<WellnessDimension> estimated;
  final Map<WellnessDimension, double> glow;
  final WellnessDimension? pulse;
  final double pulseT;
  final Map<WellnessDimension, int> scores;
  final int? overall;
  final double progress;
  final Brightness brightness;
  final Color surface;
  final Color onSurface;
  final bool showLabels;
  final double textScale;
  final String? fontFamily;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final outer = size.width / 2;
    final inner = outer * 0.30;
    const seg = math.pi / 4;
    const gap = 0.025;
    // Labels grow with the wheel so large wheels stay legible.
    final k = (size.width / 320).clamp(1.0, 1.5);
    for (final d in WellnessDimension.values) {
      final i = d.index;
      final start = -math.pi / 2 + i * seg + gap / 2;
      const sweep = seg - gap;
      final color = d.color(brightness);
      final mid0 = start + sweep / 2;
      final g = ((glow[d] ?? 0) + (d == pulse ? pulseT * 1.3 : 0)).clamp(0.0, 2.0);
      canvas.save();
      if (g > 0) {
        // Grow: nudge the slice outward a few px, then halo its outer edge.
        canvas.translate(math.cos(mid0) * 9 * k * g.clamp(0.0, 1.4), math.sin(mid0) * 9 * k * g.clamp(0.0, 1.4));
        canvas.drawArc(
            Rect.fromCircle(center: c, radius: outer - 3),
            start,
            sweep,
            false,
            Paint()
              ..color = color.withOpacity((0.55 + 0.45 * g).clamp(0.0, 1.0))
              ..style = PaintingStyle.stroke
              ..strokeWidth = (10 + 12 * g) * k
              ..maskFilter = MaskFilter.blur(BlurStyle.normal, (8 + 10 * g) * k));
      }
      // Track
      _wedge(canvas, c, inner, outer, start, sweep, Paint()..color = color.withOpacity(0.16 + 0.14 * g.clamp(0.0, 1.0)));
      // Fill (staggered per segment)
      final local = ((progress * 1.4) - i * 0.05).clamp(0.0, 1.0);
      final s = scores[d];
      final est = estimated.contains(d);
      if (s != null && s > 0 && est) {
        final r = inner + (outer - inner) * (s / 100) * local;
        _wedge(canvas, c, inner, r, start, sweep, Paint()..color = color.withOpacity(0.42));
        _dashedArc(
            canvas,
            c,
            r,
            start,
            sweep,
            Paint()
              ..color = color
              ..style = PaintingStyle.stroke
              ..strokeWidth = 2.2);
      } else if (s != null && s > 0) {
        final r = inner + (outer - inner) * (s / 100) * local;
        _wedge(
            canvas,
            c,
            inner,
            r,
            start,
            sweep,
            Paint()
              ..shader = RadialGradient(colors: [color.withOpacity(0.75), color], stops: [inner / outer, 1])
                  .createShader(Rect.fromCircle(center: c, radius: outer)));
      }
      if (showLabels) {
        final mid = start + sweep / 2;
        final pos = c + Offset(math.cos(mid), math.sin(mid)) * (outer * 0.70);
        final onSeg = (s ?? 0) >= 55 && !est ? Colors.white : onSurface;
        _text(canvas, String.fromCharCode(d.icon.codePoint), pos.translate(0, -10 * k),
            TextStyle(fontFamily: d.icon.fontFamily, package: d.icon.fontPackage, fontSize: 20 * k * textScale, color: onSeg));
        _text(canvas, d.label, pos.translate(0, 12 * k),
            TextStyle(fontFamily: fontFamily, fontSize: 9.5 * k * textScale, fontWeight: FontWeight.w600, color: onSeg));
        if (est && s != null) {
          _text(canvas, 'Quick', pos.translate(0, 26 * k),
              TextStyle(fontFamily: fontFamily, fontSize: 8 * k * textScale, fontStyle: FontStyle.italic, color: onSeg.withOpacity(0.8)));
        }
      }
      if (g > 0) {
        // Bright rim over the slice (visible even on filled slices) + inner wash.
        final a = g.clamp(0.0, 1.0);
        _wedge(canvas, c, inner, outer, start, sweep, Paint()..color = Colors.white.withOpacity(0.10 * a));
        final rim = Path()
          ..arcTo(Rect.fromCircle(center: c, radius: outer - 1.5), start, sweep, true)
          ..arcTo(Rect.fromCircle(center: c, radius: inner + 1.5), start + sweep, -sweep, false)
          ..close();
        canvas.drawPath(
            rim,
            Paint()
              ..color = Color.lerp(color, Colors.white, 0.55)!.withOpacity((0.6 + 0.4 * a).clamp(0.0, 1.0))
              ..style = PaintingStyle.stroke
              ..strokeWidth = (1.5 + 1.5 * g) * k
              ..maskFilter = MaskFilter.blur(BlurStyle.solid, 2 * k));
      }
      canvas.restore();
    }
    // Centre
    canvas.drawCircle(c, inner - 4, Paint()..color = surface);
    final o = overall;
    _text(canvas, o == null ? '—' : '${(o * progress).round()}', c.translate(0, showLabels ? -6 * k : 0),
        TextStyle(fontFamily: fontFamily, fontSize: inner * 0.55, fontWeight: FontWeight.w800, color: onSurface));
    if (showLabels) {
      _text(canvas, o == null ? 'finish all 8' : 'overall', c.translate(0, inner * 0.38),
          TextStyle(fontFamily: fontFamily, fontSize: 10 * k * textScale, color: onSurface.withOpacity(0.7)));
    }
  }

  void _wedge(Canvas canvas, Offset c, double r0, double r1, double start, double sweep, Paint p) {
    if (r1 <= r0) return;
    final path = Path()
      ..arcTo(Rect.fromCircle(center: c, radius: r1), start, sweep, true)
      ..arcTo(Rect.fromCircle(center: c, radius: r0), start + sweep, -sweep, false)
      ..close();
    canvas.drawPath(path, p);
  }

  void _dashedArc(Canvas canvas, Offset c, double r, double start, double sweep, Paint p) {
    if (r <= 0) return;
    final rect = Rect.fromCircle(center: c, radius: r);
    final dash = 6 / r, gapA = 4 / r;
    for (var a = 0.0; a < sweep; a += dash + gapA) {
      canvas.drawArc(rect, start + a, math.min(dash, sweep - a), false, p);
    }
  }

  void _text(Canvas canvas, String s, Offset center, TextStyle style) {
    final tp = TextPainter(text: TextSpan(text: s, style: style), textDirection: TextDirection.ltr)..layout();
    tp.paint(canvas, center - Offset(tp.width / 2, tp.height / 2));
  }

  @override
  bool shouldRepaint(_WheelPainter o) =>
      o.progress != progress ||
      o.scores != scores ||
      o.brightness != brightness ||
      o.overall != overall ||
      o.estimated != estimated ||
      o.glow != glow ||
      o.pulse != pulse ||
      o.pulseT != pulseT;
}
