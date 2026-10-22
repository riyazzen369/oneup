import 'package:flutter/material.dart';

/// Fade-through (Material motion) for every route; instant when animations are disabled.
class FadeThroughPageTransitionsBuilder extends PageTransitionsBuilder {
  const FadeThroughPageTransitionsBuilder();

  @override
  Widget buildTransitions<T>(
      PageRoute<T> route, BuildContext context, Animation<double> animation, Animation<double> secondaryAnimation, Widget child) {
    if (MediaQuery.maybeDisableAnimationsOf(context) ?? false) return child;
    final inCurve = CurvedAnimation(parent: animation, curve: const Interval(0.3, 1, curve: Curves.easeOutCubic));
    final outCurve = CurvedAnimation(parent: secondaryAnimation, curve: const Interval(0, 0.35, curve: Curves.easeIn));
    return FadeTransition(
      opacity: ReverseAnimation(outCurve),
      child: FadeTransition(
        opacity: inCurve,
        child: ScaleTransition(scale: Tween(begin: 0.94, end: 1.0).animate(inCurve), child: child),
      ),
    );
  }
}

/// Bouncing, always-scrollable physics app-wide.
class OneUpScrollBehavior extends MaterialScrollBehavior {
  const OneUpScrollBehavior();
  @override
  ScrollPhysics getScrollPhysics(BuildContext context) => const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics());
}
