import 'package:flutter/material.dart';

class AppTheme {
  static const Color green = Color(0xFF007A3D);
  static const Color darkGreen = Color(0xFF004F2D);
  static const Color gold = Color(0xFFFFD100);
  static const Color black = Color(0xFF111111);
  static const Color softBg = Color(0xFFF7F8F5);

  static ThemeData lightTheme = ThemeData(
    useMaterial3: true,
    scaffoldBackgroundColor: softBg,
    primaryColor: green,
    colorScheme: ColorScheme.fromSeed(
      seedColor: green,
      primary: green,
      secondary: gold,
      surface: Colors.white,
    ),
    cardTheme: CardThemeData(
      color: Colors.white,
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: green,
      foregroundColor: Colors.white,
      centerTitle: true,
      elevation: 0,
    ),
  );
}
