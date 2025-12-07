import 'package:flutter/material.dart';

class AppColors {
  // 🔵 Brand Primary Colors (AI + IELTS Theme)
  static const Color primaryDark = Color(0xFF0F172A);   // Navy blue
  static const Color primaryMid = Color(0xFF1E293B);    // Slate blue
  static const Color primaryLight = Color(0xFF334155);  // Soft blue

  // 🟦 Accent Color (Professional IELTS Blue)
  static const Color accentBlue = Color(0xFF3B82F6);

  // ✨ AI Highlight Colors
  static const Color aiPurple = Color(0xFF6D28D9);
  static const Color aiCyan = Color(0xFF06B6D4);

  // ⚪ Neutral Colors
  static const Color white = Colors.white;
  static const Color lightGrey = Color(0xFFE2E8F0);
  static const Color darkGrey = Color(0xFF94A3B8);

  // 🖤 Text Colors
  static const Color textPrimary = Color(0xFFFFFFFF);
  static const Color textSecondary = Color(0xCCFFFFFF);
  static const Color textMuted = Color(0x99FFFFFF);

  // 🟢 Success / Warning / Error
  static const Color success = Color(0xFF10B981);
  static const Color warning = Color(0xFFF59E0B);
  static const Color error = Color(0xFFEF4444);

  // 🌫️ Glassmorphism Overlay
  static Color glassWhite = Colors.white.withOpacity(0.12);
  static Color glassBorder = Colors.white.withOpacity(0.25);

  // 🔥 Shadows
  static Color softShadow = Colors.black.withOpacity(0.20);
  static Color glowWhite = Colors.white.withOpacity(0.30);

  // 🎨 Gradient for Background
  static const LinearGradient mainGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      primaryDark,
      primaryMid,
      primaryLight,
    ],
  );
}
