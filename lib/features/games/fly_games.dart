import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'arcade.dart';

class Gate {
  Gate(this.x, this.gapY, this.gap);
  double x, gapY, gap;
  bool passed = false;
}

/// Physical: hold to inhale and rise, release to exhale and sink. Pass through gates.
/// Holding/releasing for steady, even durations builds a rhythm bonus.
class BreathRunner extends Arcade {
  BreathRunner([super.rnd]);
  double y = 0, vy = 0;
  bool holding = false;
  double phase = 0, lastPhase = 0;
  final gates = <Gate>[];
  double spawnIn = 0;
  final trail = <Offset>[];
  double get px => size.width * 0.28;
  double get scroll => 130 + 14.0 * (level - 1);
  double get gap => math.max(120, 210 - 10.0 * (level - 1));
  @override
  int get levelEvery => 120;
  @override
  String get tip => 'Slow, steady breathing is a simple way to pause during a busy day.';
  @override
  String? get meterLabel => 'Rhythm';

  @override
  void start() => y = size.height / 2;

  @override
  void pointerDown(Offset p) => _switch(true);
  @override
  void pointerUp(Offset p) => _switch(false);

  void _switch(bool h) {
    if (h == holding) return;
    // Rhythm: each phase about as long as the previous, and not hurried (>0.6s).
    if (phase > 0.6 && lastPhase > 0.6 && (phase - lastPhase).abs() < 0.35) {
      meter = math.min(1, meter + 0.15);
    } else {
      meter = math.max(0, meter - 0.1);
    }
    bumpHud();
    lastPhase = phase;
    phase = 0;
    holding = h;
  }

  @override
  void update(double dt) {
    phase += dt;
    // Gentle, floaty physics: target velocity, not gravity snaps.
    final target = holding ? -170.0 : 150.0;
    vy += (target - vy) * math.min(1, dt * 3.5);
    y += vy * dt;
    final top = 70.0, bottom = size.height - 20;
    if (y < top) {
      y = top;
      vy = 0;
    }
    if (y > bottom) {
      y = bottom;
      vy = 0;
      hit(Offset(px, y));
    }
    spawnIn -= dt;
    if (spawnIn <= 0) {
      spawnIn = 2.1 * 130 / scroll + 0.3;
      final g = gap;
      final prev = gates.isEmpty ? size.height / 2 : gates.last.gapY;
      final ny = (prev + (rnd.nextDouble() - 0.5) * size.height * 0.5).clamp(90 + g / 2, size.height - 40 - g / 2);
      gates.add(Gate(size.width + 30, ny, g));
    }
    for (final g in gates) {
      g.x -= scroll * dt;
      if (!g.passed && (g.x - px).abs() < 22) {
        if ((y - g.gapY).abs() > g.gap / 2 - 12) {
          g.passed = true;
          hit(Offset(px, y));
        }
      }
      if (!g.passed && g.x < px - 22) {
        g.passed = true;
        gain(10 + (meter * 20).round(), Offset(px, y), color: const Color(0xFF6FE3A5));
      }
    }
    gates.removeWhere((g) => g.x < -40);
    if (fx) {
      trail.add(Offset(px, y));
      if (trail.length > 24) trail.removeAt(0);
    }
  }

  @override
  void paint(Canvas c) {
    paintBg(c, size, const [Color(0xFF0B2B3A), Color(0xFF0E3B47), Color(0xFF14524E)]);
    final wall = Paint()..color = const Color(0xFF2FAF8A);
    for (final g in gates) {
      final r1 = RRect.fromLTRBR(g.x - 20, 60, g.x + 20, g.gapY - g.gap / 2, const Radius.circular(10));
      final r2 = RRect.fromLTRBR(g.x - 20, g.gapY + g.gap / 2, g.x + 20, size.height, const Radius.circular(10));
      c.drawRRect(r1, wall);
      c.drawRRect(r2, wall);
    }
    for (var i = 0; i < trail.length; i++) {
      final o = trail[i] - Offset((trail.length - i) * scroll / 60, 0);
      c.drawCircle(o, 3 + i * 0.3, Paint()..color = Colors.white.withOpacity(i / trail.length * 0.3));
    }
    if (invuln <= 0 || (t * 10).floor().isEven) {
      final r = holding ? 20.0 : 16.0; // "lungs" swell on inhale
      c.drawCircle(Offset(px, y), r + 6, Paint()..color = const Color(0x446FE3A5));
      c.drawCircle(Offset(px, y), r, Paint()..color = const Color(0xFF6FE3A5));
    }
    Glyphs.text(c, holding ? 'Inhale' : 'Exhale', Offset(size.width / 2, size.height - 36), 16, Colors.white54, bold: true);
  }
}

/// Spiritual: steer a rising lantern through gaps in drifting clouds; gather light orbs.
class ZenLantern extends Arcade {
  ZenLantern([super.rnd]);
  double x = 0, targetX = 0;
  final rows = <Gate>[]; // x = gap centre, gapY = row y, gap = width
  final orbs = <Faller>[];
  double spawnIn = 0, orbIn = 1;
  double get ly => size.height * 0.72;
  double get rise => 110 + 12.0 * (level - 1);
  @override
  String get tip => 'Taking a quiet minute to notice what you are grateful for can shift your focus.';
  @override
  String? get meterLabel => 'Light';

  @override
  void start() => x = targetX = size.width / 2;
  @override
  void pointerDown(Offset p) => targetX = p.dx;
  @override
  void pointerMove(Offset p, Offset delta) => targetX = p.dx;

  @override
  void update(double dt) {
    x += (targetX - x) * math.min(1, dt * 10);
    x = x.clamp(16, size.width - 16);
    spawnIn -= dt;
    if (spawnIn <= 0) {
      spawnIn = 230 / rise;
      final w = math.max(90.0, size.width * 0.42 - 8 * (level - 1));
      rows.add(Gate(w / 2 + rnd.nextDouble() * (size.width - w), 40, w));
    }
    orbIn -= dt;
    if (orbIn <= 0) {
      orbIn = 0.8 + rnd.nextDouble();
      orbs.add(Faller(Offset(20 + rnd.nextDouble() * (size.width - 40), 40), Offset.zero, 11, 0, '✦', const Color(0xFFFFE08A)));
    }
    for (final r in rows) {
      r.gapY += rise * dt;
      if (!r.passed && (r.gapY - ly).abs() < 16) {
        r.passed = true;
        if ((x - r.x).abs() > r.gap / 2 - 14) {
          hit(Offset(x, ly));
        } else {
          gain(5, Offset(x, ly - 20), color: const Color(0xFFB39DFF));
        }
      }
    }
    rows.removeWhere((r) => r.gapY > size.height + 30);
    for (final o in orbs) {
      o.pos += Offset(math.sin(t * 2 + o.pos.dy / 40) * 20 * dt, rise * dt);
      if ((o.pos - Offset(x, ly)).distance < 30) {
        o.dead = true;
        gain(10, o.pos, color: o.color);
        meter += 0.1;
        if (meter >= 1) {
          meter = 0;
          if (lives < 3) lives++;
          gain(30, Offset(x, ly), color: const Color(0xFFFFE08A));
        }
      }
      if (o.pos.dy > size.height + 20) o.dead = true;
    }
    orbs.removeWhere((o) => o.dead);
  }

  @override
  void paint(Canvas c) {
    paintBg(c, size, const [Color(0xFF0D1030), Color(0xFF241A4A), Color(0xFF3B2459)]);
    final cloud = Paint()..color = const Color(0xFF5B4E86);
    for (final r in rows) {
      c.drawRRect(RRect.fromLTRBR(-20, r.gapY - 12, r.x - r.gap / 2, r.gapY + 12, const Radius.circular(12)), cloud);
      c.drawRRect(RRect.fromLTRBR(r.x + r.gap / 2, r.gapY - 12, size.width + 20, r.gapY + 12, const Radius.circular(12)), cloud);
    }
    for (final o in orbs) {
      if (fx) c.drawCircle(o.pos, o.r * 1.8, Paint()..color = const Color(0x33FFE08A));
      c.drawCircle(o.pos, o.r * 0.6, Paint()..color = o.color);
    }
    if (invuln <= 0 || (t * 10).floor().isEven) {
      final p = Offset(x, ly);
      final glow = 0.25 + 0.1 * math.sin(t * 4);
      c.drawCircle(p, 34, Paint()..color = const Color(0xFFFFB74D).withOpacity(fx ? glow : 0.25));
      c.drawRRect(RRect.fromRectAndRadius(Rect.fromCenter(center: p, width: 26, height: 32), const Radius.circular(8)),
          Paint()..color = const Color(0xFFFF8A50));
      c.drawCircle(p, 6, Paint()..color = const Color(0xFFFFF3C4));
    }
  }
}
