import 'package:flutter/material.dart';
import '../../core/widgets/fx.dart';
import '../../core/services/haptics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/router/app_router.dart';
import '../../core/services/secure_store.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/gradient_background.dart';
import '../../core/widgets/oneup_logo.dart';

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});
  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final _pc = PageController();

  @override
  void dispose() {
    _pc.dispose();
    super.dispose();
  }

  int _i = 0;

  static const _pages = [
    (
      '8 dimensions of wellness',
      'Emotional, Physical, Occupational, Social, Spiritual, Intellectual, Environmental and Financial — see your whole self in one view.'
    ),
    ('A short, honest check-in', '9 questions per dimension, answered on a simple 1–5 scale. Save and resume any time.'),
    (
      'Grow one step at a time',
      'See your wheel, track trends, learn everyday tips and explore resources matched to the areas you want to grow.'
    ),
  ];

  Future<void> _finish() async {
    await ref.read(secureStoreProvider).write(SecureStore.kOnboarded, 'true');
    if (mounted) context.go(Routes.login);
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final last = _i == _pages.length - 1;
    return Scaffold(
      body: GradientBackground(
        child: SafeArea(
          child: Column(children: [
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(onPressed: Haptics.tap(_finish), child: const Text('Skip')),
            ),
            Expanded(
              child: PageView.builder(
                controller: _pc,
                itemCount: _pages.length,
                onPageChanged: (i) => setState(() => _i = i),
                itemBuilder: (_, i) => Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32),
                  child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                    Flexible(child: FittedBox(fit: BoxFit.scaleDown, child: _Illustration(index: i))),
                    const SizedBox(height: 32),
                    Text(_pages[i].$1,
                        textAlign: TextAlign.center, style: t.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 12),
                    Text(_pages[i].$2, textAlign: TextAlign.center, style: t.textTheme.bodyLarge),
                  ]),
                ),
              ),
            ),
            Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              for (var d = 0; d < _pages.length; d++)
                AnimatedContainer(
                  duration: motion(context, const Duration(milliseconds: 250)),
                  margin: const EdgeInsets.all(4),
                  height: 8,
                  width: d == _i ? 24 : 8,
                  decoration: BoxDecoration(
                    color: d == _i ? t.colorScheme.primary : t.colorScheme.outlineVariant,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
            ]),
            Padding(
              padding: const EdgeInsets.all(24),
              child: FilledButton(
                onPressed: Haptics.tap(
                    last ? _finish : () => _pc.nextPage(duration: const Duration(milliseconds: 350), curve: Curves.easeOutCubic)),
                child: Text(last ? 'Get started' : 'Next'),
              ),
            ),
          ]),
        ),
      ),
    );
  }
}

class _Illustration extends StatelessWidget {
  const _Illustration({required this.index});
  final int index;

  @override
  Widget build(BuildContext context) {
    final b = Theme.of(context).brightness;
    if (index == 0) {
      return Wrap(
        alignment: WrapAlignment.center,
        spacing: 12,
        runSpacing: 12,
        children: [
          for (final d in WellnessDimension.values)
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: d.color(b).withOpacity(0.18),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Icon(d.icon, color: d.color(b), semanticLabel: d.label),
            ),
        ],
      );
    }
    if (index == 1) {
      return Column(children: [
        for (var i = 0; i < 3; i++)
          Container(
            margin: const EdgeInsets.symmetric(vertical: 6),
            height: 16,
            width: 220 - i * 40.0,
            decoration: BoxDecoration(gradient: AppColors.brandGradient, borderRadius: BorderRadius.circular(8)),
          ),
      ]);
    }
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: motion(context, const Duration(milliseconds: 1200)),
      builder: (_, v, __) => OneUpLogo(size: 160, progress: v),
    );
  }
}
