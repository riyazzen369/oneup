import 'package:flutter/material.dart';
import '../../../core/services/haptics.dart';
import 'package:go_router/go_router.dart';

import '../../../core/widgets/fx.dart';
import '../data/consult_models.dart';
import 'common.dart';

class BookingConfirmedScreen extends StatelessWidget {
  const BookingConfirmedScreen({super.key, required this.booking});
  final Booking booking;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final c = consultantById(booking.consultantId);
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(children: [
            const Spacer(),
            TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: 1),
              duration: reducedMotion(context) ? Duration.zero : const Duration(milliseconds: 700),
              curve: Curves.elasticOut,
              builder: (_, v, __) => Transform.scale(
                scale: v,
                child: Icon(Icons.check_circle_rounded, size: 110, color: t.colorScheme.primary),
              ),
            ),
            const SizedBox(height: 16),
            Text('Session booked', style: t.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            Text('${c.name} (SAMPLE)\n${fmtDay(booking.start)}, ${fmtTime(booking.start)} · ${booking.mode.label}',
                textAlign: TextAlign.center, style: t.textTheme.bodyLarge),
            const Spacer(),
            FilledButton(onPressed: Haptics.tap(() => context.go('/consult/sessions')), child: const Text('View my sessions')),
            const SizedBox(height: 8),
            OutlinedButton(onPressed: Haptics.tap(() => context.go('/consult')), child: const Text('Back to Consult')),
          ]),
        ),
      ),
    );
  }
}
