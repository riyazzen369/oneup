import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';

enum ConsultType {
  psychologist('Psychologist', 'psychologist', Icons.psychology_rounded),
  therapist('Therapist', 'therapist', Icons.spa_rounded),
  nutritionist('Nutritionist', 'nutritionist', Icons.restaurant_rounded),
  wellnessCoach('Wellness Coach', 'coach', Icons.sports_rounded);

  const ConsultType(this.label, this.dbValue, this.icon);
  final String label;
  final String dbValue;
  final IconData icon;
}

enum SessionMode {
  video('Video', Icons.videocam_rounded),
  audio('Audio', Icons.call_rounded),
  chat('Chat', Icons.chat_rounded);

  const SessionMode(this.label, this.icon);
  final String label;
  final IconData icon;
}

/// SAMPLE consultant. No real people, credentials or prices.
class Consultant {
  const Consultant(this.id, this.type, this.name, this.bio, this.languages, this.dimensions, this.modes);
  final String id; // same UUID as supabase seed
  final ConsultType type;
  final String name;
  final String bio;
  final List<String> languages;
  final List<WellnessDimension> dimensions;
  final List<SessionMode> modes;
  String get priceLabel => '₹ SAMPLE';
}

String _cid(int n) => '00000000-0000-4000-9000-${n.toString().padLeft(12, '0')}';
const _w = WellnessDimension.values;

final sampleConsultants = <Consultant>[
  Consultant(
      _cid(1),
      ConsultType.psychologist,
      'Sample Psychologist A',
      'SAMPLE profile. Placeholder bio for a psychologist offering supportive conversations.',
      ['English', 'Hindi'],
      [_w[0], _w[3]],
      SessionMode.values),
  Consultant(_cid(2), ConsultType.psychologist, 'Sample Psychologist B', 'SAMPLE profile. Placeholder bio for a psychologist.', ['English'],
      [_w[0], _w[4]], [SessionMode.video, SessionMode.chat]),
  Consultant(_cid(3), ConsultType.therapist, 'Sample Therapist A', 'SAMPLE profile. Placeholder bio for a therapist.', ['English', 'Hindi'],
      [_w[0], _w[3], _w[4]], SessionMode.values),
  Consultant(_cid(4), ConsultType.therapist, 'Sample Therapist B', 'SAMPLE profile. Placeholder bio for a therapist.', ['English'],
      [_w[3], _w[4]], [SessionMode.audio, SessionMode.video]),
  Consultant(_cid(5), ConsultType.nutritionist, 'Sample Nutritionist A', 'SAMPLE profile. Placeholder bio for a nutritionist.',
      ['English', 'Hindi'], [_w[1]], SessionMode.values),
  Consultant(_cid(6), ConsultType.nutritionist, 'Sample Nutritionist B', 'SAMPLE profile. Placeholder bio for a nutritionist.', ['English'],
      [_w[1]], [SessionMode.video, SessionMode.chat]),
  Consultant(_cid(7), ConsultType.wellnessCoach, 'Sample Wellness Coach A', 'SAMPLE profile. Placeholder bio for a wellness coach.',
      ['English', 'Hindi'], [_w[1], _w[2], _w[7]], SessionMode.values),
  Consultant(_cid(8), ConsultType.wellnessCoach, 'Sample Wellness Coach B', 'SAMPLE profile. Placeholder bio for a wellness coach.',
      ['English'], [_w[5], _w[6], _w[2]], [SessionMode.video, SessionMode.audio]),
];

Consultant consultantById(String id) => sampleConsultants.firstWhere((c) => c.id == id);

enum BookingStatus { upcoming, cancelled }

class Booking {
  Booking({
    required this.id,
    required this.consultantId,
    required this.start,
    required this.mode,
    this.notes = '',
    this.status = BookingStatus.upcoming,
    required this.createdAt,
  });
  final String id;
  final String consultantId;
  final DateTime start;
  final SessionMode mode;
  final String notes; // kept on device only (not uploaded)
  BookingStatus status;
  final DateTime createdAt;

  static const duration = Duration(minutes: 45);
  DateTime get end => start.add(duration);

  Map<String, dynamic> toJson() => {
        'id': id,
        'consultantId': consultantId,
        'start': start.toIso8601String(),
        'mode': mode.name,
        'notes': notes,
        'status': status.name,
        'createdAt': createdAt.toIso8601String(),
      };

  factory Booking.fromJson(Map<String, dynamic> j) => Booking(
        id: j['id'] as String,
        consultantId: j['consultantId'] as String,
        start: DateTime.parse(j['start'] as String),
        mode: SessionMode.values.byName(j['mode'] as String),
        notes: j['notes'] as String? ?? '',
        status: BookingStatus.values.byName(j['status'] as String),
        createdAt: DateTime.parse(j['createdAt'] as String),
      );
}
