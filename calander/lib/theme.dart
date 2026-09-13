import 'package:flutter/material.dart';

ThemeData calanderTheme(Brightness brightness) {
  final dark = brightness == Brightness.dark;
  final background = Color(dark ? 0xFF10151F : 0xFFF7F9FC);
  final surface = Color(dark ? 0xFF1A2230 : 0xFFFFFFFF);
  final text = Color(dark ? 0xFFF3F6FC : 0xFF172338);
  final muted = Color(dark ? 0xFFA7B5CA : 0xFF5F6E83);
  final border = Color(dark ? 0xFF334155 : 0xFFDEE5EF);
  final scheme = ColorScheme.fromSeed(
    seedColor: const Color(0xFF285BE0),
    brightness: brightness,
    primary: Color(dark ? 0xFF90B1FF : 0xFF285BE0),
    surface: surface,
    onSurface: text,
    onSurfaceVariant: muted,
    outline: border,
    primaryContainer: Color(dark ? 0xFF202F4D : 0xFFEAF0FF),
    onPrimaryContainer: text,
  );
  final base = ThemeData(
    useMaterial3: true,
    fontFamily: 'Inter',
    brightness: brightness,
    colorScheme: scheme,
  );
  return base.copyWith(
    scaffoldBackgroundColor: background,
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: surface,
      indicatorColor: scheme.primaryContainer,
      labelTextStyle: WidgetStateProperty.resolveWith(
        (states) => TextStyle(
          fontFamily: 'Inter',
          fontSize: 11,
          fontWeight: FontWeight.w500,
          color: states.contains(WidgetState.selected) ? scheme.primary : muted,
        ),
      ),
      iconTheme: WidgetStateProperty.resolveWith(
        (states) => IconThemeData(
          size: 22,
          color: states.contains(WidgetState.selected) ? scheme.primary : muted,
        ),
      ),
    ),
    textTheme: base.textTheme
        .copyWith(
          headlineLarge: TextStyle(
            fontSize: 36,
            height: 1.22,
            fontWeight: FontWeight.w700,
            color: text,
            letterSpacing: -0.8,
          ),
          headlineMedium: TextStyle(
            fontSize: 28,
            height: 1.28,
            fontWeight: FontWeight.w700,
            color: text,
            letterSpacing: -0.6,
          ),
          bodyLarge: TextStyle(fontSize: 15, height: 1.47, color: text),
          bodyMedium: TextStyle(fontSize: 13, height: 1.46, color: muted),
        )
        .apply(fontFamily: 'Inter'),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: surface,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      hintStyle: TextStyle(color: muted, fontSize: 15),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: scheme.primary, width: 2),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: Color(dark ? 0xFF4676EC : 0xFF285BE0),
        foregroundColor: Colors.white,
        minimumSize: const Size(double.infinity, 52),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        textStyle: const TextStyle(
          fontFamily: 'Inter',
          fontSize: 15,
          fontWeight: FontWeight.w600,
        ),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        backgroundColor: surface,
        foregroundColor: text,
        minimumSize: const Size(double.infinity, 52),
        side: BorderSide(color: border),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        textStyle: const TextStyle(
          fontFamily: 'Inter',
          fontSize: 15,
          fontWeight: FontWeight.w600,
        ),
      ),
    ),
  );
}
