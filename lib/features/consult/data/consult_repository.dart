import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/config/env.dart';
import '../../../core/services/secure_store.dart';
import '../../assess/data/assessment_models.dart' show newUuidV4;
import '../domain/consult_logic.dart';
import 'consult_models.dart';

/// Bookings live in flutter_secure_storage (encrypted at rest). Supabase sync is
/// best-effort via the book_sample_session / cancel RPCs when configured.
class ConsultRepository {
  ConsultRepository(this._store);
  final SecureStore _store;
  static const _k = 'consult_bookings_v1';

  Future<List<Booking>> load() async {
    final s = await _store.read(_k);
    if (s == null) return [];
    try {
      return [for (final e in jsonDecode(s) as List) Booking.fromJson(e as Map<String, dynamic>)];
    } catch (_) {
      return [];
    }
  }

  Future<void> save(List<Booking> b) => _store.write(_k, jsonEncode(b.map((x) => x.toJson()).toList()));

  SupabaseClient? get _c {
    if (!Env.isConfigured) return null;
    final c = Supabase.instance.client;
    return c.auth.currentUser == null ? null : c;
  }

  Future<void> syncBook(Booking b) async {
    final c = _c;
    if (c == null) return;
    try {
      await c.rpc('book_sample_session', params: {
        'p_booking_id': b.id,
        'p_consultant_id': b.consultantId,
        'p_starts_at': b.start.toUtc().toIso8601String(),
        'p_mode': b.mode.name,
      });
    } catch (e) {
      debugPrint('Booking sync failed (kept locally): $e');
    }
  }

  Future<void> syncCancel(Booking b) async {
    final c = _c;
    if (c == null) return;
    try {
      await c.rpc('cancel_my_booking', params: {'p_booking_id': b.id});
    } catch (e) {
      debugPrint('Cancel sync failed: $e');
    }
  }
}

final consultRepoProvider = Provider((ref) => ConsultRepository(ref.read(secureStoreProvider)));

final bookingsProvider =
    StateNotifierProvider<BookingsController, List<Booking>>((ref) => BookingsController(ref.read(consultRepoProvider)));

class BookingsController extends StateNotifier<List<Booking>> {
  BookingsController(this._repo) : super(const []) {
    // Merge rather than overwrite: a booking made before the load finished must not be lost.
    _repo.load().then((b) {
      if (!mounted) return;
      final ids = b.map((x) => x.id).toSet();
      state = [...b, ...state.where((x) => !ids.contains(x.id))];
    });
  }
  final ConsultRepository _repo;

  /// Creates a booking; throws if the slot is no longer free.
  Future<Booking> book({
    required Consultant consultant,
    required DateTime start,
    required SessionMode mode,
    String notes = '',
    DateTime? now,
  }) async {
    final n = now ?? DateTime.now();
    final free = generateSlots(start, n, consultantId: consultant.id, booked: state);
    if (!free.contains(start)) throw StateError('That time is no longer available');
    if (!consultant.modes.contains(mode)) throw StateError('Mode not offered');
    final b = Booking(
      id: newUuidV4(),
      consultantId: consultant.id,
      start: start,
      mode: mode,
      notes: notes.trim(),
      createdAt: n,
    );
    state = [...state, b];
    await _repo.save(state);
    await _repo.syncBook(b);
    return b;
  }

  Future<void> cancel(String id, {DateTime? now}) async {
    final b = state.firstWhere((x) => x.id == id);
    if (!canCancel(b, now ?? DateTime.now())) throw StateError('Cannot cancel');
    b.status = BookingStatus.cancelled;
    state = [...state];
    await _repo.save(state);
    await _repo.syncCancel(b);
  }
}
