import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';
import '../theme/app_colors.dart';

bool reducedMotion(BuildContext context) => MediaQuery.maybeDisableAnimationsOf(context) ?? false;

/// Duration that collapses to zero when the OS "remove animations" setting is on.
Duration motion(BuildContext context, Duration d) => reducedMotion(context) ? Duration.zero : d;

/// Exposes whether content under the nearest MeshBackground is scrolling. Read it with
/// [ScrollState.peek] (no rebuild dependency) or listen to [ScrollState.notifierOf].
class ScrollState extends InheritedWidget {
  const ScrollState({super.key, required this.notifier, required super.child});
  final ValueNotifier<bool> notifier;
  static ValueNotifier<bool>? notifierOf(BuildContext c) => c.getInheritedWidgetOfExactType<ScrollState>()?.notifier;
  static bool peek(BuildContext c) => notifierOf(c)?.value ?? false;
  @override
  bool updateShouldNotify(ScrollState oldWidget) => oldWidget.notifier != notifier;
}

/// Soft glowing blobs over a base gradient. Painted once into a cached layer (static
/// composition): a full-screen 4-gradient repaint every frame competed with scrolling.
class MeshBackground extends StatefulWidget {
  const MeshBackground({super.key, required this.child});
  final Widget child;
  @override
  State<MeshBackground> createState() => _MeshBackgroundState();
}

class _MeshBackgroundState extends State<MeshBackground> {
  final _scrolling = ValueNotifier(false);

  @override
  void dispose() {
    _scrolling.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Stack(children: [
      Positioned.fill(
        child: RepaintBoundary(
          child: CustomPaint(isComplex: true, willChange: false, painter: _BlobPainter(0.0, dark)),
        ),
      ),
      NotificationListener<ScrollNotification>(
        onNotification: (n) {
          if (n.depth == 0) {
            if (n is ScrollStartNotification) _scrolling.value = true;
            if (n is ScrollEndNotification) _scrolling.value = false;
          }
          return false;
        },
        child: ScrollState(notifier: _scrolling, child: widget.child),
      ),
    ]);
  }
}

class _BlobPainter extends CustomPainter {
  _BlobPainter(this.t, this.dark);
  final double t;
  final bool dark;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(
      Offset.zero & size,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: dark ? const [Color(0xFF17123A), AppColors.darkBg] : const [Color(0xFFEDEBFF), AppColors.lightBg],
        ).createShader(Offset.zero & size),
    );
    final blobs = [
      (AppColors.primary, 0.2, 0.15, 0.55),
      (AppColors.secondary, 0.85, 0.30, 0.45),
      (AppColors.accent, 0.30, 0.70, 0.50),
      (const Color(0xFFFFB74D), 0.80, 0.85, 0.40),
    ];
    for (var i = 0; i < blobs.length; i++) {
      final b = blobs[i];
      final a = 2 * math.pi * (t + i / blobs.length);
      final center = Offset(
        size.width * (b.$2 + 0.08 * math.sin(a)),
        size.height * (b.$3 + 0.05 * math.cos(a * 1.3)),
      );
      final r = size.width * b.$4;
      canvas.drawCircle(
        center,
        r,
        Paint()
          ..shader = RadialGradient(colors: [b.$1.withOpacity(dark ? 0.35 : 0.28), b.$1.withOpacity(0)])
              .createShader(Rect.fromCircle(center: center, radius: r)),
      );
    }
  }

  @override
  bool shouldRepaint(_BlobPainter o) => o.t != t || o.dark != dark;
}

/// Frosted glass card.
class GlassCard extends StatelessWidget {
  const GlassCard({super.key, required this.child, this.padding = const EdgeInsets.all(16), this.radius = 24});
  final Widget child;
  final EdgeInsets padding;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    // Pre-baked translucent fill instead of BackdropFilter blur: the background is already
    // soft, so the look is nearly identical and no offscreen blur pass runs per card.
    return RepaintBoundary(
      child: Container(
        padding: padding,
        decoration: BoxDecoration(
          color: dark ? const Color(0x1FFFFFFF) : const Color(0xC2FFFFFF),
          borderRadius: BorderRadius.circular(radius),
          border: Border.all(color: Colors.white.withOpacity(dark ? 0.12 : 0.7)),
        ),
        child: child,
      ),
    );
  }
}

/// Press-scale micro-interaction with spring physics (haptics come from Haptics.tap at call sites).
class PressScale extends StatefulWidget {
  const PressScale({super.key, required this.child, this.onTap, this.semanticLabel});
  final Widget child;
  final VoidCallback? onTap;
  final String? semanticLabel;
  @override
  State<PressScale> createState() => _PressScaleState();
}

class _PressScaleState extends State<PressScale> with SingleTickerProviderStateMixin {
  late final _c = AnimationController.unbounded(vsync: this, value: 1);
  // Stiff, slightly under-damped: reaches the pressed scale in ~100 ms.
  static const _spring = SpringDescription(mass: 1, stiffness: 900, damping: 42);

  void _to(double target) {
    if (reducedMotion(context)) return;
    _c.animateWith(SpringSimulation(_spring, _c.value, target, _c.velocity));
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: widget.onTap != null,
      label: widget.semanticLabel,
      // Listener reacts on pointer-down immediately (GestureDetector.onTapDown waits
      // ~100 ms inside scrollables); the tap itself still goes through GestureDetector.
      child: Listener(
        onPointerDown: widget.onTap == null ? null : (_) => _to(0.95),
        onPointerUp: (_) => _to(1),
        onPointerCancel: (_) => _to(1),
        child: GestureDetector(
          onTap: widget.onTap,
          child: AnimatedBuilder(
            animation: _c,
            child: widget.child,
            builder: (_, child) => Transform.scale(scale: _c.value, child: child),
          ),
        ),
      ),
    );
  }
}

/// Staggered fade + slide-up entrance. Plays only on first screen build; items that are
/// lazily built while the user scrolls appear instantly (no per-item fade during scroll).
class StaggerIn extends StatefulWidget {
  const StaggerIn({super.key, required this.index, required this.child});
  final int index;
  final Widget child;
  @override
  State<StaggerIn> createState() => _StaggerInState();
}

class _StaggerInState extends State<StaggerIn> with SingleTickerProviderStateMixin {
  AnimationController? _c;
  Animation<double>? _v;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_c != null) return;
    if (reducedMotion(context) || ScrollState.peek(context)) return;
    final total = 500 + widget.index * 110;
    _c = AnimationController(vsync: this, duration: Duration(milliseconds: total))..forward();
    _v = CurvedAnimation(parent: _c!, curve: Interval((widget.index * 110) / total, 1, curve: Curves.easeOutCubic));
  }

  @override
  void dispose() {
    _c?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final v = _v;
    if (v == null) return widget.child;
    return FadeTransition(
      opacity: v,
      child: AnimatedBuilder(
        animation: v,
        child: widget.child,
        builder: (_, c) => Transform.translate(offset: Offset(0, 24 * (1 - v.value)), child: c),
      ),
    );
  }
}

/// Implicitly animates a number when it changes (instant with reduced motion).
class AnimatedScore extends StatelessWidget {
  const AnimatedScore(this.value, {super.key, this.style});
  final int value;
  final TextStyle? style;
  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<int>(
        tween: IntTween(begin: 0, end: value),
        duration: motion(context, const Duration(milliseconds: 700)),
        curve: Curves.easeOutCubic,
        builder: (_, v, __) => Text('$v', style: style, semanticsLabel: '$value'),
      );
}
