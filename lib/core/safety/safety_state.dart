import 'package:flutter_riverpod/flutter_riverpod.dart';

/// True once a crisis signal was seen this app session: all coaching, product, course
/// and consultant suggestions are hidden (spec crisis_protocol step 1).
final crisisModeProvider = StateProvider<bool>((ref) => false);
