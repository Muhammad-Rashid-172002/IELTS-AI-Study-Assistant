import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  static const background = Color(0xFF07111F);
  static const surface = Color(0xFF101C2E);
  static const surfaceHigh = Color(0xFF182A40);
  static const text = Color(0xFFF8FAFC);
  static const textMuted = Color(0xFF94A3B8);
  static const blue = Color(0xFF2563EB);
  static const cyan = Color(0xFF22D3EE);
  static const violet = Color(0xFF8B5CF6);
  static const success = Color(0xFF34D399);
  static const danger = Color(0xFFFB7185);

  /// The learner experience is intentionally dark-first. Defining the system
  /// here keeps framework-owned surfaces (dialogs, menus, fields, snackbars and
  /// progress indicators) consistent with the handcrafted learning screens.
  static final dark = ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    fontFamily: GoogleFonts.inter().fontFamily,
    colorScheme: const ColorScheme.dark(
      primary: cyan,
      onPrimary: Color(0xFF04131D),
      secondary: violet,
      onSecondary: Colors.white,
      surface: surface,
      onSurface: text,
      error: danger,
      onError: Color(0xFF23070C),
    ),
    scaffoldBackgroundColor: background,
    canvasColor: background,
    splashColor: cyan.withOpacity(.10),
    highlightColor: cyan.withOpacity(.06),
    focusColor: cyan.withOpacity(.16),
    progressIndicatorTheme: const ProgressIndicatorThemeData(
      color: cyan,
      linearTrackColor: surfaceHigh,
      circularTrackColor: surfaceHigh,
    ),
    textTheme: GoogleFonts.interTextTheme(
      const TextTheme(
        displayLarge: TextStyle(
          color: text,
          fontSize: 48,
          height: 1.05,
          fontWeight: FontWeight.w900,
          letterSpacing: -1.4,
        ),
        headlineLarge: TextStyle(
          color: text,
          fontSize: 28,
          height: 1.15,
          fontWeight: FontWeight.w900,
          letterSpacing: -.7,
        ),
        headlineMedium: TextStyle(
          color: text,
          fontSize: 21,
          height: 1.2,
          fontWeight: FontWeight.w800,
          letterSpacing: -.35,
        ),
        titleLarge: TextStyle(
          color: text,
          fontSize: 18,
          height: 1.25,
          fontWeight: FontWeight.w800,
        ),
        titleMedium: TextStyle(
          color: text,
          fontSize: 16,
          height: 1.3,
          fontWeight: FontWeight.w700,
        ),
        bodyLarge: TextStyle(color: text, fontSize: 16, height: 1.5),
        bodyMedium: TextStyle(color: textMuted, fontSize: 14, height: 1.5),
        bodySmall: TextStyle(color: textMuted, fontSize: 12, height: 1.4),
        labelLarge: TextStyle(
          color: text,
          fontSize: 14,
          fontWeight: FontWeight.w800,
        ),
      ),
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.transparent,
      foregroundColor: text,
      elevation: 0,
      centerTitle: false,
      surfaceTintColor: Colors.transparent,
      titleTextStyle: TextStyle(
        color: text,
        fontSize: 20,
        fontWeight: FontWeight.w800,
        letterSpacing: -.25,
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: surface,
      hintStyle: const TextStyle(color: textMuted, fontSize: 14),
      labelStyle: const TextStyle(color: textMuted),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: Colors.white.withOpacity(.08)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: Colors.white.withOpacity(.08)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: cyan, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: danger),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: danger, width: 1.5),
      ),
    ),
    cardTheme: CardThemeData(
      color: surface,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadii.card),
        side: BorderSide(color: Colors.white.withOpacity(.08)),
      ),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: surfaceHigh,
      selectedColor: cyan.withOpacity(.14),
      disabledColor: surfaceHigh.withOpacity(.55),
      side: BorderSide(color: Colors.white.withOpacity(.08)),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(100)),
      labelStyle: const TextStyle(
        color: textMuted,
        fontSize: 12,
        fontWeight: FontWeight.w700,
      ),
      secondaryLabelStyle: const TextStyle(
        color: cyan,
        fontSize: 12,
        fontWeight: FontWeight.w800,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
    ),
    checkboxTheme: CheckboxThemeData(
      fillColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.selected) ? cyan : surfaceHigh,
      ),
      checkColor: const WidgetStatePropertyAll(Color(0xFF04131D)),
      side: BorderSide(color: Colors.white.withOpacity(.16), width: 1.4),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
    ),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.selected) ? cyan : textMuted,
      ),
      trackColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.selected)
            ? cyan.withOpacity(.28)
            : surfaceHigh,
      ),
      trackOutlineColor: WidgetStatePropertyAll(Colors.white.withOpacity(.08)),
    ),
    listTileTheme: const ListTileThemeData(
      textColor: text,
      iconColor: textMuted,
      contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      minTileHeight: 56,
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: blue,
        foregroundColor: Colors.white,
        disabledBackgroundColor: surfaceHigh,
        disabledForegroundColor: textMuted,
        minimumSize: const Size(48, 52),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
        textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: text,
        minimumSize: const Size(48, 52),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
        side: BorderSide(color: Colors.white.withOpacity(.12)),
        textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: cyan,
        textStyle: const TextStyle(fontWeight: FontWeight.w700),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    ),
    iconButtonTheme: IconButtonThemeData(
      style: IconButton.styleFrom(
        foregroundColor: text,
        highlightColor: cyan.withOpacity(.10),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: surfaceHigh,
      contentTextStyle: const TextStyle(color: text, height: 1.35),
      actionTextColor: cyan,
      behavior: SnackBarBehavior.floating,
      elevation: 12,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    ),
    dividerTheme: DividerThemeData(
      color: Colors.white.withOpacity(.07),
      thickness: 1,
      space: 1,
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: surface,
      modalBackgroundColor: surface,
      surfaceTintColor: Colors.transparent,
      showDragHandle: true,
      dragHandleColor: textMuted,
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: surface,
      surfaceTintColor: Colors.transparent,
      titleTextStyle: const TextStyle(
        color: text,
        fontSize: 20,
        fontWeight: FontWeight.w800,
      ),
      contentTextStyle: const TextStyle(color: textMuted, height: 1.5),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
    ),
    tooltipTheme: TooltipThemeData(
      decoration: BoxDecoration(
        color: surfaceHigh,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white.withOpacity(.08)),
      ),
      textStyle: const TextStyle(color: text, fontSize: 12),
    ),
    textSelectionTheme: const TextSelectionThemeData(
      cursorColor: cyan,
      selectionColor: Color(0x5522D3EE),
      selectionHandleColor: cyan,
    ),
    pageTransitionsTheme: const PageTransitionsTheme(
      builders: {
        TargetPlatform.android: PredictiveBackPageTransitionsBuilder(),
        TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
        TargetPlatform.macOS: CupertinoPageTransitionsBuilder(),
      },
    ),
  );

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
      hintStyle: TextStyle(color: Colors.grey.shade500, fontSize: 14),

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
        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
        padding: const EdgeInsets.symmetric(vertical: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    ),

    // TEXT THEME
    textTheme: TextTheme(
      headlineLarge: GoogleFonts.inter(
        fontSize: 28,
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
        color: Colors.black87,
        height: 1.4,
      ),
      bodyMedium: GoogleFonts.inter(
        fontSize: 14,
        color: Colors.black87,
        height: 1.4,
      ),
      bodySmall: GoogleFonts.inter(
        fontSize: 12,
        color: Colors.black54,
        height: 1.3,
      ),
    ),

    // ICONS
    iconTheme: const IconThemeData(color: Colors.black87),
  );
}

/// Shared tokens for learner-facing screens. Feature screens may compose these
/// tokens differently, while still keeping rhythm and interaction targets
/// consistent across the complete learning journey.
abstract final class AppSpacing {
  static const double xxs = 4;
  static const double xs = 8;
  static const double sm = 12;
  static const double md = 16;
  static const double lg = 20;
  static const double xl = 24;
  static const double xxl = 32;
  static const double page = 20;
}

abstract final class AppRadii {
  static const double control = 16;
  static const double card = 22;
  static const double hero = 28;
  static const double sheet = 30;
}

abstract final class AppMotion {
  static const Duration quick = Duration(milliseconds: 160);
  static const Duration standard = Duration(milliseconds: 260);
  static const Duration reveal = Duration(milliseconds: 520);
  static const Curve emphasized = Curves.easeOutCubic;
}
