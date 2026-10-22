import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'arcade.dart';

class SortItem {
  SortItem(this.label, this.glyph, this.lane, this.pos, this.vy);
  final String label, glyph;
  final int lane;
  Offset pos;
  double vy, vx = 0;
  bool dead = false;
}

/// Items fall; drag or flick them sideways. When an item reaches the bin row it is
/// sorted into whichever lane it is over.
abstract class SortGame extends Arcade {
  SortGame([super.rnd]);
  List<(String, Color)> get lanes;
  SortItem make(Offset p, double vy);
  void onWrong(SortItem i) => hit(i.pos);
  final items = <SortItem>[];
  SortItem? held;
  Offset _vel = Offset.zero;
  double spawnIn = 0.3;
  double get binTop => size.height - 90;
  double get laneW => size.width / lanes.length;
  double get fall => 60 + 10.0 * (level - 1);
  double get spawnEvery => math.max(1.0, 2.6 - 0.15 * (level - 1));
  @override
  int get levelEvery => 100;

  int laneAt(double x) => (x / laneW).floor().clamp(0, lanes.length - 1);

  @override
  void start() {}

  @override
  void update(double dt) {
    spawnIn -= dt;
    if (spawnIn <= 0 && items.length < 4) {
      spawnIn = spawnEvery;
      items.add(make(Offset(60 + rnd.nextDouble() * (size.width - 120), 80), fall));
    }
    for (final i in items) {
      if (i == held) continue;
      i.pos += Offset(i.vx * dt, i.vy * dt);
      i.vx *= math.pow(0.02, dt).toDouble();
      if (i.pos.dx < 30 || i.pos.dx > size.width - 30) {
        i.vx = -i.vx;
        i.pos = Offset(i.pos.dx.clamp(30, size.width - 30), i.pos.dy);
      }
      if (i.pos.dy >= binTop) {
        i.dead = true;
        if (laneAt(i.pos.dx) == i.lane) {
          gain(10, i.pos, color: lanes[i.lane].$2);
          meter = math.max(0, meter - 0.05);
        } else {
          meter = math.min(1, meter + 0.25);
          if (fx) floats.add(FloatText('→ ${lanes[i.lane].$1}', i.pos - const Offset(0, 30), 0.8));
          onWrong(i);
        }
      }
    }
    items.removeWhere((i) => i.dead);
  }

  @override
  void pointerDown(Offset p) {
    SortItem? best;
    var bd = 70.0;
    for (final i in items) {
      final d = (i.pos - p).distance;
      if (d < bd) {
        bd = d;
        best = i;
      }
    }
    held = best;
    _vel = Offset.zero;
  }

  @override
  void pointerMove(Offset p, Offset delta) {
    final h = held;
    if (h == null) return;
    h.pos = Offset((h.pos.dx + delta.dx).clamp(30, size.width - 30), (h.pos.dy + math.max(0, delta.dy)).clamp(0, binTop - 1));
    _vel = _vel * 0.5 + delta * 30;
  }

  @override
  void pointerUp(Offset p) {
    final h = held;
    if (h == null) return;
    h.vx = _vel.dx.clamp(-900, 900);
    // A firm downward flick drops it fast.
    if (_vel.dy > 400) h.vy = math.max(h.vy, 600);
    held = null;
  }

  @override
  void paint(Canvas c) {
    paintBg(c, size, const [Color(0xFF14202E), Color(0xFF1B2B3D)]);
    for (var l = 0; l < lanes.length; l++) {
      final r = Rect.fromLTWH(l * laneW, binTop, laneW, size.height - binTop);
      c.drawRect(Rect.fromLTWH(l * laneW, 60, laneW, binTop - 60), Paint()..color = lanes[l].$2.withOpacity(l.isEven ? 0.05 : 0.09));
      c.drawRRect(RRect.fromRectAndRadius(r.deflate(4), const Radius.circular(12)), Paint()..color = lanes[l].$2.withOpacity(0.85));
      Glyphs.text(c, lanes[l].$1, r.center, 14, Colors.white, bold: true);
    }
    for (final i in items) {
      final hl = i == held;
      final r = RRect.fromRectAndRadius(Rect.fromCenter(center: i.pos, width: 112, height: 50), const Radius.circular(12));
      c.drawRRect(r, Paint()..color = hl ? Colors.white : const Color(0xFFECEFF4));
      if (hl) {
        c.drawRRect(
            r,
            Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = 3
              ..color = const Color(0xFF4FC3F7));
        c.drawLine(
            i.pos,
            Offset(i.pos.dx, binTop),
            Paint()
              ..color = Colors.white24
              ..strokeWidth = 2);
      }
      Glyphs.text(c, i.glyph, i.pos - const Offset(0, 9), 16, Colors.black);
      Glyphs.text(c, i.label, i.pos + const Offset(0, 12), 11, const Color(0xFF263238), bold: true);
    }
  }
}

/// Occupational: Eisenhower-style sorting. urgent+important → Do, important → Plan,
/// urgent only → Delegate, neither → Drop.
class TaskSort extends SortGame {
  TaskSort([super.rnd]);
  static int laneFor({required bool urgent, required bool important}) => important ? (urgent ? 0 : 1) : (urgent ? 2 : 3);
  // (label, urgent, important) — original example tasks.
  static const tasks = [
    ('Report due today', true, true),
    ('Fix login bug', true, true),
    ('Client call now', true, true),
    ('Learn a skill', false, true),
    ('Plan next month', false, true),
    ('Exercise slot', false, true),
    ('Book meeting room', true, false),
    ('Reply to group', true, false),
    ('Print handouts', true, false),
    ('Scroll social feed', false, false),
    ('Reorder icons', false, false),
    ('Random video', false, false),
  ];
  @override
  List<(String, Color)> get lanes => const [
        ('DO', Color(0xFFE5484D)),
        ('PLAN', Color(0xFF3E8EDE)),
        ('DELEGATE', Color(0xFFF2A93B)),
        ('DROP', Color(0xFF6B7280)),
      ];
  @override
  String get tip => 'Sorting tasks by urgency and importance helps you spend energy where it matters.';

  @override
  SortItem make(Offset p, double vy) {
    final k = tasks[rnd.nextInt(tasks.length)];
    final tag = '${k.$2 ? '⏰' : ''}${k.$3 ? '⭐' : ''}';
    return SortItem(k.$1, tag.isEmpty ? '·' : tag, laneFor(urgent: k.$2, important: k.$3), p, vy);
  }
}

/// Environmental: Wet / Dry / Hazard bins. A wrong bin raises pollution; full pollution costs a life.
/// [VERIFY] Category examples follow common Indian household guidance; rules vary by city.
class EcoSortRush extends SortGame {
  EcoSortRush([super.rnd]);
  static const waste = [
    ('Banana peel', '🍌', 0),
    ('Tea leaves', '🍵', 0),
    ('Veg scraps', '🥕', 0),
    ('Eggshells', '🥚', 0),
    ('Newspaper', '📰', 1),
    ('Plastic bottle', '🧴', 1),
    ('Cardboard', '📦', 1),
    ('Tin can', '🥫', 1),
    ('Battery', '🔋', 2),
    ('Expired medicine', '💊', 2),
    ('CFL bulb', '💡', 2),
  ];
  @override
  List<(String, Color)> get lanes => const [
        ('WET', Color(0xFF2E9E5B)),
        ('DRY', Color(0xFF3E8EDE)),
        ('HAZARD', Color(0xFFD84343)),
      ];
  @override
  String? get meterLabel => 'Pollution';
  @override
  String get tip => 'Keeping wet and dry waste separate at home makes recycling easier. Rules vary by city. [VERIFY]';

  @override
  SortItem make(Offset p, double vy) {
    final k = waste[rnd.nextInt(waste.length)];
    return SortItem(k.$1, k.$2, k.$3, p, vy);
  }

  @override
  void onWrong(SortItem i) {
    if (meter >= 1) {
      meter = 0.4;
      hit(i.pos);
    } else {
      miss();
      bumpHud();
    }
  }

  @override
  void paint(Canvas c) {
    super.paint(c);
    if (meter > 0) c.drawRect(Offset.zero & size, Paint()..color = const Color(0xFF6B5B2E).withOpacity(meter * 0.25));
    Glyphs.text(c, 'Rules vary by city', Offset(size.width / 2, binTop - 12), 10, Colors.white38);
  }
}
