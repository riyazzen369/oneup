import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../core/services/haptics.dart';

/// Minimal real-time game model: fixed-step-free update(dt), canvas paint, raw pointer input.
/// Pure Dart (no widgets) so it can be stepped in tests and rendered for previews.
abstract class Arcade {
  Arcade([math.Random? rnd]) : rnd = rnd ?? math.Random();
  final math.Random rnd;
  Size size = Size.zero;
  int score = 0, lives = 3, combo = 0, level = 1;
  bool over = false;

  /// Particles and screen effects; off for reduced motion.
  bool fx = true;
  double t = 0;
  double meter = 0; // 0..1, shown when [meterLabel] != null
  String? get meterLabel => null;
  double? timeLeft; // shown when not null
  bool get showLives => true;
  String get tip;
  int hudRev = 0;
  final particles = <Particle>[];
  final floats = <FloatText>[];
  double invuln = 0;

  void bumpHud() => hudRev++;

  void resize(Size s) {
    final first = size == Size.zero;
    size = s;
    if (first) start();
  }

  void start();
  void update(double dt);
  void paint(Canvas c);

  void step(double dt) {
    if (over || size == Size.zero) return;
    t += dt;
    if (invuln > 0) invuln -= dt;
    update(dt);
    for (final p in particles) {
      p.pos += p.vel * dt;
      p.vel = p.vel * (1 - 1.5 * dt) + Offset(0, 120 * dt);
      p.life -= dt;
    }
    particles.removeWhere((p) => p.life <= 0);
    for (final f in floats) {
      f.life -= dt;
      f.pos += Offset(0, -40 * dt);
    }
    floats.removeWhere((f) => f.life <= 0);
  }

  void paintFx(Canvas c) {
    final paint = Paint();
    for (final p in particles) {
      paint.color = p.color.withOpacity((p.life / p.max).clamp(0, 1));
      c.drawCircle(p.pos, p.r, paint);
    }
    for (final f in floats) {
      Glyphs.text(c, f.text, f.pos, 18, Colors.white.withOpacity((f.life / 0.8).clamp(0, 1)), bold: true);
    }
  }

  void burst(Offset at, Color color, {int n = 12}) {
    if (!fx) return;
    for (var i = 0; i < n; i++) {
      final a = rnd.nextDouble() * math.pi * 2, s = 60 + rnd.nextDouble() * 160;
      particles.add(Particle(at, Offset(math.cos(a), math.sin(a)) * s, color, 2 + rnd.nextDouble() * 3, 0.5 + rnd.nextDouble() * 0.4));
    }
  }

  /// Reward: combo multiplies points (x2 at 5, x3 at 10, ...).
  void gain(int pts, Offset at, {Color color = Colors.white}) {
    combo++;
    final mult = 1 + combo ~/ 5;
    score += pts * mult;
    Haptics.selection();
    burst(at, color);
    if (fx) floats.add(FloatText('+${pts * mult}', at, 0.8));
    level = 1 + score ~/ levelEvery;
    bumpHud();
  }

  int get levelEvery => 150;

  /// Mistake that only breaks the combo.
  void miss() {
    if (combo > 0) bumpHud();
    combo = 0;
  }

  /// Damage: lose a life (brief invulnerability).
  void hit(Offset at) {
    if (invuln > 0) return;
    combo = 0;
    lives--;
    invuln = 1.0;
    Haptics.medium();
    burst(at, const Color(0xFFFF6B6B), n: 18);
    if (lives <= 0) over = true;
    bumpHud();
  }

  void pointerDown(Offset p) {}
  void pointerMove(Offset p, Offset delta) {}
  void pointerUp(Offset p) {}
}

class Particle {
  Particle(this.pos, this.vel, this.color, this.r, this.life) : max = life;
  Offset pos, vel;
  final Color color;
  final double r, max;
  double life;
}

class FloatText {
  FloatText(this.text, this.pos, this.life);
  final String text;
  Offset pos;
  double life;
}

/// Generic falling object.
class Faller {
  Faller(this.pos, this.vel, this.r, this.kind, this.glyph, this.color);
  Offset pos, vel;
  final double r;
  final int kind;
  final String glyph;
  final Color color;
  bool dead = false;
}

/// Cached text/emoji painting (layout once per glyph+size+colour).
class Glyphs {
  static final _cache = <String, TextPainter>{};

  /// Null = platform default (app). Previews set explicit fonts.
  static String? family;
  static List<String>? fallback;
  static void text(Canvas c, String s, Offset center, double size, Color color, {bool bold = false}) {
    final k = '$s|$size|${color.value}|$bold';
    final tp = _cache[k] ??= (TextPainter(
      text: TextSpan(
          text: s,
          style: TextStyle(
              fontFamily: family,
              fontFamilyFallback: fallback,
              fontSize: size,
              color: color,
              fontWeight: bold ? FontWeight.w800 : FontWeight.w500)),
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.center,
    )..layout(maxWidth: 220));
    if (_cache.length > 400) _cache.clear();
    tp.paint(c, center - Offset(tp.width / 2, tp.height / 2));
  }
}

/// Dark themed background shared by the games (cheap: one gradient rect).
void paintBg(Canvas c, Size s, List<Color> colors) {
  c.drawRect(
      Offset.zero & s,
      Paint()
        ..shader = LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: colors).createShader(Offset.zero & s));
}
