import 'package:flutter_test/flutter_test.dart';
import 'package:oneup/core/services/secure_store.dart';
import 'package:oneup/features/assess/data/answer_crypto.dart';

class _MemStore extends SecureStore {
  final m = <String, String>{};
  @override
  Future<String?> read(String k) async => m[k];
  @override
  Future<void> write(String k, String v) async => m[k] = v;
}

void main() {
  test('AES-256-GCM round trip, random nonce, AAD bound', () async {
    final store = _MemStore();
    final c = AnswerCrypto(store);
    final a = await c.encrypt(4, aad: 'x:q1');
    final b = await c.encrypt(4, aad: 'x:q1');
    expect(a, isNot(b));
    expect(await c.decrypt(a, aad: 'x:q1'), 4);
    expect(() => c.decrypt(a, aad: 'x:q2'), throwsA(anything));
    // Key persists across instances.
    expect(await AnswerCrypto(store).decrypt(a, aad: 'x:q1'), 4);
  });
}
