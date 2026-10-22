import '../../../core/theme/app_colors.dart';

/// dimension_playbook from assets/companion/spec.json (general wellness starting points only).
const Map<WellnessDimension, List<String>> kPlaybook = {
  WellnessDimension.emotional: ['name the feeling', 'box breathing', 'journaling prompt'],
  WellnessDimension.physical: ['sleep routine', 'short walk', 'hydration and meal regularity'],
  WellnessDimension.occupational: ['values check', 'boundary setting', 'weekly priorities'],
  WellnessDimension.social: ['one small reach-out', 'active listening', 'community activity'],
  WellnessDimension.spiritual: ['purpose reflection', 'gratitude practice', 'quiet time'],
  WellnessDimension.intellectual: ['new skill sprint', 'curiosity time', 'reading habit'],
  WellnessDimension.environmental: ['declutter one spot', 'light and noise check', 'nature time'],
  WellnessDimension.financial: ['track spending for a week', 'simple budget', 'one savings goal'],
};

/// Short, general how-to for each playbook skill (plain wellness wording, no clinical claims).
const Map<String, String> kSkillHowTo = {
  'name the feeling': 'Pause and put a simple word to what you feel right now, like "tense" or "flat".',
  'box breathing': 'Breathe in for 4, hold for 4, out for 4, hold for 4. Repeat a few rounds.',
  'journaling prompt': 'Write two lines: what happened today, and how it felt.',
  'sleep routine': 'Pick a regular wind-down time and keep screens away for the last part of it.',
  'short walk': 'Take a 10-minute walk, outdoors if you can.',
  'hydration and meal regularity': 'Keep water nearby and aim for meals at roughly regular times.',
  'values check': 'Note one thing you value in your work or study, and one task that reflects it.',
  'boundary setting': 'Choose one small limit, like a fixed stop time, and try it this week.',
  'weekly priorities': 'List the top three things that matter most this week, and start with one.',
  'one small reach-out': 'Send a short message to someone you have not spoken to in a while.',
  'active listening': 'In your next chat, listen fully and reflect back what you heard.',
  'community activity': 'Look for one group or local activity you might enjoy joining.',
  'purpose reflection': 'Write a line about what gives your days meaning.',
  'gratitude practice': 'Note three small things you appreciated today.',
  'quiet time': 'Set aside five quiet minutes without your phone.',
  'new skill sprint': 'Spend 15 minutes on something new you are curious about.',
  'curiosity time': 'Follow one question you have wondered about, just for fun.',
  'reading habit': 'Read a few pages of something you enjoy each day.',
  'declutter one spot': 'Tidy one small area, like a desk corner or a drawer.',
  'light and noise check': 'Notice the light and noise where you spend most time, and adjust one thing.',
  'nature time': 'Spend a few minutes near plants, trees or open sky.',
  'track spending for a week': 'Jot down what you spend each day for one week.',
  'simple budget': 'Split your money into needs, wants and saving, and see how it looks.',
  'one savings goal': 'Pick one small savings goal and an amount you are comfortable setting aside.',
};
