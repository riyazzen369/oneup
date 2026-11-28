import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:oneup/features/profile/about_screen.dart';

/// The About screen showed a stale "0.2.0" while pubspec said 0.3.0+28. Keep them in step.
void main() {
  test('About screen version matches pubspec.yaml', () {
    final m = RegExp(r'^version:\s*(\S+)\+(\d+)\s*$', multiLine: true).firstMatch(File('pubspec.yaml').readAsStringSync());
    expect(m, isNotNull, reason: 'pubspec version line not found');
    expect(kAppVersion, '${m![1]} (${m[2]})');
  });
}
