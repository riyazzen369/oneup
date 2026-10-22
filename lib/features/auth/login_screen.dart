import 'package:flutter/material.dart';
import '../../core/services/haptics.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/router/app_router.dart';
import '../../core/services/auth_service.dart';
import '../../core/widgets/gradient_background.dart';
import '../../core/widgets/oneup_logo.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});
  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _phone = TextEditingController();

  @override
  void dispose() {
    _phone.dispose();
    super.dispose();
  }

  bool _busy = false;

  bool get _valid => RegExp(r'^\d{10}$').hasMatch(_phone.text);

  Future<void> _send() async {
    final phone = '+91${_phone.text}';
    setState(() => _busy = true);
    try {
      await ref.read(authServiceProvider).sendOtp(phone);
      if (mounted) context.push(Routes.otp, extra: phone);
    } catch (e) {
      _err(e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _google() async {
    setState(() => _busy = true);
    try {
      await ref.read(authServiceProvider).signInWithGoogle();
      // After the OAuth redirect returns, the splash re-routes based on session.
      if (mounted) context.go(Routes.splash);
    } catch (e) {
      _err(e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _err(Object e) {
    if (!mounted) return;
    Haptics.error();
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final demo = ref.read(authServiceProvider).isDemo;
    return Scaffold(
      body: GradientBackground(
        child: SafeArea(
          child: ListView(padding: const EdgeInsets.all(24), children: [
            const SizedBox(height: 32),
            const Center(child: OneUpLogo(size: 88)),
            const SizedBox(height: 24),
            Text('Welcome to OneUp', textAlign: TextAlign.center, style: t.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            Text('Sign in with your mobile number', textAlign: TextAlign.center, style: t.textTheme.bodyLarge),
            if (demo) ...[
              const SizedBox(height: 16),
              Card(
                color: t.colorScheme.tertiaryContainer,
                child: ListTile(
                  leading: Icon(Icons.science_outlined, color: t.colorScheme.onTertiaryContainer),
                  title: Text('Demo mode', style: TextStyle(color: t.colorScheme.onTertiaryContainer, fontWeight: FontWeight.w700)),
                  subtitle: Text(
                      'No server connected. Use any 10-digit mobile number and code ${AuthService.demoOtp}. Data stays on this phone.',
                      style: TextStyle(color: t.colorScheme.onTertiaryContainer)),
                ),
              ),
            ],
            const SizedBox(height: 32),
            TextField(
              controller: _phone,
              keyboardType: TextInputType.phone,
              maxLength: 10,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(
                labelText: 'Mobile number',
                prefixText: '+91  ',
                counterText: '',
              ),
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: Haptics.tap(_valid && !_busy ? _send : null),
              child:
                  _busy ? const SizedBox(height: 22, width: 22, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('Send OTP'),
            ),
            const SizedBox(height: 24),
            Row(children: [
              const Expanded(child: Divider()),
              Padding(padding: const EdgeInsets.symmetric(horizontal: 12), child: Text('or', style: t.textTheme.bodySmall)),
              const Expanded(child: Divider()),
            ]),
            const SizedBox(height: 24),
            OutlinedButton.icon(
              onPressed: Haptics.tap(_busy || demo ? null : _google),
              icon: const Icon(Icons.g_mobiledata_rounded, size: 32),
              label: Text(demo ? 'Google: unavailable in demo' : 'Continue with Google'),
            ),
          ]),
        ),
      ),
    );
  }
}
