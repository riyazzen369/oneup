import 'package:flutter_test/flutter_test.dart';
import 'package:oneup/core/theme/app_colors.dart';
import 'package:oneup/features/consult/data/consult_models.dart';
import 'package:oneup/features/consult/data/consult_repository.dart';
import 'package:oneup/features/consult/domain/consult_logic.dart';
import 'mem_store.dart';

const W = WellnessDimension.values;

void main() {
  group('recommendation mapping', () {
    test('agreed dimension → types', () {
      for (final d in [WellnessDimension.emotional, WellnessDimension.social, WellnessDimension.spiritual]) {
        expect(typesForDimension(d), [ConsultType.psychologist, ConsultType.therapist]);
      }
      expect(typesForDimension(WellnessDimension.physical), [ConsultType.nutritionist, ConsultType.wellnessCoach]);
      for (final d in [
        WellnessDimension.occupational,
        WellnessDimension.financial,
        WellnessDimension.intellectual,
        WellnessDimension.environmental
      ]) {
        expect(typesForDimension(d), [ConsultType.wellnessCoach]);
      }
    });

    test('recommendTypes keeps focus order and de-dupes', () {
      expect(recommendTypes([WellnessDimension.physical, WellnessDimension.financial, WellnessDimension.emotional]),
          [ConsultType.nutritionist, ConsultType.wellnessCoach, ConsultType.psychologist, ConsultType.therapist]);
      expect(recommendTypes([]), isEmpty);
    });

    test('recommendConsultants: type order, then dimension match, max 4, all SAMPLE', () {
      final r = recommendConsultants([WellnessDimension.spiritual], sampleConsultants);
      expect(r.map((c) => c.type).toSet(), {ConsultType.psychologist, ConsultType.therapist});
      expect(r.first.type, ConsultType.psychologist);
      expect(r.first.dimensions, contains(WellnessDimension.spiritual)); // Psychologist B lists Spiritual
      expect(r.length, lessThanOrEqualTo(4));
      expect(sampleConsultants.every((c) => c.name.startsWith('Sample ') && c.priceLabel == '₹ SAMPLE'), isTrue);
    });
  });

  group('booking logic', () {
    final now = DateTime(2026, 10, 22, 11, 30);
    final c = sampleConsultants.first;

    test('date strip = 7 days from today', () {
      final d = dateStrip(now);
      expect(d.length, 7);
      expect(d.first, DateTime(2026, 10, 22));
      expect(d.last, DateTime(2026, 10, 28));
    });

    test('slots: hourly 10–18 minus lunch, past/lead-time removed', () {
      final tomorrow = generateSlots(DateTime(2026, 10, 23), now);
      expect(tomorrow.map((s) => s.hour), [10, 11, 12, 14, 15, 16, 17, 18]);
      final today = generateSlots(DateTime(2026, 10, 22), now);
      expect(today.first.hour, 14); // 12:00 < now+1h(12:30)
    });

    test('booked slots disappear for that consultant only; cancelled ones return', () {
      final b = Booking(id: 'x', consultantId: c.id, start: DateTime(2026, 10, 23, 10), mode: SessionMode.video, createdAt: now);
      expect(generateSlots(DateTime(2026, 10, 23), now, consultantId: c.id, booked: [b]).first.hour, 11);
      expect(generateSlots(DateTime(2026, 10, 23), now, consultantId: 'other', booked: [b]).first.hour, 10);
      b.status = BookingStatus.cancelled;
      expect(generateSlots(DateTime(2026, 10, 23), now, consultantId: c.id, booked: [b]).first.hour, 10);
    });

    test('split upcoming / past, cancel & join windows', () {
      final up = Booking(id: 'u', consultantId: c.id, start: DateTime(2026, 10, 22, 14), mode: SessionMode.audio, createdAt: now);
      final old = Booking(id: 'p', consultantId: c.id, start: DateTime(2026, 10, 20, 10), mode: SessionMode.chat, createdAt: now);
      final (u, p) = splitSessions([old, up], now);
      expect(u.map((b) => b.id), ['u']);
      expect(p.map((b) => b.id), ['p']);
      expect(canCancel(up, now), isTrue);
      expect(canCancel(old, now), isFalse);
      expect(canJoin(up, now), isFalse);
      expect(canJoin(up, DateTime(2026, 10, 22, 13, 55)), isTrue);
      expect(canJoin(up, DateTime(2026, 10, 22, 14, 46)), isFalse);
    });

    test('controller books, blocks double-booking, cancels, persists', () async {
      final store = MemStore();
      final ctrl = BookingsController(ConsultRepository(store));
      await Future<void>.delayed(const Duration(milliseconds: 10));
      final start = DateTime(2026, 10, 23, 15);
      final b = await ctrl.book(consultant: c, start: start, mode: SessionMode.video, notes: ' hi ', now: now);
      expect(b.notes, 'hi');
      await expectLater(ctrl.book(consultant: c, start: start, mode: SessionMode.video, now: now), throwsStateError);
      await ctrl.cancel(b.id, now: now);
      expect(ctrl.state.single.status, BookingStatus.cancelled);
      final again = await ctrl.book(consultant: c, start: start, mode: SessionMode.audio, now: now);
      expect(again.mode, SessionMode.audio);
      final reloaded = BookingsController(ConsultRepository(store));
      await Future<void>.delayed(const Duration(milliseconds: 10));
      expect(reloaded.state.length, 2);
    });

    test('mode not offered is rejected', () async {
      final coachB = sampleConsultants.firstWhere((x) => x.name == 'Sample Wellness Coach B');
      final ctrl = BookingsController(ConsultRepository(MemStore()));
      await expectLater(
          ctrl.book(consultant: coachB, start: DateTime(2026, 10, 23, 10), mode: SessionMode.chat, now: now), throwsStateError);
    });
  });
}
