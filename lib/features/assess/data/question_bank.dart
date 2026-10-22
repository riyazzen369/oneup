import '../../../core/theme/app_colors.dart';

enum ScaleType { agreement, frequency, openText }

const agreementLabels = ['Strongly disagree', 'Disagree', 'Neutral', 'Agree', 'Strongly agree'];
const frequencyLabels = ['Never', 'Rarely', 'Sometimes', 'Often', 'Always'];
const kQuestionIntro = 'Thinking about the past two weeks…';

class Question {
  const Question(this.id, this.dimension, this.order, this.text, this.scale, {this.reverse = false});
  final String id; // same UUID as supabase seed
  final WellnessDimension dimension;
  final int order;
  final String text;
  final ScaleType scale;
  final bool reverse;
  bool get isOpenText => scale == ScaleType.openText;
  List<String> get labels => scale == ScaleType.agreement ? agreementLabels : frequencyLabels;
}

/// Deterministic UUID shared with supabase/migrations/..._seed_questions.sql.
String qid(int dim, int order) => '00000000-0000-4000-8000-${(dim * 100 + order).toString().padLeft(12, '0')}';

const _f = ScaleType.frequency;
const _a = ScaleType.agreement;
const _o = ScaleType.openText;

const kReflectionMin = 15;
const kReflectionMax = 500;

// Original items. (text, scale, reverse)
const Map<WellnessDimension, List<(String, ScaleType, bool)>> _raw = {
  WellnessDimension.emotional: [
    ('How often have you been able to name what you were feeling as it happened?', _f, false),
    ('How much do you agree: "When I feel upset, I have ways to calm myself down."', _a, false),
    ('How often have your feelings felt too much to handle?', _f, true),
    ('How much do you agree: "I can share how I feel with at least one person I trust."', _a, false),
    ('How often have you bounced back within a day after something disappointing?', _f, false),
    ('How often have you held in feelings you wanted to express?', _f, true),
    ('How much do you agree: "I treat myself kindly when I make a mistake."', _a, false),
    ('How often have you felt calm or content during your day?', _f, false),
    ('In a line or two, describe how you feel about your emotional wellbeing right now.', _o, false),
  ],
  WellnessDimension.physical: [
    ('How often have you done some form of movement you enjoy for at least 20 minutes?', _f, false),
    ('How often have you woken up feeling rested?', _f, false),
    ('How often have you skipped meals because you were busy or distracted?', _f, true),
    ('How much do you agree: "I notice and respond to my body\'s signals, like hunger, thirst or tiredness."', _a, false),
    ('How often have you had enough water through the day?', _f, false),
    ('How often have you felt too low on energy to get through your usual tasks?', _f, true),
    ('How much do you agree: "I make time to rest when my body needs it."', _a, false),
    ('How often have you eaten meals that included vegetables or fruit?', _f, false),
    ('In a line or two, describe how you feel about your physical wellbeing right now.', _o, false),
  ],
  WellnessDimension.occupational: [
    ('How much do you agree: "The work or study I do feels meaningful to me."', _a, false),
    ('How often have you felt that your skills were being put to good use?', _f, false),
    ('How often has work or study spilled into time you wanted for yourself?', _f, true),
    ('How much do you agree: "I have a clear sense of what is expected of me at work or study."', _a, false),
    ('How often have you felt drained at the end of a work or study day?', _f, true),
    ('How often have you learned something that helps you grow in your role?', _f, false),
    ('How much do you agree: "I feel comfortable asking for help or raising concerns at work or study."', _a, false),
    ('How often have you looked forward to the work or study ahead of you?', _f, false),
    ('In a line or two, describe how you feel about your occupational (work or study) wellbeing right now.', _o, false),
  ],
  WellnessDimension.social: [
    ('How often have you had a conversation that left you feeling connected?', _f, false),
    ('How much do you agree: "There are people I can count on when I need support."', _a, false),
    ('How often have you felt left out or alone, even around others?', _f, true),
    ('How often have you reached out to someone just to check in?', _f, false),
    ('How much do you agree: "I can say no to others when I need to."', _a, false),
    ('How often have your relationships felt more draining than supportive?', _f, true),
    ('How much do you agree: "I feel a sense of belonging in at least one group or community."', _a, false),
    ('How often have you spent time with others doing something you both enjoy?', _f, false),
    ('In a line or two, describe how you feel about your social wellbeing right now.', _o, false),
  ],
  WellnessDimension.spiritual: [
    ('How much do you agree: "I have a sense of what gives my life meaning."', _a, false),
    ('How often have you taken quiet time to reflect, pray, meditate or simply be still?', _f, false),
    ('How often have your daily choices felt out of step with what you value?', _f, true),
    ('How much do you agree: "I feel connected to something larger than myself."', _a, false),
    ('How often have you felt a sense of gratitude during your day?', _f, false),
    ('How often have you felt that your days lacked direction or purpose?', _f, true),
    ('How much do you agree: "I can find some peace even when things are uncertain."', _a, false),
    ('How often have you done something that reflects your personal values?', _f, false),
    ('In a line or two, describe how you feel about your spiritual wellbeing right now.', _o, false),
  ],
  WellnessDimension.intellectual: [
    ('How often have you learned something new out of curiosity?', _f, false),
    ('How much do you agree: "I enjoy exploring ideas that are different from my own."', _a, false),
    ('How often have you felt mentally stuck or unstimulated?', _f, true),
    ('How often have you read, listened to or watched something that made you think?', _f, false),
    ('How much do you agree: "I like solving problems or puzzles, at work or for fun."', _a, false),
    ('How often have you spent time on a creative activity?', _f, false),
    ('How much do you agree: "I tend to avoid topics I don\'t already understand."', _a, true),
    ('How often have you discussed an idea or question with someone else?', _f, false),
    ('In a line or two, describe how you feel about your intellectual wellbeing right now.', _o, false),
  ],
  WellnessDimension.environmental: [
    ('How much do you agree: "The space where I spend most of my time feels comfortable to me."', _a, false),
    ('How often have you spent time outdoors or in green spaces?', _f, false),
    ('How often has clutter or mess in your space bothered you?', _f, true),
    ('How much do you agree: "I feel safe in the places I live and move around."', _a, false),
    ('How often have you had access to fresh air and natural light during your day?', _f, false),
    ('How often has noise or crowding around you made it hard to relax?', _f, true),
    ('How often have you made small choices to reduce waste or save resources?', _f, false),
    ('How much do you agree: "I can make changes to my surroundings to suit my needs."', _a, false),
    ('In a line or two, describe how you feel about your environmental wellbeing right now.', _o, false),
  ],
  WellnessDimension.financial: [
    ('How much do you agree: "I have a clear picture of where my money goes each month."', _a, false),
    ('How often have you followed a budget or spending plan?', _f, false),
    ('How often have money worries kept you from relaxing or sleeping?', _f, true),
    ('How much do you agree: "I feel prepared for an unexpected expense."', _a, false),
    ('How often have you set aside some money for savings or future goals?', _f, false),
    ('How often have you made purchases you later regretted?', _f, true),
    ('How much do you agree: "I feel comfortable talking about money with people close to me."', _a, false),
    ('How often have you reviewed your bills, payments or accounts?', _f, false),
    ('In a line or two, describe how you feel about your financial wellbeing right now.', _o, false),
  ],
};

final List<Question> questionBank = [
  for (final d in WellnessDimension.values)
    for (var i = 0; i < _raw[d]!.length; i++)
      Question(qid(d.index + 1, i + 1), d, i + 1, _raw[d]![i].$1, _raw[d]![i].$2, reverse: _raw[d]![i].$3),
];

List<Question> questionsFor(WellnessDimension d) => questionBank.where((q) => q.dimension == d).toList();

/// The 8 Likert items that are scored (excludes the open-text reflection).
List<Question> scoredQuestionsFor(WellnessDimension d) => questionsFor(d).where((q) => !q.isOpenText).toList();

Question reflectionQuestionFor(WellnessDimension d) => questionsFor(d).firstWhere((q) => q.isOpenText);
