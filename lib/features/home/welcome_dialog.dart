import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/services/haptics.dart';
import '../../core/services/secure_store.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/fx.dart';

// Copy is general wellness-model wording only: no statistics, studies or medical claims.
// [VERIFY] The eight-dimension model is commonly associated with SAMHSA's "Eight Dimensions
// of Wellness"; confirm attribution before naming any source in the UI (intentionally unnamed).
const welcomeTitle = 'Welcome to OneUp';
const welcomeBody1 = 'Wellbeing is more than one thing. OneUp looks at eight connected areas of life: emotional, physical, '
    'occupational, social, spiritual, intellectual, environmental and financial.';
const welcomeBody2 = 'These areas influence each other, so when one is neglected the others can feel it too. Checking in on all '
    'eight helps you see where you are doing well and where a small step could bring more balance.';
const welcomeDisclaimer = 'OneUp is for wellness awareness, not medical diagnosis.';
const welcomeCta = "Let's begin";

const kWelcomeShown = 'welcome_shown_v1';

/// Shows the welcome note once (first Home arrival after setup). The flag lives in
/// secure storage, so delete-my-data (deleteAll) resets it.
Future<void> maybeShowWelcome(BuildContext context, WidgetRef ref) async {
  final store = ref.read(secureStoreProvider);
  if (await store.read(kWelcomeShown) != null) return;
  await store.write(kWelcomeShown, DateTime.now().toUtc().toIso8601String());
  if (!context.mounted) return;
  Haptics.medium();
  await showGeneralDialog<void>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Welcome',
    barrierColor: Colors.black.withOpacity(0.55),
    transitionDuration: motion(context, const Duration(milliseconds: 420)),
    pageBuilder: (_, __, ___) => const WelcomeCard(),
    transitionBuilder: (_, a, __, child) {
      final c = CurvedAnimation(parent: a, curve: Curves.easeOutBack, reverseCurve: Curves.easeIn);
      return FadeTransition(
        opacity: a,
        child: ScaleTransition(scale: Tween(begin: 0.9, end: 1.0).animate(c), child: child),
      );
    },
  );
}

class WelcomeCard extends StatelessWidget {
  const WelcomeCard({super.key});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final b = t.brightness;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Material(
          color: Colors.transparent,
          child: Container(
            constraints: const BoxConstraints(maxWidth: 420),
            padding: const EdgeInsets.fromLTRB(22, 24, 22, 18),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(28),
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF3A2C9E), Color(0xFF231A63), Color(0xFF15123A)],
                stops: [0, 0.55, 1],
              ),
              border: Border.all(color: AppColors.primary.withOpacity(0.6), width: 1.2),
              boxShadow: [BoxShadow(color: AppColors.primary.withOpacity(0.45), blurRadius: 40, offset: const Offset(0, 16))],
            ),
            child: SingleChildScrollView(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                const _WheelMotif(size: 84),
                const SizedBox(height: 14),
                Text(welcomeTitle,
                    textAlign: TextAlign.center,
                    style: t.textTheme.headlineSmall?.copyWith(color: Colors.white, fontWeight: FontWeight.w800)),
                const SizedBox(height: 12),
                Text(welcomeBody1, textAlign: TextAlign.center, style: t.textTheme.bodyMedium?.copyWith(color: Colors.white, height: 1.4)),
                const SizedBox(height: 8),
                Text(welcomeBody2,
                    textAlign: TextAlign.center, style: t.textTheme.bodyMedium?.copyWith(color: Colors.white70, height: 1.4)),
                const SizedBox(height: 16),
                Wrap(spacing: 6, runSpacing: 6, alignment: WrapAlignment.center, children: [
                  for (final d in WellnessDimension.values)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: d.color(b).withOpacity(0.18),
                        borderRadius: BorderRadius.circular(99),
                        border: Border.all(color: d.color(b).withOpacity(0.5)),
                      ),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        Icon(d.icon, size: 13, color: d.color(Brightness.dark)),
                        const SizedBox(width: 4),
                        Text(d.label, style: t.textTheme.labelSmall?.copyWith(color: Colors.white, fontWeight: FontWeight.w600)),
                      ]),
                    ),
                ]),
                const SizedBox(height: 16),
                Text(welcomeDisclaimer, textAlign: TextAlign.center, style: t.textTheme.labelSmall?.copyWith(color: Colors.white60)),
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  child: PressScale(
                    semanticLabel: welcomeCta,
                    onTap: Haptics.tap(() => Navigator.of(context).pop()),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(gradient: AppColors.brandGradient, borderRadius: BorderRadius.circular(16)),
                      child: const Text(welcomeCta, style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 16)),
                    ),
                  ),
                ),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}

/// Eight coloured segments that sweep in, echoing the wellness wheel.
class _WheelMotif extends StatelessWidget {
  const _WheelMotif({required this.size});
  final double size;
  @override
  Widget build(BuildContext context) => RepaintBoundary(
        child: TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: 1),
          duration: motion(context, const Duration(milliseconds: 900)),
          curve: Curves.easeOutCubic,
          builder: (_, p, __) => CustomPaint(size: Size.square(size), painter: _MotifPainter(p)),
        ),
      );
}

class _MotifPainter extends CustomPainter {
  _MotifPainter(this.p);
  final double p;
  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.width / 2;
    const seg = 3.14159265 / 4;
    for (final d in WellnessDimension.values) {
      final local = ((p * 1.6) - d.index * 0.08).clamp(0.0, 1.0);
      final paint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = r * 0.32
        ..strokeCap = StrokeCap.butt
        ..color = d.color(Brightness.dark).withOpacity(0.25 + 0.75 * local);
      canvas.drawArc(
          Rect.fromCircle(center: c, radius: r * 0.78), -3.14159265 / 2 + d.index * seg + 0.04, (seg - 0.08) * local, false, paint);
    }
    canvas.drawCircle(c, r * 0.42, Paint()..color = Colors.white.withOpacity(0.12));
  }

  @override
  bool shouldRepaint(_MotifPainter o) => o.p != p;
}
