import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/services/haptics.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/fx.dart';
import '../plus/plus_ui.dart';
import 'org.dart';

/// Profile entries: company team (join / leave) and "For organisations".
class OrgProfileCard extends ConsumerWidget {
  const OrgProfileCard({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final m = ref.watch(orgProvider);
    return Card(
      child: Column(children: [
        if (m == null)
          ListTile(
            key: const Key('org-join'),
            leading: const Icon(Icons.badge_outlined),
            title: const Text('Join with company code'),
            subtitle: const Text('Your employer may offer OneUP Plus'),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: Haptics.tap(() => context.push('/org/join')),
          )
        else
          ListTile(
            key: const Key('org-member'),
            leading: const Icon(Icons.apartment_rounded),
            title: Text(m.company),
            subtitle: const Text('Company plan · employer sees only anonymous team averages'),
            trailing: TextButton(key: const Key('org-leave'), onPressed: () => confirmLeaveTeam(context, ref), child: const Text('Leave')),
          ),
        ListTile(
          key: const Key('org-for-orgs'),
          leading: const Icon(Icons.business_center_outlined),
          title: const Text('For organisations'),
          subtitle: const Text('See the demo team dashboard'),
          trailing: const Icon(Icons.chevron_right_rounded),
          onTap: Haptics.tap(() => context.push('/org')),
        ),
      ]),
    );
  }
}

Future<void> confirmLeaveTeam(BuildContext context, WidgetRef ref) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (c) => AlertDialog(
      key: const Key('org-leave-dialog'),
      title: const Text('Leave your company team?'),
      content: const Text('You stop counting toward team averages and lose the Company plan. Your own data stays on your device.'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Stay')),
        FilledButton(key: const Key('org-leave-confirm'), onPressed: () => Navigator.pop(c, true), child: const Text('Leave team')),
      ],
    ),
  );
  if (ok == true) await ref.read(orgProvider.notifier).leave();
}

/// Employee side: enter code → explicit consent → join.
class OrgJoinScreen extends ConsumerStatefulWidget {
  const OrgJoinScreen({super.key});
  @override
  ConsumerState<OrgJoinScreen> createState() => _OrgJoinScreenState();
}

class _OrgJoinScreenState extends ConsumerState<OrgJoinScreen> {
  final _code = TextEditingController();
  String? _company, _error;
  bool _consent = false;

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    Widget point(IconData i, String s, {bool ok = true}) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 5),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Icon(i, size: 20, color: ok ? Colors.green : t.colorScheme.error),
            const SizedBox(width: 10),
            Expanded(child: Text(s)),
          ]),
        );
    return Scaffold(
      appBar: AppBar(title: const Text('Join your company')),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        if (_company == null) ...[
          Text('Enter the code from your employer', style: t.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
          const SizedBox(height: 4),
          Text('Demo code: STELLAR-DEMO', style: t.textTheme.bodySmall),
          const SizedBox(height: 12),
          TextField(
            key: const Key('org-code'),
            controller: _code,
            textCapitalization: TextCapitalization.characters,
            decoration: InputDecoration(labelText: 'Company code', errorText: _error, border: const OutlineInputBorder()),
          ),
          const SizedBox(height: 12),
          FilledButton(
            key: const Key('org-code-next'),
            onPressed: () => setState(() {
              _company = OrgController.lookup(_code.text);
              _error = _company == null ? 'Code not recognised (demo: STELLAR-DEMO)' : null;
            }),
            child: const Text('Continue'),
          ),
        ] else ...[
          Column(key: const Key('org-consent'), crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Before you join $_company', style: t.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
            const SizedBox(height: 12),
            Text('Your employer sees ONLY', style: t.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800)),
            point(Icons.check_circle_rounded, 'Anonymous, aggregated team averages'),
            point(Icons.check_circle_rounded, 'Only for groups of $orgMinGroup or more people'),
            point(Icons.check_circle_rounded, 'How many people joined (participation)'),
            const SizedBox(height: 8),
            Text('Your employer NEVER sees', style: t.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800)),
            point(Icons.block_rounded, 'Your individual answers or scores', ok: false),
            point(Icons.block_rounded, 'Your reflections, journal or mood', ok: false),
            point(Icons.block_rounded, 'Whether you used crisis or safety help', ok: false),
            const SizedBox(height: 8),
            point(Icons.logout_rounded, 'You can leave the team anytime from Profile.'),
            const SizedBox(height: 8),
            Text(orgDpdpNote, style: t.textTheme.bodySmall),
            CheckboxListTile(
              key: const Key('org-consent-check'),
              contentPadding: EdgeInsets.zero,
              value: _consent,
              onChanged: (v) => setState(() => _consent = v ?? false),
              title: const Text('I agree to share anonymous, aggregated data with my employer'),
              controlAffinity: ListTileControlAffinity.leading,
            ),
            const SizedBox(height: 8),
            OverflowBar(alignment: MainAxisAlignment.spaceBetween, overflowAlignment: OverflowBarAlignment.end, children: [
              TextButton(onPressed: () => context.pop(), child: const Text('Not now')),
              PlusButton(
                key: const Key('org-join-confirm'),
                label: 'Join team',
                onPressed: !_consent
                    ? null
                    : () async {
                        final ok = await ref.read(orgProvider.notifier).join(_code.text, consent: _consent);
                        if (ok && context.mounted) {
                          ScaffoldMessenger.of(context)
                              .showSnackBar(const SnackBar(content: Text('Joined (demo). Company plan includes OneUP Plus.')));
                          context.pop();
                        }
                      },
              ),
            ]),
          ]),
        ],
      ]),
    );
  }
}

/// Employer side: SAMPLE HR dashboard. Only aggregates with k ≥ 5; no individual drill-down.
class OrgDashboardScreen extends StatelessWidget {
  const OrgDashboardScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final d = sampleOrgDashboard();
    Widget section(String title, Widget child, {Key? key}) => Padding(
          padding: const EdgeInsets.only(top: 12),
          child: GlassCard(
            child: Column(key: key, crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, style: t.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800)),
              const SizedBox(height: 10),
              child,
            ]),
          ),
        );
    Widget bar(String label, double v, Color c) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(children: [
            SizedBox(width: 108, child: Text(label, style: t.textTheme.bodySmall, overflow: TextOverflow.ellipsis)),
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(99),
                child: LinearProgressIndicator(value: v / 100, minHeight: 10, color: c, backgroundColor: c.withOpacity(0.15)),
              ),
            ),
            SizedBox(width: 36, child: Text(v.round().toString(), textAlign: TextAlign.end, style: t.textTheme.bodySmall)),
          ]),
        );
    final maxT = d.trend.map((e) => e.$2).reduce((a, b) => a > b ? a : b);
    return Scaffold(
      appBar: AppBar(title: const Text('Team dashboard (demo)')),
      body: ListView(key: const Key('org-dashboard'), padding: const EdgeInsets.all(16), children: [
        PlusFrame(
          glow: 0.5,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const PlusBadge(small: true),
              const SizedBox(height: 6),
              Text(d.company, style: t.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900)),
              const SizedBox(height: 6),
              Text('${(d.participation * 100).round()}% participation',
                  key: const Key('org-participation'),
                  style: t.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900, color: plusOn(context))),
              Text('${d.participants} of ${d.eligible} employees opted in (SAMPLE)', style: t.textTheme.bodySmall),
            ]),
          ),
        ),
        const SizedBox(height: 8),
        Container(
          key: const Key('org-privacy'),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(14), color: t.colorScheme.surfaceContainerHighest.withOpacity(0.5)),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Icon(Icons.shield_outlined, size: 20),
            const SizedBox(width: 10),
            Expanded(
                child: Text(
                    'Anonymous averages only. Groups under $orgMinGroup people are hidden. No individual drill-down, and no mood or crisis data is ever shown.',
                    style: t.textTheme.bodySmall)),
          ]),
        ),
        section(
          'Team average by dimension',
          d.average == null
              ? const Text(orgNotEnough)
              : Column(children: [for (final dim in WellnessDimension.values) bar(dim.label, d.average![dim]!, dim.dark)]),
          key: const Key('org-dimensions'),
        ),
        section(
          'Overall trend (SAMPLE)',
          SizedBox(
            height: 120,
            child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
              for (final (m, v) in d.trend)
                Expanded(
                  child: Column(mainAxisAlignment: MainAxisAlignment.end, children: [
                    Text(v.round().toString(), style: t.textTheme.labelSmall),
                    const SizedBox(height: 2),
                    Container(
                      height: 80 * v / maxT,
                      margin: const EdgeInsets.symmetric(horizontal: 6),
                      decoration: BoxDecoration(gradient: plusGradient, borderRadius: BorderRadius.circular(6)),
                    ),
                    const SizedBox(height: 4),
                    Text(m, style: t.textTheme.labelSmall),
                  ]),
                ),
            ]),
          ),
          key: const Key('org-trend'),
        ),
        section(
          'Departments',
          Column(children: [
            for (final dep in d.departments)
              Padding(
                key: Key('org-dept-${dep.name}'),
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(children: [
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(dep.name, style: const TextStyle(fontWeight: FontWeight.w700)),
                      Text(dep.hidden ? orgNotEnough : 'Overall ${overall(dep.avg!).round()} / 100', style: t.textTheme.bodySmall),
                    ]),
                  ),
                  Icon(dep.hidden ? Icons.visibility_off_outlined : Icons.groups_rounded, size: 20),
                ]),
              ),
          ]),
          key: const Key('org-departments'),
        ),
        section(
          'Top focus areas & suggested programs (SAMPLE)',
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            for (final f in d.focusAreas)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(f.icon, color: f.dark),
                title: Text(f.label),
                subtitle: Text(samplePrograms[f]!),
              ),
          ]),
          key: const Key('org-focus'),
        ),
        const SizedBox(height: 16),
        PlusButton(key: const Key('org-book-demo'), label: 'Book a demo for your company', onPressed: () => context.push('/org/demo')),
        const SizedBox(height: 12),
        Text('$orgDisclaimer\n\n$orgDpdpNote', key: const Key('org-disclaimer'), style: t.textTheme.bodySmall, textAlign: TextAlign.center),
      ]),
    );
  }
}

/// Demo "book a demo" form. Nothing is sent anywhere.
class OrgDemoFormScreen extends StatefulWidget {
  const OrgDemoFormScreen({super.key});
  @override
  State<OrgDemoFormScreen> createState() => _OrgDemoFormScreenState();
}

class _OrgDemoFormScreenState extends State<OrgDemoFormScreen> {
  final _form = GlobalKey<FormState>();
  String _size = '50–200';
  bool _done = false;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    String? req(String? v) => (v == null || v.trim().isEmpty) ? 'Required' : null;
    return Scaffold(
      appBar: AppBar(title: const Text('Book a demo')),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        if (_done)
          Column(key: const Key('org-demo-done'), children: [
            const Icon(Icons.check_circle_rounded, size: 56, color: Colors.green),
            const SizedBox(height: 8),
            Text('Request saved (demo)', style: t.textTheme.titleLarge),
            const SizedBox(height: 4),
            const Text('This is a demo: nothing was sent and no one will contact you.', textAlign: TextAlign.center),
          ])
        else
          Form(
            key: _form,
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              TextFormField(key: const Key('org-demo-name'), decoration: const InputDecoration(labelText: 'Your name'), validator: req),
              TextFormField(
                key: const Key('org-demo-email'),
                decoration: const InputDecoration(labelText: 'Work email'),
                keyboardType: TextInputType.emailAddress,
                validator: (v) => req(v) ?? (v!.contains('@') ? null : 'Enter a valid email'),
              ),
              TextFormField(key: const Key('org-demo-company'), decoration: const InputDecoration(labelText: 'Company'), validator: req),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: _size,
                decoration: const InputDecoration(labelText: 'Company size'),
                items: [
                  for (final s in ['1–49', '50–200', '201–1000', '1000+']) DropdownMenuItem(value: s, child: Text(s))
                ],
                onChanged: (v) => setState(() => _size = v ?? _size),
              ),
              const SizedBox(height: 20),
              PlusButton(
                key: const Key('org-demo-submit'),
                label: 'Request demo',
                onPressed: () {
                  if (_form.currentState!.validate()) setState(() => _done = true);
                },
              ),
              const SizedBox(height: 12),
              Text('Demo form: nothing is sent or stored.', style: t.textTheme.bodySmall, textAlign: TextAlign.center),
            ]),
          ),
      ]),
    );
  }
}
