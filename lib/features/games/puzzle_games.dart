import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'arcade.dart';

class Bubble {
  Bubble(this.pos, this.vel, this.kind);
  Offset pos, vel;
  final int kind;
  double age = 0;
  bool dead = false;
}

/// Social: drag through same-colour friend bubbles to link them; release to connect.
/// Bubbles that drift off-screen unlinked cost a life.
class ConnectFriends extends Arcade {
  ConnectFriends([super.rnd]) {
    lives = 5;
  }
  static const colors = [Color(0xFFFF8FB1), Color(0xFF7FD3C5), Color(0xFFFFC94D), Color(0xFF8FB8FF)];
  static const faces = ['🙂', '😄', '😎', '🤗'];
  final bubbles = <Bubble>[];
  final chain = <Bubble>[];
  Offset? finger;
  double spawnIn = 0;
  static const r = 26.0;
  double get drift => 30 + 6.0 * (level - 1);
  double get lifeSpan => math.max(5.5, 9 - 0.4 * (level - 1));
  @override
  String get tip => 'Small, regular check-ins keep friendships connected.';

  @override
  void start() {
    for (var i = 0; i < 8; i++) {
      _spawn();
    }
  }

  void _spawn() {
    final kinds = math.min(colors.length, 2 + level ~/ 2);
    for (var a = 0; a < 20; a++) {
      final p = Offset(r + 10 + rnd.nextDouble() * (size.width - 2 * r - 20), 100 + rnd.nextDouble() * (size.height - 180));
      if (bubbles.every((b) => (b.pos - p).distance > 2.4 * r)) {
        final ang = rnd.nextDouble() * math.pi * 2;
        bubbles.add(Bubble(p, Offset(math.cos(ang), math.sin(ang)) * drift, rnd.nextInt(kinds)));
        return;
      }
    }
  }

  @override
  void update(double dt) {
    spawnIn -= dt;
    if (spawnIn <= 0 && bubbles.length < 14) {
      spawnIn = math.max(0.35, 0.9 - 0.05 * level);
      _spawn();
    }
    for (final b in bubbles) {
      b.age += dt;
      if (!chain.contains(b)) {
        b.pos += b.vel * dt;
        if (b.pos.dx < r || b.pos.dx > size.width - r) b.vel = Offset(-b.vel.dx, b.vel.dy);
        if (b.pos.dy < 90 || b.pos.dy > size.height - r) b.vel = Offset(b.vel.dx, -b.vel.dy);
        b.pos = Offset(b.pos.dx.clamp(r, size.width - r), b.pos.dy.clamp(90, size.height - r));
      }
      if (b.age > lifeSpan) {
        b.dead = true;
        chain.remove(b);
        hit(b.pos);
      }
    }
    bubbles.removeWhere((b) => b.dead);
  }

  Bubble? _at(Offset p) {
    for (final b in bubbles) {
      if ((b.pos - p).distance < r + 6) return b;
    }
    return null;
  }

  @override
  void pointerDown(Offset p) {
    chain.clear();
    finger = p;
    final b = _at(p);
    if (b != null) chain.add(b);
  }

  @override
  void pointerMove(Offset p, Offset delta) {
    finger = p;
    final b = _at(p);
    if (b == null) return;
    if (chain.isEmpty) {
      chain.add(b);
    } else if (chain.length >= 2 && chain[chain.length - 2] == b) {
      chain.removeLast(); // backtrack
    } else if (!chain.contains(b) && b.kind == chain.first.kind && (b.pos - chain.last.pos).distance < 4.5 * r) {
      chain.add(b);
    }
  }

  @override
  void pointerUp(Offset p) {
    finger = null;
    if (chain.length >= 2) {
      final n = chain.length;
      for (final b in chain) {
        b.dead = true;
        burst(b.pos, colors[b.kind], n: 8);
      }
      gain(10 * n * (n - 1), chain.last.pos, color: colors[chain.first.kind]);
      bubbles.removeWhere((b) => b.dead);
    }
    chain.clear();
  }

  @override
  void paint(Canvas c) {
    paintBg(c, size, const [Color(0xFF2A1640), Color(0xFF3C1D4E), Color(0xFF4A2147)]);
    if (chain.isNotEmpty) {
      final path = Path()..moveTo(chain.first.pos.dx, chain.first.pos.dy);
      for (final b in chain.skip(1)) {
        path.lineTo(b.pos.dx, b.pos.dy);
      }
      if (finger != null) path.lineTo(finger!.dx, finger!.dy);
      c.drawPath(
          path,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 8
            ..strokeCap = StrokeCap.round
            ..strokeJoin = StrokeJoin.round
            ..color = colors[chain.first.kind].withOpacity(0.8));
    }
    for (final b in bubbles) {
      final fade = ((lifeSpan - b.age) / 2).clamp(0.25, 1.0);
      final inChain = chain.contains(b);
      c.drawCircle(b.pos, r + (inChain ? 4 : 0), Paint()..color = colors[b.kind].withOpacity(fade));
      // Shrinking ring = time left.
      c.drawArc(
          Rect.fromCircle(center: b.pos, radius: r + 6),
          -math.pi / 2,
          2 * math.pi * (1 - b.age / lifeSpan),
          false,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 3
            ..color = Colors.white.withOpacity(0.5 * fade));
      Glyphs.text(c, faces[b.kind], b.pos, 22, Colors.white);
    }
  }
}

class Card {
  Card(this.face);
  final int face;
  bool up = false, done = false;
  double flip = 0; // 0 = back, 1 = face (animated)
}

/// Intellectual: timed pair matching. Matches add time; clearing grows the grid.
class MemoryFlip extends Arcade {
  MemoryFlip([super.rnd]) {
    timeLeft = 40;
  }
  static const icons = ['🌿', '🌙', '⭐', '🍎', '🎈', '🎵', '📚', '🌻', '🐢', '🦋', '🧩', '☀️', '🚲', '🎨', '🍀'];
  List<Card> cards = [];
  int cols = 3, rowsN = 4;
  final open = <Card>[];
  double closeIn = 0;
  double _tick = 0;
  @override
  bool get showLives => false;
  @override
  String get tip => 'Linking new information to something you already know makes it easier to recall.';

  @override
  void start() => _deal();

  void _deal() {
    final pairs = cols * rowsN ~/ 2;
    final faces = [for (var i = 0; i < pairs; i++) i % icons.length, for (var i = 0; i < pairs; i++) i % icons.length]..shuffle(rnd);
    cards = [for (final f in faces) Card(f)];
    open.clear();
  }

  Rect cardRect(int i) {
    const top = 90.0, pad = 10.0;
    final w = (size.width - pad * (cols + 1)) / cols;
    final h = math.min(w * 1.2, (size.height - top - 20 - pad * (rowsN + 1)) / rowsN);
    final cw = math.min(w, h / 1.2);
    final ox = (size.width - (cw * cols + pad * (cols - 1))) / 2;
    return Rect.fromLTWH(ox + (i % cols) * (cw + pad), top + (i ~/ cols) * (h + pad), cw, h);
  }

  @override
  void update(double dt) {
    timeLeft = timeLeft! - dt;
    _tick += dt;
    if (_tick >= 0.25) {
      _tick = 0;
      bumpHud();
    }
    if (timeLeft! <= 0) {
      timeLeft = 0;
      over = true;
      return;
    }
    for (final c in cards) {
      final target = c.up || c.done ? 1.0 : 0.0;
      c.flip += (target - c.flip).sign * math.min((target - c.flip).abs(), dt * (fx ? 8 : 100));
    }
    if (closeIn > 0) {
      closeIn -= dt;
      if (closeIn <= 0) {
        for (final c in open) {
          c.up = false;
        }
        open.clear();
      }
    }
  }

  /// Returns true for a match (exposed for tests).
  bool? tapCard(int i) {
    if (i < 0 || i >= cards.length) return null;
    final c = cards[i];
    if (c.done || c.up || closeIn > 0) return null;
    c.up = true;
    open.add(c);
    if (open.length < 2) return null;
    final match = open[0].face == open[1].face;
    if (match) {
      for (final o in open) {
        o.done = true;
      }
      gain(20, cardRect(i).center, color: const Color(0xFF8FB8FF));
      timeLeft = timeLeft! + 3;
      open.clear();
      if (cards.every((c) => c.done)) {
        gain(50, Offset(size.width / 2, size.height / 2), color: const Color(0xFFFFC94D));
        timeLeft = timeLeft! + 10;
        if (cols * rowsN < 30) {
          if (cols <= rowsN - 1) {
            cols++;
          } else {
            rowsN++;
          }
          if (cols * rowsN % 2 == 1) rowsN++;
        }
        _deal();
      }
    } else {
      miss();
      closeIn = 0.6;
    }
    return match;
  }

  @override
  int get levelEvery => 200;

  @override
  void pointerDown(Offset p) {
    for (var i = 0; i < cards.length; i++) {
      if (cardRect(i).contains(p)) {
        tapCard(i);
        return;
      }
    }
  }

  @override
  void paint(Canvas c) {
    paintBg(c, size, const [Color(0xFF0F1B3D), Color(0xFF1A2A5A)]);
    for (var i = 0; i < cards.length; i++) {
      final card = cards[i];
      final r = cardRect(i);
      final sx = (card.flip - 0.5).abs() * 2; // squash through the middle
      final rr = Rect.fromCenter(center: r.center, width: r.width * math.max(0.05, sx), height: r.height);
      final face = card.flip > 0.5;
      c.drawRRect(RRect.fromRectAndRadius(rr, const Radius.circular(10)),
          Paint()..color = card.done ? const Color(0xFF2F5D50) : (face ? const Color(0xFFF5F7FF) : const Color(0xFF4C6EF5)));
      if (face && sx > 0.3) Glyphs.text(c, icons[card.face], r.center, r.width * 0.42, Colors.black);
      if (!face && sx > 0.3) Glyphs.text(c, '?', r.center, r.width * 0.3, Colors.white70, bold: true);
    }
  }
}
