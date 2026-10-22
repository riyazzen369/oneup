import 'package:flutter_test/flutter_test.dart';
import 'package:oneup/core/theme/app_colors.dart';
import 'package:oneup/core/services/haptics.dart';
import 'package:oneup/features/assess/domain/focus.dart';
import 'package:oneup/features/assess/domain/suggestion.dart';

void main() {
  const e = WellnessDimension.emotional;
  test('needs attention, no goal → Thriving range wording with gap', () {
    final s = smartSuggestion(const FocusItem(e, 30, 71, false));
    expect(s, contains('Emotional is at 30'));
    expect(s, contains('Needs Attention'));
    expect(s, contains('41 points from the Thriving range (71+)'));
  });
  test('developing with goal', () {
    final s = smartSuggestion(const FocusItem(e, 55, 80, true));
    expect(s, contains('25 points to your goal of 80'));
  });
  test('at/above target', () {
    expect(smartSuggestion(const FocusItem(e, 85, 80, true)), contains('already at or above your goal of 80'));
  });
  test('one sentence, never claims AI', () {
    for (final f in [const FocusItem(e, 10, 71, false), const FocusItem(e, 75, 90, true)]) {
      final s = smartSuggestion(f);
      expect('.'.allMatches(s).length, 1);
      expect(s.toLowerCase(), isNot(contains('ai ')));
    }
  });
  test('haptics flag can be disabled', () {
    Haptics.enabled = false;
    Haptics.light(); // no-op, must not throw
    Haptics.enabled = true;
  });
}
