import 'package:flutter/material.dart';
import '../../../core/widgets/fx.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/services/haptics.dart';
import '../data/consult_models.dart';
import '../data/consult_repository.dart';
import '../domain/consult_logic.dart';
import 'common.dart';

class MySessionsScreen extends ConsumerWidget {
  const MySessionsScreen({super.key});

  Future<void> _cancel(BuildContext context, WidgetRef ref, Booking b) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Cancel this session?'),
        content: Text('${fmtDay(b.start)}, ${fmtTime(b.start)}'),
        actions: [
          TextButton(onPressed: Haptics.tap(() => Navigator.pop(c, false)), child: const Text('Keep')),
          FilledButton(onPressed: Haptics.tap(() => Navigator.pop(c, true)), child: const Text('Cancel session')),
        ],
      ),
    );
    if (ok == true) {
      Haptics.medium();
      await ref.read(bookingsProvider.notifier).cancel(b.id);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final now = DateTime.now();
    final (up, past) = splitSessions(ref.watch(bookingsProvider), now);
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('My sessions'),
          bottom: TabBar(tabs: [Tab(text: 'Upcoming (${up.length})'), Tab(text: 'Past (${past.length})')]),
        ),
        body: TabBarView(children: [
          _List(items: up, empty: 'No upcoming sessions', now: now, onCancel: (b) => _cancel(context, ref, b)),
          _List(items: past, empty: 'No past sessions', now: now),
        ]),
      ),
    );
  }
}

class _List extends StatelessWidget {
  const _List({required this.items, required this.empty, required this.now, this.onCancel});
  final List<Booking> items;
  final String empty;
  final DateTime now;
  final void Function(Booking)? onCancel;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    if (items.isEmpty) return Center(child: Text(empty));
    return ListView(padding: const EdgeInsets.all(16), children: [
      for (final b in items)
        StaggerIn(
            index: items.indexOf(b).clamp(0, 10),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    ConsultantAvatar(c: consultantById(b.consultantId), radius: 20),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(consultantById(b.consultantId).name, style: t.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
                        Text('${fmtDay(b.start)}, ${fmtTime(b.start)} · ${b.mode.label}', style: t.textTheme.bodySmall),
                      ]),
                    ),
                    if (b.status == BookingStatus.cancelled) const Chip(label: Text('Cancelled')),
                  ]),
                  if (b.notes.isNotEmpty)
                    Padding(padding: const EdgeInsets.only(top: 8), child: Text('Notes: ${b.notes}', style: t.textTheme.bodySmall)),
                  if (onCancel != null) ...[
                    const SizedBox(height: 8),
                    Row(children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: Haptics.tap(canCancel(b, now) ? () => onCancel!(b) : null),
                          child: const Text('Cancel'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: () {
                            Haptics.light();
                            context.push('/consult/call/${b.id}');
                          },
                          icon: Icon(b.mode.icon),
                          label: Text(canJoin(b, now) ? 'Join' : 'Preview'),
                        ),
                      ),
                    ]),
                  ],
                ]),
              ),
            )),
    ]);
  }
}
