import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/services/auth_service.dart';
import '../../../core/services/haptics.dart';
import '../../../core/widgets/fx.dart';
import '../data/profile_repository.dart';
import '../domain/user_profile.dart';
import 'profile_avatar.dart';

class EditProfileScreen extends ConsumerStatefulWidget {
  const EditProfileScreen({super.key});
  @override
  ConsumerState<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends ConsumerState<EditProfileScreen> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController(),
      _email = TextEditingController(),
      _other = TextEditingController(),
      _city = TextEditingController();
  UserProfile? _initial;
  String? _profession, _age, _gender;
  bool _busy = false;

  void _fill(UserProfile p) {
    _initial = p;
    _name.text = p.name;
    _email.text = p.email;
    _city.text = p.city;
    _age = p.ageRange;
    _gender = p.gender;
    if (p.profession.isEmpty) {
      _profession = null;
    } else if (UserProfile.professions.contains(p.profession)) {
      _profession = p.profession;
    } else {
      _profession = 'Other';
      _other.text = p.profession;
    }
  }

  UserProfile _current() => (_initial ?? const UserProfile()).copyWith(
        name: _name.text.trim(),
        email: _email.text.trim(),
        profession: _profession == 'Other' ? _other.text.trim() : (_profession ?? ''),
        ageRange: _age,
        gender: _gender,
        city: _city.text.trim(),
      );

  bool get _dirty {
    final i = _initial;
    if (i == null) return false;
    final c = _current();
    return c.name != i.name ||
        c.email != i.email ||
        c.profession != i.profession ||
        c.ageRange != i.ageRange ||
        c.gender != i.gender ||
        c.city != i.city;
  }

  @override
  void dispose() {
    for (final c in [_name, _email, _other, _city]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) {
      Haptics.error();
      return;
    }
    setState(() => _busy = true);
    try {
      final p = _current();
      await ref.read(profileRepositoryProvider).save(p);
      _initial = p;
      ref.invalidate(profileProvider);
      Haptics.success();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Profile saved')));
      Navigator.of(context).pop();
    } catch (e) {
      Haptics.error();
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<bool> _confirmDiscard() async {
    Haptics.medium();
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Discard changes?'),
        content: const Text('You have unsaved changes to your profile.'),
        actions: [
          TextButton(onPressed: Haptics.tap(() => Navigator.pop(c, false)), child: const Text('Keep editing')),
          FilledButton(onPressed: Haptics.tap(() => Navigator.pop(c, true)), child: const Text('Discard')),
        ],
      ),
    );
    return ok == true;
  }

  void _changeMobile() {
    final demo = ref.read(authServiceProvider).isDemo;
    showDialog<void>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Change mobile number'),
        content: Text(demo
            ? 'Changing your number needs a fresh OTP verification. This is a placeholder in the demo build.'
            : 'Changing your number needs a fresh OTP verification. This is coming soon.'),
        actions: [TextButton(onPressed: Haptics.tap(() => Navigator.pop(c)), child: const Text('OK'))],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final async = ref.watch(profileProvider);
    final p = async.valueOrNull;
    if (p != null && _initial == null) _fill(p);
    return PopScope(
      canPop: !_dirty,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        if (await _confirmDiscard() && context.mounted) {
          _initial = _current(); // allow pop
          Navigator.of(context).pop();
        }
      },
      child: Scaffold(
        appBar: AppBar(title: const Text('Edit profile')),
        body: p == null
            ? const Center(child: CircularProgressIndicator())
            : Form(
                key: _form,
                onChanged: () => setState(() {}),
                child: ListView(padding: const EdgeInsets.fromLTRB(16, 8, 16, 32), children: [
                  Center(
                    child: ProfileAvatar(
                      initials: _current().initials,
                      onEdit: Haptics.tap(() => showPhotoSheet(context, ref, hasPhoto: p.hasAvatar)),
                    ),
                  ),
                  const SizedBox(height: 16),
                  StaggerIn(
                      index: 0,
                      child: TextFormField(
                        controller: _name,
                        textCapitalization: TextCapitalization.words,
                        textInputAction: TextInputAction.next,
                        validator: ProfileValidators.name,
                        decoration: const InputDecoration(labelText: 'Full name *', prefixIcon: Icon(Icons.person_outline_rounded)),
                      )),
                  const SizedBox(height: 12),
                  StaggerIn(
                      index: 1,
                      child: TextFormField(
                        key: const Key('mobile'),
                        initialValue: p.phone.isEmpty ? '' : ProfileValidators.formatPhone(p.phone),
                        readOnly: true,
                        decoration: InputDecoration(
                          labelText: 'Mobile number',
                          prefixIcon: const Icon(Icons.phone_iphone_rounded),
                          suffixIcon: Row(mainAxisSize: MainAxisSize.min, children: [
                            if (p.phone.isNotEmpty) _Badge('Verified', t.colorScheme.primary, Icons.verified_rounded),
                            TextButton(onPressed: Haptics.tap(_changeMobile), child: const Text('Change')),
                          ]),
                        ),
                      )),
                  const SizedBox(height: 12),
                  StaggerIn(
                      index: 2,
                      child: TextFormField(
                        controller: _email,
                        keyboardType: TextInputType.emailAddress,
                        autocorrect: false,
                        textInputAction: TextInputAction.next,
                        validator: ProfileValidators.email,
                        autovalidateMode: AutovalidateMode.onUserInteraction,
                        decoration: InputDecoration(
                          labelText: 'Email (optional)',
                          prefixIcon: const Icon(Icons.alternate_email_rounded),
                          suffixIcon: _email.text.trim().isEmpty
                              ? null
                              : Padding(
                                  padding: const EdgeInsets.only(right: 8),
                                  child: _Badge('Unverified', t.colorScheme.outline, Icons.info_outline_rounded)),
                          suffixIconConstraints: const BoxConstraints(minHeight: 24),
                        ),
                      )),
                  const SizedBox(height: 20),
                  StaggerIn(
                      index: 3,
                      child: _Section('Profession', [
                        for (final o in UserProfile.professions)
                          ChoiceChip(
                              label: Text(o),
                              selected: _profession == o,
                              onSelected: Haptics.pick((s) => setState(() => _profession = s ? o : null))),
                      ])),
                  AnimatedSize(
                    duration: motion(context, const Duration(milliseconds: 220)),
                    child: _profession == 'Other'
                        ? Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: TextFormField(
                              controller: _other,
                              textCapitalization: TextCapitalization.sentences,
                              validator: ProfileValidators.otherProfession,
                              decoration: const InputDecoration(labelText: 'Your profession'),
                            ),
                          )
                        : const SizedBox(width: double.infinity),
                  ),
                  const SizedBox(height: 20),
                  StaggerIn(
                      index: 4,
                      child: _Section('Age range', [
                        for (final o in UserProfile.ageRanges)
                          ChoiceChip(
                              label: Text(o), selected: _age == o, onSelected: Haptics.pick((s) => setState(() => _age = s ? o : null))),
                      ])),
                  const SizedBox(height: 20),
                  StaggerIn(
                      index: 5,
                      child: _Section('Gender (optional)', [
                        for (final o in UserProfile.genders)
                          ChoiceChip(
                              label: Text(o),
                              selected: _gender == o,
                              onSelected: Haptics.pick((s) => setState(() => _gender = s ? o : null))),
                      ])),
                  const SizedBox(height: 20),
                  StaggerIn(
                      index: 6,
                      child: TextFormField(
                        controller: _city,
                        textCapitalization: TextCapitalization.words,
                        validator: ProfileValidators.city,
                        decoration: const InputDecoration(labelText: 'City (optional)', prefixIcon: Icon(Icons.location_city_rounded)),
                      )),
                  const SizedBox(height: 12),
                  Text('We only use these details to personalise your experience. OneUp is for wellness awareness, not medical diagnosis.',
                      style: t.textTheme.bodySmall),
                  const SizedBox(height: 20),
                  FilledButton.icon(
                    onPressed: Haptics.tap(_busy || !_dirty ? null : _save),
                    icon: _busy
                        ? const SizedBox.square(dimension: 18, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.check_rounded),
                    label: const Text('Save'),
                  ),
                ]),
              ),
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section(this.title, this.chips);
  final String title;
  final List<Widget> chips;
  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title, style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 8),
        Wrap(spacing: 8, runSpacing: 8, children: chips),
      ]);
}

class _Badge extends StatelessWidget {
  const _Badge(this.label, this.color, this.icon);
  final String label;
  final Color color;
  final IconData icon;
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(99)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(label, style: Theme.of(context).textTheme.labelSmall?.copyWith(color: color, fontWeight: FontWeight.w600)),
        ]),
      );
}
