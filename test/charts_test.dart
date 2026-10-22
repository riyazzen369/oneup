import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oneup/core/theme/app_colors.dart';
import 'package:oneup/core/theme/app_theme.dart';
import 'package:oneup/features/results/radar_chart.dart';
import 'package:oneup/features/results/wellness_wheel.dart';

void main() {
  testWidgets('wheel + radar render in light/dark and report taps', (t) async {
    WellnessDimension? tapped;
    for (final th in [AppTheme.light(), AppTheme.dark()]) {
      await t.pumpWidget(MaterialApp(
        theme: th,
        home: Scaffold(
          body: ListView(children: [
            Center(
              child: WellnessWheel(
                scores: {for (final d in WellnessDimension.values) d: d.index * 12},
                overall: 42,
                size: 300,
                onTapDimension: (d) => tapped = d,
              ),
            ),
            const RadarChart(series: [
              RadarSeries('Current', Colors.blue, {WellnessDimension.social: 50})
            ]),
          ]),
        ),
      ));
      await t.pumpAndSettle();
    }
    final wheel = t.getTopLeft(find.byType(WellnessWheel));
    await t.tapAt(wheel + const Offset(170, 20)); // just right of top-centre → first segment
    expect(tapped, WellnessDimension.emotional);
  });
}
