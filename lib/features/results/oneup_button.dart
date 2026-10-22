import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/services/haptics.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/oneup_logo.dart';

/// Prominent gradient "OneUP" call-to-action → Your OneUP Focus.
class OneUpButton extends StatelessWidget {
  const OneUpButton({super.key, this.compact = false});
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'OneUP: see your focus areas',
      excludeSemantics: true,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: AppColors.brandGradient,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [BoxShadow(color: AppColors.primary.withOpacity(0.35), blurRadius: 16, offset: const Offset(0, 6))],
        ),
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            borderRadius: BorderRadius.circular(18),
            onTap: () {
              Haptics.medium();
              context.push('/focus');
            },
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 20, vertical: compact ? 10 : 16),
              child: Row(mainAxisSize: MainAxisSize.min, mainAxisAlignment: MainAxisAlignment.center, children: [
                OneUpLogo(size: compact ? 22 : 28),
                const SizedBox(width: 10),
                const Text('OneUP', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800, letterSpacing: 0.5)),
                const SizedBox(width: 6),
                const Icon(Icons.arrow_forward_rounded, color: Colors.white, size: 20),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}
