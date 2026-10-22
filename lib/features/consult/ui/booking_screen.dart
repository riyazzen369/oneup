import 'package:flutter/material.dart';
import '../../../core/widgets/fx.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/services/haptics.dart';
import '../data/consult_models.dart';
import '../data/consult_repository.dart';
import '../domain/consult_logic.dart';
import 'common.dart';

class BookingDraft {
  const BookingDraft(this.consultant, this.start, this.mode, this.notes);
  final Consultant consultant;
  final DateTime start;
  final SessionMode mode;
  final String notes;
}

class BookingScreen extends ConsumerStatefulWidget {
  const BookingScreen({super.key, required this.c});
  final Consultant c;
  @override
  ConsumerState<BookingScreen> createState() => _BookingScreenState();
}

class _BookingScreenState extends ConsumerState<BookingScreen> {
  final _now = DateTime.now();
  late DateTime _day = dateStrip(_now).first;
  DateTime? _slot;
  late SessionMode _mode = widget.c.modes.first;
  final _notes = TextEditingController();

  @override
  void dispose() {
    _notes.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final booked = ref.watch(bookingsProvider);
    final slots = generateSlots(_day, DateTime.now(), consultantId: widget.c.id, booked: booked);
    return Scaffold(
      appBar: AppBar(title: Text('Book ${widget.c.name}')),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        Text('Choose a date', style: t.textTheme.titleMedium),
        const SizedBox(height: 8),
        SizedBox(
          height: 78,
          child: ListView(scrollDirection: Axis.horizontal, children: [
            for (final d in dateStrip(_now))
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: _DayChip(
                  day: d,
                  selected: d == _day,
                  onTap: () {
                    Haptics.selection();
                    setState(() {
                      _day = d;
                      _slot = null;
                    });
                  },
                ),
              ),
          ]),
        ),
        const SizedBox(height: 16),
        Text('Available times (SAMPLE)', style: t.textTheme.titleMedium),
        const SizedBox(height: 8),
        if (slots.isEmpty) const Text('No times left on this day. Try another date.'),
        Wrap(spacing: 8, runSpacing: 8, children: [
          for (final s in slots)
            ChoiceChip(
              label: Text(fmtTime(s)),
              selected: _slot == s,
              onSelected: (_) {
                Haptics.selection();
                setState(() => _slot = s);
              },
            ),
        ]),
        const SizedBox(height: 16),
        Text('Session mode', style: t.textTheme.titleMedium),
        const SizedBox(height: 8),
        SegmentedButton<SessionMode>(
          segments: [
            for (final m in widget.c.modes) ButtonSegment(value: m, icon: Icon(m.icon), label: Text(m.label)),
          ],
          selected: {_mode},
          onSelectionChanged: (v) {
            Haptics.selection();
            setState(() => _mode = v.first);
          },
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _notes,
          minLines: 2,
          maxLines: 4,
          maxLength: 300,
          decoration: const InputDecoration(
            labelText: 'Notes for the session (optional)',
            helperText: 'Kept on this device only.',
          ),
        ),
        const SizedBox(height: 8),
        FilledButton(
          onPressed: _slot == null
              ? null
              : () {
                  Haptics.light();
                  context.push('/consult/pay', extra: BookingDraft(widget.c, _slot!, _mode, _notes.text));
                },
          child: Text(_slot == null ? 'Pick a time' : 'Continue · ${fmtDay(_slot!)}, ${fmtTime(_slot!)}'),
        ),
      ]),
    );
  }
}

class _DayChip extends StatelessWidget {
  const _DayChip({required this.day, required this.selected, required this.onTap});
  final DateTime day;
  final bool selected;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final parts = fmtDay(day).split(' ');
    return Semantics(
      selected: selected,
      button: true,
      label: fmtDay(day),
      excludeSemantics: true,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: Haptics.tap(onTap),
        child: AnimatedContainer(
          duration: motion(context, const Duration(milliseconds: 200)),
          width: 62,
          decoration: BoxDecoration(
            color: selected ? t.colorScheme.primary : t.colorScheme.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: selected ? t.colorScheme.primary : t.colorScheme.outlineVariant),
          ),
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Text(parts[0], style: TextStyle(color: selected ? t.colorScheme.onPrimary : null, fontSize: 12)),
            Text(parts[1], style: TextStyle(color: selected ? t.colorScheme.onPrimary : null, fontSize: 20, fontWeight: FontWeight.w800)),
            Text(parts[2], style: TextStyle(color: selected ? t.colorScheme.onPrimary : null, fontSize: 11)),
          ]),
        ),
      ),
    );
  }
}
