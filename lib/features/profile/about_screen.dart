import 'package:flutter/material.dart';
import '../../core/widgets/oneup_logo.dart';
import '../consent/consent_screen.dart' show kDisclaimer;

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('About')),
      body: ListView(padding: const EdgeInsets.all(24), children: [
        const Center(child: OneUpLogo(size: 96)),
        const SizedBox(height: 16),
        Text('OneUp', textAlign: TextAlign.center, style: t.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700)),
        Text('Version 0.2.0', textAlign: TextAlign.center, style: t.textTheme.bodySmall),
        const SizedBox(height: 24),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(children: [
              Text('A product of StellarOne Healthcare Pvt Ltd', style: t.textTheme.titleSmall),
              const SizedBox(height: 12),
              // Dark backdrop keeps the supplied dark-background logo legible in light mode.
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: const Color(0xFF0E1020), borderRadius: BorderRadius.circular(12)),
                child: Image.asset('assets/images/stellarone_logo.png', height: 40, semanticLabel: 'StellarOne logo'),
              ),
            ]),
          ),
        ),
        const Card(
          child: ListTile(leading: Icon(Icons.info_outline_rounded), title: Text(kDisclaimer)),
        ),
      ]),
    );
  }
}
