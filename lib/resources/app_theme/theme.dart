import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  static final light = ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,

    // GLOBAL FONT (Excellent for reading-heavy apps)
    fontFamily: GoogleFonts.inter().fontFamily,

    // COLOR SCHEME (Professional IELTS Blue)
    colorScheme: ColorScheme.fromSeed(
      seedColor: const Color(0xFF3F6AE1), // premium blue
      brightness: Brightness.light,
    ),

    scaffoldBackgroundColor: const Color(0xFFF6F8FC),

    // APP BAR
    appBarTheme: AppBarTheme(
      backgroundColor: Colors.white,
      elevation: 0,
      centerTitle: false,
      titleTextStyle: GoogleFonts.inter(
        fontSize: 18,
        fontWeight: FontWeight.w700,
        color: Colors.black87,
      ),
      iconTheme: const IconThemeData(color: Colors.black87),
      surfaceTintColor: Colors.transparent,
    ),

    // TEXT FIELDS
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white,
      hintStyle: TextStyle(
        color: Colors.grey.shade500,
        fontSize: 14,
      ),
      labelStyle: const TextStyle(fontWeight: FontWeight.w600),

      contentPadding:
          const EdgeInsets.symmetric(horizontal: 18, vertical: 16),

      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide.none,
      ),

      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide:
            const BorderSide(color: Color(0xFF3F6AE1), width: 1.4),
      ),
    ),

    // CARD THEME (Modules / Practice / Mock Tests)
    cardTheme: CardThemeData(
  color: Colors.white,
  elevation: 2,
  surfaceTintColor: Colors.transparent,
  shadowColor: Colors.black.withOpacity(0.06),
  shape: RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(18),
  ),
),


    // PRIMARY BUTTON
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: const Color(0xFF3F6AE1),
        foregroundColor: Colors.white,
        textStyle: const TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w700,
        ),
        padding: const EdgeInsets.symmetric(vertical: 16),
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    ),

    // SECONDARY BUTTON
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: const Color(0xFF3F6AE1),
        textStyle: const TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w600,
        ),
        side: const BorderSide(color: Color(0xFF3F6AE1)),
        padding: const EdgeInsets.symmetric(vertical: 16),
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    ),

    // TEXT THEME (Optimized for reading & study)
    textTheme: TextTheme(
      headlineLarge: GoogleFonts.inter(
        fontSize: 30,
        fontWeight: FontWeight.bold,
        color: Colors.black87,
      ),
      headlineMedium: GoogleFonts.inter(
        fontSize: 22,
        fontWeight: FontWeight.bold,
        color: Colors.black87,
      ),
      headlineSmall: GoogleFonts.inter(
        fontSize: 18,
        fontWeight: FontWeight.w700,
        color: Colors.black87,
      ),
      bodyLarge: GoogleFonts.inter(
        fontSize: 16,
        height: 1.6,
        color: Colors.black87,
      ),
      bodyMedium: GoogleFonts.inter(
        fontSize: 14,
        height: 1.6,
        color: Colors.black87,
      ),
      bodySmall: GoogleFonts.inter(
        fontSize: 12,
        height: 1.5,
        color: Colors.black54,
      ),
    ),

    // ICONS
    iconTheme: const IconThemeData(
      color: Colors.black87,
      size: 22,
    ),

    dividerTheme: DividerThemeData(
      color: Colors.grey.shade200,
      thickness: 1,
    ),
  );
}
