import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

final secureStoreProvider = Provider<SecureStore>((ref) => SecureStore());

/// Encrypted on-device storage (Keychain on iOS, EncryptedSharedPreferences on Android).
class SecureStore {
  static const kOnboarded = 'onboarded';
  static const kConsentVersion = 'consent_version';
  static const kTheme = 'theme_mode';

  final _s = const FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  Future<String?> read(String k) => _s.read(key: k);
  Future<void> write(String k, String v) => _s.write(key: k, value: v);
  Future<void> delete(String k) => _s.delete(key: k);
  Future<void> deleteAll() => _s.deleteAll();
}
