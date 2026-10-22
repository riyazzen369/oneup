import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'arcade.dart';

/// Shared "drag the catcher, catch good fallers, dodge bad ones" loop.
abstract class CatchGame extends Arcade {
  CatchGame([super.rnd]);
  double catcherX = 0;
  double spawnIn = 0;
  final items = <Faller>[];
  double get catcherW => size.width * 0.24;
  double get catcherY => size.height - 70;
  double get speed => 150 + 28.0 * (level - 1);
  double get spawnEvery => math.max(0.32, 0.9 - 0.06 * (level - 1));
  double get badChance => math.min(0.45, 0.22 + 0.025 * (level - 1));

  Faller makeGood(Offset p, Offset v);
  Faller makeBad(Offset p, Offset v);
  void onGood(Faller f);
  void onBad(Faller f) => hit(f.pos);
  void onMissGood(Faller f) => miss();
  void paintCatcher(Canvas c, Rect r);
  void paintBackground(Canvas c);

  @override
  void start() => catcherX = size.width / 2;

  @override
  void update(double dt) {
    spawnIn -= dt;
    if (spawnIn <= 0) {
      spawnIn = spawnEvery * (0.7 + rnd.nextDouble() * 0.6);
      final p = Offset(24 + rnd.nextDouble() * (size.width - 48), 60);
      final v = Offset((rnd.nextDouble() - 0.5) * 30, speed * (0.85 + rnd.nextDouble() * 0.3));
      items.add(rnd.nextDouble() < badChance ? makeBad(p, v) : makeGood(p, v));
    }
    final rect = catcherRect;
    for (final f in items) {
      f.pos += f.vel * dt;
      if (f.pos.dx < f.r || f.pos.dx > size.width - f.r) f.vel = Offset(-f.vel.dx, f.vel.dy);
      if (!f.dead &&
          f.pos.dy + f.r >= rect.top &&
          f.pos.dy < rect.bottom &&
          f.pos.dx > rect.left - f.r * 0.5 &&
          f.pos.dx < rect.right + f.r * 0.5) {
        f.dead = true;
        f.kind == 0 ? onGood(f) : onBad(f);
      } else if (f.pos.dy - f.r > size.height) {
        f.dead = true;
        if (f.kind == 0) onMissGood(f);
      }
    }
    items.removeWhere((f) => f.dead);
  }

  Rect get catcherRect => Rect.fromCenter(center: Offset(catcherX, catcherY), width: catcherW, height: 34);

  @override
  void pointerDown(Offset p) => catcherX = p.dx.clamp(catcherW / 2, size.width - catcherW / 2);
  @override
  void pointerMove(Offset p, Offset delta) => pointerDown(p);

  @override
  void paint(Canvas c) {
    paintBackground(c);
    for (final f in items) {
      if (f.kind == 0 && fx) c.drawCircle(f.pos, f.r * 1.35, Paint()..color = f.color.withOpacity(0.18));
      c.drawCircle(f.pos, f.r, Paint()..color = f.color.withOpacity(f.kind == 0 ? 0.9 : 0.75));
      Glyphs.text(c, f.glyph, f.pos, f.r * 1.15, Colors.white);
    }
    final blink = invuln > 0 && (t * 10).floor().isEven;
    if (!blink) paintCatcher(c, catcherRect);
  }
}

/// Emotional: catch calm/happy orbs; storms cost a life; a full calm meter gives a bonus.
class MoodCatcher extends CatchGame {
  MoodCatcher([super.rnd]);
  static const good = [('😊', Color(0xFFFFC94D)), ('😌', Color(0xFF7FD3C5)), ('🙂', Color(0xFF8FB8FF)), ('🥰', Color(0xFFFF8FB1))];
  @override
  String get tip => 'Noticing and naming a feeling can make it easier to choose what to do next.';
  @override
  String? get meterLabel => 'Calm';

  @override
  Faller makeGood(Offset p, Offset v) {
    final g = good[rnd.nextInt(good.length)];
    return Faller(p, v, 20, 0, g.$1, g.$2);
  }

  @override
  Faller makeBad(Offset p, Offset v) => Faller(p, v * 1.1, 22, 1, '⛈', const Color(0xFF4A4F6A));

  @override
  void onGood(Faller f) {
    gain(10, f.pos, color: f.color);
    meter += 0.1;
    if (meter >= 1) {
      meter = 0;
      gain(50, Offset(size.width / 2, size.height / 2), color: const Color(0xFF7FD3C5));
      burst(Offset(size.width / 2, size.height / 2), const Color(0xFF7FD3C5), n: 40);
    }
  }

  @override
  void onBad(Faller f) {
    meter = math.max(0, meter - 0.3);
    hit(f.pos);
  }

  @override
  void paintBackground(Canvas c) => paintBg(c, size, const [Color(0xFF1B1446), Color(0xFF2B1B4F), Color(0xFF3A2150)]);

  @override
  void paintCatcher(Canvas c, Rect r) {
    final path = Path()
      ..moveTo(r.left, r.top)
      ..lineTo(r.right, r.top)
      ..lineTo(r.right - 14, r.bottom)
      ..lineTo(r.left + 14, r.bottom)
      ..close();
    c.drawPath(path, Paint()..color = const Color(0xFFFF8FB1));
    c.drawLine(
        r.topLeft,
        r.topRight,
        Paint()
          ..color = Colors.white
          ..strokeWidth = 3);
  }
}

/// Financial: catch coins to reach a SAMPLE savings goal; impulse buys cost a life.
class CoinSaver extends CatchGame {
  CoinSaver([super.rnd]);
  static const coins = [1, 2, 5, 10];
  static const impulses = ['🛍', '🍔', '📱', '🎮', '👟'];
  int saved = 0;
  int goal = 100;
  @override
  String get tip => 'Saving a small fixed amount first, before spending, makes goals easier to reach.';
  @override
  String? get meterLabel => 'SAMPLE goal ₹$saved / ₹$goal';

  @override
  Faller makeGood(Offset p, Offset v) {
    final k = coins[rnd.nextInt(coins.length)];
    return Faller(p, v, 14.0 + k, 0, '₹$k', k >= 5 ? const Color(0xFFFFC107) : const Color(0xFFB0BEC5));
  }

  @override
  Faller makeBad(Offset p, Offset v) => Faller(p, v, 22, 1, impulses[rnd.nextInt(impulses.length)], const Color(0xFFE53970));

  @override
  void onGood(Faller f) {
    final k = int.parse(f.glyph.substring(1));
    saved += k;
    gain(k * 2, f.pos, color: f.color);
    if (saved >= goal) {
      gain(50, Offset(size.width / 2, size.height / 2), color: const Color(0xFFFFC107));
      burst(Offset(size.width / 2, size.height / 2), const Color(0xFFFFC107), n: 40);
      saved = 0;
      goal += 50;
    }
    meter = saved / goal;
  }

  @override
  void onBad(Faller f) {
    saved = math.max(0, saved - 10);
    meter = saved / goal;
    hit(f.pos);
  }

  @override
  void paintBackground(Canvas c) => paintBg(c, size, const [Color(0xFF0E2A2A), Color(0xFF123B34), Color(0xFF16302A)]);

  @override
  void paintCatcher(Canvas c, Rect r) {
    final jar = RRect.fromRectAndCorners(r.inflate(4), bottomLeft: const Radius.circular(14), bottomRight: const Radius.circular(14));
    c.drawRRect(jar, Paint()..color = const Color(0x8890CAF9));
    final fill = Rect.fromLTRB(r.left, r.bottom - r.height * meter.clamp(0, 1), r.right, r.bottom);
    c.drawRect(fill, Paint()..color = const Color(0xFFFFC107));
    c.drawRRect(
        jar,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..color = Colors.white);
    Glyphs.text(c, 'SAVE', r.center, 12, Colors.white, bold: true);
  }
}
