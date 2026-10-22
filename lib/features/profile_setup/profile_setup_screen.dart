import 'package:flutter/material.dart';
import '../../core/services/haptics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/router/app_router.dart';
import '../../core/services/auth_service.dart';
import '../../core/widgets/gradient_background.dart';
import '../profile/data/profile_repository.dart';

/// Minimal data collection: display name + age range only.
class ProfileSetupScreen extends ConsumerStatefulWidget {
  const ProfileSetupScreen({super.key});
  @override
  ConsumerState<ProfileSetupScreen> createState() => _ProfileSetupScreenState();
}

class _ProfileSetupScreenState extends ConsumerState<ProfileSetupScreen> {
  final _name = TextEditingController();

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  String? _age;
  bool _busy = false;
  static const _ranges = ['18–24', '25–34', '35–44', '45–54', '55–64', '65+'];

  Future<void> _save() async {
    setState(() => _busy = true);
    try {
      await ref.read(authServiceProvider).upsertProfile(name: _name.text.trim(), ageRange: _age!);
      ref.invalidate(profileProvider);
      Haptics.success();
      if (mounted) context.go(Routes.consent);
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
    final ok = _name.text.trim().isNotEmpty && _age != null;
    return Scaffold(
      body: GradientBackground(
        child: SafeArea(
          child: ListView(padding: const EdgeInsets.all(24), children: [
            const SizedBox(height: 24),
            Text('About you', style: t.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            Text('We only ask for what we need.', style: t.textTheme.bodyLarge),
            const SizedBox(height: 24),
            Center(
              child: CircleAvatar(
                radius: 44,
                backgroundColor: t.colorScheme.primaryContainer,
                child: Text(
                  _name.text.trim().isEmpty ? '?' : _name.text.trim()[0].toUpperCase(),
                  style: t.textTheme.headlineMedium,
                ),
              ),
            ),
            const SizedBox(height: 24),
            TextField(
              controller: _name,
              textCapitalization: TextCapitalization.words,
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(labelText: 'What should we call you?'),
            ),
            const SizedBox(height: 24),
            Text('Age range', style: t.textTheme.titleMedium),
            const SizedBox(height: 8),
            Wrap(spacing: 8, runSpacing: 8, children: [
              for (final r in _ranges)
                ChoiceChip(label: Text(r), selected: _age == r, onSelected: Haptics.pick((_) => setState(() => _age = r))),
            ]),
            const SizedBox(height: 32),
            FilledButton(onPressed: Haptics.tap(ok && !_busy ? _save : null), child: const Text('Continue')),
          ]),
        ),
      ),
    );
  }
}
