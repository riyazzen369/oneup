import 'package:flutter_test/flutter_test.dart';
import 'package:oneup/core/theme/app_colors.dart';
import 'package:oneup/features/assess/domain/focus.dart';

const e = WellnessDimension.emotional, p = WellnessDimension.physical, o = WellnessDimension.occupational;
const so = WellnessDimension.social, sp = WellnessDimension.spiritual;

void main() {
  test('Needs Attention first, then largest gap', () {
    // physical 35 (NA, gap 36), social 50 with goal 95 (gap 45), emotional 30 (NA, gap 41)
    final r = rankFocus({p: 35, so: 50, e: 30}, {so: 95});
    expect(r.map((x) => x.dimension), [e, p, so]);
    expect(r.map((x) => x.gap), [41, 36, 45]);
  });

  test('gap uses goal when set, else 71', () {
    final r = rankFocus({o: 60, sp: 60}, {sp: 90});
    expect(r.first.dimension, sp);
    expect(r.first.gap, 30);
    expect(r.first.hasGoal, isTrue);
    expect(r.last.gap, 11);
    expect(r.last.target, 71);
  });

  test('ties: lower score then wheel order; top 3 only', () {
    final r = rankFocus({sp: 50, so: 50, e: 80, p: 90}, {});
    expect(r.length, 3);
    expect(r.map((x) => x.dimension), [so, sp, e]);
  });

  test('negative gap ranks last; unassessed dims excluded', () {
    final r = rankFocus({e: 85, p: 60}, {e: 80});
    expect(r.map((x) => x.dimension), [p, e]);
    expect(r.last.gap, -5);
    expect(rankFocus({}, {e: 90}), isEmpty);
  });
}
