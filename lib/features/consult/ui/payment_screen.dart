import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/services/haptics.dart';
import '../data/consult_repository.dart';
import 'booking_screen.dart';
import 'common.dart';

class PaymentScreen extends ConsumerStatefulWidget {
  const PaymentScreen({super.key, required this.draft});
  final BookingDraft draft;
  @override
  ConsumerState<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends ConsumerState<PaymentScreen> {
  bool _busy = false;

  Future<void> _confirm() async {
    setState(() => _busy = true);
    try {
      final d = widget.draft;
      final b = await ref.read(bookingsProvider.notifier).book(consultant: d.consultant, start: d.start, mode: d.mode, notes: d.notes);
      Haptics.medium();
      if (mounted) context.go('/consult/done', extra: b);
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
    final d = widget.draft;
    return Scaffold(
      appBar: AppBar(title: const Text('Review & pay')),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        Card(
          child: Column(children: [
            ListTile(
                leading: ConsultantAvatar(c: d.consultant, radius: 20),
                title: Text(d.consultant.name),
                subtitle: Text(d.consultant.type.label),
                trailing: const SampleBadge()),
            ListTile(
                leading: const Icon(Icons.event_rounded),
                title: Text('${fmtDay(d.start)}, ${fmtTime(d.start)}'),
                subtitle: const Text('45 minutes')),
            ListTile(leading: Icon(d.mode.icon), title: Text('${d.mode.label} session')),
            ListTile(
                leading: const Icon(Icons.payments_outlined),
                title: const Text('Fee'),
                trailing: Text(d.consultant.priceLabel, style: t.textTheme.titleMedium)),
          ]),
        ),
        Card(
          color: t.colorScheme.errorContainer,
          child: ListTile(
            leading: Icon(Icons.construction_rounded, color: t.colorScheme.onErrorContainer),
            title:
                Text('Payment integration pending', style: TextStyle(color: t.colorScheme.onErrorContainer, fontWeight: FontWeight.w700)),
            subtitle: Text('No money is charged. This is a placeholder for a licensed payment gateway.',
                style: TextStyle(color: t.colorScheme.onErrorContainer)),
          ),
        ),
        const SizedBox(height: 12),
        FilledButton.icon(
          onPressed: Haptics.tap(_busy ? null : _confirm),
          icon: const Icon(Icons.lock_outline_rounded),
          label: const Text('Confirm booking (no charge)'),
        ),
      ]),
    );
  }
}
