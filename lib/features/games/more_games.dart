import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../core/services/haptics.dart';
import 'arcade.dart';

double _segDist(Offset p, Offset a, Offset b) {
  final ab = b - a;
  final l2 = ab.distanceSquared;
  if (l2 == 0) return (p - a).distance;
  final t = (((p - a).dx * ab.dx + (p - a).dy * ab.dy) / l2).clamp(0.0, 1.0);
  return (p - (a + ab * t)).distance;
}

// ───────────────────────── Emotional: CalmBubble Calm ─────────────────────────
class CalmBubble {
  CalmBubble(this.pos, this.r, this.kind, this.vy, this.phase);
  Offset pos;
  final double r;
  final int kind; // 0..3 colours, 4 = stress
  final double vy, phase;
}

/// Pop same-colour bubbles in chains before the pressure fills up. Dark stress bubbles cost a life.
class BubbleCalm extends Arcade {
  BubbleCalm([super.rnd]);
  static const colors = [Color(0xFF7FD3C5), Color(0xFFFF8FB1), Color(0xFF8FB8FF), Color(0xFFFFC94D)];
  final bubbles = <CalmBubble>[];
  double spawnIn = 0;
  int get cap => 38;
  @override
  String get tip => 'When worries pile up, handling one small thing at a time can feel lighter.';
  @override
  String? get meterLabel => 'Pressure';

  @override
  void start() {
    for (var i = 0; i < 14; i++) {
      _spawn(Offset(30 + rnd.nextDouble() * (size.width - 60), 140 + rnd.nextDouble() * (size.height - 260)));
    }
  }

  void _spawn([Offset? at]) {
    final stress = level >= 2 && rnd.nextDouble() < math.min(0.18, 0.05 + 0.02 * level);
    bubbles.add(CalmBubble(at ?? Offset(30 + rnd.nextDouble() * (size.width - 60), size.height + 30), 20 + rnd.nextDouble() * 10,
        stress ? 4 : rnd.nextInt(colors.length), -(30 + rnd.nextDouble() * 30), rnd.nextDouble() * 6));
  }

  @override
  void update(double dt) {
    spawnIn -= dt;
    if (spawnIn <= 0) {
      spawnIn = math.max(0.28, 0.85 - 0.06 * level);
      _spawn();
    }
    const top = 90.0;
    for (final b in bubbles) {
      final x = b.pos.dx + math.sin(t * 1.4 + b.phase) * 12 * dt;
      b.pos = Offset(x.clamp(b.r, size.width - b.r), math.max(top + b.r, b.pos.dy + b.vy * dt));
    }
    // Soft separation so bubbles pile up instead of overlapping.
    for (var i = 0; i < bubbles.length; i++) {
      for (var j = i + 1; j < bubbles.length; j++) {
        final a = bubbles[i], b = bubbles[j];
        final d = b.pos - a.pos;
        final m = a.r + b.r;
        final dist = d.distance;
        if (dist > 0.01 && dist < m) {
          final push = d / dist * ((m - dist) / 2);
          a.pos -= push;
          b.pos += push;
        }
      }
    }
    meter = (bubbles.length / cap).clamp(0.0, 1.0);
    if (bubbles.length >= cap) {
      hit(Offset(size.width / 2, top + 40));
      bubbles.shuffle(rnd);
      bubbles.removeRange(0, 15);
    }
  }

  @override
  void pointerDown(Offset p) {
    CalmBubble? hitB;
    for (final b in bubbles) {
      if ((b.pos - p).distance <= b.r + 8) hitB = b;
    }
    if (hitB == null) return;
    if (hitB.kind == 4) {
      bubbles.remove(hitB);
      hit(hitB.pos);
      return;
    }
    final chain = <CalmBubble>{hitB};
    final queue = [hitB];
    while (queue.isNotEmpty) {
      final c = queue.removeLast();
      for (final o in bubbles) {
        if (o.kind == hitB.kind && !chain.contains(o) && (o.pos - c.pos).distance < c.r + o.r + 14) {
          chain.add(o);
          queue.add(o);
        }
      }
    }
    for (final b in chain) {
      burst(b.pos, colors[b.kind], n: 8);
    }
    bubbles.removeWhere(chain.contains);
    if (chain.length == 1) {
      miss();
      score += 2;
      bumpHud();
    } else {
      gain(10 * chain.length + (chain.length >= 4 ? 20 : 0), hitB.pos, color: colors[hitB.kind]);
    }
  }

  @override
  void paint(Canvas c) {
    paintBg(c, size, const [Color(0xFF14204A), Color(0xFF233467), Color(0xFF3A2D6B)]);
    c.drawRect(Rect.fromLTWH(0, 0, size.width, 90), Paint()..color = Color.lerp(const Color(0x22FFFFFF), const Color(0x66FF6B6B), meter)!);
    for (final b in bubbles) {
      final col = b.kind == 4 ? const Color(0xFF3B3F55) : colors[b.kind];
      c.drawCircle(b.pos, b.r, Paint()..color = col.withOpacity(0.8));
      c.drawCircle(b.pos - Offset(b.r * 0.35, b.r * 0.35), b.r * 0.25, Paint()..color = Colors.white.withOpacity(0.55));
      if (b.kind == 4) Glyphs.text(c, '😣', b.pos, b.r, Colors.white);
    }
  }
}

// ───────────────────────── Physical: Step Jump ─────────────────────────
class Plat {
  Plat(this.x, this.y, this.w, this.vx);
  double x, y, w, vx;
  String? item;
}

/// Platform hopper: steer left/right, bounce upward, collect water and fruit.
class StepJump extends Arcade {
  StepJump([super.rnd]);
  double px = 0, py = 0, vy = 0, targetX = 0, camY = 0, best = 0;
  final plats = <Plat>[];
  static const g = 1500.0, bounce = -860.0;
  static const items = ['💧', '🍎', '🍌', '🥕'];
  @override
  String get tip => 'Short bursts of movement through the day add up. Keep water nearby.';
  @override
  int get levelEvery => 200;

  @override
  void start() {
    px = targetX = size.width / 2;
    py = size.height - 120;
    plats.add(Plat(size.width / 2 - 60, size.height - 60, 120, 0));
    var y = size.height - 60;
    while (y > -400) {
      y -= _gap();
      _add(y);
    }
  }

  double _gap() => 70 + rnd.nextDouble() * math.min(70, 30 + 6.0 * level);

  void _add(double y) {
    final w = math.max(56.0, 96 - 4.0 * level);
    final p = Plat(rnd.nextDouble() * (size.width - w), y, w, level >= 2 && rnd.nextDouble() < 0.3 ? (rnd.nextBool() ? 60 : -60) : 0);
    if (rnd.nextDouble() < 0.35) p.item = items[rnd.nextInt(items.length)];
    plats.add(p);
  }

  @override
  void pointerDown(Offset p) => targetX = p.dx;
  @override
  void pointerMove(Offset p, Offset delta) => targetX = p.dx;

  @override
  void update(double dt) {
    final prevBottom = py;
    px += (targetX - px) * math.min(1, dt * 9);
    vy += g * dt;
    py += vy * dt;
    for (final p in plats) {
      if (p.vx != 0) {
        p.x += p.vx * dt;
        if (p.x < 0 || p.x + p.w > size.width) p.vx = -p.vx;
      }
      if (vy > 0 && prevBottom <= p.y && py >= p.y && px > p.x - 10 && px < p.x + p.w + 10) {
        py = p.y;
        vy = bounce;
        Haptics.light();
      }
      if (p.item != null && (Offset(px, py - 18) - Offset(p.x + p.w / 2, p.y - 22)).distance < 30) {
        gain(p.item == '💧' ? 15 : 10, Offset(p.x + p.w / 2 - 0, p.y - 22 - camY), color: const Color(0xFF64B5F6));
        p.item = null;
      }
    }
    if (py - camY < size.height * 0.4) camY = py - size.height * 0.4;
    final h = (size.height - 120 - py) / 10;
    if (h > best + 1) {
      score += (h - best).floor();
      best = h.floorToDouble();
      level = 1 + score ~/ levelEvery;
      bumpHud();
    }
    plats.removeWhere((p) => p.y > camY + size.height + 80);
    var top = plats.map((p) => p.y).fold(double.infinity, math.min);
    while (top > camY - 300) {
      top -= _gap();
      _add(top);
    }
    if (py - camY > size.height + 40) {
      hit(Offset(px, size.height - 40));
      if (!over) {
        final vis = plats.where((p) => p.y > camY + size.height * 0.5 && p.y < camY + size.height - 40).toList();
        final p = vis.isEmpty ? (plats..sort((a, b) => b.y.compareTo(a.y))).first : vis.first;
        px = targetX = p.x + p.w / 2;
        py = p.y;
        vy = bounce;
      }
    }
  }

  @override
  void paint(Canvas c) {
    paintBg(c, size, const [Color(0xFF0D3B66), Color(0xFF1E6091), Color(0xFF168AAD)]);
    final pp = Paint()..color = const Color(0xFF99D98C);
    for (final p in plats) {
      final r = RRect.fromRectAndRadius(Rect.fromLTWH(p.x, p.y - camY, p.w, 12), const Radius.circular(6));
      c.drawRRect(r, pp..color = p.vx != 0 ? const Color(0xFFFFD166) : const Color(0xFF99D98C));
      if (p.item != null) Glyphs.text(c, p.item!, Offset(p.x + p.w / 2, p.y - 22 - camY), 22, Colors.white);
    }
    if (!(invuln > 0 && (t * 10).floor().isEven)) {
      final o = Offset(px, py - camY - 18);
      c.drawCircle(o, 16, Paint()..color = const Color(0xFFFF8FB1));
      c.drawCircle(o + const Offset(-5, -3), 3, Paint()..color = Colors.white);
      c.drawCircle(o + const Offset(5, -3), 3, Paint()..color = Colors.white);
    }
  }
}

// ───────────────────────── Occupational: Inbox Zero ─────────────────────────
class Mail {
  Mail(this.pos, this.vel, this.spam, this.glyph);
  Offset pos, vel;
  final bool spam;
  final String glyph;
  bool done = false;
}

/// Swipe to slice spam; tap to keep important mail. Slicing important mail costs a life.
class InboxZero extends Arcade {
  InboxZero([super.rnd]);
  final mails = <Mail>[];
  final trail = <Offset>[];
  double spawnIn = 0.5, moved = 0;
  Offset? last;
  static const g = 900.0, r = 26.0;
  static const spamG = ['📢', '🎰', '🤑', '🔔'];
  static const keepG = ['📩', '⭐', '📅'];
  @override
  String get tip => 'Checking email at set times, rather than constantly, can protect focus for deeper work.';
  @override
  String? get meterLabel => 'Inbox clutter';

  @override
  void start() {}

  void _spawn() {
    final x = size.width * (0.2 + rnd.nextDouble() * 0.6);
    final h = size.height * (0.55 + rnd.nextDouble() * 0.25);
    final vx = (size.width / 2 - x) * (0.4 + rnd.nextDouble() * 0.5);
    final spam = rnd.nextDouble() < math.min(0.75, 0.6 + 0.02 * level);
    mails.add(Mail(Offset(x, size.height + 30), Offset(vx, -math.sqrt(2 * g * h)), spam,
        spam ? spamG[rnd.nextInt(spamG.length)] : keepG[rnd.nextInt(keepG.length)]));
  }

  void _clutter(Offset at) {
    miss();
    meter += 0.2;
    if (meter >= 1) {
      meter = 0;
      hit(at);
    }
    bumpHud();
  }

  @override
  void update(double dt) {
    spawnIn -= dt;
    if (spawnIn <= 0) {
      spawnIn = math.max(0.45, 1.2 - 0.07 * level);
      final n = 1 + rnd.nextInt(math.min(3, 1 + level ~/ 2));
      for (var i = 0; i < n; i++) {
        _spawn();
      }
    }
    for (final m in mails) {
      m.vel += Offset(0, g * dt);
      m.pos += m.vel * dt;
      if (!m.done && m.vel.dy > 0 && m.pos.dy > size.height + 40) {
        m.done = true;
        _clutter(Offset(m.pos.dx, size.height - 30));
      }
    }
    mails.removeWhere((m) => m.done);
    if (trail.length > 8) trail.removeRange(0, trail.length - 8);
  }

  @override
  void pointerDown(Offset p) {
    last = p;
    moved = 0;
    trail
      ..clear()
      ..add(p);
  }

  @override
  void pointerMove(Offset p, Offset delta) {
    final a = last ?? p;
    moved += (p - a).distance;
    last = p;
    trail.add(p);
    if (moved < 18) return;
    for (final m in mails) {
      if (!m.done && _segDist(m.pos, a, p) < r) {
        m.done = true;
        if (m.spam) {
          gain(10, m.pos, color: const Color(0xFFFF6B6B));
        } else {
          hit(m.pos);
        }
      }
    }
  }

  @override
  void pointerUp(Offset p) {
    if (moved < 12) {
      for (final m in mails) {
        if (!m.done && !m.spam && (m.pos - p).distance < r + 12) {
          m.done = true;
          gain(15, m.pos, color: const Color(0xFFFFC94D));
          break;
        }
      }
    }
    last = null;
    trail.clear();
  }

  @override
  void paint(Canvas c) {
    paintBg(c, size, const [Color(0xFF2B1B10), Color(0xFF4A2A12), Color(0xFF6B3A12)]);
    for (final m in mails) {
      c.drawCircle(m.pos, r, Paint()..color = m.spam ? const Color(0xFFE53935) : const Color(0xFFFFB300));
      Glyphs.text(c, m.glyph, m.pos, 24, Colors.white);
    }
    if (trail.length > 1) {
      final path = Path()..moveTo(trail.first.dx, trail.first.dy);
      for (final p in trail.skip(1)) {
        path.lineTo(p.dx, p.dy);
      }
      c.drawPath(
          path,
          Paint()
            ..color = Colors.white.withOpacity(0.8)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 4
            ..strokeCap = StrokeCap.round);
    }
  }
}

// ───────────────────────── Social: Pass the Smile ─────────────────────────
/// One-tap timing: toss a smile straight up to a friend moving across the top.
class PassTheSmile extends Arcade {
  PassTheSmile([super.rnd]);
  double ballX = 0, ballY = 0, amp = 0, freq = 1.2, phase = 0, myFreq = 0.8;
  bool flying = false;
  double cloudX = -100, cloudV = 0;
  double get fromY => size.height - 150;
  double get toY => 200;
  double get friendX => size.width / 2 + amp * math.sin(t * freq + phase);
  double get meX => size.width / 2 + size.width * 0.25 * math.sin(t * myFreq);
  @override
  String get tip => 'A quick, kind message to someone can brighten both of your days.';

  @override
  void start() => _round();

  void _round() {
    amp = size.width * (0.25 + rnd.nextDouble() * 0.15);
    freq = 1.0 + 0.15 * level + rnd.nextDouble() * 0.5;
    phase = rnd.nextDouble() * 6;
    myFreq = 0.6 + rnd.nextDouble() * 0.5;
    flying = false;
    if (level >= 2) {
      cloudV = (rnd.nextBool() ? 1 : -1) * (80 + 15.0 * level);
      cloudX = cloudV > 0 ? -40 : size.width + 40;
    }
  }

  @override
  void pointerDown(Offset p) {
    if (flying) return;
    flying = true;
    ballX = meX;
    ballY = fromY - 30;
  }

  @override
  void update(double dt) {
    if (level >= 2) {
      cloudX += cloudV * dt;
      if (cloudX < -60 || cloudX > size.width + 60) cloudV = -cloudV;
    }
    if (!flying) return;
    ballY -= 950 * dt;
    final cy = (fromY + toY) / 2;
    if (level >= 2 && (Offset(ballX, ballY) - Offset(cloudX, cy)).distance < 42) {
      hit(Offset(ballX, ballY));
      _round();
      return;
    }
    if (ballY <= toY + 20) {
      final d = (ballX - friendX).abs();
      if (d < 40) {
        gain(d < 12 ? 25 : 10, Offset(friendX, toY), color: const Color(0xFFFFC94D));
        if (d < 12 && fx) floats.add(FloatText('Perfect!', Offset(friendX, toY + 40), 0.8));
      } else {
        hit(Offset(ballX, toY));
      }
      _round();
    }
  }

  @override
  void paint(Canvas c) {
    paintBg(c, size, const [Color(0xFF00423D), Color(0xFF00695C), Color(0xFF26A69A)]);
    final rail = Paint()
      ..color = Colors.white24
      ..strokeWidth = 2;
    c.drawLine(Offset(0, toY), Offset(size.width, toY), rail);
    c.drawLine(Offset(0, fromY), Offset(size.width, fromY), rail);
    Glyphs.text(c, '🧑', Offset(friendX, toY), 40, Colors.white);
    Glyphs.text(c, '🙋', Offset(meX, fromY), 40, Colors.white);
    if (level >= 2) Glyphs.text(c, '☁', Offset(cloudX, (fromY + toY) / 2), 54, Colors.white70);
    Glyphs.text(c, '😊', flying ? Offset(ballX, ballY) : Offset(meX, fromY - 34), 28, Colors.white);
  }
}

// ───────────────────────── Spiritual: Balance Stones ─────────────────────────
/// Stack sliding stones; overhang is trimmed; perfect drops restore width.
class BalanceStones extends Arcade {
  BalanceStones([super.rnd]);
  final stack = <Rect>[]; // world coords: y grows downward
  double x = 0, w = 0, dir = 1, camY = 0;
  static const h = 30.0;
  double get speed => 150 + 22.0 * level;
  @override
  String get tip => 'A few slow breaths before a task can help you feel steadier.';
  @override
  int get levelEvery => 120;

  @override
  void start() {
    w = size.width * 0.55;
    stack.add(Rect.fromLTWH((size.width - w) / 2, size.height - 80, w, h));
    x = 0;
  }

  double get nextY => stack.last.top - h;

  @override
  void update(double dt) {
    x += dir * speed * dt;
    if (x < 0) {
      x = 0;
      dir = 1;
    } else if (x + w > size.width) {
      x = size.width - w;
      dir = -1;
    }
    final want = nextY - size.height * 0.45;
    if (want < camY) camY += (want - camY) * math.min(1, dt * 4);
  }

  @override
  void pointerDown(Offset p) {
    final prev = stack.last;
    final l = math.max(x, prev.left), r = math.min(x + w, prev.right);
    final at = Offset(x + w / 2, nextY - camY);
    if (r - l <= 2) {
      hit(at);
      x = 0;
      return;
    }
    if ((x - prev.left).abs() < 6) {
      x = prev.left;
      w = math.min(size.width * 0.55, prev.width + 8);
      stack.add(Rect.fromLTWH(x, nextY, w, h));
      gain(20, at, color: const Color(0xFFB39DDB));
      if (fx) floats.add(FloatText('Perfect', at + const Offset(0, -24), 0.8));
    } else {
      w = r - l;
      stack.add(Rect.fromLTWH(l, nextY, w, h));
      miss();
      gain(10, at, color: const Color(0xFFD1C4E9));
      if (w < 14) {
        hit(at);
        w = size.width * 0.35;
      }
    }
    x = dir > 0 ? 0 : size.width - w;
  }

  @override
  void paint(Canvas c) {
    paintBg(c, size, const [Color(0xFF1A1033), Color(0xFF2E1F5E), Color(0xFF5E4B8B)]);
    for (var i = 0; i < stack.length; i++) {
      final s = stack[i].shift(Offset(0, -camY));
      if (s.top > size.height || s.bottom < 0) continue;
      final shade = 0.55 + 0.4 * ((i * 37) % 10) / 10;
      c.drawRRect(RRect.fromRectAndRadius(s, const Radius.circular(14)),
          Paint()..color = Color.lerp(const Color(0xFF6D6875), const Color(0xFFE5E5E5), shade)!);
    }
    c.drawRRect(
        RRect.fromRectAndRadius(Rect.fromLTWH(x, nextY - camY, w, h), const Radius.circular(14)), Paint()..color = const Color(0xFFD1C4E9));
  }
}

// ───────────────────────── Intellectual: Pattern Snake ─────────────────────────
/// Snake that must eat numbers in ascending order. Swipe or tap to turn.
class PatternSnake extends Arcade {
  PatternSnake([super.rnd]);
  static const cols = 12;
  late int rows;
  double cell = 0, top = 0, acc = 0;
  var body = <math.Point<int>>[];
  var dir = const math.Point(1, 0), nextDir = const math.Point(1, 0);
  final targets = <math.Point<int>, int>{};
  int want = 1, count = 3, grow = 0;
  Offset swipe = Offset.zero, downAt = Offset.zero;
  double get stepTime => math.max(0.08, 0.2 - 0.012 * level);
  @override
  String get tip => 'Breaking a big problem into ordered steps can make it easier to tackle.';
  @override
  String? get meterLabel => 'Next: $want of $count';

  @override
  void start() {
    cell = size.width / cols;
    top = 90;
    rows = ((size.height - top - 20) / cell).floor();
    _reset();
    _place();
  }

  void _reset() {
    final c = math.Point(cols ~/ 2, rows ~/ 2);
    body = [c, math.Point(c.x - 1, c.y), math.Point(c.x - 2, c.y)];
    dir = nextDir = const math.Point(1, 0);
  }

  void _place() {
    targets.clear();
    want = 1;
    for (var k = 1; k <= count; k++) {
      math.Point<int> p;
      do {
        p = math.Point(rnd.nextInt(cols), rnd.nextInt(rows));
      } while (body.contains(p) || targets.containsKey(p));
      targets[p] = k;
    }
    meter = 0;
    bumpHud();
  }

  void _turn(math.Point<int> d) {
    if (d.x == -dir.x && d.y == -dir.y) return;
    nextDir = d;
  }

  @override
  void pointerDown(Offset p) {
    downAt = p;
    swipe = Offset.zero;
  }

  @override
  void pointerMove(Offset p, Offset delta) {
    swipe += delta;
    if (swipe.distance > 24) {
      _turn(swipe.dx.abs() > swipe.dy.abs() ? math.Point(swipe.dx.sign.toInt(), 0) : math.Point(0, swipe.dy.sign.toInt()));
      swipe = Offset.zero;
    }
  }

  @override
  void pointerUp(Offset p) {
    if ((p - downAt).distance > 12) return;
    final h = Offset((body.first.x + 0.5) * cell, top + (body.first.y + 0.5) * cell);
    if (dir.x != 0) {
      _turn(math.Point(0, p.dy < h.dy ? -1 : 1));
    } else {
      _turn(math.Point(p.dx < h.dx ? -1 : 1, 0));
    }
  }

  Offset _px(math.Point<int> c) => Offset((c.x + 0.5) * cell, top + (c.y + 0.5) * cell);

  @override
  void update(double dt) {
    acc += dt;
    if (acc < stepTime) return;
    acc = 0;
    dir = nextDir;
    final head = math.Point(body.first.x + dir.x, body.first.y + dir.y);
    if (head.x < 0 || head.y < 0 || head.x >= cols || head.y >= rows || body.contains(head)) {
      hit(_px(body.first));
      _reset();
      return;
    }
    body.insert(0, head);
    final k = targets.remove(head);
    if (k != null) {
      if (k == want) {
        grow += 1;
        gain(10 * k, _px(head), color: const Color(0xFFFFD54F));
        want++;
        meter = (want - 1) / count;
        if (want > count) {
          gain(30, _px(head), color: const Color(0xFFFFD54F));
          count = math.min(9, count + 1);
          _place();
        }
      } else {
        hit(_px(head));
        _place();
      }
      bumpHud();
    }
    if (grow > 0) {
      grow--;
    } else {
      body.removeLast();
    }
  }

  @override
  void paint(Canvas c) {
    paintBg(c, size, const [Color(0xFF2B2300), Color(0xFF3E3300), Color(0xFF574500)]);
    c.drawRect(Rect.fromLTWH(0, top, cols * cell, rows * cell), Paint()..color = Colors.black26);
    targets.forEach((p, k) {
      final o = _px(p);
      c.drawCircle(o, cell * 0.42, Paint()..color = k == want ? const Color(0xFFFFD54F) : const Color(0xFF8D6E63));
      Glyphs.text(c, '$k', o, cell * 0.5, Colors.black87, bold: true);
    });
    final blink = invuln > 0 && (t * 10).floor().isEven;
    if (blink) return;
    for (var i = body.length - 1; i >= 0; i--) {
      c.drawRRect(
          RRect.fromRectAndRadius(
              Rect.fromCenter(center: _px(body[i]), width: cell * 0.9, height: cell * 0.9), Radius.circular(cell * 0.3)),
          Paint()..color = i == 0 ? const Color(0xFF81C784) : const Color(0xFF4CAF50));
    }
  }
}

// ───────────────────────── Environmental: Tree Planter ─────────────────────────
class Smog {
  Smog(this.pos, this.v, this.hp);
  Offset pos;
  final double v;
  int hp;
}

class Leaf {
  Leaf(this.pos);
  Offset pos;
}

/// Plant trees in plots; grown trees shoot leaves that clear descending smog. Tap smog to clear it too.
class TreePlanter extends Arcade {
  TreePlanter([super.rnd]);
  static const plots = 5;
  final growth = List<double>.filled(plots, -1); // -1 empty, 0..1 growing, >=1 grown
  final reload = List<double>.filled(plots, 0);
  final smog = <Smog>[];
  final leaves = <Leaf>[];
  int seeds = 2, cleared = 0;
  double spawnIn = 1;
  double get groundY => size.height - 90;
  double plotX(int i) => size.width * (i + 0.5) / plots;
  @override
  String get tip => 'Plants and a little fresh air can make a room feel more pleasant.';
  @override
  String? get meterLabel => 'Seeds: $seeds';

  @override
  void start() {}

  void _clear(Smog s) {
    gain(10, s.pos, color: const Color(0xFFB0BEC5));
    cleared++;
    if (cleared % 3 == 0) {
      seeds = math.min(9, seeds + 1);
      if (fx) floats.add(FloatText('+1 seed', s.pos + const Offset(0, 24), 0.8));
    }
    meter = (seeds / 9).clamp(0.0, 1.0);
  }

  @override
  void update(double dt) {
    spawnIn -= dt;
    if (spawnIn <= 0) {
      spawnIn = math.max(0.55, 1.6 - 0.1 * level);
      smog.add(Smog(Offset(plotX(rnd.nextInt(plots)) + (rnd.nextDouble() - 0.5) * 30, 70), 40 + 6.0 * level + rnd.nextDouble() * 20,
          level >= 3 && rnd.nextDouble() < 0.4 ? 2 : 1));
    }
    for (var i = 0; i < plots; i++) {
      if (growth[i] >= 0 && growth[i] < 1) growth[i] = math.min(1, growth[i] + dt * 0.5);
      if (growth[i] >= 1) {
        reload[i] -= dt;
        if (reload[i] <= 0 && smog.any((s) => (s.pos.dx - plotX(i)).abs() < 40)) {
          reload[i] = 1.1;
          leaves.add(Leaf(Offset(plotX(i), groundY - 50)));
        }
      }
    }
    for (final l in leaves) {
      l.pos += Offset(0, -420 * dt);
    }
    for (final s in smog) {
      s.pos += Offset(0, s.v * dt);
      for (final l in leaves) {
        if (l.pos.dy > -10 && (l.pos - s.pos).distance < 30) {
          l.pos = const Offset(0, -100);
          s.hp--;
          if (s.hp == 0) _clear(s);
        }
      }
      if (s.hp > 0 && s.pos.dy >= groundY - 40) {
        s.hp = 0;
        final i = ((s.pos.dx / size.width) * plots).floor().clamp(0, plots - 1);
        if (growth[i] >= 0) {
          growth[i] = -1;
          miss();
          burst(Offset(plotX(i), groundY - 30), const Color(0xFF8D6E63));
        } else {
          hit(Offset(plotX(i), groundY));
        }
      }
    }
    smog.removeWhere((s) => s.hp <= 0);
    leaves.removeWhere((l) => l.pos.dy < -20);
  }

  @override
  void pointerDown(Offset p) {
    for (final s in smog) {
      if ((s.pos - p).distance < 40) {
        s.hp--;
        if (s.hp == 0) _clear(s);
        return;
      }
    }
    if (p.dy > groundY - 80) {
      final i = ((p.dx / size.width) * plots).floor().clamp(0, plots - 1);
      if (growth[i] < 0 && seeds > 0) {
        seeds--;
        growth[i] = 0;
        meter = seeds / 9;
        burst(Offset(plotX(i), groundY), const Color(0xFF81C784), n: 8);
        bumpHud();
      }
    }
  }

  @override
  void paint(Canvas c) {
    final clean = (1 - smog.length / 12).clamp(0.0, 1.0);
    paintBg(c, size, [
      Color.lerp(const Color(0xFF5D5D5D), const Color(0xFF4FC3F7), clean)!,
      Color.lerp(const Color(0xFF7A7A7A), const Color(0xFFB3E5FC), clean)!
    ]);
    c.drawRect(Rect.fromLTWH(0, groundY, size.width, size.height - groundY), Paint()..color = const Color(0xFF6D4C41));
    for (var i = 0; i < plots; i++) {
      final o = Offset(plotX(i), groundY);
      if (growth[i] < 0) {
        c.drawOval(Rect.fromCenter(center: o + const Offset(0, 6), width: 46, height: 14), Paint()..color = const Color(0xFF4E342E));
      } else {
        final s = 0.3 + 0.7 * growth[i];
        c.drawRect(Rect.fromCenter(center: o - Offset(0, 14 * s), width: 8, height: 28 * s), Paint()..color = const Color(0xFF795548));
        c.drawCircle(o - Offset(0, 40 * s), 24 * s, Paint()..color = const Color(0xFF43A047));
      }
    }
    for (final l in leaves) {
      c.drawOval(Rect.fromCenter(center: l.pos, width: 10, height: 16), Paint()..color = const Color(0xFF9CCC65));
    }
    for (final s in smog) {
      final p = Paint()..color = (s.hp > 1 ? const Color(0xFF424242) : const Color(0xFF757575)).withOpacity(0.9);
      c.drawCircle(s.pos, 22, p);
      c.drawCircle(s.pos + const Offset(-18, 6), 15, p);
      c.drawCircle(s.pos + const Offset(18, 6), 15, p);
    }
  }
}

// ───────────────────────── Financial: Coin Run ─────────────────────────
class Lane {
  Lane(this.lane, this.y, this.kind);
  final int lane;
  double y;
  final int kind; // 0 coin, 1 debt trap, 2 big coin
  bool done = false;
}

/// Three-lane runner: collect SAMPLE ₹ coins, avoid debt traps. A full savings streak gives a shield.
class CoinRun extends Arcade {
  CoinRun([super.rnd]);
  int lane = 1, saved = 0;
  double drawX = 0, spawnIn = 0, road = 0;
  Offset downAt = Offset.zero;
  double swipe = 0;
  final objs = <Lane>[];
  double get speed => 300 + 28.0 * level;
  double laneX(int i) => size.width * (i + 0.5) / 3;
  double get py => size.height - 130;
  @override
  String get tip => 'Small, steady habits can add up over time. SAMPLE ₹ only; not financial advice.';
  @override
  String? get meterLabel => 'Streak · SAMPLE ₹$saved';

  @override
  void start() => drawX = laneX(1);

  void _move(int d) => lane = (lane + d).clamp(0, 2);

  @override
  void pointerDown(Offset p) {
    downAt = p;
    swipe = 0;
  }

  @override
  void pointerMove(Offset p, Offset delta) {
    swipe += delta.dx;
    if (swipe.abs() > 30) {
      _move(swipe.sign.toInt());
      swipe = 0;
    }
  }

  @override
  void pointerUp(Offset p) {
    if ((p - downAt).distance < 12) _move(p.dx < size.width / 2 ? -1 : 1);
  }

  @override
  void update(double dt) {
    road = (road + speed * dt) % 80;
    drawX += (laneX(lane) - drawX) * math.min(1, dt * 14);
    spawnIn -= dt;
    if (spawnIn <= 0) {
      spawnIn = math.max(0.38, 0.8 - 0.04 * level);
      final trap = rnd.nextDouble() < math.min(0.6, 0.35 + 0.03 * level) ? rnd.nextInt(3) : -1;
      final trap2 = level >= 4 && trap >= 0 && rnd.nextDouble() < 0.3 ? (trap + 1 + rnd.nextInt(2)) % 3 : -1;
      for (var i = 0; i < 3; i++) {
        if (i == trap || i == trap2) {
          objs.add(Lane(i, -30, 1));
        } else if (rnd.nextDouble() < 0.45) {
          objs.add(Lane(i, -30, rnd.nextDouble() < 0.1 ? 2 : 0));
        }
      }
    }
    for (final o in objs) {
      o.y += speed * dt;
      if (!o.done && o.lane == lane && (o.y - py).abs() < 30) {
        o.done = true;
        final at = Offset(laneX(o.lane), py);
        if (o.kind == 1) {
          meter = 0;
          hit(at);
        } else {
          final v = o.kind == 2 ? 10 : 2;
          saved += v;
          gain(v * 2, at, color: const Color(0xFFFFC107));
          meter += 0.07;
          if (meter >= 1) {
            meter = 0;
            invuln = 3;
            if (fx) floats.add(FloatText('Shield!', at + const Offset(0, -30), 0.8));
          }
        }
      }
    }
    objs.removeWhere((o) => o.done || o.y > size.height + 40);
  }

  @override
  void paint(Canvas c) {
    paintBg(c, size, const [Color(0xFF0B1033), Color(0xFF1A237E), Color(0xFF283593)]);
    final line = Paint()
      ..color = Colors.white24
      ..strokeWidth = 3;
    for (var i = 1; i < 3; i++) {
      final x = size.width * i / 3;
      for (var y = -80 + road; y < size.height; y += 80) {
        c.drawLine(Offset(x, y), Offset(x, y + 40), line);
      }
    }
    for (final o in objs) {
      final at = Offset(laneX(o.lane), o.y);
      if (o.kind == 1) {
        c.drawRRect(RRect.fromRectAndRadius(Rect.fromCenter(center: at, width: 70, height: 40), const Radius.circular(8)),
            Paint()..color = const Color(0xFFE53970));
        Glyphs.text(c, 'DEBT', at, 14, Colors.white, bold: true);
      } else {
        c.drawCircle(at, o.kind == 2 ? 20 : 15, Paint()..color = o.kind == 2 ? const Color(0xFFFFC107) : const Color(0xFFFFD54F));
        Glyphs.text(c, '₹', at, o.kind == 2 ? 20 : 15, Colors.black87, bold: true);
      }
    }
    final me = Offset(drawX, py);
    if (invuln > 0) c.drawCircle(me, 34, Paint()..color = const Color(0x5582B1FF));
    Glyphs.text(c, '🏃', me, 40, Colors.white);
  }
}
