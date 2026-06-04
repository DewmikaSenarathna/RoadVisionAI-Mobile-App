import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

ThemeData buildRoadVisionTheme() {
  const background = Color(0xFF06131B);
  const surface = Color(0xFF0A1A26);
  const surfaceElevated = Color(0xFF102437);

  final colorScheme = ColorScheme.fromSeed(
    seedColor: const Color(0xFF67EAD6),
    brightness: Brightness.dark,
    surface: surface,
  ).copyWith(
    primary: const Color(0xFF67EAD6),
    secondary: const Color(0xFF9AB0FF),
    tertiary: const Color(0xFFFFB66B),
    surface: surface,
    surfaceContainerHighest: surfaceElevated,
  );

  return ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    colorScheme: colorScheme,
    scaffoldBackgroundColor: background,
    textTheme: GoogleFonts.manropeTextTheme().apply(
      bodyColor: Colors.white,
      displayColor: Colors.white,
    ).copyWith(
      displaySmall: GoogleFonts.playfairDisplay(
        fontSize: 40,
        fontWeight: FontWeight.w600,
        letterSpacing: -1.0,
        color: Colors.white,
      ),
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.transparent,
      foregroundColor: Colors.white,
      elevation: 0,
      centerTitle: false,
    ),
    cardTheme: const CardThemeData(
      color: surface,
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(24))),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white.withValues(alpha: 0.04),
      hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.45)),
      labelStyle: TextStyle(color: Colors.white.withValues(alpha: 0.72)),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.12)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.12)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: const BorderSide(color: Color(0xFF67EAD6), width: 1.2),
      ),
    ),
  );
}