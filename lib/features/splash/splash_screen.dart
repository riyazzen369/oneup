import 'package:flutter/material.dart';
import '../../core/widgets/fx.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/router/app_router.dart';
import '../../core/services/auth_service.dart';
import '../../core/services/secure_store.dart';
import '../../core/widgets/gradient_background.dart';
import '../../core/widgets/oneup_logo.dart';
import '../../core/widgets/stellar_agents_logo.dart';
import '../consent/consent_screen.dart';

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});
  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen> with TickerProviderStateMixin {
  late final _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1800));
  // Stellar Agents wheel: one slow turn every 16 s, continuous.
  late final _spin = AnimationController(vsync: this, duration: const Duration(seconds: 16));

  @override
  void initState() {
    super.initState();
    _c.forward();
    _spin.repeat();
    _route();
  }

  Future<void> _route() async {
    final store = ref.read(secureStoreProvider);
    final auth = ref.read(authServiceProvider);
    final results = await Future.wait([
      store.read(SecureStore.kOnboarded),
      store.read(SecureStore.kConsentVersion),
      Future.delayed(const Duration(milliseconds: 2200)),
    ]);
    if (!mounted) return;
    String dest;
    if (results[0] != 'true') {
      dest = Routes.onboarding;
    } else if (!await auth.isSignedIn()) {
      dest = Routes.login;
    } else {
      Map<String, dynamic>? profile;
      try {
        profile = await auth.fetchProfile();
      } catch (_) {}
      if (profile == null || (profile['name'] as String?)?.isNotEmpty != true) {
        dest = Routes.profileSetup;
      } else if (results[1] != kConsentVersion && profile['consent_version'] != kConsentVersion) {
        dest = Routes.consent;
      } else {
        dest = Routes.home;
      }
    }
    if (mounted) context.go(dest);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (reducedMotion(context)) {
      _c.stop();
      _c.value = 1;
      _spin.stop(); // reduced motion: static wheel
    }
    // Precache brand image + fonts so first frames after splash don't hitch.
    GoogleFonts.pendingFonts([GoogleFonts.poppins(), GoogleFonts.poppins(fontWeight: FontWeight.w700)]).catchError((_) => <void>[]);
  }

  @override
  void dispose() {
    _c.dispose();
    _spin.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SplashView(progress: _c, turns: _spin);
}

/// Opening-screen visuals: OneUp logo (unchanged), small rotating Stellar Agents credit.
class SplashView extends StatelessWidget {
  const SplashView({super.key, required this.progress, required this.turns});
  final Animation<double> progress;
  final Animation<double> turns;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    return Scaffold(
      body: GradientBackground(
        child: Center(
          child: AnimatedBuilder(
            animation: progress,
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Container(
                padding: const EdgeInsets.all(4),
                decoration: const BoxDecoration(color: Color(0xFF0E1020), shape: BoxShape.circle),
                child: StellarWheel(size: 52, turns: turns),
              ),
              const SizedBox(height: 8),
              Text('Created by Stellar Agents', style: t.textTheme.bodyMedium),
            ]),
            builder: (_, credit) {
              final v = Curves.easeInOutCubic.transform(progress.value);
              final fade = ((progress.value - 0.55) / 0.45).clamp(0.0, 1.0);
              return Column(mainAxisSize: MainAxisSize.min, children: [
                Transform.scale(scale: 0.8 + 0.2 * v, child: OneUpLogo(size: 140, progress: v)),
                const SizedBox(height: 24),
                Opacity(
                  opacity: fade,
                  child: Column(children: [
                    Text('OneUp', style: t.textTheme.headlineLarge?.copyWith(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 16),
                    credit!,
                  ]),
                ),
              ]);
            },
          ),
        ),
      ),
    );
  }
}
