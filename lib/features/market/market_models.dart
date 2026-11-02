import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';

/// Marketplace data. Every product is a SAMPLE placeholder: no real brands, no real prices.
class Product {
  const Product(this.id, this.dimension, this.category, this.name, this.blurb, this.price, this.icon, {this.consultOnly = false});
  final String id;
  final WellnessDimension dimension;
  final String category;
  final String name;
  final String blurb;

  /// Placeholder price in rupees (SAMPLE). 0 for consult-only items.
  final int price;
  final IconData icon;

  /// Medicines / supplements: no cart, no dosing, no claims; consult first.
  final bool consultOnly;

  String get priceLabel => consultOnly ? 'Consult first' : '₹$price (sample)';
}

const sampleNote = 'SAMPLE listing for demo purposes. Not a real product, brand or price.';
const consultNote = 'Consult a qualified professional before use. This is a placeholder listing; '
    'OneUP gives no dosing or health claims.';
const demoNote = 'Demo — no payment taken.';

typedef _P = Product;
const _e = WellnessDimension.emotional, _ph = WellnessDimension.physical, _o = WellnessDimension.occupational;
const _so = WellnessDimension.social, _sp = WellnessDimension.spiritual, _i = WellnessDimension.intellectual;
const _en = WellnessDimension.environmental, _f = WellnessDimension.financial;

const catalog = <Product>[
  // Physical
  _P('ph-yoga-mat', _ph, 'Yoga', 'SAMPLE Yoga Mat', 'A cushioned mat for stretching and floor exercise.', 999,
      Icons.self_improvement_rounded),
  _P('ph-yoga-blocks', _ph, 'Yoga', 'SAMPLE Yoga Blocks (pair)', 'Foam blocks that can help with reach during poses.', 449,
      Icons.view_in_ar_rounded),
  _P('ph-bands', _ph, 'Fitness gear', 'SAMPLE Resistance Bands Set', 'Elastic bands in several tension levels for home workouts.', 599,
      Icons.fitness_center_rounded),
  _P('ph-dumbbells', _ph, 'Fitness gear', 'SAMPLE Hand Weights (pair)', 'Light hand weights for simple strength routines.', 1199,
      Icons.fitness_center_rounded),
  _P('ph-rope', _ph, 'Fitness gear', 'SAMPLE Skipping Rope', 'An adjustable rope for cardio at home.', 299, Icons.sports_rounded),
  _P('ph-bottle', _ph, 'Nutrition', 'SAMPLE Water Bottle', 'A reusable bottle with volume markings.', 399, Icons.water_drop_rounded),
  _P('ph-oats', _ph, 'Nutrition', 'SAMPLE Rolled Oats', 'A plain pantry staple for breakfasts.', 249, Icons.breakfast_dining_rounded),
  _P('ph-nuts', _ph, 'Nutrition', 'SAMPLE Mixed Nuts Pack', 'An unsalted snack mix.', 449, Icons.eco_rounded),
  _P('ph-eye-mask', _ph, 'Sleep', 'SAMPLE Sleep Eye Mask', 'A soft mask that blocks light.', 249, Icons.bedtime_rounded),
  _P('ph-pillow', _ph, 'Sleep', 'SAMPLE Support Pillow', 'A contoured pillow for side or back sleepers.', 1499, Icons.bed_rounded),
  _P('ph-supplement', _ph, 'Supplements', 'SAMPLE Supplement (placeholder)',
      'Placeholder for supplements. Available via consultation only.', 0, Icons.medication_rounded,
      consultOnly: true),
  _P('ph-medicine', _ph, 'Medicines', 'SAMPLE Medicine (placeholder)', 'Placeholder for medicines. Available via consultation only.', 0,
      Icons.medical_services_rounded,
      consultOnly: true),
  // Emotional
  _P('em-journal', _e, 'Journals', 'SAMPLE Guided Journal', 'A notebook with simple daily reflection prompts.', 399,
      Icons.menu_book_rounded),
  _P('em-gratitude', _e, 'Journals', 'SAMPLE Gratitude Notebook', 'A small notebook for noting good moments.', 299,
      Icons.edit_note_rounded),
  _P('em-mood-cards', _e, 'Journals', 'SAMPLE Mood Check-in Cards', 'A deck of prompts for naming how you feel.', 349, Icons.style_rounded),
  _P('em-calm-kit', _e, 'Calming kits', 'SAMPLE Calm Corner Kit', 'A small box with a fidget, stress ball and a soft cloth.', 799,
      Icons.spa_rounded),
  _P('em-stress-ball', _e, 'Calming kits', 'SAMPLE Squeeze Ball', 'A soft ball to fidget with.', 149, Icons.sports_baseball_rounded),
  _P('em-weighted-throw', _e, 'Calming kits', 'SAMPLE Cosy Throw Blanket', 'A heavy, soft blanket for the sofa.', 1999,
      Icons.weekend_rounded),
  _P('em-colouring', _e, 'Creative', 'SAMPLE Colouring Book', 'Patterns to colour at your own pace.', 249, Icons.palette_rounded),
  _P('em-pencils', _e, 'Creative', 'SAMPLE Coloured Pencils', 'A set of pencils in many shades.', 299, Icons.brush_rounded),
  _P('em-headphones', _e, 'Audio', 'SAMPLE Over-ear Headphones', 'Closed headphones for music or quiet time.', 2499,
      Icons.headphones_rounded),
  _P('em-sleep-aid', _e, 'Supplements', 'SAMPLE Relaxation Supplement (placeholder)', 'Placeholder only. Available via consultation only.',
      0, Icons.medication_rounded,
      consultOnly: true),
  // Occupational
  _P('oc-laptop-stand', _o, 'Desk ergonomics', 'SAMPLE Laptop Stand', 'Raises a laptop screen nearer to eye level.', 1199,
      Icons.laptop_rounded),
  _P('oc-footrest', _o, 'Desk ergonomics', 'SAMPLE Footrest', 'An angled rest for under the desk.', 899, Icons.chair_rounded),
  _P('oc-wrist-rest', _o, 'Desk ergonomics', 'SAMPLE Keyboard Wrist Rest', 'A soft rest in front of the keyboard.', 399,
      Icons.keyboard_rounded),
  _P('oc-lamp', _o, 'Desk ergonomics', 'SAMPLE Desk Lamp', 'An adjustable lamp with warm and cool light.', 1299, Icons.light_rounded),
  _P('oc-planner', _o, 'Planners', 'SAMPLE Weekly Planner', 'A undated planner for tasks and priorities.', 449, Icons.event_note_rounded),
  _P('oc-notes', _o, 'Planners', 'SAMPLE Sticky Notes Pack', 'Notes in several colours for to-dos.', 149, Icons.sticky_note_2_rounded),
  _P('oc-timer', _o, 'Focus tools', 'SAMPLE Focus Timer', 'A simple countdown timer for work blocks.', 599, Icons.timer_rounded),
  _P('oc-organiser', _o, 'Focus tools', 'SAMPLE Desk Organiser', 'Trays for pens and papers.', 499, Icons.inventory_2_rounded),
  _P('oc-course', _o, 'Courses', 'SAMPLE Course: Time Planning Basics', 'A placeholder self-paced course.', 999, Icons.school_rounded),
  _P('oc-cv-course', _o, 'Courses', 'SAMPLE Course: Writing a CV', 'A placeholder self-paced course.', 799, Icons.description_rounded),
  // Social
  _P('so-board-game', _so, 'Board games', 'SAMPLE Family Board Game', 'A turn-based game for 2–6 players.', 1299, Icons.casino_rounded),
  _P('so-cards', _so, 'Board games', 'SAMPLE Party Card Game', 'A quick card game for groups.', 499, Icons.style_rounded),
  _P('so-conv-cards', _so, 'Board games', 'SAMPLE Conversation Cards', 'Questions to get to know each other.', 399, Icons.forum_rounded),
  _P('so-puzzle-coop', _so, 'Board games', 'SAMPLE Co-op Puzzle Game', 'Players work together to solve it.', 999, Icons.extension_rounded),
  _P('so-gift-kit', _so, 'Gift kits', 'SAMPLE Thank-you Gift Box', 'A small box with a card and small snacks.', 899,
      Icons.card_giftcard_rounded),
  _P('so-cards-pack', _so, 'Gift kits', 'SAMPLE Greeting Cards Pack', 'Blank cards for any occasion.', 249, Icons.mail_rounded),
  _P('so-picnic', _so, 'Get-togethers', 'SAMPLE Picnic Blanket', 'A foldable blanket for outdoor meetups.', 799, Icons.deck_rounded),
  _P('so-cookbook', _so, 'Get-togethers', 'SAMPLE Sharing Recipes Book', 'Simple recipes for groups.', 499, Icons.restaurant_rounded),
  _P('so-photo', _so, 'Gift kits', 'SAMPLE Photo Frame', 'A frame for a shared memory.', 399, Icons.photo_rounded),
  // Spiritual
  _P('sp-cushion', _sp, 'Meditation', 'SAMPLE Meditation Cushion', 'A firm round cushion for sitting practice.', 1299,
      Icons.self_improvement_rounded),
  _P('sp-mat', _sp, 'Meditation', 'SAMPLE Meditation Mat', 'A flat mat to place under a cushion.', 899, Icons.crop_square_rounded),
  _P('sp-bench', _sp, 'Meditation', 'SAMPLE Kneeling Bench', 'A low wooden bench for kneeling.', 1999, Icons.chair_alt_rounded),
  _P('sp-bell', _sp, 'Calm items', 'SAMPLE Small Bell', 'A bell to mark the start and end of a quiet sit.', 499,
      Icons.notifications_rounded),
  _P('sp-lamp', _sp, 'Calm items', 'SAMPLE Warm Night Lamp', 'A dim, warm light for evenings. Incense-free.', 799,
      Icons.light_mode_rounded),
  _P('sp-sand', _sp, 'Calm items', 'SAMPLE Mini Sand Tray', 'A small tray with sand and a rake.', 599, Icons.waves_rounded),
  _P('sp-reflect', _sp, 'Reflection', 'SAMPLE Reflection Journal', 'Prompts about values and meaning.', 399, Icons.auto_stories_rounded),
  _P('sp-mala', _sp, 'Reflection', 'SAMPLE Counting Beads', 'A string of beads for counting breaths.', 349, Icons.blur_circular_rounded),
  _P('sp-course', _sp, 'Courses', 'SAMPLE Course: Intro to Mindfulness', 'A placeholder self-paced course.', 999, Icons.school_rounded),
  // Intellectual
  _P('in-puzzle', _i, 'Puzzles', 'SAMPLE 1000-piece Jigsaw', 'A landscape jigsaw puzzle.', 699, Icons.extension_rounded),
  _P('in-cube', _i, 'Puzzles', 'SAMPLE Puzzle Cube', 'A twisty cube puzzle.', 299, Icons.view_in_ar_rounded),
  _P('in-sudoku', _i, 'Puzzles', 'SAMPLE Logic Puzzle Book', 'Number and grid puzzles.', 199, Icons.grid_on_rounded),
  _P('in-chess', _i, 'Games', 'SAMPLE Chess Set', 'A folding board with pieces.', 899, Icons.sports_esports_rounded),
  _P('in-book-habits', _i, 'Books', 'SAMPLE Book: Habits (placeholder)',
      'Placeholder book listing. See the Learn tab for book-based lessons.', 399, Icons.menu_book_rounded),
  _P('in-book-mind', _i, 'Books', 'SAMPLE Book: Mindfulness (placeholder)', 'Placeholder book listing.', 399, Icons.menu_book_rounded),
  _P('in-course-lang', _i, 'Courses', 'SAMPLE Course: New Language Starter', 'A placeholder self-paced course.', 1499,
      Icons.translate_rounded),
  _P('in-course-code', _i, 'Courses', 'SAMPLE Course: Coding Basics', 'A placeholder self-paced course.', 1499, Icons.code_rounded),
  _P('in-notebook', _i, 'Study tools', 'SAMPLE Study Notebook', 'A ruled notebook for notes.', 149, Icons.note_alt_rounded),
  _P('in-kit', _i, 'Study tools', 'SAMPLE Science Kit', 'A hands-on kit of simple experiments.', 1199, Icons.science_rounded),
  // Environmental
  _P('en-plant', _en, 'Plants', 'SAMPLE Indoor Plant', 'A small leafy plant in a pot.', 449, Icons.local_florist_rounded),
  _P('en-herbs', _en, 'Plants', 'SAMPLE Herb Grow Kit', 'Seeds, soil and pots for a windowsill.', 599, Icons.grass_rounded),
  _P('en-planter', _en, 'Plants', 'SAMPLE Planter Pot', 'A pot with a drainage tray.', 349, Icons.yard_rounded),
  _P('en-bottle', _en, 'Eco products', 'SAMPLE Steel Lunch Box', 'A reusable box for meals.', 699, Icons.lunch_dining_rounded),
  _P('en-bag', _en, 'Eco products', 'SAMPLE Cloth Shopping Bag', 'A foldable reusable bag.', 199, Icons.shopping_bag_rounded),
  _P('en-straws', _en, 'Eco products', 'SAMPLE Reusable Straws', 'Straws with a cleaning brush.', 249, Icons.local_drink_rounded),
  _P('en-compost', _en, 'Eco products', 'SAMPLE Compost Bin', 'A small bin for kitchen scraps.', 1299, Icons.recycling_rounded),
  _P('en-bins', _en, 'Home order', 'SAMPLE Sorting Bins', 'Bins to separate waste at home.', 899, Icons.delete_outline_rounded),
  _P('en-storage', _en, 'Home order', 'SAMPLE Storage Boxes', 'Boxes to reduce clutter.', 799, Icons.inventory_2_rounded),
  _P('en-cloths', _en, 'Home order', 'SAMPLE Washable Cleaning Cloths', 'Reusable cloths for the home.', 249,
      Icons.cleaning_services_rounded),
  // Financial
  _P('fi-planner', _f, 'Budget planners', 'SAMPLE Budget Planner', 'Pages to track income and spending.', 399,
      Icons.account_balance_wallet_rounded),
  _P('fi-envelopes', _f, 'Budget planners', 'SAMPLE Cash Envelopes', 'Labelled envelopes for spending categories.', 199,
      Icons.mail_outline_rounded),
  _P('fi-tracker', _f, 'Budget planners', 'SAMPLE Savings Tracker Poster', 'A chart to colour in as you save.', 149,
      Icons.insert_chart_outlined_rounded),
  _P('fi-jar', _f, 'Savings tools', 'SAMPLE Savings Jar', 'A clear jar for coins.', 249, Icons.savings_rounded),
  _P('fi-calc', _f, 'Savings tools', 'SAMPLE Calculator', 'A basic desk calculator.', 349, Icons.calculate_rounded),
  _P('fi-wallet', _f, 'Savings tools', 'SAMPLE Card Wallet', 'A slim wallet with few slots.', 499, Icons.wallet_rounded),
  _P('fi-course-basics', _f, 'Money courses', 'SAMPLE Course: Money Basics', 'A placeholder course. Not financial advice.', 999,
      Icons.school_rounded),
  _P('fi-course-budget', _f, 'Money courses', 'SAMPLE Course: Building a Budget', 'A placeholder course. Not financial advice.', 799,
      Icons.school_rounded),
  _P('fi-workbook', _f, 'Money courses', 'SAMPLE Money Goals Workbook', 'Exercises for writing down money goals. Not financial advice.',
      299, Icons.flag_rounded),
];

Product? productById(String id) => catalog.where((p) => p.id == id).firstOrNull;

List<String> categoriesFor(WellnessDimension? d) => {
      for (final p in catalog)
        if (d == null || p.dimension == d) p.category
    }.toList();

List<Product> searchProducts({String q = '', WellnessDimension? dim, String? category}) {
  final s = q.trim().toLowerCase();
  return [
    for (final p in catalog)
      if ((dim == null || p.dimension == dim) &&
          (category == null || p.category == category) &&
          (s.isEmpty || '${p.name} ${p.category} ${p.blurb} ${p.dimension.label}'.toLowerCase().contains(s)))
        p
  ];
}

/// Items for the user's OneUP Focus dimensions, round-robin, skipping consult-only.
List<Product> recommendedProducts(List<WellnessDimension> focus, {int n = 8}) {
  final lists = [for (final d in focus) catalog.where((p) => p.dimension == d && !p.consultOnly).toList()];
  final out = <Product>[];
  for (var i = 0; out.length < n && lists.any((l) => i < l.length); i++) {
    for (final l in lists) {
      if (i < l.length && out.length < n) out.add(l[i]);
    }
  }
  return out;
}

/// Plus "Picked for you": items for the user's lowest-scored dimensions (2 per dimension, up to 3 dimensions).
/// Uses only scores the user already sees; no health claims.
List<(Product, WellnessDimension, int)> pickedForYou(Map<WellnessDimension, int> latest, {int dims = 3, int per = 2}) {
  final low = latest.entries.toList()..sort((a, b) => a.value.compareTo(b.value));
  return [
    for (final e in low.take(dims))
      for (final p in catalog.where((p) => p.dimension == e.key && !p.consultOnly).toList().reversed.take(per)) (p, e.key, e.value),
  ];
}

class Order {
  const Order(
      {required this.id,
      required this.lines,
      required this.total,
      required this.createdAt,
      required this.name,
      required this.city,
      this.status = 'Placed (demo)'});
  final String id;
  final Map<String, int> lines;
  final int total;
  final DateTime createdAt;
  final String name, city, status;

  Map<String, dynamic> toJson() =>
      {'id': id, 'lines': lines, 'total': total, 'createdAt': createdAt.toIso8601String(), 'name': name, 'city': city, 'status': status};
  factory Order.fromJson(Map<String, dynamic> j) => Order(
        id: j['id'] as String,
        lines: Map<String, int>.from(j['lines'] as Map),
        total: j['total'] as int,
        createdAt: DateTime.parse(j['createdAt'] as String),
        name: j['name'] as String,
        city: j['city'] as String,
        status: j['status'] as String? ?? 'Placed (demo)',
      );

  /// Demo status timeline derived from age (no real fulfilment).
  String statusAt(DateTime now) {
    final h = now.difference(createdAt).inHours;
    if (h >= 72) return 'Delivered (demo)';
    if (h >= 24) return 'Shipped (demo)';
    return status;
  }
}

/// A shop-by-category entry: one category name, with every dimension it spans (SAMPLE items only).
class MarketCategory {
  const MarketCategory(this.name, this.dimensions, this.count, this.icon);
  final String name;
  final List<WellnessDimension> dimensions;
  final int count;
  final IconData icon;
  WellnessDimension get primary => dimensions.first;
}

/// All categories, ordered by dimension then first appearance in the catalog.
List<MarketCategory> marketCategories() {
  final order = <String>[];
  final dims = <String, List<WellnessDimension>>{};
  final count = <String, int>{};
  final icon = <String, IconData>{};
  for (final d in WellnessDimension.values) {
    for (final p in catalog.where((p) => p.dimension == d)) {
      if (!dims.containsKey(p.category)) {
        order.add(p.category);
        dims[p.category] = [];
        icon[p.category] = p.icon;
      }
      if (!dims[p.category]!.contains(d)) dims[p.category]!.add(d);
      count[p.category] = (count[p.category] ?? 0) + 1;
    }
  }
  return [for (final c in order) MarketCategory(c, dims[c]!, count[c]!, icon[c]!)];
}

MarketCategory? categoryByName(String name) => marketCategories().where((c) => c.name == name).firstOrNull;

enum CategorySort { featured, priceLow, priceHigh, name }

/// Products in a category, optionally one dimension, sorted. Consult-first items (no price) sort last on price sorts.
List<Product> categoryProducts(String category, {WellnessDimension? dim, CategorySort sort = CategorySort.featured}) {
  final l = [
    for (final p in catalog)
      if (p.category == category && (dim == null || p.dimension == dim)) p
  ];
  int price(Product p, bool asc) => p.consultOnly ? (asc ? 1 << 30 : -1) : p.price;
  switch (sort) {
    case CategorySort.featured:
      break;
    case CategorySort.priceLow:
      l.sort((a, b) => price(a, true).compareTo(price(b, true)));
    case CategorySort.priceHigh:
      l.sort((a, b) => price(b, false).compareTo(price(a, false)));
    case CategorySort.name:
      l.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
  }
  return l;
}
