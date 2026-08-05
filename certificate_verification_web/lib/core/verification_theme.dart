import 'package:flutter/material.dart';

class VerificationColors {
  static const darkBackground = Color(0xFF050C16);
  static const darkSurface = Color(0xFF0D1828);
  static const darkSurfaceSoft = Color(0xFF14243A);
  static const darkBorder = Color(0xFF263A55);

  static const lightBackground = Color(0xFFF5F7FB);
  static const lightSurface = Color(0xFFFFFFFF);
  static const lightSurfaceSoft = Color(0xFFF0F4FA);
  static const lightBorder = Color(0xFFDCE4EF);

  static const textDark = Color(0xFFF8FAFC);
  static const textLight = Color(0xFF0F172A);
  static const cyan = Color(0xFF22D3EE);
  static const blue = Color(0xFF2563EB);
  static const violet = Color(0xFF7C3AED);
  static const green = Color(0xFF16A34A);
  static const orange = Color(0xFFF59E0B);
  static const red = Color(0xFFEF4444);

  static const premiumGradient = LinearGradient(
    colors: [cyan, blue, violet],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}

class VerificationTheme {
  static ThemeData get dark => _build(Brightness.dark);
  static ThemeData get light => _build(Brightness.light);

  static ThemeData _build(Brightness brightness) {
    final dark = brightness == Brightness.dark;
    final background = dark
        ? VerificationColors.darkBackground
        : VerificationColors.lightBackground;
    final surface = dark
        ? VerificationColors.darkSurface
        : VerificationColors.lightSurface;
    final border = dark
        ? VerificationColors.darkBorder
        : VerificationColors.lightBorder;
    final text = dark
        ? VerificationColors.textDark
        : VerificationColors.textLight;

    final scheme = ColorScheme.fromSeed(
      seedColor: VerificationColors.blue,
      brightness: brightness,
      surface: surface,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor: background,
      fontFamily: 'Inter',
      textTheme: ThemeData(brightness: brightness).textTheme.apply(
            bodyColor: text,
            displayColor: text,
          ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surface,
        hintStyle: TextStyle(
          color: text.withOpacity(.48),
        ),
        labelStyle: TextStyle(
          color: text.withOpacity(.70),
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide(color: border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide(color: border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(
            color: VerificationColors.cyan,
            width: 1.5,
          ),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(0, 54),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(17),
          ),
          textStyle: const TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(0, 52),
          side: BorderSide(color: border),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(17),
          ),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: dark
            ? VerificationColors.darkSurfaceSoft
            : VerificationColors.textLight,
      ),
    );
  }
}

class PortalPalette {
  PortalPalette(BuildContext context)
      : dark = Theme.of(context).brightness == Brightness.dark;

  final bool dark;

  Color get background => dark
      ? VerificationColors.darkBackground
      : VerificationColors.lightBackground;
  Color get surface => dark
      ? VerificationColors.darkSurface
      : VerificationColors.lightSurface;
  Color get surfaceSoft => dark
      ? VerificationColors.darkSurfaceSoft
      : VerificationColors.lightSurfaceSoft;
  Color get border => dark
      ? VerificationColors.darkBorder
      : VerificationColors.lightBorder;
  Color get text => dark
      ? VerificationColors.textDark
      : VerificationColors.textLight;
  Color get secondary => text.withOpacity(.72);
  Color get muted => text.withOpacity(.52);
}
