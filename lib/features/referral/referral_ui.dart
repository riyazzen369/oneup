import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../plus/plus_ui.dart';
import '../report/weekly_report.dart';
import '../ritual/ritual.dart';
import 'referral.dart';

class InviteScreen extends ConsumerWidget {
  const InviteScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(referralProvider);
    final t = Theme.of(context);
    final code = s.code;
    final c = s.challenge;
    final mine = ref.watch(challengeProgressProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Invite friends')),
      body: ListView(padding: const EdgeInsets.fromLTRB(16, 8, 16, 32), children: [
        PlusFrame(
          key: const Key('invite-hero'),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(children: [
              const PlusWordmark(),
              const SizedBox(height: 10),
              Text('Both of you get 1 week of OneUP Plus',
                  key: const Key('invite-reward'),
                  textAlign: TextAlign.center,
                  style: t.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900)),
              const SizedBox(height: 6),
              const Text('Share your code. When a friend redeems it, you each get 7 days of Plus.', textAlign: TextAlign.center),
              const SizedBox(height: 16),
              Text('YOUR INVITE CODE', style: t.textTheme.labelMedium?.copyWith(letterSpacing: 1.2, color: plusOn(context))),
              const SizedBox(height: 6),
              GestureDetector(
                onLongPress: code == null ? null : () => Clipboard.setData(ClipboardData(text: code)),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                  decoration:
                      BoxDecoration(borderRadius: BorderRadius.circular(14), border: Border.all(color: plusOn(context), width: 1.5)),
                  child: Text(code ?? '…',
                      key: const Key('invite-code'),
                      style: t.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900, letterSpacing: 2)),
                ),
              ),
              const SizedBox(height: 16),
              PlusButton(
                key: const Key('invite-share'),
                icon: Icons.ios_share_rounded,
                label: 'Share invite',
                onPressed: code == null
                    ? null
                    : () async {
                        await ref.read(referralProvider.notifier).keepCode();
                        await ref.read(inviteSharerProvider)(inviteText(code));
                      },
              ),
            ]),
          ),
        ),
        const SizedBox(height: 12),
        Card(
          key: const Key('invite-friends'),
          child: ListTile(
            leading: const Icon(Icons.group_add_rounded),
            title: Text('${s.friendsJoined} friends joined · SAMPLE'),
            subtitle: const Text('Demo counter. Each join adds 7 days of Plus (up to $maxRewardedFriends).'),
            trailing: TextButton(
              key: const Key('invite-simulate'),
              onPressed: () async {
                final got = await ref.read(referralProvider.notifier).simulateFriendJoined();
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(got ? 'Demo: a friend joined. +7 days of Plus' : 'Demo: friend joined (reward cap reached)')));
                }
              },
              child: const Text('Simulate'),
            ),
          ),
        ),
        Card(
          child: ListTile(
            key: const Key('invite-redeem-entry'),
            leading: const Icon(Icons.redeem_rounded),
            title: const Text('Have an invite code?'),
            subtitle: Text(s.redeemed == null ? 'Redeem it for 7 days of Plus' : 'Redeemed ${s.redeemed}'),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () => showRedeemSheet(context),
          ),
        ),
        const SizedBox(height: 16),
        Text('Friend challenges', style: t.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
        const SizedBox(height: 4),
        const Text('Pick one, share it, and track your side here. Your progress comes only from this device.'),
        const SizedBox(height: 8),
        if (c != null && mine != null)
          PlusFrame(
            key: const Key('challenge-active'),
            glow: 0.4,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(c.kind.title, style: t.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900)),
                Text(c.kind.blurb),
                const SizedBox(height: 12),
                _Bar(key: const Key('challenge-you'), label: 'You', value: mine, goal: c.kind.goal),
                const SizedBox(height: 8),
                _Bar(
                    key: const Key('challenge-friend'),
                    label: 'Friend · SAMPLE',
                    value: c.kind.sampleFriend,
                    goal: c.kind.goal,
                    sample: true),
                const SizedBox(height: 4),
                Text('Friend progress is SAMPLE data: there is no backend, so real friends\' progress is not shown.',
                    style: t.textTheme.bodySmall),
                const SizedBox(height: 12),
                Row(children: [
                  Expanded(
                    child: PlusButton(
                      key: const Key('challenge-share'),
                      icon: Icons.ios_share_rounded,
                      label: 'Share challenge',
                      onPressed: code == null ? null : () => ref.read(inviteSharerProvider)(challengeText(c.kind, code)),
                    ),
                  ),
                  const SizedBox(width: 8),
                  TextButton(
                      key: const Key('challenge-leave'),
                      onPressed: () => ref.read(referralProvider.notifier).leaveChallenge(),
                      child: const Text('Leave')),
                ]),
              ]),
            ),
          )
        else
          for (final k in ChallengeKind.values)
            Card(
              child: ListTile(
                key: Key('challenge-${k.name}'),
                leading: Icon(switch (k) {
                  ChallengeKind.ritualStreak => Icons.local_fire_department_rounded,
                  ChallengeKind.lessonsWeek => Icons.menu_book_rounded,
                  ChallengeKind.everyDimension => Icons.sports_esports_rounded,
                }),
                title: Text(k.title),
                subtitle: Text(k.blurb),
                trailing: const Icon(Icons.add_circle_outline_rounded),
                onTap: () => ref.read(referralProvider.notifier).startChallenge(k),
              ),
            ),
        const SizedBox(height: 16),
        Text(referralDemoNote, key: const Key('invite-demo-note'), textAlign: TextAlign.center, style: t.textTheme.bodySmall),
      ]),
    );
  }
}

class _Bar extends StatelessWidget {
  const _Bar({super.key, required this.label, required this.value, required this.goal, this.sample = false});
  final String label;
  final int value, goal;
  final bool sample;
  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [Expanded(child: Text(label, style: const TextStyle(fontWeight: FontWeight.w700))), Text('$value / $goal')]),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(99),
          child: LinearProgressIndicator(
            value: goal == 0 ? 0 : value / goal,
            minHeight: 8,
            color: sample ? Theme.of(context).colorScheme.outline : plusOn(context),
          ),
        ),
      ]);
}

Future<void> showRedeemSheet(BuildContext context) =>
    showModalBottomSheet<void>(context: context, isScrollControlled: true, showDragHandle: true, builder: (_) => const RedeemSheet());

class RedeemSheet extends ConsumerStatefulWidget {
  const RedeemSheet({super.key});
  @override
  ConsumerState<RedeemSheet> createState() => _RedeemSheetState();
}

class _RedeemSheetState extends ConsumerState<RedeemSheet> {
  final _c = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  Future<void> _go() async {
    final r = await ref.read(referralProvider.notifier).redeem(_c.text);
    if (!mounted) return;
    if (r == RedeemResult.ok) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Code redeemed: 7 days of OneUP Plus added (demo)')));
      return;
    }
    setState(() => _error = switch (r) {
          RedeemResult.badFormat => 'Codes look like ONEUP-AB23',
          RedeemResult.ownCode => 'That\'s your own code. Share it with a friend instead.',
          RedeemResult.alreadyRedeemed => 'An invite code was already redeemed on this device.',
          RedeemResult.ok => null,
        });
  }

  @override
  Widget build(BuildContext context) {
    final done = ref.watch(referralProvider).redeemed;
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 0, 20, 20 + MediaQuery.viewInsetsOf(context).bottom),
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text('Have an invite code?', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
        const SizedBox(height: 4),
        Text(done == null ? 'Enter a friend\'s code for 7 days of OneUP Plus. One code per device.' : 'You already redeemed $done.'),
        const SizedBox(height: 12),
        TextField(
          key: const Key('redeem-field'),
          controller: _c,
          textCapitalization: TextCapitalization.characters,
          decoration:
              InputDecoration(labelText: 'Invite code', hintText: 'ONEUP-AB23', errorText: _error, border: const OutlineInputBorder()),
          onSubmitted: (_) => _go(),
        ),
        const SizedBox(height: 12),
        PlusButton(key: const Key('redeem-submit'), label: 'Redeem', icon: Icons.redeem_rounded, onPressed: _go),
        const SizedBox(height: 8),
        Text('Demo: only the code format is checked, on this device.',
            style: Theme.of(context).textTheme.bodySmall, textAlign: TextAlign.center),
      ]),
    );
  }
}

/// Gentle Home card: shown after 3+ ritual days or once a weekly report exists; dismissible.
class InviteHomeCard extends ConsumerWidget {
  const InviteHomeCard({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(referralProvider);
    final days = ref.watch(ritualProvider).days.values.where((d) => d.counts).length;
    final hasReport = ref.watch(reportsProvider).reports.isNotEmpty;
    if (!s.loaded || s.homeCardDismissed || (days < 3 && !hasReport)) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: PlusFrame(
        key: const Key('invite-home-card'),
        glow: 0.35,
        child: ListTile(
          leading: Icon(Icons.card_giftcard_rounded, color: plusOn(context)),
          title: const Text('Better with a friend', style: TextStyle(fontWeight: FontWeight.w800)),
          subtitle: const Text('Invite someone: you both get 1 week of Plus.'),
          onTap: () => context.push('/invite'),
          trailing: IconButton(
              key: const Key('invite-home-dismiss'),
              tooltip: 'Not now',
              icon: const Icon(Icons.close_rounded),
              onPressed: () => ref.read(referralProvider.notifier).dismissHomeCard()),
        ),
      ),
    );
  }
}

/// "Get Plus free: invite a friend" for the Plus screen.
class InvitePlusCta extends StatelessWidget {
  const InvitePlusCta({super.key});
  @override
  Widget build(BuildContext context) => OutlinedButton.icon(
        key: const Key('plus-invite'),
        style: OutlinedButton.styleFrom(side: BorderSide(color: plusOn(context), width: 1.5), padding: const EdgeInsets.all(14)),
        onPressed: () => context.push('/invite'),
        icon: Icon(Icons.group_add_rounded, color: plusOn(context)),
        label: Text('Get Plus free: invite a friend', style: TextStyle(color: plusOn(context), fontWeight: FontWeight.w800)),
      );
}
