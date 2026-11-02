import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/services/haptics.dart';
import '../../core/services/secure_store.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/fx.dart';
import '../ritual/ritual.dart' show ritualClockProvider;
import 'entitlement.dart';
import 'plus_ui.dart';

/// DEMO/SAMPLE services for OneUP Plus. Nothing is booked, sent or charged; requests stay on this device.
const coachDisclaimer = 'SAMPLE coaches, demo booking. Wellness coaching is not therapy or medical care. '
    'For health concerns, see a qualified professional. In an emergency, use Crisis help.';
const supportCrisisNote = 'If you are in danger or thinking about harming yourself, do not wait for a reply. '
    'Crisis help is free and immediate for everyone.';

class SampleCoach {
  const SampleCoach(this.id, this.name, this.dimension, this.focus);
  final String id, name, focus;
  final WellnessDimension dimension;
}

const sampleCoaches = <SampleCoach>[
  SampleCoach('coach-emotional', 'SAMPLE Coach Asha', WellnessDimension.emotional, 'Noticing feelings and building calm routines'),
  SampleCoach('coach-physical', 'SAMPLE Coach Vikram', WellnessDimension.physical, 'Gentle movement, sleep and energy habits'),
  SampleCoach('coach-occupational', 'SAMPLE Coach Meera', WellnessDimension.occupational, 'Work rhythm, focus and boundaries'),
  SampleCoach('coach-social', 'SAMPLE Coach Rahul', WellnessDimension.social, 'Staying connected and reaching out'),
  SampleCoach('coach-spiritual', 'SAMPLE Coach Priya', WellnessDimension.spiritual, 'Values, meaning and quiet reflection'),
  SampleCoach('coach-intellectual', 'SAMPLE Coach Arjun', WellnessDimension.intellectual, 'Curiosity, learning plans and reading habits'),
  SampleCoach('coach-environmental', 'SAMPLE Coach Kavya', WellnessDimension.environmental, 'Tidy spaces and greener routines'),
  SampleCoach(
      'coach-financial', 'SAMPLE Coach Nikhil', WellnessDimension.financial, 'Budget basics and saving habits (no financial advice)'),
];

/// Demo slots: next 3 days at 10:00, 14:00 and 18:00 local time.
List<DateTime> demoSlots(DateTime now) => [
      for (var d = 1; d <= 3; d++)
        for (final h in [10, 14, 18]) DateTime(now.year, now.month, now.day + d, h),
    ];

String slotLabel(DateTime s) {
  const wd = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
  const mo = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
  final h = s.hour % 12 == 0 ? 12 : s.hour % 12;
  return '${wd[s.weekday - 1]} ${s.day} ${mo[s.month - 1]} · $h:00 ${s.hour < 12 ? 'AM' : 'PM'}';
}

/// A coaching booking/chat request or a support request, stored encrypted on device only.
class ServiceRequest {
  const ServiceRequest({required this.kind, required this.title, required this.at, this.slot, this.priority = false});
  final String kind; // coach-session | coach-chat | support
  final String title;
  final DateTime at;
  final DateTime? slot;
  final bool priority;
  Map<String, dynamic> toJson() =>
      {'k': kind, 't': title, 'at': at.toIso8601String(), if (slot != null) 's': slot!.toIso8601String(), 'p': priority};
  factory ServiceRequest.fromJson(Map<String, dynamic> j) => ServiceRequest(
      kind: j['k'] as String,
      title: j['t'] as String,
      at: DateTime.parse(j['at'] as String),
      slot: j['s'] == null ? null : DateTime.parse(j['s'] as String),
      priority: j['p'] as bool? ?? false);
}

class ServiceRequestsController extends StateNotifier<List<ServiceRequest>> {
  ServiceRequestsController(this._store, this._clock) : super(const []) {
    ready = _load();
  }
  static const key = 'plus_requests_v1';
  final SecureStore _store;
  final DateTime Function() _clock;
  late final Future<void> ready;
  Future<void> _load() async {
    try {
      final raw = await _store.read(key);
      if (raw != null && mounted) {
        state = [for (final e in jsonDecode(raw) as List) ServiceRequest.fromJson(e as Map<String, dynamic>)];
      }
    } catch (_) {}
  }

  Future<ServiceRequest> add(String kind, String title, {DateTime? slot, bool priority = false}) async {
    await ready;
    final r = ServiceRequest(kind: kind, title: title, at: _clock(), slot: slot, priority: priority);
    state = [r, ...state].take(20).toList();
    await _store.write(key, jsonEncode([for (final x in state) x.toJson()]));
    return r;
  }
}

final serviceRequestsProvider = StateNotifierProvider<ServiceRequestsController, List<ServiceRequest>>(
    (ref) => ServiceRequestsController(ref.read(secureStoreProvider), ref.read(ritualClockProvider)));

class _DemoLabel extends StatelessWidget {
  const _DemoLabel(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(color: Colors.orange.withOpacity(0.18), borderRadius: BorderRadius.circular(8)),
        child: Text(text, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.orange)),
      );
}

/// Demo slot picker sheet. Returns the chosen slot or null.
Future<DateTime?> pickDemoSlot(BuildContext context, DateTime now, String who) => showModalBottomSheet<DateTime>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (c) {
        DateTime? sel;
        return StatefulBuilder(
          builder: (c, set) => SafeArea(
            child: Padding(
              key: const Key('demo-slot-picker'),
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Pick a time with $who', style: Theme.of(c).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
                const SizedBox(height: 4),
                const _DemoLabel('SAMPLE, demo booking · nothing is booked or charged'),
                const SizedBox(height: 12),
                Wrap(spacing: 8, runSpacing: 8, children: [
                  for (final (i, s) in demoSlots(now).indexed)
                    ChoiceChip(key: Key('slot-$i'), label: Text(slotLabel(s)), selected: sel == s, onSelected: (_) => set(() => sel = s)),
                ]),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    key: const Key('slot-confirm'),
                    onPressed: sel == null ? null : () => Navigator.pop(c, sel),
                    child: const Text('Confirm demo booking'),
                  ),
                ),
              ]),
            ),
          ),
        );
      },
    );

class CoachingScreen extends ConsumerWidget {
  const CoachingScreen({super.key});

  Future<void> _book(BuildContext context, WidgetRef ref, SampleCoach c, {required bool chat}) async {
    if (!ref.read(isPlusProvider)) return showPlusUpsell(context, PlusFeature.coaching);
    final m = ScaffoldMessenger.of(context);
    if (chat) {
      await ref.read(serviceRequestsProvider.notifier).add('coach-chat', 'Chat request · ${c.name}');
      m.showSnackBar(SnackBar(content: Text('Chat request saved (demo). ${c.name} is a SAMPLE coach; no message is sent.')));
      return;
    }
    final s = await pickDemoSlot(context, ref.read(ritualClockProvider)(), c.name);
    if (s == null) return;
    await ref.read(serviceRequestsProvider.notifier).add('coach-session', 'Coaching · ${c.name}', slot: s);
    m.showSnackBar(SnackBar(content: Text('Demo booking saved: ${slotLabel(s)}. Nothing was booked or charged.')));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = Theme.of(context);
    final plus = ref.watch(isPlusProvider);
    final reqs = ref.watch(serviceRequestsProvider).where((r) => r.kind.startsWith('coach')).toList();
    return Scaffold(
      appBar: AppBar(title: const Text('1-on-1 coaching')),
      body: ListView(key: const Key('coaching-screen'), padding: const EdgeInsets.all(16), children: [
        Text(coachDisclaimer, key: const Key('coach-disclaimer'), style: t.textTheme.bodySmall),
        const SizedBox(height: 8),
        if (!plus)
          const PlusLockCard(
              feature: PlusFeature.coaching,
              message: 'Booking a coach or requesting a chat is part of OneUP Plus. You can browse coaches below.'),
        if (reqs.isNotEmpty) ...[
          Text('Your demo requests', style: t.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
          for (final r in reqs)
            ListTile(
              dense: true,
              leading: Icon(r.slot == null ? Icons.chat_bubble_outline_rounded : Icons.event_available_rounded),
              title: Text(r.title),
              subtitle: Text(r.slot == null ? 'Chat request (demo)' : slotLabel(r.slot!)),
            ),
          const SizedBox(height: 8),
        ],
        for (final c in sampleCoaches)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: GlassCard(
              key: Key(c.id),
              padding: const EdgeInsets.all(12),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  CircleAvatar(
                      backgroundColor: c.dimension.color(t.brightness), foregroundColor: Colors.white, child: Icon(c.dimension.icon)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(c.name, style: t.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
                      Text('${c.dimension.label} · ${c.focus}', style: t.textTheme.bodySmall),
                    ]),
                  ),
                ]),
                const SizedBox(height: 8),
                Wrap(alignment: WrapAlignment.end, crossAxisAlignment: WrapCrossAlignment.center, spacing: 4, children: [
                  if (!plus) const PlusBadge(small: true),
                  TextButton(
                      key: Key('${c.id}-chat'), onPressed: () => _book(context, ref, c, chat: true), child: const Text('Request chat')),
                  FilledButton.tonal(
                      key: Key('${c.id}-book'), onPressed: () => _book(context, ref, c, chat: false), child: const Text('Book')),
                ]),
              ]),
            ),
          ),
      ]),
    );
  }
}

class SupportScreen extends ConsumerStatefulWidget {
  const SupportScreen({super.key});
  @override
  ConsumerState<SupportScreen> createState() => _SupportScreenState();
}

class _SupportScreenState extends ConsumerState<SupportScreen> {
  final _msg = TextEditingController();
  String _topic = 'App help';

  @override
  void dispose() {
    _msg.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    if (_msg.text.trim().isEmpty) return;
    final plus = ref.read(isPlusProvider);
    // Only the topic is kept; the message text is not stored or sent anywhere in this demo.
    await ref.read(serviceRequestsProvider.notifier).add('support', 'Support · $_topic', priority: plus);
    _msg.clear();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content:
              Text(plus ? 'Request saved with priority response (demo). Nothing was sent.' : 'Request saved (demo). Nothing was sent.')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final plus = ref.watch(isPlusProvider);
    final reqs = ref.watch(serviceRequestsProvider).where((r) => r.kind == 'support').toList();
    return Scaffold(
      appBar: AppBar(title: const Text('Support')),
      body: ListView(key: const Key('support-screen'), padding: const EdgeInsets.all(16), children: [
        // Always first, always free, never behind priority.
        Card(
          key: const Key('support-crisis'),
          color: Colors.red.withOpacity(0.15),
          child: ListTile(
            leading: const Icon(Icons.sos_rounded, color: Colors.redAccent),
            title: const Text('Need help right now?', style: TextStyle(fontWeight: FontWeight.w800)),
            subtitle: const Text(supportCrisisNote),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: Haptics.tap(() => context.push('/crisis')),
          ),
        ),
        const SizedBox(height: 12),
        Wrap(spacing: 8, crossAxisAlignment: WrapCrossAlignment.center, children: [
          Text('Send a request', style: t.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(width: 8),
          if (plus) const _DemoLabel('Priority response (demo)') else const PlusBadge(small: true),
        ]),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          key: const Key('support-topic'),
          value: _topic,
          decoration: const InputDecoration(labelText: 'Topic', border: OutlineInputBorder()),
          items: [
            for (final s in ['App help', 'Account & privacy', 'OneUP Plus (demo)', 'Feedback']) DropdownMenuItem(value: s, child: Text(s)),
          ],
          onChanged: (v) => setState(() => _topic = v ?? _topic),
        ),
        const SizedBox(height: 8),
        TextField(
          key: const Key('support-message'),
          controller: _msg,
          minLines: 3,
          maxLines: 6,
          decoration:
              const InputDecoration(labelText: 'Message', hintText: 'Please don’t include health details.', border: OutlineInputBorder()),
        ),
        const SizedBox(height: 8),
        FilledButton(
            key: const Key('support-send'), onPressed: _send, child: Text(plus ? 'Send priority request (demo)' : 'Send request (demo)')),
        const SizedBox(height: 6),
        Text(
            plus
                ? 'Plus requests are marked for priority response (demo). Demo only: nothing is sent; only the topic is saved on this device.'
                : 'Standard response (demo). Plus members get priority response (demo). Demo only: nothing is sent.',
            style: t.textTheme.bodySmall),
        if (reqs.isNotEmpty) ...[
          const SizedBox(height: 16),
          Text('Your demo requests', style: t.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
          for (final r in reqs)
            ListTile(
              dense: true,
              leading: const Icon(Icons.support_agent_rounded),
              title: Text(r.title),
              trailing: r.priority ? const _DemoLabel('Priority (demo)') : const Text('Standard'),
            ),
        ],
      ]),
    );
  }
}
