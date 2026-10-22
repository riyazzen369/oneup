import 'dart:math';
import '../../../core/theme/app_colors.dart';

String newUuidV4() {
  final r = Random.secure();
  final b = List<int>.generate(16, (_) => r.nextInt(256));
  b[6] = (b[6] & 0x0f) | 0x40;
  b[8] = (b[8] & 0x3f) | 0x80;
  final h = b.map((x) => x.toRadixString(16).padLeft(2, '0')).join();
  return '${h.substring(0, 8)}-${h.substring(8, 12)}-${h.substring(12, 16)}-${h.substring(16, 20)}-${h.substring(20)}';
}

enum DimStatus { notStarted, inProgress, done }

/// An unfinished attempt at ONE dimension. Each attempt is its own `assessments` row
/// server-side, so redoing a single dimension never overwrites earlier history.
/// [encAnswers]: AES-GCM ciphertext per question id (never plaintext at rest).
class DimDraft {
  DimDraft({required this.id, required this.dimension, required this.startedAt, Map<String, String>? encAnswers, this.position = 0})
      : encAnswers = encAnswers ?? {};

  factory DimDraft.fresh(WellnessDimension d) => DimDraft(id: newUuidV4(), dimension: d, startedAt: DateTime.now());

  final String id;
  final WellnessDimension dimension;
  final DateTime startedAt;
  final Map<String, String> encAnswers;
  int position;

  Map<String, dynamic> toJson() => {
        'id': id,
        'dim': dimension.name,
        'startedAt': startedAt.toIso8601String(),
        'encAnswers': encAnswers,
        'position': position,
      };

  factory DimDraft.fromJson(Map<String, dynamic> j) => DimDraft(
        id: j['id'] as String,
        dimension: WellnessDimension.values.byName(j['dim'] as String),
        startedAt: DateTime.parse(j['startedAt'] as String),
        encAnswers: Map<String, String>.from((j['encAnswers'] as Map?) ?? {}),
        position: j['position'] as int? ?? 0,
      );
}

/// A completed attempt at one dimension (score history entry).
class DimAttempt {
  const DimAttempt({required this.id, required this.dimension, required this.score, required this.completedAt, this.encReflection});
  final String id;

  /// AES-GCM ciphertext of the open-text reflection (AAD = "$id:<question id>").
  final String? encReflection;
  final WellnessDimension dimension;
  final int score;
  final DateTime completedAt;

  Map<String, dynamic> toJson() =>
      {'id': id, 'dim': dimension.name, 'score': score, 'completedAt': completedAt.toIso8601String(), 'encReflection': encReflection};

  factory DimAttempt.fromJson(Map<String, dynamic> j) => DimAttempt(
        id: j['id'] as String,
        dimension: WellnessDimension.values.byName(j['dim'] as String),
        score: j['score'] as int,
        completedAt: DateTime.parse(j['completedAt'] as String),
        encReflection: j['encReflection'] as String?,
      );
}
