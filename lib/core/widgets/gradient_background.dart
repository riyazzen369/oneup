import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

class GradientBackground extends StatelessWidget {
  const GradientBackground({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: dark ? [const Color(0xFF1B1640), AppColors.darkBg] : [const Color(0xFFEDEBFF), AppColors.lightBg],
        ),
      ),
      child: child,
    );
  }
}

class PlaceholderPage extends StatelessWidget {
  const PlaceholderPage({super.key, required this.title, required this.icon, required this.note});
  final String title;
  final IconData icon;
  final String note;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(title), backgroundColor: Colors.transparent),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(28),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Icon(icon, size: 56, color: t.colorScheme.primary),
                const SizedBox(height: 16),
                Text(title, style: t.textTheme.titleLarge),
                const SizedBox(height: 8),
                Text(note, textAlign: TextAlign.center, style: t.textTheme.bodyMedium),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}
