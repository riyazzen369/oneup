import 'dart:convert';
import 'package:cryptography/cryptography.dart';
import '../../../core/services/secure_store.dart';

/// AES-256-GCM. Key is generated once per device and kept in flutter_secure_storage.
/// Ciphertext format: base64(nonce[12] | ciphertext | mac[16]).
class AnswerCrypto {
  AnswerCrypto(this._store);
  final SecureStore _store;
  static const _kKey = 'answer_key_v1';
  final _algo = AesGcm.with256bits();
  SecretKey? _key;

  Future<SecretKey> _getKey() async {
    if (_key != null) return _key!;
    final existing = await _store.read(_kKey);
    if (existing != null) return _key = SecretKey(base64Decode(existing));
    final k = await _algo.newSecretKey();
    await _store.write(_kKey, base64Encode(await k.extractBytes()));
    return _key = k;
  }

  /// [aad] binds ciphertext to its question so values can't be swapped between rows.
  Future<String> encryptText(String value, {required String aad}) async {
    final box = await _algo.encrypt(utf8.encode(value), secretKey: await _getKey(), aad: utf8.encode(aad));
    return base64Encode(box.concatenation());
  }

  Future<String> decryptText(String enc, {required String aad}) async {
    final box = SecretBox.fromConcatenation(base64Decode(enc), nonceLength: 12, macLength: 16);
    final clear = await _algo.decrypt(box, secretKey: await _getKey(), aad: utf8.encode(aad));
    return utf8.decode(clear);
  }

  Future<String> encrypt(int value, {required String aad}) => encryptText('$value', aad: aad);

  Future<int> decrypt(String enc, {required String aad}) async => int.parse(await decryptText(enc, aad: aad));
}
