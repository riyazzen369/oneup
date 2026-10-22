import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_displaymode/flutter_displaymode.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'core/config/env.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/motion.dart';
import 'core/services/settings_service.dart';
import 'core/services/haptics.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await applyHighRefreshRate();
  if (Env.isConfigured) {
    await Supabase.initialize(url: Env.supabaseUrl, publishableKey: Env.supabaseAnonKey);
  }
  runApp(const ProviderScope(child: OneUpApp()));
  // Re-apply after the first frame (some OEMs reset it once the surface exists) and on resume.
  WidgetsBinding.instance.addPostFrameCallback((_) => applyHighRefreshRate());
  WidgetsBinding.instance.addObserver(_RefreshRateObserver());
}

class _RefreshRateObserver extends WidgetsBindingObserver {
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) applyHighRefreshRate();
  }
}

/// Picks the highest refresh rate available at the current resolution (e.g. 120 Hz) and
/// logs the result. Best-effort: unsupported devices / OS versions keep their default.
Future<void> applyHighRefreshRate() async {
  if (kIsWeb || !Platform.isAndroid) return;
  try {
    final modes = await FlutterDisplayMode.supported;
    final active = await FlutterDisplayMode.active;
    final same = modes.where((m) => m.width == active.width && m.height == active.height).toList()
      ..sort((a, b) => b.refreshRate.compareTo(a.refreshRate));
    if (same.isNotEmpty && same.first.refreshRate > active.refreshRate) {
      await FlutterDisplayMode.setPreferredMode(same.first);
    } else {
      await FlutterDisplayMode.setHighRefreshRate();
    }
    final now = await FlutterDisplayMode.active;
    debugPrint('OneUp display mode: ${now.width}x${now.height} @ ${now.refreshRate.toStringAsFixed(0)} Hz '
        '(max available ${same.isEmpty ? '?' : same.first.refreshRate.toStringAsFixed(0)} Hz)');
  } catch (e) {
    debugPrint('OneUp display mode: unchanged ($e)');
  }
}

class OneUpApp extends ConsumerWidget {
  const OneUpApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    final themeMode = ref.watch(themeModeProvider);
    ref.watch(hapticsProvider); // loads saved Haptics preference
    return MaterialApp.router(
      title: 'OneUp',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: themeMode,
      routerConfig: router,
      scrollBehavior: const OneUpScrollBehavior(),
      builder: (context, child) {
        // Respect user font scaling but clamp to keep layouts usable.
        final mq = MediaQuery.of(context);
        return MediaQuery(
          data: mq.copyWith(textScaler: mq.textScaler.clamp(minScaleFactor: 0.85, maxScaleFactor: 1.6)),
          child: child!,
        );
      },
    );
  }
}
