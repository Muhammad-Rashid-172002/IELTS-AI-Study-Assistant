import 'package:flutter/material.dart';

class ProgressColors {
  static const background = Color(0xFF08111F);
  static const surface = Color(0xFF111C2E);
  static const surfaceSoft = Color(0xFF162235);
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
}

BoxDecoration progressPanelDecoration({
  Color? borderColor,
}) {
  return BoxDecoration(
    color: ProgressColors.surface,
    borderRadius: BorderRadius.circular(20),
    border: Border.all(
      color: borderColor ?? ProgressColors.border,
    ),
    boxShadow: [
      BoxShadow(
        color: Colors.black.withOpacity(.12),
        blurRadius: 18,
        offset: const Offset(0, 8),
      ),
    ],
  );
}

BoxDecoration progressHeroDecoration() {
  return BoxDecoration(
    gradient: LinearGradient(
      colors: [
        ProgressColors.surface,
        ProgressColors.blue.withOpacity(.18),
        ProgressColors.cyan.withOpacity(.10),
        ProgressColors.violet.withOpacity(.10),
      ],
    ),
    borderRadius: BorderRadius.circular(23),
    border: Border.all(
      color: ProgressColors.cyan.withOpacity(.25),
    ),
  );
}
