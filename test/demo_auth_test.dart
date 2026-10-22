import 'package:flutter_test/flutter_test.dart';
import 'package:oneup/core/services/auth_service.dart';
import 'mem_store.dart';

void main() {
  test('demo mode: OTP 123456 only, local profile + consent, sign out', () async {
    final a = AuthService(MemStore());
    expect(a.isDemo, isTrue);
    expect(await a.isSignedIn(), isFalse);
    await a.sendOtp('+911234567890');
    await expectLater(a.verifyOtp('+911234567890', '000000'), throwsA(isA<AuthException>()));
    await a.verifyOtp('+911234567890', '123456');
    expect(await a.isSignedIn(), isTrue);
    await a.upsertProfile(name: 'Asha', ageRange: '25–34');
    await a.recordConsent('v1');
    final p = await a.fetchProfile();
    expect(p!['name'], 'Asha');
    expect(p['consent_version'], 'v1');
    await expectLater(a.signInWithGoogle(), throwsA(isA<AuthException>()));
    await a.signOut();
    expect(await a.isSignedIn(), isFalse);
  });
}
