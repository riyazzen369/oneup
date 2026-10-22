import '../router/nav.dart';
import 'package:flutter/foundation.dart';
import '../../core/services/haptics.dart';
import 'package:flutter/material.dart';

import 'package:url_launcher/url_launcher.dart';

import '../config/env.dart';

class Helpline {
  const Helpline(this.name, this.number, {this.verified = false});
  final String name;
  final String number;
  final bool verified;
}

/// From spec helpline_card. Only "verified" items show in production builds; unverified
/// ones appear only in debug or demo builds with a "verify before launch" note.
const kHelplines = [
  Helpline('Emergency services', '112', verified: true),
  Helpline('Tele-MANAS (Govt. of India mental health helpline)', '14416'),
];

bool get showUnverifiedHelplines => kDebugMode || !Env.isConfigured;

List<Helpline> visibleHelplines({bool? showUnverified}) =>
    kHelplines.where((h) => h.verified || (showUnverified ?? showUnverifiedHelplines)).toList();

/// Full-screen helpline card (crisis protocol). Calm, brief, no probing questions, no suggestions.
class CrisisScreen extends StatefulWidget {
  const CrisisScreen({super.key});
  @override
  State<CrisisScreen> createState() => _CrisisScreenState();
}

class _CrisisScreenState extends State<CrisisScreen> {
  @override
  void initState() {
    super.initState();
    Haptics.medium();
  }

  Future<void> _call(String n) async {
    final ok = await launchUrl(Uri(scheme: 'tel', path: n));
    if (!ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Please dial $n from your phone')));
    }
  }

  void _close() => context.popOrHome();

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    return Scaffold(
      backgroundColor: t.colorScheme.surface,
      body: SafeArea(
        child: ListView(padding: const EdgeInsets.all(24), children: [
          Align(
            alignment: Alignment.centerRight,
            child: IconButton(tooltip: 'Close', onPressed: Haptics.tap(_close), icon: const Icon(Icons.close_rounded)),
          ),
          Icon(Icons.favorite_rounded, size: 64, color: t.colorScheme.primary),
          const SizedBox(height: 16),
          Text("You don't have to go through this alone",
              textAlign: TextAlign.center, style: t.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800)),
          const SizedBox(height: 12),
          Text(
            'It sounds like things are really hard right now. Please reach out to someone you trust, '
            'or contact emergency or crisis services now. If you are in immediate danger, call emergency services.',
            textAlign: TextAlign.center,
            style: t.textTheme.bodyLarge,
          ),
          const SizedBox(height: 24),
          for (final h in visibleHelplines())
            Card(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
                child: Row(children: [
                  Icon(h.verified ? Icons.emergency_rounded : Icons.support_agent_rounded, color: t.colorScheme.error),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(h.name, style: t.textTheme.titleMedium),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text(h.number, style: t.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800)),
                      ),
                      if (!h.verified) Text('Verify before launch', style: t.textTheme.labelSmall?.copyWith(color: t.colorScheme.error)),
                    ]),
                  ),
                  const SizedBox(width: 8),
                  FilledButton.icon(
                    style: FilledButton.styleFrom(minimumSize: const Size(0, 48)),
                    onPressed: Haptics.tap(() => _call(h.number)),
                    icon: const Icon(Icons.call_rounded),
                    label: const Text('Call'),
                  ),
                ]),
              ),
            ),
          const SizedBox(height: 16),
          Text('I can stay here with you. You can also message or call a trusted friend or family member right now.',
              textAlign: TextAlign.center, style: t.textTheme.bodyMedium),
          const SizedBox(height: 24),
          OutlinedButton(onPressed: Haptics.tap(_close), child: const Text('Back')),
          const SizedBox(height: 8),
          Text('OneUp is not a crisis service.', textAlign: TextAlign.center, style: t.textTheme.bodySmall),
        ]),
      ),
    );
  }
}
