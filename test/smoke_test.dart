import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oneup/core/theme/app_theme.dart';
import 'package:oneup/core/widgets/oneup_logo.dart';

void main() {
  testWidgets('logo renders in light and dark', (t) async {
    for (final th in [AppTheme.light(), AppTheme.dark()]) {
      await t.pumpWidget(MaterialApp(theme: th, home: const Scaffold(body: OneUpLogo(progress: 0.7))));
      expect(find.byType(OneUpLogo), findsOneWidget);
    }
  });
}
