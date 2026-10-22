import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/services/haptics.dart';

/// Floating gradient entry to OneUp Companion (no extra tab).
class CompanionButton extends StatelessWidget {
  const CompanionButton({super.key});
  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Open OneUp Companion',
      excludeSemantics: true,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: const LinearGradient(colors: [Color(0xFFFF6B8B), Color(0xFF8E5BF5), Color(0xFF16C2B0)]),
          borderRadius: BorderRadius.circular(30),
          boxShadow: [BoxShadow(color: const Color(0xFF8E5BF5).withOpacity(0.45), blurRadius: 18, offset: const Offset(0, 6))],
        ),
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            borderRadius: BorderRadius.circular(30),
            onTap: () {
              Haptics.light();
              context.push('/companion');
            },
            child: const Padding(
              padding: EdgeInsets.symmetric(horizontal: 18, vertical: 14),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.chat_bubble_rounded, color: Colors.white),
                SizedBox(width: 8),
                Text('Companion', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}
