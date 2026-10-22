import 'package:oneup/core/services/secure_store.dart';

class MemStore extends SecureStore {
  final m = <String, String>{};
  @override
  Future<String?> read(String k) async => m[k];
  @override
  Future<void> write(String k, String v) async => m[k] = v;
  @override
  Future<void> delete(String k) async => m.remove(k);
  @override
  Future<void> deleteAll() async => m.clear();
}
