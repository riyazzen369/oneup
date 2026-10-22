import '../../../core/safety/crisis_detector.dart';
import '../../../core/theme/app_colors.dart';
import '../../assess/domain/history.dart' show lowestDimensions;
import '../../assess/domain/scoring.dart';
import '../../consult/domain/consult_logic.dart';
import '../data/playbook.dart';
import 'companion_models.dart';

/// Rule-based responder used when no AI backend is configured (demo mode).
/// Follows the spec: reflect + one open question, playbook skill, declines medicine
/// and diagnosis, discloses AI, crisis protocol. Never invents scores or facts.
CompanionReply respondOffline(String message, CompanionContext ctx) {
  final m = normaliseForSafety(message);
  bool has(List<String> ks) => ks.any((k) => RegExp('\\b${RegExp.escape(k)}').hasMatch(m));

  // 1. Crisis (app-side detector always wins)
  if (detectCrisis(message) != null) {
    return const CompanionReply(
      reply: "I'm really sorry you're feeling this way, and I'm glad you told me. You deserve support right now. "
          'Please reach out to someone you trust, or contact emergency or crisis services now. '
          "I'm showing you helpline numbers, and I can help you contact someone.",
      risk: RiskLevel.crisis,
      flagForReview: true,
    );
  }

  final dim = _detectDimension(m) ?? _focus(ctx);

  // 2. Medicines / supplements
  if (has([
    'tablet',
    'medicine',
    'medication',
    'pill',
    'dose',
    'dosage',
    'supplement',
    'capsule',
    'antidepressant',
    'prescription',
    'dawai',
    'dawa',
    'goli',
    'maathirai',
    'marunthu'
  ])) {
    final d = dim ?? WellnessDimension.emotional;
    return CompanionReply(
      reply: "I can't recommend or advise on any medicine, tablet or supplement. A doctor or pharmacist is the right "
          'person to advise you on that. If you like, I can show you consultants you could talk to. '
          'In the meantime, what has been feeling hardest for you lately?',
      dimensionFocus: d.name,
      actionType: ActionType.consultant,
      actionId: typesForDimension(d).first.name,
    );
  }

  // 3. Diagnosis requests
  if (has([
    'do i have',
    'am i depressed',
    'diagnos',
    'disorder',
    'is this depression',
    'is it anxiety',
    'what condition',
    'mental illness',
    'bipolar',
    'adhd',
    'ocd',
    'ptsd'
  ])) {
    final d = dim ?? WellnessDimension.emotional;
    final stated = RegExp(r'\b(\d{1,3})\b').firstMatch(m)?.group(1);
    final score = stated != null ? int.tryParse(stated) : ctx.scores?[d];
    final scorePart = (score != null && score <= 100)
        ? 'A ${d.label} score of $score falls in the ${bandFor(score).label} band. That is a wellness indicator, '
            'not a clinical finding, and it simply means this area may need some care right now. '
        : "I don't have a score to go on here, and either way a score here is a wellness indicator, not a clinical finding. ";
    return CompanionReply(
      reply: "I can't diagnose or label any condition. I'm an AI, not a clinician. $scorePart"
          'A qualified professional can help you explore this properly, and I can show you consultants if you like. '
          'What has day-to-day life been feeling like for you?',
      dimensionFocus: d.name,
      actionType: ActionType.consultant,
      actionId: typesForDimension(d).first.name,
    );
  }

  // 4. Identity
  if (has([
    'are you real',
    'real therapist',
    'are you human',
    'are you a person',
    'are you ai',
    'are you an ai',
    'are you a bot',
    'are you a doctor',
    'are you a therapist',
    'who are you',
    'what are you'
  ])) {
    return const CompanionReply(
      reply: "I'm an AI wellness companion, not a real therapist or doctor, and I don't have a licence or human experience. "
          "I can't diagnose or treat, but I can listen, help you reflect and share small everyday wellness skills. "
          'If you would like a human professional, I can show you consultants. What would feel most helpful right now?',
      actionType: ActionType.consultant,
      actionId: 'therapist',
    );
  }

  // 5. User asks for professional help
  if (has([
    'therapy',
    'therapist',
    'counsellor',
    'counselor',
    'psychologist',
    'professional',
    'consultant',
    'talk to someone',
    'talk to a human',
    'nutritionist',
    'coach'
  ])) {
    final d = dim ?? WellnessDimension.emotional;
    return CompanionReply(
      reply: 'That sounds like a thoughtful step. I can show you consultants in the Consult section who may be a good fit. '
          'This is a suggestion, not medical advice, and there is no pressure. What would you most like support with?',
      dimensionFocus: d.name,
      actionType: ActionType.consultant,
      actionId: typesForDimension(d).first.name,
    );
  }

  // 6. Explain scores
  if (has(['my score', 'my scores', 'results', 'wheel', 'understand my', 'what does my', 'band'])) {
    final s = ctx.scores;
    if (s == null) {
      return const CompanionReply(
        reply: "I don't have access to your scores in this chat. You can turn on \"Use my scores\" in Companion settings, "
            'or tell me a score and the dimension. Which area would you like to talk about?',
      );
    }
    if (s.isEmpty) {
      return const CompanionReply(
        reply: "You haven't completed any dimensions yet, so I don't have scores to look at. "
            'A short check-in in the Assess tab will give us something to explore together. Which area interests you most?',
      );
    }
    final low = lowestDimensions(s, 1).first;
    return CompanionReply(
      reply: 'Your scores are wellness indicators, not clinical results. Bands run 0–40 Needs Attention, 41–70 Developing '
          'and 71–100 Thriving. Right now ${low.key.label} is your lowest at ${low.value}, in the ${bandFor(low.value).label} band. '
          'What comes to mind when you think about that area?',
      dimensionFocus: low.key.name,
    );
  }

  // 7. Reflect + one open question + one optional skill
  final d = dim;
  final reflection = _reflect(message) ?? 'Thank you for sharing that with me.';
  if (d == null) {
    return CompanionReply(reply: '$reflection What feels most important to you about this right now?');
  }
  final skill = _skillFor(d, m);
  final escalate = ctx.escalate.contains(d);
  final tail = escalate
      ? ' Since ${d.label} has been in Needs Attention for a while, talking with a consultant could also help, if you would like that.'
      : ' You are welcome to try it, or we can just keep talking.';
  return CompanionReply(
    reply: limitWords('$reflection ${_question(d)} One small thing you could try is ${_cap(skill)}: ${kSkillHowTo[skill]}$tail', 120),
    dimensionFocus: d.name,
    actionType: escalate ? ActionType.consultant : ActionType.skill,
    actionId: escalate ? typesForDimension(d).first.name : skill,
  );
}

WellnessDimension? _focus(CompanionContext ctx) {
  final s = ctx.scores;
  if (s == null || s.isEmpty) return null;
  return lowestDimensions(s, 1).first.key;
}

WellnessDimension? _detectDimension(String m) {
  const map = <WellnessDimension, List<String>>{
    WellnessDimension.occupational: ['work', 'job', 'office', 'boss', 'career', 'deadline', 'colleague', 'study', 'exam', 'college'],
    WellnessDimension.financial: ['money', 'salary', 'debt', 'loan', 'budget', 'expense', 'saving', 'bills', 'emi'],
    WellnessDimension.physical: ['sleep', 'tired', 'exercise', 'body', 'eating', 'diet', 'energy', 'walk', 'fitness'],
    WellnessDimension.social: ['friend', 'lonely', 'alone', 'family', 'relationship', 'people'],
    WellnessDimension.spiritual: ['purpose', 'meaning', 'faith', 'prayer', 'meditat', 'values'],
    WellnessDimension.intellectual: ['bored', 'learn', 'curious', 'reading', 'skill'],
    WellnessDimension.environmental: ['home', 'room', 'noise', 'clutter', 'mess', 'neighbourhood', 'pollution'],
    WellnessDimension.emotional: [
      'sad',
      'anxious',
      'anxiety',
      'stressed',
      'stress',
      'upset',
      'angry',
      'worried',
      'overwhelmed',
      'low',
      'feel'
    ],
  };
  for (final e in map.entries) {
    if (e.value.any((k) => RegExp('\\b$k').hasMatch(m))) return e.key;
  }
  return null;
}

String _skillFor(WellnessDimension d, String m) {
  final list = kPlaybook[d]!;
  if (d == WellnessDimension.emotional && (m.contains('stress') || m.contains('anxious') || m.contains('worr'))) {
    return 'box breathing';
  }
  if (d == WellnessDimension.occupational && (m.contains('stress') || m.contains('busy') || m.contains('deadline'))) {
    return 'weekly priorities';
  }
  return list.first;
}

String _question(WellnessDimension d) => switch (d) {
      WellnessDimension.emotional => 'What has been on your mind most when you feel this way?',
      WellnessDimension.physical => 'How have your days been feeling for your body lately?',
      WellnessDimension.occupational => 'What part of it feels heaviest for you right now?',
      WellnessDimension.social => 'Who in your life feels easiest to connect with at the moment?',
      WellnessDimension.spiritual => 'What tends to give your days a sense of meaning?',
      WellnessDimension.intellectual => 'What kind of thing usually sparks your curiosity?',
      WellnessDimension.environmental => 'What would make your space feel a little better to be in?',
      WellnessDimension.financial => 'Which part of money matters feels most on your mind lately?',
    };

String? _reflect(String message) {
  final r = RegExp(r"\bi(?:'?m| am| feel| have been feeling| been feeling|'ve been feeling)\s+([^.!?]{3,80})", caseSensitive: false)
      .firstMatch(message);
  if (r == null) return null;
  var x = r.group(1)!.trim();
  x = x.replaceAllMapped(RegExp(r'\b(my|me|i|myself|mine)\b', caseSensitive: false), (mm) {
    return switch (mm.group(1)!.toLowerCase()) {
      'my' => 'your',
      'me' => 'you',
      'i' => 'you',
      'myself' => 'yourself',
      _ => 'yours',
    };
  });
  return "It sounds like you've been feeling $x.";
}

String _cap(String s) => s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);
