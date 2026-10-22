import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

extension SafePop on BuildContext {
  /// Pops if there is something to pop, otherwise goes Home (e.g. after a deep link), instead of throwing.
  void popOrHome() => canPop() ? pop() : go('/home');
}
