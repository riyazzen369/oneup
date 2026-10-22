import 'package:flutter/material.dart';

/// Original OneUp palette. Each dimension has a light and dark variant,
/// tuned for contrast on its respective background.
enum WellnessDimension {
  emotional('Emotional', Color(0xFFE5487A), Color(0xFFFF7AA2), Icons.favorite_rounded),
  physical('Physical', Color(0xFF1E88E5), Color(0xFF64B5F6), Icons.directions_run_rounded),
  occupational('Occupational', Color(0xFFF57C00), Color(0xFFFFB74D), Icons.work_rounded),
  social('Social', Color(0xFF00897B), Color(0xFF4DD0C1), Icons.groups_rounded),
  spiritual('Spiritual', Color(0xFF7E57C2), Color(0xFFB39DDB), Icons.self_improvement_rounded),
  intellectual('Intellectual', Color(0xFFC79100), Color(0xFFFFD54F), Icons.lightbulb_rounded),
  environmental('Environmental', Color(0xFF43A047), Color(0xFF81C784), Icons.eco_rounded),
  financial('Financial', Color(0xFF3949AB), Color(0xFF8C9EFF), Icons.savings_rounded);

  const WellnessDimension(this.label, this.light, this.dark, this.icon);
  final String label;
  final Color light;
  final Color dark;
  final IconData icon;

  Color color(Brightness b) => b == Brightness.dark ? dark : light;
}

class AppColors {
  static const primary = Color(0xFF5B4BF5);
  static const secondary = Color(0xFF16C2B0);
  static const accent = Color(0xFFFF6B8B);
  static const lightBg = Color(0xFFF6F7FB);
  static const darkBg = Color(0xFF0E1020);
  static const darkSurface = Color(0xFF181B30);

  static const brandGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [primary, Color(0xFF8E5BF5), secondary],
  );

  static List<Color> get wheel => WellnessDimension.values.map((d) => d.light).toList();
}
