import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/config/env.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/services/secure_store.dart';
import '../../assess/data/answer_crypto.dart';
import '../domain/user_profile.dart';
import 'avatar_codec.dart';

/// Profile details + avatar. Avatar is AES-256-GCM encrypted on device (inside secure storage)
/// and, when Supabase is configured, also kept in the private bucket `avatars/<uid>/avatar.jpg`.
class ProfileRepository {
  ProfileRepository(this._auth, this._store) : _crypto = AnswerCrypto(_store);
  final AuthService _auth;
  final SecureStore _store;
  final AnswerCrypto _crypto;
  static const kAvatar = 'avatar_v1';
  static const bucket = 'avatars';

  bool get _remote => Env.isConfigured;
  SupabaseClient get _c => Supabase.instance.client;
  String? get _uid => _remote ? _c.auth.currentUser?.id : null;
  String _path(String uid) => '$uid/avatar.jpg';

  Future<UserProfile> load() async {
    final m = await _auth.fetchProfile();
    final phone = await _auth.currentPhone() ?? '';
    final has = (await _store.read(kAvatar)) != null || (m?['avatar_path'] as String?) != null;
    return UserProfile.fromMap(m, phone: phone, hasAvatar: has);
  }

  Future<void> save(UserProfile p) => _auth.patchProfile(p.toPatch());

  Future<Uint8List?> loadAvatar() async {
    final enc = await _store.read(kAvatar);
    if (enc != null) {
      try {
        return base64Decode(await _crypto.decryptText(enc, aad: kAvatar));
      } catch (_) {
        return null;
      }
    }
    final uid = _uid;
    if (uid == null) return null;
    try {
      final bytes = await _c.storage.from(bucket).download(_path(uid));
      await _cache(bytes);
      return bytes;
    } catch (_) {
      return null;
    }
  }

  Future<void> _cache(Uint8List jpeg) async => _store.write(kAvatar, await _crypto.encryptText(base64Encode(jpeg), aad: kAvatar));

  /// Processes raw picker bytes off the UI thread, stores locally and remotely.
  Future<Uint8List> setAvatar(Uint8List raw) async {
    final jpeg = await compute(squareJpeg, raw);
    await _cache(jpeg);
    final uid = _uid;
    if (uid != null) {
      await _c.storage.from(bucket).uploadBinary(_path(uid), jpeg, fileOptions: const FileOptions(contentType: 'image/jpeg', upsert: true));
      await _auth.patchProfile({'avatar_path': _path(uid)});
    }
    return jpeg;
  }

  Future<void> removeAvatar() async {
    await _store.delete(kAvatar);
    final uid = _uid;
    if (uid != null) {
      try {
        await _c.storage.from(bucket).remove([_path(uid)]);
      } catch (_) {}
      await _auth.patchProfile({'avatar_path': null});
    }
  }

  /// Called by delete-my-data before the account is removed (storage objects can't be
  /// deleted from SQL). Local copy is wiped with the rest of secure storage.
  Future<void> deleteRemoteAvatar() async {
    final uid = _uid;
    if (uid == null) return;
    try {
      await _c.storage.from(bucket).remove([_path(uid)]);
    } catch (_) {}
  }
}

final profileRepositoryProvider =
    Provider<ProfileRepository>((ref) => ProfileRepository(ref.read(authServiceProvider), ref.read(secureStoreProvider)));

final profileProvider = FutureProvider<UserProfile>((ref) => ref.read(profileRepositoryProvider).load());
final avatarProvider = FutureProvider<Uint8List?>((ref) => ref.read(profileRepositoryProvider).loadAvatar());
