import '../../../core/theme/app_colors.dart';
import '../data/consult_models.dart';

/// Agreed mapping from wellness dimension → consultant types.
List<ConsultType> typesForDimension(WellnessDimension d) => switch (d) {
      WellnessDimension.emotional || WellnessDimension.social || WellnessDimension.spiritual => const [
          ConsultType.psychologist,
          ConsultType.therapist
        ],
      WellnessDimension.physical => const [ConsultType.nutritionist, ConsultType.wellnessCoach],
      WellnessDimension.occupational ||
      WellnessDimension.financial ||
      WellnessDimension.intellectual ||
      WellnessDimension.environmental =>
        const [ConsultType.wellnessCoach],
    };

/// Ordered, de-duplicated consultant types for the given focus dimensions (most important first).
List<ConsultType> recommendTypes(List<WellnessDimension> focus) {
  final out = <ConsultType>[];
  for (final d in focus) {
    for (final t in typesForDimension(d)) {
      if (!out.contains(t)) out.add(t);
    }
  }
  return out;
}

/// Consultants matching recommended types, preferring those who list the focus dimension.
List<Consultant> recommendConsultants(List<WellnessDimension> focus, List<Consultant> all, {int max = 4}) {
  final types = recommendTypes(focus);
  final picks = all.where((c) => types.contains(c.type)).toList()
    ..sort((a, b) {
      final ta = types.indexOf(a.type), tb = types.indexOf(b.type);
      if (ta != tb) return ta.compareTo(tb);
      final ma = a.dimensions.where(focus.contains).length, mb = b.dimensions.where(focus.contains).length;
      if (ma != mb) return mb.compareTo(ma);
      return a.name.compareTo(b.name);
    });
  return picks.take(max).toList();
}

/// Next [days] calendar days starting today.
List<DateTime> dateStrip(DateTime now, {int days = 7}) => [for (var i = 0; i < days; i++) DateTime(now.year, now.month, now.day + i)];

/// Locally generated SAMPLE slots: hourly 10:00–18:00 (no 13:00), excluding past
/// (needs ≥ 1h lead time) and already-booked times for this consultant.
List<DateTime> generateSlots(DateTime day, DateTime now, {String? consultantId, List<Booking> booked = const []}) {
  final taken = {
    for (final b in booked)
      if (b.status == BookingStatus.upcoming && (consultantId == null || b.consultantId == consultantId)) b.start,
  };
  return [
    for (var h = 10; h <= 18; h++)
      if (h != 13) DateTime(day.year, day.month, day.day, h),
  ].where((s) => s.isAfter(now.add(const Duration(hours: 1))) && !taken.contains(s)).toList();
}

bool isUpcoming(Booking b, DateTime now) => b.status == BookingStatus.upcoming && b.end.isAfter(now);

/// Upcoming (soonest first) and past/cancelled (newest first).
(List<Booking>, List<Booking>) splitSessions(List<Booking> all, DateTime now) {
  final up = all.where((b) => isUpcoming(b, now)).toList()..sort((a, b) => a.start.compareTo(b.start));
  final past = all.where((b) => !isUpcoming(b, now)).toList()..sort((a, b) => b.start.compareTo(a.start));
  return (up, past);
}

bool canCancel(Booking b, DateTime now) => b.status == BookingStatus.upcoming && b.start.isAfter(now);

/// Call screen is enabled from 10 min before start until the session ends.
bool canJoin(Booking b, DateTime now) =>
    b.status == BookingStatus.upcoming && !now.isBefore(b.start.subtract(const Duration(minutes: 10))) && now.isBefore(b.end);
