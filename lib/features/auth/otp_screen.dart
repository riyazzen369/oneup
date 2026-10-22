import 'dart:async';
import '../../core/services/haptics.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/router/app_router.dart';
import '../../core/services/auth_service.dart';
import '../../core/widgets/gradient_background.dart';

class OtpScreen extends ConsumerStatefulWidget {
  const OtpScreen({super.key, required this.phone});
  final String phone;
  @override
  ConsumerState<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends ConsumerState<OtpScreen> {
  final _code = TextEditingController();
  bool _busy = false;
  int _seconds = 30;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _startTimer();
  }

  void _startTimer() {
    _seconds = 30;
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (_seconds == 0) return t.cancel();
      if (mounted) setState(() => _seconds--);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _code.dispose();
    super.dispose();
  }

  Future<void> _verify() async {
    setState(() => _busy = true);
    try {
      await ref.read(authServiceProvider).verifyOtp(widget.phone, _code.text);
      if (mounted) context.go(Routes.splash); // splash decides profile/consent/home
    } catch (e) {
      Haptics.error();
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _resend() async {
    try {
      await ref.read(authServiceProvider).sendOtp(widget.phone);
      _startTimer();
    } catch (e) {
      Haptics.error();
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    return Scaffold(
      appBar: AppBar(backgroundColor: Colors.transparent),
      extendBodyBehindAppBar: true,
      body: GradientBackground(
        child: SafeArea(
          child: ListView(padding: const EdgeInsets.all(24), children: [
            const SizedBox(height: 24),
            Text('Verify your number', style: t.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            Text(
                ref.read(authServiceProvider).isDemo
                    ? 'Demo mode: no SMS is sent. Enter ${AuthService.demoOtp}.'
                    : 'Enter the 6-digit code sent to ${widget.phone}',
                style: t.textTheme.bodyLarge),
            const SizedBox(height: 32),
            TextField(
              controller: _code,
              autofocus: true,
              keyboardType: TextInputType.number,
              maxLength: 6,
              textAlign: TextAlign.center,
              style: t.textTheme.headlineSmall?.copyWith(letterSpacing: 12),
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              autofillHints: const [AutofillHints.oneTimeCode],
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(counterText: '', hintText: '------'),
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: Haptics.tap(_code.text.length == 6 && !_busy ? _verify : null),
              child: _busy ? const SizedBox(height: 22, width: 22, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('Verify'),
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: Haptics.tap(_seconds == 0 ? _resend : null),
              child: Text(_seconds == 0 ? 'Resend code' : 'Resend in ${_seconds}s'),
            ),
          ]),
        ),
      ),
    );
  }
}
