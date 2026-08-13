import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AttendifyTheme {
  AttendifyTheme({required this.light, required this.dark});

  final ThemeData light;
  final ThemeData dark;
}

AttendifyTheme buildAttendifyTheme() {
  // New Palette based on reference
  const background = Color(0xFF0B1121); // Dark blue background
  const surface = Color(0xFF151A2D); // Slightly lighter blue for cards/surfaces
  const primary = Color(0xFF3B82F6); // Bright Blue
  const secondary = Color(0xFF6366F1); // Indigo
  const accent = Color(0xFF0EA5E9); // Sky Blue
  const textPrimary = Colors.white;
  const textSecondary = Color(0xFF94A3B8); // Slate 400

  final baseTextTheme = GoogleFonts.outfitTextTheme();

  final dark = ThemeData.dark(useMaterial3: true).copyWith(
    brightness: Brightness.dark,
    scaffoldBackgroundColor: background,
    colorScheme: ColorScheme.fromSeed(
      seedColor: primary,
      primary: primary,
      secondary: secondary,
      tertiary: accent,
      surface: surface,
      brightness: Brightness.dark,
    ),
    textTheme: baseTextTheme
        .apply(bodyColor: textPrimary, displayColor: textPrimary)
        .copyWith(
          bodyMedium: baseTextTheme.bodyMedium?.copyWith(color: textSecondary),
          bodySmall: baseTextTheme.bodySmall?.copyWith(color: textSecondary),
        ),
    cardTheme: CardThemeData(
      elevation: 0,
      color: surface.withValues(alpha: 0.7),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.white.withValues(alpha: 0.05), width: 1),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: const Color(0xFF1E293B), // Slate 800
      hintStyle: const TextStyle(color: Color(0xFF64748B)), // Slate 500
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.05)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: primary, width: 1),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: primary,
        foregroundColor: Colors.white,
        elevation: 0,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
      ),
    ),
  );

  // Light theme is not prioritized but keeping a placeholder or mapping it to dark for now
  // as the request is specific to the dark UI style.
  // For safety, we'll make light theme similar to dark or just basic light.
  // Given the strict UI style request, let's make the "light" theme also dark
  // to enforce the look, or just provide a basic light version.
  // Let's stick to the requested dark style for both to ensure consistency if system theme varies.

  return AttendifyTheme(light: dark, dark: dark);
}
