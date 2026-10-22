import 'package:flutter/material.dart';
import '../../core/services/haptics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/router/app_router.dart';
import '../../core/services/auth_service.dart';
import '../../core/services/secure_store.dart';
import '../../core/widgets/gradient_background.dart';

const kConsentVersion = '2026-10-v1';
const kDisclaimer = 'OneUp is for wellness awareness, not medical diagnosis.';

class ConsentScreen extends ConsumerStatefulWidget {
  const ConsentScreen({super.key});
  @override
  ConsumerState<ConsentScreen> createState() => _ConsentScreenState();
}

class _ConsentScreenState extends ConsumerState<ConsentScreen> {
  bool _data = false;
  bool _disclaimer = false;
  bool _busy = false;

  static const _sections = [
    (
      Icons.inventory_2_outlined,
      'What we collect',
      'Your mobile number or Google email (for sign-in), display name, age range, and your assessment answers and scores.'
    ),
    (Icons.flag_outlined, 'Why', 'Only to calculate your wellness scores, show your progress over time and suggest relevant resources.'),
    (
      Icons.lock_outline,
      'How it is protected',
      'Answers are encrypted on your device before upload and stored with access limited to your account.'
    ),
    (
      Icons.verified_user_outlined,
      'Your rights [VERIFY: DPDP Act 2023 wording]',
      'You can view, export or delete your data, and withdraw consent at any time from Profile → Privacy centre. '
          'Wording to be reviewed against the Digital Personal Data Protection Act, 2023 by legal counsel. [VERIFY]'
    ),
  ];

  Future<void> _accept() async {
    setState(() => _busy = true);
    try {
      await ref.read(authServiceProvider).recordConsent(kConsentVersion);
      await ref.read(secureStoreProvider).write(SecureStore.kConsentVersion, kConsentVersion);
      Haptics.success();
      if (mounted) context.go(Routes.home);
    } catch (e) {
      Haptics.error();
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    return Scaffold(
      body: GradientBackground(
        child: SafeArea(
          child: Column(children: [
            Expanded(
              child: ListView(padding: const EdgeInsets.all(24), children: [
                Text('Your privacy', style: t.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700)),
                const SizedBox(height: 8),
                Text('Your wellness answers are sensitive. Here is how we handle them.', style: t.textTheme.bodyLarge),
                const SizedBox(height: 20),
                for (final s in _sections)
                  Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    child: ListTile(
                      contentPadding: const EdgeInsets.all(16),
                      leading: Icon(s.$1, color: t.colorScheme.primary),
                      title: Text(s.$2, style: t.textTheme.titleMedium),
                      subtitle: Padding(padding: const EdgeInsets.only(top: 6), child: Text(s.$3)),
                    ),
                  ),
                Card(
                  color: t.colorScheme.tertiaryContainer,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(children: [
                      Icon(Icons.info_outline, color: t.colorScheme.onTertiaryContainer),
                      const SizedBox(width: 12),
                      Expanded(child: Text(kDisclaimer, style: TextStyle(color: t.colorScheme.onTertiaryContainer))),
                    ]),
                  ),
                ),
                const SizedBox(height: 12),
                CheckboxListTile(
                  value: _data,
                  onChanged: Haptics.pick((v) => setState(() => _data = v ?? false)),
                  title: const Text('I agree to OneUp processing my data as described above.'),
                  controlAffinity: ListTileControlAffinity.leading,
                ),
                CheckboxListTile(
                  value: _disclaimer,
                  onChanged: Haptics.pick((v) => setState(() => _disclaimer = v ?? false)),
                  title: const Text('I understand OneUp does not provide diagnosis or treatment.'),
                  controlAffinity: ListTileControlAffinity.leading,
                ),
              ]),
            ),
            Padding(
              padding: const EdgeInsets.all(24),
              child: FilledButton(
                onPressed: Haptics.tap(_data && _disclaimer && !_busy ? _accept : null),
                child: const Text('Agree and continue'),
              ),
            ),
          ]),
        ),
      ),
    );
  }
}
