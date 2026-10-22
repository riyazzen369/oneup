import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oneup/core/services/haptics.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final calls = <MethodCall>[];
  setUp(() {
    calls.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, (c) async {
      calls.add(c);
      return null;
    });
  });

  test('haptics is a no-op when disabled, callbacks still run', () async {
    Haptics.enabled = false;
    Haptics.light();
    Haptics.selection();
    Haptics.medium();
    Haptics.success();
    Haptics.error();
    var tapped = 0;
    int? picked;
    Haptics.tap(() => tapped++)!();
    Haptics.pick<int>((v) => picked = v)!(3);
    await Future<void>.delayed(const Duration(milliseconds: 200));
    expect(calls.where((c) => c.method.startsWith('HapticFeedback')), isEmpty);
    expect(tapped, 1);
    expect(picked, 3);
  });

  test('haptics fires when enabled', () async {
    Haptics.enabled = true;
    Haptics.light();
    await Future<void>.delayed(const Duration(milliseconds: 10));
    expect(calls.where((c) => c.method.startsWith('HapticFeedback')), isNotEmpty);
    Haptics.enabled = false;
  });
}
