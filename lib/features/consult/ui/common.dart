import 'package:flutter/material.dart';
import '../data/consult_models.dart';

const kConsultDisclaimer = 'Consultants shown are SAMPLE profiles for demonstration, not real practitioners. OneUp is for wellness '
    'awareness, not medical diagnosis. In an emergency, contact your local emergency services. '
    '[VERIFY: official India emergency / mental-health helpline numbers before listing any]';

String fmtDay(DateTime d) {
  const w = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
  const m = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
  return '${w[d.weekday - 1]} ${d.day} ${m[d.month - 1]}';
}

String fmtTime(DateTime d) {
  final h = d.hour % 12 == 0 ? 12 : d.hour % 12;
  return '$h:${d.minute.toString().padLeft(2, '0')} ${d.hour < 12 ? 'AM' : 'PM'}';
}

class SampleBadge extends StatelessWidget {
  const SampleBadge({super.key});
  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(color: t.colorScheme.tertiaryContainer, borderRadius: BorderRadius.circular(8)),
      child: Text('SAMPLE', style: t.textTheme.labelSmall?.copyWith(color: t.colorScheme.onTertiaryContainer, fontWeight: FontWeight.w800)),
    );
  }
}

class ConsultantAvatar extends StatelessWidget {
  const ConsultantAvatar({super.key, required this.c, this.radius = 26});
  final Consultant c;
  final double radius;
  @override
  Widget build(BuildContext context) => CircleAvatar(
        radius: radius,
        backgroundColor: Theme.of(context).colorScheme.primaryContainer,
        child: Icon(c.type.icon, size: radius, color: Theme.of(context).colorScheme.onPrimaryContainer),
      );
}

class DisclaimerNote extends StatelessWidget {
  const DisclaimerNote({super.key});
  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    return Card(
      color: t.colorScheme.surfaceContainerHighest,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(Icons.health_and_safety_outlined, color: t.colorScheme.primary),
          const SizedBox(width: 10),
          Expanded(child: Text(kConsultDisclaimer, style: t.textTheme.bodySmall)),
        ]),
      ),
    );
  }
}
