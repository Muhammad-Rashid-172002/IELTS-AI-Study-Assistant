// import 'package:flutter/material.dart';
// import 'package:google_fonts/google_fonts.dart';
//
// class AppTheme {
//   static final light = ThemeData(
//     useMaterial3: true,
//     brightness: Brightness.light,
//     colorSchemeSeed: Colors.blue,
//     fontFamily: GoogleFonts.inter().fontFamily,
//   );
// }

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  static final light = ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,

    // GLOBAL FONT
    fontFamily: GoogleFonts.inter().fontFamily,

    // MAIN COLOR SCHEME (soft blue – from your app design)
    colorScheme: ColorScheme.fromSeed(
      seedColor: const Color(0xFF4A79F6),
      brightness: Brightness.light,
    ),

    scaffoldBackgroundColor: const Color(0xFFF4F7FB),

    // APP BAR
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.white,
      elevation: 0,
      centerTitle: false,
      foregroundColor: Colors.black87,
      surfaceTintColor: Colors.transparent,
    ),

    // INPUT DECORATION (TextFields)
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white,
      hintStyle: TextStyle(
        color: Colors.grey.shade500,
        fontSize: 14,
      ),

      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),

      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: Colors.grey.shade300),
      ),

      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: Colors.grey.shade300),
      ),

      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0xFF4A79F6), width: 1.4),
      ),

      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Colors.red, width: 1.2),
      ),
    ),

    // // CARD THEME (for your module cards)
    // cardTheme: CardTheme(
    //   color: Colors.white,
    //   elevation: 2,
    //   surfaceTintColor: Colors.transparent,
    //   shape: RoundedRectangleBorder(
    //     borderRadius: BorderRadius.circular(16),
    //   ),
    //   shadowColor: Colors.black.withOpacity(0.05),
    // ),

    // BUTTON THEME
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: const Color(0xFF4A79F6),
        foregroundColor: Colors.white,
        textStyle: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w700,
        ),
        padding: const EdgeInsets.symmetric(vertical: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    ),

    // TEXT THEME
    textTheme: TextTheme(
      headlineLarge: GoogleFonts.inter(
          fontSize: 28, fontWeight: FontWeight.bold, color: Colors.black87),
      headlineMedium: GoogleFonts.inter(
          fontSize: 22, fontWeight: FontWeight.bold, color: Colors.black87),
      headlineSmall: GoogleFonts.inter(
          fontSize: 18, fontWeight: FontWeight.w700, color: Colors.black87),

      bodyLarge: GoogleFonts.inter(
          fontSize: 16, color: Colors.black87, height: 1.4),
      bodyMedium: GoogleFonts.inter(
          fontSize: 14, color: Colors.black87, height: 1.4),
      bodySmall: GoogleFonts.inter(
          fontSize: 12, color: Colors.black54, height: 1.3),
    ),

    // ICONS
    iconTheme: const IconThemeData(color: Colors.black87),
  );
}
