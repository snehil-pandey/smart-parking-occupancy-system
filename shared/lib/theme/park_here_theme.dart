import 'package:flutter/material.dart';

class ParkHereTheme {
  static const black = Color(0xFF141414);
  static const yellow = Color(0xFFFFC928);
  static const ink = Color(0xFF1C1B17);
  static const surface = Color(0xFFFFFCF2);
  static const adminBlue = Color(0xFF315C72);
  static const mint = Color(0xFF8AC6A4);

  static ThemeData userTheme() {
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: yellow,
        primary: black,
        secondary: yellow,
        surface: surface,
      ),
      scaffoldBackgroundColor: surface,
      fontFamily: 'Roboto',
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: black,
          foregroundColor: Colors.white,
          minimumSize: const Size.fromHeight(52),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      ),
    );
  }

  static ThemeData adminTheme() {
    const adminSurface = Color(0xFFFFFBED);
    const adminPrimary = Color(0xFF1C1B17);
    const adminAccent = Color(0xFFFFC928);
    const adminSuccess = Color(0xFF2E7D32);
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: adminAccent,
        primary: adminPrimary,
        secondary: adminAccent,
        tertiary: adminSuccess,
        surface: Colors.white,
        error: const Color(0xFFB3261E),
      ),
      scaffoldBackgroundColor: adminSurface,
      appBarTheme: const AppBarTheme(
        backgroundColor: adminSurface,
        foregroundColor: adminPrimary,
        elevation: 0,
        centerTitle: false,
      ),
      cardTheme: const CardThemeData(
        color: Colors.white,
        elevation: 1,
        shadowColor: Color(0x1A000000),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(12)),
          side: BorderSide(color: Color(0xFFE8DFC1)),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: Colors.white,
        indicatorColor: adminAccent.withAlpha(80),
        labelTextStyle: WidgetStateProperty.all(
          const TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: Colors.white,
        selectedIconTheme: const IconThemeData(color: adminPrimary),
        selectedLabelTextStyle: const TextStyle(
          color: adminPrimary,
          fontWeight: FontWeight.w700,
        ),
        indicatorColor: adminAccent.withAlpha(90),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: adminPrimary,
          foregroundColor: Colors.white,
          minimumSize: const Size(0, 46),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: adminPrimary,
          side: const BorderSide(color: Color(0xFFDAC36A)),
          minimumSize: const Size(0, 44),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: const Color(0xFFFFF6D5),
        selectedColor: adminAccent.withAlpha(110),
        side: const BorderSide(color: Color(0xFFE8D58A)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }
}
