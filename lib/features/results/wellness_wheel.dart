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
  });
  final Map<WellnessDimension, int> scores;
  final int? overall;
  final double size;
  final bool showLabels;
  final ValueChanged<WellnessDimension>? onTapDimension;

  /// Optional; null keeps the platform default font (used by the preview render).
  final String? labelFontFamily;

  @override
  State<WellnessWheel> createState() => _WellnessWheelState();
}

class _WellnessWheelState extends State<WellnessWheel> with SingleTickerProviderStateMixin {
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
  void didUpdateWidget(WellnessWheel old) {
    super.didUpdateWidget(old);
    if (old.scores.toString() != widget.scores.toString() && !reducedMotion(context)) _c.forward(from: 0);
  }

  @override
  void dispose() {
    _c.dispose();
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
      for (final d in WellnessDimension.values) '${d.label} ${widget.scores[d]?.toString() ?? "not assessed"}',
    ].join(', ');
    return Semantics(
      label: 'Wellness wheel. ${widget.overall == null ? "" : "Overall ${widget.overall}. "}$summary',
      child: GestureDetector(
        onTapUp: _tap,
        child: RepaintBoundary(
          child: AnimatedBuilder(
            animation: _c,
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
  });
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
      // Track
      _wedge(canvas, c, inner, outer, start, sweep, Paint()..color = color.withOpacity(0.16));
      // Fill (staggered per segment)
      final local = ((progress * 1.4) - i * 0.05).clamp(0.0, 1.0);
      final s = scores[d];
      if (s != null && s > 0) {
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
        final onSeg = (s ?? 0) >= 55 ? Colors.white : onSurface;
        _text(canvas, String.fromCharCode(d.icon.codePoint), pos.translate(0, -10 * k),
            TextStyle(fontFamily: d.icon.fontFamily, package: d.icon.fontPackage, fontSize: 20 * k * textScale, color: onSeg));
        _text(canvas, d.label, pos.translate(0, 12 * k),
            TextStyle(fontFamily: fontFamily, fontSize: 9.5 * k * textScale, fontWeight: FontWeight.w600, color: onSeg));
      }
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

  void _text(Canvas canvas, String s, Offset center, TextStyle style) {
    final tp = TextPainter(text: TextSpan(text: s, style: style), textDirection: TextDirection.ltr)..layout();
    tp.paint(canvas, center - Offset(tp.width / 2, tp.height / 2));
  }

  @override
  bool shouldRepaint(_WheelPainter o) => o.progress != progress || o.scores != scores || o.brightness != brightness || o.overall != overall;
}
