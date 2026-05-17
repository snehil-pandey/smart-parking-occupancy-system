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
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: adminBlue,
        primary: adminBlue,
        secondary: mint,
        surface: Colors.white,
      ),
      scaffoldBackgroundColor: const Color(0xFFF6F8F7),
      cardTheme: const CardThemeData(
        color: Colors.white,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(8)),
          side: BorderSide(color: Color(0xFFE1E7E4)),
        ),
      ),
    );
  }
}
