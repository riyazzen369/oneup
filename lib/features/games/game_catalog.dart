import '../../core/theme/app_colors.dart';

/// One arcade game per wellness dimension. The wellness idea is the theme; play is real-time.
class GameInfo {
  const GameInfo(this.id, this.dimension, this.title, this.blurb, this.howTo);
  final String id;
  final WellnessDimension dimension;
  final String title;
  final String blurb;
  final String howTo;
}

const games = <GameInfo>[
  GameInfo('mood-catcher', WellnessDimension.emotional, 'Mood Catcher', 'Catch calm and happy orbs, dodge storm clouds.',
      'Drag the basket. Catch smiles to fill the calm meter. Avoid storm clouds.'),
  GameInfo('breath-runner', WellnessDimension.physical, 'Breath Runner', 'Hold to inhale and rise, release to exhale and glide.',
      'Hold anywhere to rise, let go to sink. Fly through the gates. Steady breaths earn a rhythm bonus.'),
  GameInfo('task-sort', WellnessDimension.occupational, 'Task Sort', 'Slide falling tasks into Do, Plan, Delegate or Drop.',
      'Drag each falling task into a lane: urgent + important = Do, important = Plan, urgent = Delegate, neither = Drop.'),
  GameInfo('connect-friends', WellnessDimension.social, 'Connect Friends', 'Link matching friend bubbles before they drift away.',
      'Drag from a bubble through others of the same colour, then let go. Longer chains score more.'),
  GameInfo('zen-lantern', WellnessDimension.spiritual, 'Zen Lantern', 'Guide a lantern upward through gaps and gather light.',
      'Drag left and right to steer through gaps. Collect light orbs.'),
  GameInfo('memory-flip', WellnessDimension.intellectual, 'Memory Flip Rush', 'Match pairs against the clock as the grid grows.',
      'Tap two cards to flip them. Each match adds time; clear the board to level up.'),
  GameInfo('eco-sort-rush', WellnessDimension.environmental, 'Eco Sort Rush', 'Flick falling waste into Wet, Dry or Hazard bins.',
      'Drag or flick each item into the right bin before it lands. Mistakes raise the pollution meter.'),
  GameInfo('coin-saver', WellnessDimension.financial, 'Coin Saver', 'Catch coins in your savings jar, dodge impulse buys.',
      'Drag the jar. Catch coins to reach the SAMPLE ₹ savings goal. Dodge impulse buys.'),
  GameInfo('bubble-calm', WellnessDimension.emotional, 'Bubble Calm', 'Pop stress bubbles in colour chains before they fill up.',
      'Tap a bubble to pop it and every touching bubble of the same colour. Bigger chains score more. Avoid the dark stress bubbles.'),
  GameInfo('step-jump', WellnessDimension.physical, 'Step Jump', 'Bounce up the platforms, grab water and fruit.',
      'Drag left or right to steer. You bounce automatically. Collect water drops and fruit; don’t fall off the screen.'),
  GameInfo('inbox-zero', WellnessDimension.occupational, 'Inbox Zero', 'Slice the spam, keep the important mail.',
      'Swipe through red spam to slice it. Tap gold mail to keep it. Slicing important mail costs a life; missed mail adds clutter.'),
  GameInfo('pass-the-smile', WellnessDimension.social, 'Pass the Smile', 'Time your toss to a friend on the move.',
      'Tap to toss the smile straight up. Time it so your friend catches it. Watch out for clouds later on.'),
  GameInfo('balance-stones', WellnessDimension.spiritual, 'Balance Stones', 'Stack zen stones as high as you can.',
      'Tap to drop the sliding stone. Overhang is trimmed off; perfect drops restore width.'),
  GameInfo('pattern-snake', WellnessDimension.intellectual, 'Pattern Snake', 'Eat the numbers in order as the snake grows.',
      'Swipe, or tap beside the head, to turn. Eat 1, 2, 3… in order. Avoid walls and your own tail.'),
  GameInfo('tree-planter', WellnessDimension.environmental, 'Tree Planter', 'Plant trees that clear the smog.',
      'Tap an empty plot to plant (uses a seed). Grown trees shoot leaves at smog. Tap smog to clear it too; clears earn seeds.'),
  GameInfo('coin-run', WellnessDimension.financial, 'Coin Run', 'Dash between lanes for SAMPLE ₹ coins, dodge debt traps.',
      'Swipe or tap left/right to change lanes. Collect coins to build a streak shield. Avoid DEBT blocks. SAMPLE ₹ only.'),
];

GameInfo gameById(String id) => games.firstWhere((g) => g.id == id);
