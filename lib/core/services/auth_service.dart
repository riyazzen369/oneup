import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../config/env.dart';
import 'secure_store.dart';

final authServiceProvider = Provider<AuthService>((ref) => AuthService(ref.read(secureStoreProvider)));

class AuthException implements Exception {
  AuthException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// Demo/offline mode is active whenever SUPABASE_URL / key are not provided.
/// In demo mode: any valid 10-digit number, OTP 123456, profile + consent stored on device.
class AuthService {
  AuthService(this._store);
  final SecureStore _store;

  static const demoOtp = '123456';
  static const _kDemoUser = 'demo_user_v1';
  static const _kDemoProfile = 'demo_profile_v1';

  bool get isDemo => !Env.isConfigured;
  SupabaseClient get _c => Supabase.instance.client;

  Future<bool> isSignedIn() async => isDemo ? (await _store.read(_kDemoUser)) != null : _c.auth.currentSession != null;

  /// Phone must be E.164, e.g. +919876543210.
  Future<void> sendOtp(String phone) async {
    if (isDemo) return; // nothing is sent in demo mode
    await _c.auth.signInWithOtp(phone: phone);
  }

  Future<void> verifyOtp(String phone, String token) async {
    if (isDemo) {
      if (token != demoOtp) throw AuthException('Demo mode: use code $demoOtp');
      await _store.write(_kDemoUser, phone);
      return;
    }
    await _c.auth.verifyOTP(phone: phone, token: token, type: OtpType.sms);
  }

  Future<void> signInWithGoogle() async {
    if (isDemo) throw AuthException('Google sign-in is unavailable in demo mode');
    await _c.auth.signInWithOAuth(OAuthProvider.google, redirectTo: 'in.stellarone.oneup://login-callback');
  }

  Future<Map<String, dynamic>?> fetchProfile() async {
    if (isDemo) {
      final s = await _store.read(_kDemoProfile);
      return s == null ? null : jsonDecode(s) as Map<String, dynamic>;
    }
    final id = _c.auth.currentUser?.id;
    if (id == null) return null;
    return _c.from('profiles').select().eq('id', id).maybeSingle();
  }

  Future<void> _patchDemoProfile(Map<String, dynamic> patch) async {
    final p = await fetchProfile() ?? {};
    await _store.write(_kDemoProfile, jsonEncode({...p, ...patch}));
  }

  Future<void> upsertProfile({required String name, required String ageRange}) async {
    if (isDemo) return _patchDemoProfile({'name': name, 'age_range': ageRange});
    await _c.from('profiles').upsert({'id': _c.auth.currentUser!.id, 'name': name, 'age_range': ageRange});
  }

  /// E.164 number the user signed in with (read-only in Profile).
  Future<String?> currentPhone() async {
    if (isDemo) return _store.read(_kDemoUser);
    final p = _c.auth.currentUser?.phone;
    if (p == null || p.isEmpty) return null;
    return p.startsWith('+') ? p : '+$p';
  }

  Future<void> patchProfile(Map<String, dynamic> patch) async {
    if (isDemo) return _patchDemoProfile(patch);
    await _c.from('profiles').upsert({'id': _c.auth.currentUser!.id, ...patch});
  }

  Future<void> recordConsent(String version) async {
    final patch = {'consent_version': version, 'consent_at': DateTime.now().toUtc().toIso8601String()};
    if (isDemo) return _patchDemoProfile(patch);
    await _c.from('profiles').update(patch).eq('id', _c.auth.currentUser!.id);
  }

  Future<void> signOut() async {
    if (isDemo) {
      await _store.delete(_kDemoUser);
      return;
    }
    await _c.auth.signOut();
  }
}
