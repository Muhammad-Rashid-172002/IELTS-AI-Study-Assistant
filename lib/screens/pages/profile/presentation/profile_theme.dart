import 'package:flutter/material.dart';

class ProfileColors {
  static const background = Color(0xFF08111F);
  static const surface = Color(0xFF111C2E);
  static const border = Color(0xFF25344C);
  static const text = Color(0xFFF8FAFC);
  static const secondary = Color(0xFFCBD5E1);
  static const muted = Color(0xFF94A3B8);
  static const cyan = Color(0xFF06B6D4);
  static const blue = Color(0xFF2563EB);
  static const violet = Color(0xFF8B5CF6);
  static const green = Color(0xFF22C55E);
  static const orange = Color(0xFFF59E0B);
  static const red = Color(0xFFEF4444);
  static const Color primary = Color(0xFF2563EB);
}

BoxDecoration profilePanel() => BoxDecoration(
  color: ProfileColors.surface,
  borderRadius: BorderRadius.circular(20),
  border: Border.all(color: ProfileColors.border),
  boxShadow: [
    BoxShadow(
      color: Colors.black.withOpacity(.13),
      blurRadius: 18,
      offset: const Offset(0, 8),
    ),
  ],
);

BoxDecoration profileHero() => BoxDecoration(
  gradient: LinearGradient(
    colors: [
      ProfileColors.surface,
      ProfileColors.blue.withOpacity(.18),
      ProfileColors.cyan.withOpacity(.10),
      ProfileColors.violet.withOpacity(.10),
    ],
  ),
  borderRadius: BorderRadius.circular(24),
  border: Border.all(color: ProfileColors.cyan.withOpacity(.25)),
);
