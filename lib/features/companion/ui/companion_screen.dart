import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/config/env.dart';
import '../../../core/services/haptics.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/fx.dart';
import '../data/playbook.dart';
import '../domain/companion_controller.dart';
import '../domain/companion_models.dart';

/// Loads disclaimers from the bundled spec.
final companionSpecProvider = FutureProvider<Map<String, dynamic>>((ref) async {
  return jsonDecode(await rootBundle.loadString('assets/companion/spec.json')) as Map<String, dynamic>;
});

class CompanionScreen extends ConsumerStatefulWidget {
  const CompanionScreen({super.key});
  @override
  ConsumerState<CompanionScreen> createState() => _CompanionScreenState();
}

class _CompanionScreenState extends ConsumerState<CompanionScreen> {
  final _input = TextEditingController();
  final _scroll = ScrollController();
  bool _shownIntro = false;

  static const _chips = [
    'Help me understand my scores',
    'I feel stressed about work lately',
    'Give me a small habit for this week',
    'Are you a real therapist?',
  ];

  @override
  void dispose() {
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _maybeIntro() async {
    if (_shownIntro) return;
    final s = ref.read(companionProvider);
    if (!s.loaded || s.disclaimerSeen) return;
    _shownIntro = true;
    Map<String, dynamic>? spec;
    try {
      spec = await ref.read(companionSpecProvider.future);
    } catch (_) {}
    if (!mounted) return;
    final d = spec?['disclaimers'];
    final first = d is Map ? d['first_session'] : null;
    await showConsentSheet(context, ref,
        firstSession: first is String
            ? first
            : "I'm an AI wellness companion, not a therapist or doctor. I can't diagnose or treat. For that, I can connect you with a qualified professional.");
  }

  Future<void> _send(String text) async {
    if (text.trim().isEmpty) return;
    _input.clear();
    final r = await ref.read(companionProvider.notifier).send(text);
    if (!mounted) return;
    Haptics.selection();
    _toEnd();
    if (r.risk == RiskLevel.crisis && mounted) {
      Haptics.medium();
      context.push('/crisis');
    }
  }

  void _toEnd() => WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _scroll.hasClients) {
          _scroll.animateTo(_scroll.position.maxScrollExtent + 120,
              duration: motion(context, const Duration(milliseconds: 300)), curve: Curves.easeOut);
        }
      });

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(companionProvider);
    final t = Theme.of(context);
    ref.listen(companionProvider, (_, __) => _toEnd());
    if (!_shownIntro) WidgetsBinding.instance.addPostFrameCallback((_) => _maybeIntro());
    final disc = ref.watch(companionSpecProvider).valueOrNull?['disclaimers'];
    final fs = disc is Map ? disc['footer_short'] : null;
    final footer = fs is String ? fs : 'For wellness awareness, not medical diagnosis.';
    return Scaffold(
      appBar: AppBar(
        title: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('OneUp Companion'),
          Text(Env.isConfigured ? 'AI wellness companion' : 'AI wellness companion · offline demo', style: t.textTheme.labelSmall),
        ]),
        actions: [
          IconButton(
            tooltip: 'Companion settings',
            icon: const Icon(Icons.tune_rounded),
            onPressed: Haptics.tap(() => showConsentSheet(context, ref)),
          ),
        ],
      ),
      body: Column(children: [
        Expanded(
          child: ListView(controller: _scroll, padding: const EdgeInsets.all(16), children: [
            const _Bubble(
              fromUser: false,
              text: "Hi, I'm OneUp Companion, an AI. I can help you reflect on your wellness scores and try small everyday habits. "
                  'What would you like to talk about?',
            ),
            for (final m in s.messages) ...[
              _Bubble(fromUser: m.fromUser, text: m.text),
              if (!m.fromUser && m.meta != null) _ActionRow(reply: m.meta!),
            ],
            if (s.typing) const _Typing(),
          ]),
        ),
        if (s.messages.isEmpty)
          SizedBox(
            height: 48,
            child: ListView(scrollDirection: Axis.horizontal, padding: const EdgeInsets.symmetric(horizontal: 12), children: [
              for (final c in _chips)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ActionChip(label: Text(c), onPressed: Haptics.tap(() => _send(c))),
                ),
            ]),
          ),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 6, 12, 6),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Row(children: [
                Expanded(
                  child: TextField(
                    controller: _input,
                    minLines: 1,
                    maxLines: 4,
                    maxLength: 600,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: const InputDecoration(hintText: 'Type a message…', counterText: ''),
                    onSubmitted: (v) {
                      Haptics.light();
                      _send(v);
                    },
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filled(
                  tooltip: 'Send',
                  onPressed: Haptics.tap(s.typing ? null : () => _send(_input.text)),
                  icon: const Icon(Icons.send_rounded),
                ),
              ]),
              const SizedBox(height: 4),
              Text(footer, style: t.textTheme.labelSmall),
            ]),
          ),
        ),
      ]),
    );
  }
}

Future<void> showConsentSheet(BuildContext context, WidgetRef ref, {String? firstSession}) async {
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    isDismissible: firstSession == null,
    enableDrag: firstSession == null,
    showDragHandle: true,
    builder: (c) => Consumer(builder: (c, ref, _) {
      final s = ref.watch(companionProvider);
      final ctrl = ref.read(companionProvider.notifier);
      final t = Theme.of(c);
      return SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Text(firstSession == null ? 'Companion settings' : 'Before we start', style: t.textTheme.titleLarge),
            if (firstSession != null) ...[
              const SizedBox(height: 8),
              Card(
                color: t.colorScheme.tertiaryContainer,
                child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Text(firstSession, style: TextStyle(color: t.colorScheme.onTertiaryContainer))),
              ),
            ],
            SwitchListTile(
              title: const Text('Use my scores in chat'),
              subtitle: const Text('Lets the companion refer to your latest dimension scores.'),
              value: s.useScores,
              onChanged: Haptics.pick((v) => ctrl.setConsent(useScores: v)),
            ),
            SwitchListTile(
              title: const Text('Store chat history'),
              subtitle: const Text('Saved encrypted on this phone only. Turning this off deletes it.'),
              value: s.storeHistory,
              onChanged: Haptics.pick((v) => ctrl.setConsent(storeHistory: v)),
            ),
            SwitchListTile(
              title: const Text('Allow human review of flagged sessions'),
              subtitle: const Text('Only a safety flag is recorded, never your messages.'),
              value: s.allowReview,
              onChanged: Haptics.pick((v) => ctrl.setConsent(allowReview: v)),
            ),
            if (s.messages.isNotEmpty && firstSession == null)
              TextButton.icon(
                onPressed: Haptics.tap(ctrl.clearHistory),
                icon: const Icon(Icons.delete_outline_rounded),
                label: const Text('Clear this conversation'),
              ),
            const SizedBox(height: 4),
            Text('Absolute confidentiality cannot be promised. See the privacy policy.', style: t.textTheme.bodySmall),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: Haptics.tap(() {
                ctrl.setConsent(disclaimerSeen: true);
                Navigator.pop(c);
              }),
              child: Text(firstSession == null ? 'Done' : 'I understand'),
            ),
          ]),
        ),
      );
    }),
  );
  // Closing the first-session sheet counts as acknowledged.
  await ref.read(companionProvider.notifier).setConsent(disclaimerSeen: true);
}

class _Bubble extends StatelessWidget {
  const _Bubble({required this.fromUser, required this.text});
  final bool fromUser;
  final String text;
  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final bubble = Container(
      constraints: BoxConstraints(maxWidth: MediaQuery.sizeOf(context).width * 0.78),
      margin: const EdgeInsets.symmetric(vertical: 4),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        gradient: fromUser ? AppColors.brandGradient : null,
        color: fromUser ? null : t.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.only(
          topLeft: const Radius.circular(18),
          topRight: const Radius.circular(18),
          bottomLeft: Radius.circular(fromUser ? 18 : 4),
          bottomRight: Radius.circular(fromUser ? 4 : 18),
        ),
      ),
      child: Text(text, style: t.textTheme.bodyMedium?.copyWith(color: fromUser ? Colors.white : null)),
    );
    final animated = reducedMotion(context)
        ? bubble
        : TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: 1),
            duration: motion(context, const Duration(milliseconds: 260)),
            curve: Curves.easeOutCubic,
            child: bubble,
            builder: (_, v, c) => Opacity(opacity: v, child: Transform.translate(offset: Offset(0, 10 * (1 - v)), child: c)),
          );
    return Semantics(
      label: '${fromUser ? 'You' : 'Companion'}: $text',
      excludeSemantics: true,
      child: Align(alignment: fromUser ? Alignment.centerRight : Alignment.centerLeft, child: animated),
    );
  }
}

class _ActionRow extends StatelessWidget {
  const _ActionRow({required this.reply});
  final CompanionReply reply;
  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    Widget? chip;
    switch (reply.actionType) {
      case ActionType.consultant:
        chip = ActionChip(
          avatar: const Icon(Icons.support_agent_rounded, size: 18),
          label: const Text('See consultants (suggestion)'),
          onPressed: () {
            Haptics.light();
            context.go('/consult${reply.actionId == null ? '' : '?type=${reply.actionId}'}');
          },
        );
      case ActionType.skill:
        final id = reply.actionId;
        if (id != null && kSkillHowTo.containsKey(id)) {
          chip = ActionChip(
            avatar: const Icon(Icons.self_improvement_rounded, size: 18),
            label: Text('Try: $id'),
            onPressed: () {
              Haptics.light();
              showDialog<void>(
                context: context,
                builder: (c) => AlertDialog(
                  title: Text(id[0].toUpperCase() + id.substring(1)),
                  content: Text('${kSkillHowTo[id]}\n\nA general wellness idea, not medical advice.'),
                  actions: [TextButton(onPressed: () => Navigator.pop(c), child: const Text('Close'))],
                ),
              );
            },
          );
        }
      case ActionType.content:
      case ActionType.none:
        break;
    }
    if (reply.risk == RiskLevel.crisis) {
      chip = ActionChip(
        avatar: Icon(Icons.emergency_rounded, size: 18, color: t.colorScheme.error),
        label: const Text('Show helplines'),
        onPressed: Haptics.tap(() => context.push('/crisis')),
      );
    }
    if (chip == null) return const SizedBox.shrink();
    return Align(alignment: Alignment.centerLeft, child: Padding(padding: const EdgeInsets.only(bottom: 4), child: chip));
  }
}

class _Typing extends StatefulWidget {
  const _Typing();
  @override
  State<_Typing> createState() => _TypingState();
}

class _TypingState extends State<_Typing> with SingleTickerProviderStateMixin {
  late final _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 900))..repeat();

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (reducedMotion(context)) {
      _c.stop();
      _c.value = 0.5; // static dots
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    return Semantics(
      label: 'Companion is typing',
      child: Align(
        alignment: Alignment.centerLeft,
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 4),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(color: t.colorScheme.surfaceContainerHighest, borderRadius: BorderRadius.circular(18)),
          child: AnimatedBuilder(
            animation: _c,
            builder: (_, __) => Row(mainAxisSize: MainAxisSize.min, children: [
              for (var i = 0; i < 3; i++)
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 2),
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: t.colorScheme.onSurface
                        .withOpacity(0.3 + 0.6 * (((_c.value * 3) - i).clamp(0.0, 1.0) * (1 - (((_c.value * 3) - i - 1).clamp(0.0, 1.0))))),
                    shape: BoxShape.circle,
                  ),
                ),
            ]),
          ),
        ),
      ),
    );
  }
}
