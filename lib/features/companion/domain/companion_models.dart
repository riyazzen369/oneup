import '../../../core/theme/app_colors.dart';

enum RiskLevel { none, elevated, crisis }

enum ActionType { skill, content, consultant, none }

/// Validated output_schema from the spec.
class CompanionReply {
  const CompanionReply({
    required this.reply,
    this.risk = RiskLevel.none,
    this.dimensionFocus,
    this.actionType = ActionType.none,
    this.actionId,
    this.flagForReview = false,
  });
  final String reply;
  final RiskLevel risk;
  final String? dimensionFocus;
  final ActionType actionType;
  final String? actionId;
  final bool flagForReview;

  WellnessDimension? get dimension => WellnessDimension.values.where((d) => d.name == dimensionFocus).firstOrNull;

  Map<String, dynamic> toJson() => {
        'reply': reply,
        'risk_level': risk.name,
        'dimension_focus': dimensionFocus,
        'suggested_action': {'type': actionType.name, 'id': actionId},
        'flag_for_review': flagForReview,
      };

  /// Strict parse: throws FormatException if the schema is not met.
  factory CompanionReply.fromJson(Map<String, dynamic> j) {
    final reply = j['reply'];
    if (reply is! String || reply.trim().isEmpty) throw const FormatException('reply');
    final risk = RiskLevel.values.where((r) => r.name == j['risk_level']).firstOrNull;
    if (risk == null) throw const FormatException('risk_level');
    final dim = j['dimension_focus'];
    if (dim != null && (dim is! String || !WellnessDimension.values.any((d) => d.name == dim))) {
      throw const FormatException('dimension_focus');
    }
    final sa = j['suggested_action'];
    if (sa is! Map) throw const FormatException('suggested_action');
    final type = ActionType.values.where((a) => a.name == sa['type']).firstOrNull;
    if (type == null) throw const FormatException('suggested_action.type');
    final id = sa['id'];
    if (id != null && id is! String) throw const FormatException('suggested_action.id');
    final flag = j['flag_for_review'];
    if (flag is! bool) throw const FormatException('flag_for_review');
    return CompanionReply(
      reply: limitWords(reply.trim(), 120),
      risk: risk,
      dimensionFocus: dim as String?,
      actionType: risk == RiskLevel.crisis ? ActionType.none : type, // crisis: no suggestions
      actionId: risk == RiskLevel.crisis ? null : id as String?,
      flagForReview: flag || risk == RiskLevel.crisis,
    );
  }
}

String limitWords(String s, int max) {
  final w = s.split(RegExp(r'\s+'));
  return w.length <= max ? s : '${w.take(max).join(' ')}…';
}

int wordCount(String s) => s.trim().isEmpty ? 0 : s.trim().split(RegExp(r'\s+')).length;

class ChatMessage {
  const ChatMessage({required this.fromUser, required this.text, required this.at, this.meta});
  final bool fromUser;
  final String text;
  final DateTime at;
  final CompanionReply? meta;

  Map<String, dynamic> toJson() => {'u': fromUser, 't': text, 'at': at.toIso8601String(), 'm': meta?.toJson()};
  factory ChatMessage.fromJson(Map<String, dynamic> j) => ChatMessage(
        fromUser: j['u'] as bool,
        text: j['t'] as String,
        at: DateTime.parse(j['at'] as String),
        meta: j['m'] == null ? null : CompanionReply.fromJson(Map<String, dynamic>.from(j['m'] as Map)),
      );
}

/// Context the companion may use. [scores] is null unless the user consented.
class CompanionContext {
  const CompanionContext({this.scores, this.escalate = const {}, this.language = 'en'});
  final Map<WellnessDimension, int>? scores;
  final Set<WellnessDimension> escalate; // Needs Attention in 2+ attempts
  final String language;
}
