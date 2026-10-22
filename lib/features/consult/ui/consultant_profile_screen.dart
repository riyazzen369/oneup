import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/services/haptics.dart';
import '../data/consult_models.dart';
import 'common.dart';

class ConsultantProfileScreen extends StatelessWidget {
  const ConsultantProfileScreen({super.key, required this.c});
  final Consultant c;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Consultant')),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        Center(child: Hero(tag: 'c-${c.id}', child: ConsultantAvatar(c: c, radius: 48))),
        const SizedBox(height: 12),
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Flexible(
              child: Text(c.name, textAlign: TextAlign.center, style: t.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800))),
          const SizedBox(width: 8),
          const SampleBadge(),
        ]),
        Text(c.type.label, textAlign: TextAlign.center, style: t.textTheme.titleMedium),
        const SizedBox(height: 16),
        Card(child: Padding(padding: const EdgeInsets.all(16), child: Text(c.bio))),
        Card(
          child: Column(children: [
            ListTile(leading: const Icon(Icons.translate_rounded), title: const Text('Languages'), subtitle: Text(c.languages.join(', '))),
            ListTile(
              leading: const Icon(Icons.donut_large_rounded),
              title: const Text('Dimensions helped'),
              subtitle: Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Wrap(spacing: 6, runSpacing: 6, children: [
                  for (final d in c.dimensions)
                    Chip(
                      avatar: Icon(d.icon, size: 16, color: d.color(t.brightness)),
                      label: Text(d.label),
                      visualDensity: VisualDensity.compact,
                    ),
                ]),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.devices_rounded),
              title: const Text('Session modes'),
              subtitle: Text(c.modes.map((m) => m.label).join(' · ')),
            ),
            ListTile(
              leading: const Icon(Icons.payments_outlined),
              title: const Text('Fee (45 min)'),
              subtitle: Text(c.priceLabel),
            ),
            const ListTile(
              leading: Icon(Icons.verified_outlined),
              title: Text('Credentials'),
              subtitle: Text('SAMPLE — verification pending real onboarding'),
            ),
          ]),
        ),
        const SizedBox(height: 8),
        FilledButton.icon(
          onPressed: () {
            Haptics.light();
            context.push('/consult/book/${c.id}');
          },
          icon: const Icon(Icons.calendar_month_rounded),
          label: const Text('Book a session'),
        ),
        const SizedBox(height: 12),
        const DisclaimerNote(),
      ]),
    );
  }
}
